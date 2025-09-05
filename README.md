# SNN on FPGA

Team members:
- Induwara Gunasena
- Ishan Kawshalya



---

Nice — Vivado + VHDL is a great combo for this project. Below I’ll give you a practical, concrete plan: a recommended repo layout, the VHDL module breakdown, step-by-step development & verification flow in Vivado, tips for interfacing camera/VGA, where to put weights/constraints, debugging techniques, and performance/resource guidance. Follow these steps sequentially (you can parallelize later), and you’ll have a reproducible workflow and a clean report section.

---

# 1) Recommended repository / project layout

Use a Git repo. Keep simulation, scripts, and generated data separate.

```
snn-fpga/                         # repo root
├─ README.md
├─ doc/
│  └─ design_notes.md
├─ src/
│  ├─ vhdl/
│  │  ├─ top/                    # top-level designs
│  │  │  └─ snn_top.vhd
│  │  ├─ modules/                # reusable modules
│  │  │  ├─ control.vhd
│  │  │  ├─ gen_input.vhd
│  │  │  ├─ neuron.vhd
│  │  │  ├─ camera_if.vhd
│  │  │  ├─ vga_ctrl.vhd
│  │  │  ├─ frame_buffer.vhd
│  │  │  ├─ overlay.vhd
│  │  │  └─ weight_loader.vhd
│  │  └─ packages/
│  │     └─ constants_pkg.vhd    # e.g. weight arrays, fixed-point definitions
│  └─ constraints/
│     └─ basys3_constraints.xdc  # placeholders / board XDC
├─ sim/
│  ├─ tb/                        # testbenches and test vectors
│  └─ images/                    # ppm test images used in sim
├─ py/                           # python training + export scripts
│  ├─ train.py
│  └─ export_weights_to_vhd.py   # writes constants_pkg.vhd or .mem files
├─ scripts/
│  └─ vivado_project.tcl         # reproducible project creation
└─ tools/
   └─ convert_ppm_to_stream.py
```

---

# 2) Top-level module breakdown (files & responsibilities)

You already have many modules — structure them clearly.

* `snn_top.vhd` (top)

  * Instantiate modules, manage clocks/resets, expose board I/O.
  * Connect camera/VGA, debug outputs, and weight loader.

* `camera_if.vhd`

  * Handles camera signals (PCLK, VSYNC, HREF) or HDMI-to-RGB adapter outputs.
  * Captures pixel bytes into line FIFO or directly to `frame_buffer`.
  * Handles I2C configuration (SCCB) if using OV cameras (I2C controller module optional).

* `frame_buffer.vhd`

  * Dual-port BRAM to store incoming frames.
  * One port written with camera clock domain, other read by SNN/VGA domain.
  * Also used to implement ping-pong buffering for continuous output.

* `vga_ctrl.vhd`

  * Generates VGA timing (hsync/vsync, pixel clock enable).
  * Reads pixel data from `frame_buffer` and outputs RGB.
  * Supports overlay input signals (text/box) from overlay module.

* `overlay.vhd`

  * Accepts classification map (one-bit per pixel or small buffer) and draws bounding boxes/text.
  * Could be simple: if classification\_map\[x,y] then change pixel color and optionally draw text.

* `gen_input.vhd`

  * Converts pixel values to spike streams (your randomized spike generator or deterministic encoding).
  * Should be clocked at SNN timestep rate or produce spikes each pixel cycle with internal timing.

* `neuron.vhd`

  * The LIF or integrate-and-fire neuron implementation.
  * Parameterizable via generics or via weight memory lookups.

* `weight_loader.vhd`

  * Loads trained weights formatted by Python into BRAM or as VHDL constants.
  * Provide a simple UART/USB loader or compile-time package generation (recommended for early dev).

* `control.vhd`

  * Manages per-pixel timestep sequencing, resets and spike counting, classification decision logic.

---

# 3) Recommended data flow & clocking domains

