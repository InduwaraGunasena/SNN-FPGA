# Spiking Neural Network on FPGA for Handwritten Digit Recognition

-----

Our project involves implementing a Spiking Neural Network (SNN) on an FPGA for real-time handwritten digit recognition using VHDL. The SNN mimics the spiking behavior of biological neurons, addressing the demand for efficient and low-power neural network solutions in embedded systems. Designed with VHDL to leverage FPGA capabilities, our model undergoes a crucial training phase in Python for weight calculation, data normalization, evaluation, experimentation, and testing. Users can write digits in a pixel grid and get the inference in real-time on a 7-segment display. The model communicates via a UART interface to share pixel grid data between the FPGA and the host machine.

## Project Layout

```
SNN-FPGA/
├─ README.md
├─ snn-fpga/snn-fpga.srcs
│  ├─ sources_1/new/
│  │  ├─ packages/
│  │  │  ├─ types_pkg.vhd       # Custom integer vector/matrix types
│  │  │  └─ weights_pkg.vhd     # (Generated) Quantized Model Weights & Biases
│  │  ├─ layers/
│  │  │  ├─ fc_layer_seq.vhd    # Fully Connected Layer (Sequential Logic)
│  │  │  └─ lif_array_seq.vhd   # Array of Leaky Integrate-and-Fire Neurons
│  │  ├─ top/
│  │  │  ├─ snn_core.vhd        # SNN controller: Manages layer sequencing
│  │  │  ├─ seven_seg.vhd       # 7-Segment Display Driver
│  │  │  └─ top_fpga.vhd        # Top-level entity: Clock divider, UART & SNN orchestration
│  │  └─ uart/
│  │     ├─ uart_frame_receiver256.vhd    # Frame Logic: Buffers 256 bytes, Handles Checksum
│  │     ├─ uart_rx.vhd                   # UART Byte Receiver (Oversampled)
│  │     └─ uart_tx.vhd                   # UART Byte Transmitter
│  ├─ constrs_1/imports/Downloads/
│  │  └─ Basys3Labs.xdc         # Pin constraints for Basys-3
│  └─ sim_1/new
│     ├─ tb_fc_layer.vhd        # Testbench: fc_layer + neuron_array
│     └─ tb_snn_core.vhd        # Testbench: integrated SNN core (no IO)
└─ Python scripts/
   ├─ sample MNIST data         # Sample dataset for testing purposes
   ├─ input_interface.py        # Main GUI application for drawing & testing
   ├─ snn_test.ipynb            # Train, test, and evaluate the SNN model in Python environment
   └─ weights_pkg.vhd           # Sample weight and parameter file ready to move to VHDL
```

> [\!NOTE]
> I built the SNN in the Python environment first. The workflow began with the contents in **Python scripts**, where I trained, evaluated, and experimented with the SNN model before finally testing it.
> Subsequently, I used Vivado 2018.1 to develop the FPGA model. Therefore, the **snn-fpga** directory contains all files related to the SNN model implementation on the FPGA.

## Model Design

### Introduction to Spiking Neural Networks (SNNs)

Spiking Neural Networks (SNNs) represent the third generation of neural networks, designed to bridge the gap between machine learning and neuroscience. Unlike traditional Artificial Neural Networks (ANNs) that communicate using continuous numerical values (activations), SNNs operate using discrete events called "spikes," much like biological brains.

[Image of Biological neuron vs Spiking neuron]

In an SNN, information is encoded in the timing and frequency of these spikes. Neurons accumulate voltage over time and only transmit a signal when a specific threshold is reached. This temporal dynamic allows SNNs to process time-series data efficiently and offers significant potential for energy efficiency, as computations are event-driven rather than continuous.

### Project Architecture

The primary goal of this project is to classify handwritten digits from 0 to 9 using the MNIST dataset. However, standard MNIST images are 28x28 pixels, which results in an input layer of 784 neurons. Given the limited logic and memory resources of the Digilent Basys 3 FPGA (Artix-7), a full-scale implementation was not feasible.

To address this, we optimized the architecture as follows:

  * **Input Downsampling:** We downsampled the MNIST dataset to **16x16 pixels**, reducing the input layer to 256 neurons.
  * **Network Topology:** After experimenting with various multi-layer architectures, we determined that a single hidden layer provided the best balance between accuracy and resource usage.
  * **Final Structure:** The model consists of a **256-64-10** architecture:
      * **Input Layer:** 256 neurons (receiving pixel intensity as current).
      * **Hidden Layer:** 64 Leaky Integrate-and-Fire (LIF) neurons.
      * **Output Layer:** 10 LIF neurons (representing digits 0-9).

### Core Concepts & Implementation

To successfully port the SNN to hardware, several specific design choices were made:

  * **Temporal Simulation (`num_steps=20`):** SNNs require time to integrate information. We simulate the network for 20 time steps per inference. This duration is sufficient for the spiking dynamics to settle and produce a reliable classification without introducing excessive latency.
  * **Leaky Integrate-and-Fire (LIF) Neurons:** We utilized LIF neurons because they introduce a "leak" term. This mimics biological memory—if a neuron doesn't receive enough input quickly, its potential decays, preventing old noise from triggering false spikes.
  * **Quantization (Q8.8):** Floating-point arithmetic is computationally expensive on FPGAs. We implemented **Q8.8 fixed-point arithmetic**, where 8 bits are used for the integer part and 8 bits for the fractional part. This allows us to perform calculations using standard integer logic while maintaining enough precision for the neural network weights.

