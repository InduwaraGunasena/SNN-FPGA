# SNN on FPGA
---

## **1. Input Layer**

* **Neurons:** 256 (1 per pixel).
* **Spike encoding:** Use **rate coding** — pixel intensity determines spike probability per timestep.
* **Timesteps:** 32–64 per pixel (depending on desired temporal resolution).

---

## **2. Hidden Layer**

* **Neurons:** 32–64 (experimentally chosen; depends on FPGA resources).
* **Connections:** Each hidden neuron receives spikes from **all 256 input neurons**.
* **Weights:** Train offline (Python/PyTorch SNN or conversion from ANN to SNN), then load as constants or ROM.
* **Bias & Threshold:** Set per neuron; adjustable for tuning.

---

## **3. Output Layer**

* **Neurons:** 10 (one per digit 0–9).
* **Connections:** Each output neuron receives spikes from **all hidden neurons**.
* **Spike accumulation:** Count spikes over all timesteps to determine the recognized digit.
* **Display:** Map the neuron with **max spike count** to 7-segment display.

---

## **4. Spike Processing**

* Each neuron is similar to your `neuron.vhd`:

  * Accumulate weighted inputs.
  * Fire a spike if threshold exceeded.
  * Reset or reduce membrane potential.

* Hidden & output layers work **exactly the same**, just with different numbers of inputs and weights.

---

## **5. Memory & Resource Considerations (Basys 3)**

* **Input neurons:** 256 × 1 → simple spike generator per pixel.
* **Hidden neurons:** 32–64 × 256 inputs → can use **time-multiplexing** to reuse one hardware neuron for multiple logical neurons.
* **Output neurons:** 10 × 32–64 inputs → fits easily.
* **Weights storage:** Use **ROM or VHDL generics**.

---

## **6. Timing & Control**

* Use a **controller module** (like your `control.vhd`) to:

  * Sequence timesteps for input spikes.
  * Reset neurons after each image evaluation.
  * Count output spikes.

---

## **7. Workflow Summary**

1. **Preprocess image:** Downsample MNIST to 16×16 grayscale.
2. **Generate input spikes:** Encode intensity → spike probability.
3. **Feed input to SNN:** 256 neurons → 1 hidden layer → 10 output neurons.
4. **Accumulate output spikes:** Determine which output neuron fired the most.
5. **Display result:** Show digit on 7-segment display.

---






## SNN Architecture
---

### **Input Layer**

* Each pixel is **grayscale 0–255**, which can be represented with **8 bits** (or 7 bits if you ignore the MSB).

* You have **16×16 = 256 pixels**, so **256 input neurons**, one per pixel.

* If you want to encode the pixel value as spikes:

  * You can use **rate coding** or **binary encoding**:

    * **Rate coding:** the pixel value determines how many spikes appear over multiple timesteps.
    * **Binary coding:** treat the 7 bits of the pixel as separate input spikes per neuron.

* In your case, if your neuron accepts 7 inputs, then each **pixel neuron will have 7 input spikes** representing the 7 bits of that pixel. ✅

* **Output of each input neuron:** 1 spike per timestep (or 0 if no spike).

---

### **Hidden Layer**

* Let’s say **32–64 hidden neurons**.

* Each hidden neuron receives input from **all 256 input neurons**.

* Each hidden neuron has **256 inputs**, each with its own weight. ✅

* Each hidden neuron produces **1 output spike per timestep**.

* Implementation note:

  * Your current neuron module only supports 7 inputs.
  * For 256 inputs, you can:

    1. **Extend the neuron module** to accept 256 inputs (one big adder tree).
    2. Or **time-multiplex** inputs: feed 7 inputs per cycle in 37 cycles (37×7≈259).

       * You accumulate the weighted sum in a register over cycles, then generate a spike.

---

### **Output Layer**

* **10 output neurons** (for digits 0–9).
* Each output neuron receives inputs from **all hidden neurons** (32–64 inputs).
* Each output neuron has **1 spike output per timestep**.

---

### ✅ **Summary Table**

| Layer  | # Neurons | Inputs per neuron          | Outputs per neuron |
| ------ | --------- | -------------------------- | ------------------ |
| Input  | 256       | 7 (bits of pixel)          | 1 spike            |
| Hidden | 32–64     | 256 (all input neurons)    | 1 spike            |
| Output | 10        | 32–64 (all hidden neurons) | 1 spike            |

---

