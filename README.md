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