* **Camera domain** — driven by camera PCLK (pixel clock).

  * Write pixel bytes into `line_fifo` / `frame_buffer` in this domain.
  * If camera PCLK differs from system clock, use asynchronous FIFO or write-side BRAM with handshaking.

* **System / SNN domain** — use a stable clock (e.g., 50–100 MHz from Basys3 board clock via BUFG).

  * Read pixels from `frame_buffer` at your processing rate.
  * Run SNN inference (pipelined) on system clock.

* **VGA domain** — often same as system clock if you choose a VGA-friendly clock (e.g., 25.175 MHz for 640×480).

  * Option A (simpler): use VGA 640×480 @25MHz; derive pixel clock with a PLL/MMCM from the board clock.
  * Option B: read and output from `frame_buffer` in system domain — use buffering to bridge clocks.

**Important**: Always design proper CDC (clock-domain crossing) when bridging camera and system or VGA domains.

---

# 4) Step-by-step development & verification plan

### Stage 0 — Preparations

1. Install Vivado (match the version used in your lab or target environment).
2. Create the repo structure above.
3. Add a `vivado_project.tcl` script to automate project creation (see below for a short example).
4. Collect board files and Basys3 XDC from Digilent (store in `src/constraints/`).

---

### Stage 1 — Build & test VGA output (smoke test)

1. Implement `vga_ctrl.vhd` that generates basic test patterns (color bars).
2. Create `snn_top.vhd` that ties `vga_ctrl` to the board VGA pins.
3. Build Vivado project, implement, generate bitstream, program Basys3, and validate monitor output.

   * This confirms pinouts, video connection, timing, and clocking.

**Why first?** VGA output is the quickest way to check board I/O and clocks.

---

### Stage 2 — Frame buffer + test image playback

1. Implement `frame_buffer.vhd` using dual-port BRAM.
2. Add a testbench or hardware initializer to load a small PPM into BRAM (or use `frame_buffer` writer logic).
3. Display the frame from BRAM through `vga_ctrl`.
4. Validate colors and image positioning.

---

### Stage 3 — Camera interface (optional early) or PPM file input

* Option A (faster): Use PPM files converted to memory initialization files (`.mem`) and load them into BRAM for testing.
* Option B (real camera): Implement `camera_if.vhd` for OV7670/OV2640 and test pixel capture into BRAM.

  * Implement I2C init config (SCCB) or use existing open-source camera controller VHDL.

**Tip**: Develop camera interface in simulation with recorded PPM patterns before connecting physical camera.

---

### Stage 4 — SNN modules + simulation

1. Implement `gen_input.vhd` and `neuron.vhd` with clear generics for weights/thresholds.
2. Build testbenches under `sim/tb/` that:

   * Feed pixel values or spike trains.
   * Observe neuron membrane, spikes, and accumulation.
3. Use ModelSim or Vivado simulator + GTKWave to inspect signals.
4. Iterate until neuron behavior matches expected python/octave simulation.

**Unit tests**:

* Single neuron with known input spike pattern.
* 7-neuron hidden layer producing expected spikes.
* Output neuron spike counts and classification decision.

---

### Stage 5 — Integrate SNN into video pipeline

1. Hook SNN inference engine to read pixels from `frame_buffer` (or streaming from `camera_if`).
2. Implement sequencing: for each pixel, run `sp_steps` timesteps (or run pipelined inference that amortizes timesteps).
3. Store classification result (one bit or class ID) in a small `classification_map` BRAM.
4. Overlay classification map while reading for VGA.

**Performance decision**:

* If 64 timesteps per pixel is used sequentially → frame rate falls dramatically.
* Prefer pipelined/time-multiplexed design: process many pixels in a pipeline stage per cycle.

---

### Stage 6 — Overlay, bounding boxes & text

1. Implement a simple overlay module:

   * For each pixel output, check `classification_map[x,y]` and modify RGB.
   * Optionally draw bounding rectangles by scanning map to find connected regions (or simple sliding window).