you trained your network in Python and now you have **weights and biases**, but your VHDL top entity (`snn_top.vhd`) has other neuron parameters like:

```vhdl
V_TH    -- neuron threshold
LEAK    -- membrane leak per cycle
MEM_BITS -- bit width of neuron membrane potential
```

These **cannot be directly obtained from training**. You have to choose them based on your FPGA design and how you want the SNN to behave. Let me explain each:

---

### 1️⃣ `V_TH` – neuron threshold

* Determines when a neuron “spikes” in your VHDL model.
* The value of `V_TH` should roughly match the **scale of your weighted sum of inputs + bias**.
* Example:
  Suppose your input spikes are `0` or `1` (binary) and weights are integers from `-128` to `128` (after quantization).

  * Max input to a neuron = sum(weights * spikes_in) + bias.
  * If your hidden layer neuron has 256 inputs, each weight max 128, max sum = 256*128 = 32768.
  * You probably **cannot set `V_TH=32768`** because MEM_BITS is only 16. So you need to **scale down weights**.
* Rule of thumb:

  1. Determine max weighted sum (`max_sum`) from quantized weights.
  2. Set `V_TH` somewhere in the middle of `0..max_sum` so neuron spikes realistically.

---

### 2️⃣ `LEAK` – membrane decay per cycle

* Determines how fast the membrane potential decays if the neuron doesn’t spike.
* If you trained your Python network as a **static feedforward MLP**, you probably **don’t need leak**: set `LEAK = 0`.
* If you want more biologically realistic SNN dynamics, choose a small positive integer (e.g., 1–10) and test.

---

### 3️⃣ `MEM_BITS` – membrane potential bit width

* Determines the range of values your neuron can store.
* Must be large enough to represent the **scaled sum of inputs** without overflow.
* Formula:

  ```text
  MEM_BITS >= ceil(log2(max_weighted_sum))
  ```
* Example:

  * Max weighted sum after quantization = 1000 → MEM_BITS >= 10 bits.
  * Add some safety margin → 16 bits is safe.

---

### ✅ How to determine them practically

1. Load your `model_weights.npz`:

```python
import numpy as np

data = np.load("model_weights.npz")
W_input_hidden  = data["W_input_hidden"]
B_input_hidden  = data["B_input_hidden"]
W_hidden_output = data["W_hidden_output"]
B_hidden_output = data["B_hidden_output"]
```

2. Find max possible input sum for each layer:

```python
max_hidden_input = np.max(np.sum(np.abs(W_input_hidden), axis=1) + np.abs(B_input_hidden))
max_output_input = np.max(np.sum(np.abs(W_hidden_output), axis=1) + np.abs(B_hidden_output))

print("Max weighted sum hidden layer:", max_hidden_input)
print("Max weighted sum output layer:", max_output_input)
```

3. Choose:

```text
V_TH_hidden = max_hidden_input / 2  # or 1/4 if you want sparse spikes
V_TH_output = max_output_input / 2
LEAK = 0
MEM_BITS = next_power_of_2(max(max_hidden_input, max_output_input))
```

`next_power_of_2` can be implemented in Python:

```python
def next_power_of_2(x):
    return int(np.ceil(np.log2(x)))
```

---

In short:

| Parameter | How to set                                   |
| --------- | -------------------------------------------- |
| N_INPUTS  | Equals number of features (16x16 = 256)      |
| N_HIDDEN  | Chosen when designing network (32)           |
| N_OUTPUT  | Number of classes (10)                       |
| V_TH      | ~half of max weighted sum after quantization |
| LEAK      | 0 (if no decay) or small integer             |
| MEM_BITS  | Enough bits to represent max weighted sum    |

---

##  A few practical tips / gotchas

* **Clock frequency**: set `CLK_FREQ` correctly to your FPGA system clock (Basys3 default clock often 100 MHz or 74.25 MHz). Wrong `CLK_FREQ` will break baud sampling.
* **Baud tolerance**: `TICKS_PER_SAMPLE` must be integer. For `CLK_FREQ=100_000_000` and `BAUD=115200`, `TICKS_PER_SAMPLE = 100_000_000 / (115200*16) ≈ 54.25`. Not integer — that creates an issue. You must choose a `CLK_FREQ` such that `CLK_FREQ / (BAUD * OVERSAMP)` is close to integer, or use a fractional baud generator. **Recommendation**:

  * If your board clock is 100 MHz, use `OVERSAMP = 16` and compute `TICKS_PER_SAMPLE` with rounding — but rounding can cause bit sampling drift. Better options:

    * Use `CLK_FREQ = 73_728_000` or `74_250_000` (common video clocks) that may produce integer tick counts for 115200.
    * Or implement a better baud generator using integer division with remainder (not included here). If you get sampling mismatches, pick a BAUD that divides your clock cleanly or implement fractional divider.