### Python Workflow

The `snn_test.ipynb` notebook serves as the development hub for the model:

1.  **Preprocessing:** Raw MNIST images are resized to 16x16, normalized, and centered (center-of-mass) to match the GUI input format.
2.  **Training:** The model is built using PyTorch and `snntorch`. It is trained using backpropagation through time (BPTT).
3.  **Fine-Tuning & Quantization:** We employ quantization-aware training to simulate the effects of Q8.8 fixed-point arithmetic, ensuring the model's accuracy doesn't drop when moved to the FPGA.
4.  **Evaluation:** The model is tested against a validation set to ensure robustness.
5.  **Export:** Finally, the trained weights and biases are exported into a VHDL package file (`weights_pkg.vhd`), ready for synthesis.

## FPGA Design

The FPGA implementation is divided into two major subsystems: the **SNN Core** (computation) and the **UART Interface** (communication).

### SNN Core & Sequential Logic

The SNN core is responsible for executing the neural network inference. Due to the limited number of DSP slices and Block RAM on the Basys 3, a fully parallel implementation (where every neuron updates simultaneously) is impossible. Instead, we utilized a **sequential processing approach**:

  * **Sequential Matrix Multiplication:** The Fully Connected (FC) layers compute neuron activations one by one. A single Multiply-Accumulate (MAC) unit iterates through the weights stored in distributed ROM.
  * **State Management:** The membrane potentials of the 64 hidden neurons and 10 output neurons are stored in registers. In every time step, the system reads the current potential, adds the input current, applies the decay factor (beta), checks for a threshold crossing (spike), and writes the new potential back.
  * **Clocking:** To ensure timing stability for the large combinational paths involved in the weight matrix access, the system clock is divided down to **25 MHz**.

### UART Communication

Real-time interaction is achieved via a custom UART interface running at **115200 baud**.

  * **Reception:** The `uart_frame_receiver256` module buffers the incoming 256 bytes (representing the 16x16 pixel grid).
  * **Synchronization:** It handles clock domain crossing and validates the integrity of the data frame using a checksum. If the checksum matches, a "valid" signal triggers the SNN inference.
  * **Transmission:** Once inference is complete, the predicted class is sent back to the host PC, and the result is simultaneously displayed on the 7-segment display.

### Simulation

The project includes VHDL testbenches to verify functionality before synthesis:

  * **`tb_fc_layer.vhd`:** Tests individual layer logic to ensure the sequential MAC operations and neuron updates match Python outputs.
  * **`tb_snn_core.vhd`:** Simulates the entire network flow (Input $\rightarrow$ Hidden $\rightarrow$ Output) over 20 time steps. Developers can copy input vectors from the Python debug script into this testbench to verify bit-accurate compatibility between the Python simulation and VHDL logic.

## Model Performance

The performance of the FPGA implementation is evaluated based on the number of clock cycles required to complete one inference pass (20 time steps).

### Resource & Latency Estimation

The design uses a single MAC unit per layer to conserve resources. The cycle count per time step is calculated as follows:

  * **FC1 Layer (Input to Hidden):**
      * $64 \text{ neurons} \times 256 \text{ inputs} = 16,384 \text{ cycles}$
  * **LIF1 Update:**
      * $\approx 64 \text{ cycles}$ (Sequential update of hidden neurons)
  * **FC2 Layer (Hidden to Output):**
      * $10 \text{ neurons} \times 64 \text{ inputs} = 640 \text{ cycles}$
  * **LIF2 Update:**
      * $\approx 10 \text{ cycles}$ (Sequential update of output neurons)

**Total Cycles per Time Step:**
$$16,384 + 64 + 640 + 10 \approx 17,098 \text{ cycles}$$

**Total Cycles per Inference (20 Steps):**
$$17,098 \times 20 \approx 341,960 \text{ cycles}$$

### Latency Calculation

Running on a system clock of **25 MHz**:
$$\text{Latency} = \frac{\text{Total Cycles}}{\text{Clock Frequency}} = \frac{341,960}{25 \times 10^6} \approx \mathbf{13.68 \text{ ms}}$$

This latency ($\approx 13.7$ ms) allows for approximately **73 inferences per second**, which is well within the requirements for a real-time user interface where human reaction time is significantly slower.

## Future Prospects

There are several avenues to improve and expand this project:

  * **Parallelism:** Implementing multiple MAC units (e.g., 4 or 8 in parallel) would linearly reduce the latency, potentially allowing for higher clock speeds or larger networks.
  * **Pipelining:** Pipelining the FC layers and neuron updates could allow the processing of the next time step to begin before the current one finishes.
  * **Deep SNNs:** Utilizing external DDR memory to store weights would allow for multi-layer architectures (Deep SNNs) beyond the current BRAM limitations.
  * **On-Chip Learning:** Implementing Spike-Timing-Dependent Plasticity (STDP) to allow the FPGA to learn from the user's handwriting in real-time without needing Python training.

-----