2. Implement a small font ROM (e.g., 8×8 glyphs) for text display.
3. Validate overlay rendering with test images.

---

### Stage 7 — Weight loading and runtime control

1. Use `py/export_weights_to_vhd.py` to convert Python-trained weights into `constants_pkg.vhd` or `.mem` BRAM files.
2. Provide a simple UART or DIP-switch control to toggle modes (demo/test/overlay on/off).
3. Optionally implement runtime weight loader (UART/SDcard) if you want to update weights without re-synthesis.

---

### Stage 8 — Optimization & final testing

1. Insert ILA cores to probe critical signals and verify behavior on hardware.
2. Run Vivado Implementation and check timing (use Report Timing Summary).
3. Optimize resource hotspots:

   * Time-multiplex neuron instances.
   * Use BRAM for weight storage and neuron state arrays.
   * Replace wide arithmetic with fixed-point smaller bit widths.
4. Final experiments: measure FPS, accuracy, resource utilization (post-implementation reports), and thermal behavior.

---

# 5) Practical Vivado tips & sample commands

**Create Vivado project via Tcl (script example skeleton):**

```tcl
create_project snn_proj ./vivado -part xc7a35ticsg324-1L
add_files ./src/vhdl/top/snn_top.vhd
add_files -norecurse ./src/vhdl/modules/*.vhd
set_property board_part digilentinc.com:basys3:part0:1.0 [current_project]
add_files ./src/constraints/basys3_constraints.xdc
update_compile_order -fileset sources_1
launch_runs synth_1 -jobs 4
wait_on_run synth_1
launch_runs impl_1 -to_step write_bitstream
```

**Important project settings**

* Use a global clock buffer (BUFG) for your main system clock.
* If you need a pixel clock not directly available, use an MMCM/PLL to generate VGA or camera clocks.
* Keep timing constraints realistic (use `create_clock` for main clocks and `set_input_delay`/`set_output_delay` for interfaces if needed).

**Avoid hardcoding pins** — import the Basys3 XDC from Digilent (or copy) and only override what you change.

---

# 6) Debugging & verification tools

* **Simulation**: Vivado Simulator or ModelSim. Write testbench drivers to feed PPM image streams.
* **GTKWave**: View waveforms exported by sim.
* **ILA (Integrated Logic Analyzer)**: Probe internal signals in hardware for live capture.
* **VIO**: For interactive probing/control (set inputs from Vivado while running).
* **UART logging**: Print status, spike counts, FPS to PC terminal.

---

# 7) Design choices & trade-offs (brief)

* **Resolution vs FPS**: Lower the processed resolution to increase FPS (e.g., 320×240).
* **Timesteps per pixel (sp\_steps)**: Fewer steps = faster frames but may reduce accuracy.
* **Hardware parallelism**: More parallel neurons → higher resource usage. Time multiplexing saves LUTs at the cost of throughput.
* **Weight storage**: Generics (easy, compile-time) vs BRAM/.mem (flexible, runtime updatable).

---

# 8) Fixed-point & scaling recommendations

* Pick a fixed-point format that fits your dynamic range; common choices: Q8.8 or Q7.8 depending on weight ranges.
* Document scaling factors: show how Python-trained float weights are scaled and rounded for VHDL.
* Include tests that compare float vs fixed-point outputs and report deviation.

---

# 9) Suggested milestone schedule (example)

1. Week 1: Set up templated Vivado project; implement VGA test pattern; repository setup.
2. Week 2: Frame buffer + playback of PPM images.
3. Week 3: Implement & simulate neuron + gen\_input; validate with testbenches.
4. Week 4: Integrate SNN with frame buffer and small test image; get classification map working.
5. Week 5: Camera interface and real hardware capture.
6. Week 6: Overlay, bounding boxes, text, and final optimization.
7. Week 7: Measurement, write report, and wrap up.

---

