# Real-Time Handwritten Digit Recognition using Spiking Neural Networks on FPGA

Welcome to the **SNN-FPGA** project\! This repository hosts a complete hardware-software co-design system that implements a Spiking Neural Network (SNN) on a **Digilent Basys 3 FPGA**.

Our goal was to bridge the gap between biological inspiration and hardware efficiency. By mimicking the spiking behavior of biological neurons, this project demonstrates how neural networks can be deployed in resource-constrained embedded systems using VHDL.

<p align="center">
<img src="/images/img.gif" alt="working model" height="500"/>
</p>

**Key Features:**

  * **Real-Time Interaction:** Users draw digits on a Python GUI, and the FPGA classifies them instantly.
  * **Efficient Design:** Uses a custom sequential architecture to fit a neural network onto a small Artix-7 FPGA.
  * **Hardware-Software Loop:** Features a robust UART communication pipeline connecting the host PC and the FPGA.

> [\!NOTE]
> Watch the demo video of this project: https://www.youtube.com/shorts/KOD3Yp8Q4VM 

-----

## Project Layout

```text
SNN-FPGA/
├─ README.md
├─ snn-fpga/snn-fpga.srcs
│  ├─ sources_1/new/
│  │  ├─ packages/
│  │  │  ├─ types_pkg.vhd       # Custom integer vector/matrix types
│  │  │  └─ weights_pkg.vhd     # (Auto-Generated) Quantized Model Weights & Biases
│  │  ├─ layers/
│  │  │  ├─ fc_layer_seq.vhd    # Fully Connected Layer (Sequential Logic)
│  │  │  └─ lif_array_seq.vhd   # Array of Leaky Integrate-and-Fire Neurons
│  │  ├─ top/
│  │  │  ├─ snn_core.vhd        # SNN Controller: Manages layer sequencing
│  │  │  ├─ seven_seg.vhd       # 7-Segment Display Driver
│  │  │  └─ top_fpga.vhd        # Top-Level: Clock divider, UART & SNN orchestration
│  │  └─ uart/
│  │     ├─ uart_frame_receiver256.vhd    # Buffers 256 bytes & handles Checksum
│  │     ├─ uart_rx.vhd                   # UART Receiver (Oversampled)
│  │     └─ uart_tx.vhd                   # UART Transmitter
│  ├─ constrs_1/imports/Downloads/
│  │  └─ Basys3Labs.xdc         # Pin constraints for Basys-3
│  └─ sim_1/new
│     ├─ tb_fc_layer.vhd        # Testbench: Layer logic verification
│     └─ tb_snn_core.vhd        # Testbench: Full SNN core verification
└─ Python scripts/
   ├─ sample MNIST data         # Test images
   ├─ input_interface.py        # GUI for drawing digits & communicating with FPGA
   ├─ snn_test.ipynb            # Jupyter Notebook: Train, Quantize, Evaluate & Export
   └─ weights_pkg.vhd           # Sample weights file (Reference)
```

> [\!NOTE]
> **Development Workflow:**
> This project was built in two phases. First, the SNN was designed, trained, and verified entirely in **Python** (see *Python scripts*). Once the model logic was proven and the weights were exported, I moved to **Vivado** to implement the hardware logic (see *snn-fpga*).

-----

## Understanding the Model

### Why Spiking Neural Networks?

Spiking Neural Networks (SNNs) represent the third generation of neural networks. Unlike standard Artificial Neural Networks (ANNs) that constantly multiply floating-point numbers, SNNs operate on discrete events called **"spikes"**—much like the biological brain.

<p align="center">
<img src="/images/ANN vs SNN.jpg" alt="ANN vs SNN" width="500"/>
<br>
<sub>Figure: Illustration of neural networks: (left) an ANN, where each neuron processes real numbers; and (right) an SNN, where dynamic spiking neurons process and communicate binary sparse spiking signals over time.</sub>
<br>
<em><sub>Resource: <a href="https://blogs.kcl.ac.uk/kclip/files/2019/08/prob_snn_KCLIP_0.jpg">https://blogs.kcl.ac.uk/kclip/files/2019/08/prob_snn_KCLIP_0.jpg</a></sub></em>
</p>


In our model, information isn't just a static value; it is encoded in the timing and accumulation of signals. Neurons build up electrical potential over time and only "fire" (send a signal) when they cross a specific threshold. This event-driven approach is what makes SNNs incredibly promising for energy-efficient hardware.

### Adapting MNIST for FPGA

We aimed to classify digits using the famous **MNIST dataset**. However, standard MNIST images are 28x28 pixels (784 inputs). For the Basys 3 FPGA, which has limited logic cells and memory, a fully connected network of that size was too expensive.

