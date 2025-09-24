# SNN on FPGA

Team members:
- Induwara Gunasena
- Ishan Kawshalya

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
