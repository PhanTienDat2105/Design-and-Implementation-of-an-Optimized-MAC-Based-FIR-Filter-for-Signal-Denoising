# Design and Implementation of an Optimized MAC-Based FIR Filter for Signal Denoising

## Overview
This project presents the design and implementation of a high-performance digital signal processing system based on an optimized Multiply-Accumulate (MAC) architecture integrated into a Finite Impulse Response (FIR) filter. The system is designed to perform real-time signal denoising, targeting both biomedical signals (ECG) and audio signals.

The main objective is to improve processing speed, reduce power consumption, and optimize hardware resource utilization on FPGA platforms while maintaining high signal fidelity.

---

## Problem Statement
Electrocardiogram (ECG) signals are often corrupted by various types of noise such as:
- Power line interference (50 Hz)
- Electromyographic (EMG) noise
- Baseline wander (low-frequency drift)

Similarly, audio signals are affected by background noise that reduces clarity. Traditional FIR implementations using standard MAC architectures face limitations in speed, power efficiency, and hardware cost.

---

## Proposed Solution
This project proposes a hybrid solution combining:

### 1. Algorithm-Level Optimization
- **Moving Average Filter**: Removes baseline wander (low-frequency noise)
- **Equiripple FIR Filter**: Eliminates high-frequency noise (EMG, power line interference)
- Model-based design using MATLAB for algorithm validation

### 2. Hardware-Level Optimization
- Custom **Two-cycle Pipelined MAC architecture**
- Removal of redundant carry propagation
- Balanced pipeline stages for higher clock frequency
- Improved energy efficiency and reduced critical path delay

---

## System Architecture
The system consists of two main stages:

1. **Baseline Removal Stage**
   - Uses Moving Average filtering
   - Acts as a high-pass filter after subtraction

2. **FIR Filtering Stage**
   - Implements Equiripple FIR filter
   - Performs convolution using optimized MAC unit

The entire system is implemented using Verilog HDL and deployed on FPGA.

---

## Key Features
- Real-time signal processing capability
- High-speed MAC architecture (2-cycle pipeline)
- Reduced power consumption
- Efficient FPGA resource utilization
- Bit-accurate verification with MATLAB reference
- Reconfigurable filtering for multiple applications

---

## Applications

### Biomedical Signal Processing
- ECG signal denoising
- Removal of baseline drift and noise
- Preservation of waveform morphology (P, QRS, T waves)

### Audio Signal Processing
- Frequency-based source separation
- Low-pass filtering (e.g., piano extraction)
- High-pass filtering (e.g., bird chirp isolation)

---

## Implementation Flow
1. Algorithm design and simulation in MATLAB
2. Hardware design using Verilog HDL
3. Integration of optimized MAC into FIR filter
4. FPGA synthesis and implementation
5. Verification using testbench and waveform comparison
6. Validation against MATLAB golden reference

---

## Results
- Accurate noise removal in ECG signals
- Clear signal reconstruction with minimal distortion
- Successful real-time hardware operation
- Improved performance compared to standard MAC designs:
  - Higher operating frequency
  - Lower energy consumption
  - Reduced hardware area

---

## Conclusion
The project demonstrates that integrating an optimized MAC architecture into an FIR filter significantly enhances performance for real-time signal processing applications. The proposed system achieves a balance between speed, accuracy, and hardware efficiency, making it suitable for embedded and biomedical systems.

---

## Future Work
- Hardware deployment on physical FPGA boards
- Integration with real-time sensor inputs
- Extension to multi-channel signal processing
- Further optimization for low-power wearable devices