* **Framing**: If you want more robustness add a start-of-frame marker byte or sequence (e.g., 0xAA 0x55) before 256 bytes; then receiver can resync when noise occurs. Current design assumes Python always sends exactly 256 bytes back-to-back at regular intervals.
* **Flow control**: If Python is faster than FPGA can process, consider handshaking (e.g., FPGA responds with ACK before Python sends next frame). Current code sends frames periodically — ensure FPGA processes them in time.

---

##  Protocol summary (how it works)

Every frame sent from Python → FPGA is:

```
[Preamble 0xAA][Preamble 0x55][Payload 256 bytes][Checksum 1 byte]
```

* `Checksum` = sum(payload) & 0xFF (simple modulo-256 sum).
* FPGA verifies the checksum. If OK it:

  * latches payload into `frame_data` and pulses `frame_valid` for one clock cycle,
  * sends 1-byte ACK `0x06` to the host.
* If checksum fails, FPGA sends NAK `0x15`.
* The Python sender waits for ACK/NAK (timeout) before continuing next send (so we avoid overflow / popping).

This provides resynchronization (preamble) and corruption detection (checksum), and flow control (ACK).


---

# Project layout (suggested)

```
snn_fpga/
├─ README.md
├─ doc/
│  ├─ design.md                 # high-level design notes, fixed-point strategy, bitwidth calc
│  └─ verification_plan.md      # test plan + acceptance criteria
├─ hw/
│  ├─ vhdl/
│  │  ├─ packages/
│  │  │  ├─ types_pkg.vhd       # integer_matrix/integer_vector typedefs, common constants
│  │  │  └─ weights_pkg.vhd     # auto-generated (your weights_pkg_q8_8.vhd)
│  │  ├─ primitives/
│  │  │  ├─ mac.vhd             # multiply-accumulate primitive / DSP wrapper
│  │  │  ├─ shift_round.vhd     # shift & rounding helper (Q format)
│  │  │  └─ fixed_mult.vhd      # fixed-point multiplier (option: use DSP48 wrapper)
│  │  ├─ neurons/
│  │  │  ├─ lif_neuron.vhd      # single LIF neuron (one instance)
│  │  │  ├─ neuron_array.vhd    # N parallel neurons (array wrapper)
│  │  │  └─ spike_reg.vhd       # small helper for spike storage/counting
│  │  ├─ layers/
│  │  │  ├─ fc_layer.vhd        # fully-connected layer (weights read from package)
│  │  │  └─ fc_streaming.vhd    # streaming/pipelined FC for resource tradeoffs
│  │  ├─ top/
│  │  │  ├─ sNN_core.vhd        # integrate fc1 + lif1 + fc2 + lif_out (no IO)
│  │  │  ├─ uart_comm.vhd       # UART RX/TX + packet handler (ACK/NAK + preamble)
│  │  │  ├─ sevenseg.vhd        # 7-seg driver + multiplex logic
│  │  │  └─ top_fpga.vhd        # Basys-3 top: clocks, resets, IO pins, instantiate modules
│  │  └─ tb_helpers/
│  │     ├─ mem_loader.vhd      # loads test vectors into memories (from files)
│  │     └─ stim_gen.vhd        # testbench stimulus convenience routines
│  └─ constraints/
│     └─ basys3_pins.xdc        # pin constraints for Basys-3
├─ sim/
│  ├─ tb/
│  │  ├─ tb_lif_neuron.vhd     # testbench: single neuron
│  │  ├─ tb_mac.vhd            # testbench: MAC & accumulator
│  │  ├─ tb_layer.vhd          # testbench: fc_layer + neuron_array
│  │  ├─ tb_snn_core.vhd       # testbench: integrated SNN core (no IO)
│  │  ├─ tb_uart.vhd           # testbench: UART comms (host emulator)
│  │  └─ tb_top.vhd            # full top-level tb (includes uart and 7seg)
│  ├─ wave_config.do           # ModelSim/Questa wave setup script
│  └─ run_sim.sh               # helper script to run suite of sims
├─ scripts/
│  ├─ export_weights.py        # produce weights_pkg_vhd (yours exists) & .mem/.coe dumps
│  ├─ py_dbg_to_stim.py        # convert forward_debug() arrays → CSV / mem files for tb
│  ├─ stim_check.py            # compare VHDL output CSV vs python debug (golden) 
│  └─ uart_host.py             # host-side serial test script (you have input_interface.py)
├─ tools/
│  ├─ calc_bitwidths.ipynb     # helper notebook: compute safe accumulator widths
│  └─ synth_notes.txt          # hints for Vivado synthesis on Basys-3
└─ sw/
   └─ host/
      └─ input_interface.py    # your GUI & serial sender (already present)
```