<p align="center">
<img src="/images/Basys 3 resources.png" alt="Basys 3 resources" width="500"/>
<br>
<sub>Figure: Hardware resources available in Basys 3</sub>
<br>
<em><sub>Resource: <a href="https://www.amd.com/content/dam/amd/en/documents/university/aup-boards/XUPBasys3/documentation/Basys3_rm_8_22_2014.pdf">https://www.amd.com/content/dam/amd/en/documents/university/aup-boards/XUPBasys3/documentation/Basys3_rm_8_22_2014.pdf</a></sub></em>
</p>

We optimized the architecture to fit the hardware constraints:

1.  **Downsampling:** We reduced input images to **16x16 pixels** (256 inputs).
2.  **Lean Topology:** After substantial experimentation, we found that a single hidden layer offered the best trade-off between accuracy and resource usage.
3.  **Final Architecture:** **256 Input $\rightarrow$ 64 Hidden (LIF) $\rightarrow$ 10 Output (LIF)**.

<p align="center">
<img src="/images/Architecture.png" alt="SNN Block diagram" width="500"/>
<br>
<sub>Figure: Block diagram of the SNN Architecture</sub>
</p>

### Key Technical Decisions

To bridge the gap between Python simulation and VHDL synthesis, we made three critical design choices:

  * **Temporal Simulation (20 Steps):** SNNs need "time" to think. We simulate the network for 20 time steps per inference. This gives the spiking dynamics enough time to settle and produce a clear prediction without causing noticeable lag for the user.
  * **The "Leaky" Neuron:** We use Leaky Integrate-and-Fire (LIF) neurons. The "leak" ensures that if a neuron stops receiving input, its potential gradually decays. This acts like a short-term memory filter, preventing old noise from triggering false detections.
  * **Quantization (Q8.8):** FPGAs struggle with floating-point math. We implemented **Q8.8 Fixed-Point Arithmetic** (8 bits integer, 8 bits fraction). This allows us to run the neural network using standard integer logic gates while maintaining the precision needed for accurate weights.

### The Python Training Pipeline

The `snn_test.ipynb` notebook is the "brain" behind the hardware. It handles:

1.  **Preprocessing:** Resizing and centering raw images to match the FPGA's input format.
2.  **Training:** Using `snntorch` to train the model via Backpropagation Through Time (BPTT).
3.  **Quantization-Aware Training:** Fine-tuning the model to survive the conversion from Float32 to Int8.
4.  **Export:** Generating the VHDL package `weights_pkg.vhd`, effectively "burning" the learned brain into the FPGA's memory.

-----

## Hardware Implementation

The FPGA design is split into the **SNN Core** (the brain) and the **UART Interface** (the nervous system).

### The SNN Core: Sequential Processing

On a small FPGA, we cannot update all neurons in parallel (that would require hundreds of multipliers). Instead, we designed a **Sequential Processor**:

  * **Matrix Multiplication:** A single Multiply-Accumulate (MAC) unit iterates through the weights stored in distributed ROM, calculating neuron inputs one by one.
  * **State Management:** The membrane potential of every neuron is stored in a register array. In every clock cycle, the system reads a neuron's state, adds new input, applies the leak, and checks for a spike.

### UART Communication Bridge

To interact with the model, we built a custom UART interface running at **115200 baud**.

  * **The Packet:** The host sends a 256-byte packet (the image).
  * **Validation:** The FPGA calculates a checksum as data arrives. The SNN only runs if the checksum matches, ensuring no corrupted data affects the prediction.
  * **Feedback:** Once the SNN finishes, it sends the predicted digit back to the PC and updates the 7-segment display.


<p align="center">
<img src="/images/Hardware Architecture.png" alt="Block diagram of the SNN in FPGA" width="750"/>
<br>
<sub>Figure: Block diagram of the SNN in FPGA</sub>
</p>

-----

## Performance Analysis

We evaluate performance based on the clock cycles needed for one full inference (20 time steps).

### Resource & Latency

Since we serialize the math (using one multiplier per layer), the cycle count is deterministic:

  * **FC1 Layer:** $64 \text{ neurons} \times 256 \text{ inputs} = 16,384 \text{ cycles}$
  * **FC2 Layer:** $10 \text{ neurons} \times 64 \text{ inputs} = 640 \text{ cycles}$
  * **Overhead:** $\approx 74 \text{ cycles}$ for neuron updates.

**Total per Time Step:** $\approx 17,098 \text{ cycles}$
**Total per Inference (20 Steps):** $\approx 341,960 \text{ cycles}$

### Latency Calculation

Running on a system clock of **25 MHz**:

