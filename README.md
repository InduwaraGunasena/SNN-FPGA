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