---

# What each file / folder is for (concise purpose + important notes)

### `doc/design.md`

* Explain fixed-point Q8.8 choices, rounding semantics, overflow policy, and bit-width derivations.
* Store the exact math mapping between Python ops and VHDL ops (e.g., `(W*X)>>8` behavior).
* Note any approximations (saturation vs wrap, rounding vs truncation).
* This is the authoritative reference used by all VHDL modules and tests.

### `doc/verification_plan.md`

* Test vectors, key assertions, pass/fail criteria, waveforms to inspect.
* Includes testcases: single spike, repeated spikes, heavy positive/negative inputs, threshold edgecases.

---

### `hw/vhdl/packages/types_pkg.vhd`

* Declare `integer_vector`, `integer_matrix`, Q format constants, and any useful subtype ranges.
* Provide signed / unsigned aliases and shift functions for fixed-point conversions.

### `hw/vhdl/packages/weights_pkg.vhd`

* Your auto-generated package (the sample you posted).
* Contains `W_INPUT_HIDDEN`, `B_INPUT_HIDDEN`, `W_HIDDEN_OUTPUT`, `B_HIDDEN_OUTPUT`, `LIF_BETA_Q`, `THRESHOLD_Q`, constants `N_INPUTS`, `N_HIDDEN`, `N_OUTPUT`, and `Q_SCALE`.
* Used by `fc_layer` and top-level to load constants at elaboration time.

Important: keep your generator idempotent and include a comment with exact `Q_SCALE`, `q_frac_bits` so testbench knows how to interpret integers.

---

### `hw/vhdl/primitives/mac.vhd`

* Multiply-accumulate core.
* Should accept inputs in Q8.8 (integers), produce extended-width product (e.g., signed 24-bit), and sum into an accumulator of chosen width.
* Provide two variants: behavioral & DSP-optimized (wrap a DSP block instantiation).

Implementation note: design it so you can instantiate a single MAC time-multiplexed (to save resources) OR many parallel MACs (for speed).

---

### `hw/vhdl/primitives/fixed_mult.vhd` / `shift_round.vhd`

* Multiply two Q8.8 numbers and return result scaled appropriately (implement `product >> Q_BITS` with rounding/truncation as decided in `design.md`).
* `shift_round.vhd` implements (product + round_const) >> Q_BITS if you choose rounding.

---

### `hw/vhdl/neurons/lif_neuron.vhd`

* Implements one LIF neuron with these interfaces (suggested):

  * `input`  : signed integer Q8.8
  * `mem_in` : signed wider int (accumulator)
  * `mem_out`: signed wider int
  * `spike`  : std_logic
  * control signals to reset / load / enable
* Implements the logic:

  ```
  mem = beta*mem + input
  spike = (mem > threshold)
  mem = spike ? mem - threshold : mem
  ```
* Must match Python rounding and reset semantics exactly (document them).

---

### `hw/vhdl/neurons/neuron_array.vhd`

* Replicate / instantiate `N` `lif_neuron`s.
* Provide per-neuron memory (`mem[]`) and configurable beta, threshold signals (load from package).

---

### `hw/vhdl/layers/fc_layer.vhd`

* Implements matrix-vector multiply `z = W*x + b`.
* Two modes:

  * **Streaming** (one MAC reused, iterate across inputs), minimal resources.
  * **Parallel** (many MACs at once), lower latency, higher resource use.
* Reads weights from `weights_pkg` at synthesis/elaboration time or from BRAM initialised with `.mem` files (choose approach).
* Produces output in same Q format.

---

### `hw/vhdl/layers/fc_streaming.vhd`