$$\text{Latency} = \frac{341,960}{25 \times 10^6} \approx \mathbf{13.68 \text{ ms}}$$

This results in \~73 predictions per second. For a human writing digits on a screen, this is effectively instantaneous.

> [\!WARNING]
> **Why 25 MHz instead of 100 MHz?**
> You might notice the Basys 3 has a 100 MHz oscillator, but we divide it down to 25 MHz.
> The SNN logic involves a long **combinational path**: reading a weight from ROM $\rightarrow$ multiplying by input $\rightarrow$ adding to a 32-bit accumulator. This logic chain takes longer than 10 nanoseconds (the period of a 100 MHz clock) to stabilize. Running at 100 MHz causes **timing violations**, leading to unstable or random predictions. Slowing to 25 MHz gives the signals 40 nanoseconds to propagate, ensuring stable and accurate results.

### Resource Consumption

The design was synthesized for the Basys 3 (Artix-7 XC7A35T). The table below summarizes the post-implementation resource utilization:

<p align="center">
<img src="/images/Resource_Utilization.jpg" alt="Model summary" width="600"/>
<br>
<sub>Figure: SNN Model summary</sub>
</p>

* **DSP (Digital Signal Processors) Usage (96%):** This is the most critical change. We have implemented **64 Parallel MAC units**, which consumes almost every available DSP slice on the Artix-7 chip. This massive parallelism allows us to process 64 weights per clock cycle, drastically reducing latency but pushing the hardware to its arithmetic limit.

* **LUT (Look-Up Tables) Usage (76%):** The utilization has increased significantly compared to the sequential version. This is required to support the parallel adder trees (summing 64 products instantly) and the complex muxing logic needed to feed data to 64 multipliers simultaneously.

* **IO Usage (28%) & FF (22%):** Input/Output (LEDs, UART) and Flip-Flop usage remains moderate, indicating that the design is primarily constrained by combinational logic and multipliers.

### Timing Analysis

<p align="center">
<img src="/images/Design_Timing _Summary.jpg" alt="Design Timing Summary" width="800"/>
<br>
<sub>Figure: Post-Implementation Timing Summary</sub>
</p>

The timing report confirms that the design operates reliably at the target frequency of **25 MHz**.

*   **Worst Negative Slack (WNS): +8.429 ns**
    *   This is the most critical metric. A positive WNS of ~8 ns means the signal arrives comfortably before the next clock edge.
    *   Since our clock period is 40 ns (25 MHz), this large margin indicates we could theoretically run the design even faster (up to ~31 MHz) without errors.

*   **Worst Hold Slack (WHS): +0.393 ns**
    *   This confirms that signals do not change too quickly, preventing race conditions where data might pass through a flip-flop before it's safely latched.
    *   Zero failing endpoints across both Setup and Hold checks certifies the hardware stability.

### Physical Layout

<p align="center">
<img src="/images/Implemented_Design.jpeg" alt="Implemented Design Floorplan" width="600"/>
<br>
<sub>Figure: Physical Floorplan of the Implementation</sub>
</p>

The image above shows the actual physical layout of the design on the Artix-7 FPGA. The densely packed regions (teal/green) represent the Slice Logic (LUTs and FFs) used for the neural network computations, while the specific rectangular blocks correspond to the DSP slices utilized for the parallel Multiply-Accumulate operations. 

-----

## Future Prospects

This project is a functional proof-of-concept, but there is plenty of room to scale. Here is how we plan to evolve the design:


* **Pipelining**
In the current architecture, Layer 2 (Hidden $\to$ Output) sits idle until Layer 1 (Input $\to$ Hidden) has completely finished processing all neurons. Future iterations will introduce pipelining, allowing Layer 2 to begin processing the first neuron as soon as Layer 1 finishes it. This overlapping of execution stages would significantly increase the throughput of the system without requiring additional logic resources.

* **Deep SNNs via DDR Memory**
Our weights are currently "baked" into the FPGA logic (Distributed RAM/BRAM), which has very limited capacity. This restricts us to a shallow network with only one hidden layer. To support Deep Neural Networks (DNNs) with millions of parameters, future designs will interface with the external DDR memory on the Basys 3 board. Fetching weights from off-chip memory would allow us to scale the architecture to arbitrarily deep networks, limited only by memory bandwidth rather than chip logic.

* **On-Chip Learning (STDP)**
The FPGA acts as an "inference-only" engine right now; it cannot learn new information and only knows what it was trained on in Python. A major future goal is to implement Spike-Timing-Dependent Plasticity (STDP) directly in hardware. This would allow the FPGA to update its own weights based on the timing of incoming spikes, enabling it to learn your specific handwriting style in real-time without needing to be retrained on a PC.

-----