* A pipelined streaming version: input arrives serially or from local regs, produce outputs after N cycles.

---

### `hw/vhdl/top/sNN_core.vhd`

* The SNN dataflow core: connect `fc1` → `neuron_array`(lif1) → `fc2` → `neuron_array`(lif_out).
* No host-facing IO; intended to be functionally identical to Python core.
* Expose test hooks: internal signals (z1, mem1, spike1, z2, mem2, spike2) to testbench.

---

### `hw/vhdl/top/uart_comm.vhd`

* UART RX + TX + frame parser.
* Recognize preamble `0xAA,0x55`, read 256 payload bytes, verify checksum, assert ACK/NAK.
* Provide handshake signals: `frame_valid`, `payload_ready`, `payload_data_read`.
* Must support baud as in your host script (115200), include small buffer for frames.

---

### `hw/vhdl/top/sevenseg.vhd`

* Convert predicted digit (0–9) to 7-seg codes and multiplex common anodes/cathodes.
* Include blinking / display state machine.

---

### `hw/vhdl/top/top_fpga.vhd`

* Hook up clock/reset, instantiate `uart_comm`, `sNN_core`, `sevenseg`.
* Provide user LEDs or UART debug signals for easier HW debug.
* Include optional simple CPU-like control FSM: idle → receive frame → run `num_steps` cycles → send ACK & final result.

---

### `hw/vhdl/tb_helpers/mem_loader.vhd`

* Small file read routine for simulation that loads `.mem` or `.csv` file into an array (used by tb to initialize inputs or expected outputs).

---

## Simulation files (what to test and why)

### `sim/tb/tb_lif_neuron.vhd` — Single neuron testbench

* Purpose: validate one `lif_neuron` against Python `forward_debug()` for one timestep and edge-cases.
* Stimulus:

  * Small set of input currents `cur` (positive, negative, threshold-just-below, threshold-just-above).
  * Repeated alpha bumps (to test mem leak `beta` behavior).
  * Reset sequence.
* Checks:

  * Compare `mem` and `spike` per-step to Python golden values.
  * Assertion on bit-exact equality if you used exact same Q math, else tolerance check if rounding differs.

### `sim/tb/tb_mac.vhd` — MAC / accumulator testbench

* Purpose: ensure multiply/accumulate, fixed-point shift, rounding, and accumulator width are correct.
* Stimulus:

  * Random vectors + provided worst-case vectors (max positive, max negative).
* Checks:

  * Compare MAC output to Python integer calculation (`(sum(W_i * x_i) // Q_SCALE) + b`).

### `sim/tb/tb_layer.vhd` — FC layer + neuron array

* Purpose: validate a full layer (fc1 + lif neuron array).
* Stimulus:

  * Use `py_dbg_to_stim.py` to create `.mem` files with a small input and expected `z1, mem1, spk1`.
* Checks:

  * Per-neuron `z`, `mem`, `spk` match Python debug arrays.
  * Per-step checks across `num_steps` if you simulate time steps.

### `sim/tb/tb_snn_core.vhd` — Integrated SNN (no comm)

* Purpose: validate full forward pass across `num_steps` (20).
* Stimulus:

  * Load weights from `weights_pkg`.
  * Use `py_dbg_to_stim.py` to create test input image vector AND the complete `forward_debug` arrays for all timesteps.
* Checks:

  * Bit-exact comparison of all recorded internal arrays (cur1, mem1, spk1, cur_out, mem_out, spk_out) per timestep.
  * Final predicted class matches Python argmax.

### `sim/tb/tb_uart.vhd` — UART & protocol testbench

* Purpose: validate serial reception, checksum validation, ACK/NAK logic.
* Stimulus:

  * TB drives RX line with preamble + payload + correct checksum and with corrupted frames.
* Checks:

  * `frame_valid` asserted when valid frame arrives.
  * `ACK` transmitted on TX when correct; `NAK` for bad checksum.

### `sim/tb/tb_top.vhd` — Full top-level testbench (end-to-end)

* Purpose:

  * Test the whole system: host sends frame → FPGA runs inference for `num_steps` cycles → FPGA returns ACK and optionally result via UART or seven-seg outputs.
* Stimulus:

  * Use `mem_loader` to inject input frames and compare final results with Python golden answers.
* Checks:

  * End-to-end latency measurement (cycles between frame reception and valid result).
  * Seven-seg encoding correctness (if modeled in TB).
  * UART return packets if implemented.

---

# How to feed Python golden values into VHDL tests

Create a small pipeline of helper scripts (you already have most pieces):

1. `py_dbg_to_stim.py`

   * Load `forward_debug()` outputs saved from Python as `.npz` or `.npy`.
   * Convert arrays to integer CSV or a `.mem` (text file with one integer per line) matching your VHDL memory format.
   * Save expected outputs (z1_t0.csv, mem1_t0.csv, spk1_t0.csv ...) or one file per signal with time-indexed rows.

2. `export_weights.py` (you already have weights_pkg generator)

   * Also write `.mem` versions if you prefer BRAM inits (for simulation use).

3. In testbenches, use `mem_loader.vhd` to read these files and drive stimulus.

4. `stim_check.py`

   * After simulation, export the internal signal traces to a CSV (many simulators can dump signal arrays to a file).
   * Compare bitwise with Python golden; produce PASS/FAIL, and a delta log of mismatches.

---

# Exact verification checks to include (automated)

* **Bit-exact equality** checks for all internal integers (try this first).
* If small differences appear due to rounding policy, run a **tolerance check** (absolute difference ≤ 1 or per-signal tolerance).
* **Overflow/saturation checks**: intentionally force large inputs and assert that behavior matches documented policy.
* **Timing assertions**: e.g., `frame_valid` must be asserted exactly when payload is ready.

---

# Bitwidth & fixed-point practical guidance (important)

* You chose Q8.8 (scale=256). Key arithmetic steps:

  * Multiply two Q8.8 integers → product in Q16.16 (width = sum of operand widths).
  * You must **right-shift by Q_BITS (8)** to bring product back to Q8.8.
  * Sum many products: choose accumulator width to avoid overflow.

**Conservative accumulator sizing** (recommended):

* Worst-case product magnitude with signed int16 weight (±32767) and input up to 256:

  * product_max ≈ 32767 * 256 = 8,388,352 (≈ 23 bits unsigned)
* Summing 256 inputs:

  * sum_max ≈ 8,388,352 * 256 = 2,147,483,648 (≈ 32 bits unsigned → equals 2^31)
* So the minimal signed accumulator width to hold all sums without overflow is **33 bits** (to represent ±2^31).
* **Safer practical width**: use **40 bits** (or at least 36) to allow margin for intermediate ops, bias addition and multiplication by beta.

If your trained weights are known to be much smaller (as in your sample), you can reduce width, but verify worst-case in `tools/calc_bitwidths.ipynb`.

---

# Simulation environment & practical tips

* Use **ModelSim/Questa** or **GHDL + GTKWave**. ModelSim is friendlier for large VHDL + wave configuration scripts.
* Put wave setup in `sim/wave_config.do` to quickly inspect key signals.
* Use `run_sim.sh` to run multiple test benches automatically and produce a consolidated `results` dir.
* Export simulation results for signals of interest to CSV (use simulator `-r` or `log` commands) for comparison with `stim_check.py`.

---

# Host / UART protocol notes (how your `input_interface.py` fits)

* Your host script sends `PREAMBLE + payload(256 bytes) + checksum`.
* `uart_comm.vhd` must:

  * Wait for the preamble pattern,
  * Read exactly `N_INPUTS` bytes,
  * Verify checksum (sum%256),
  * Drive `payload_ready` with payload (unpack to Q8.8 ints),
  * Send ACK (`0x06`) on success or NAK (`0x15`) on failure.

**Sim TB for UART**:

* TB must emulate host transmitter by toggling `rx` line according to the baud rate.
* You can accelerate by driving bytes directly if your UART RX primitive API supports it.


---

Resource / performance estimate (approx)

Using single MAC:

fc1: N_HIDDEN * N_INPUTS = 64 * 256 = 16384 cycles

lif1: ~N_HIDDEN = 64 cycles

fc2: N_OUTPUT * N_HIDDEN = 10 * 64 = 640 cycles

lif2: ~N_OUTPUT = 10 cycles

per timestep ≈ 17098 cycles ≈ ~17k cycles

for NUM_STEPS = 20 → ~341,960 cycles total

At 100 MHz clock → 341,960 / 100e6 ≈ 3.42 ms per inference.
This is comfortably under your 10 ms requirement. If you run at 50 MHz, ≈6.84 ms — still okay.

If you want to further reduce latency, the design can be changed to use PARALLELISM (e.g., 4 MACs) — I can add that later.