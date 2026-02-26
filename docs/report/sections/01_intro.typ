
#import "../shared/macros.typ": *

= Introduction
This project implements a real-time streaming image-processing chain on a Digilent Zybo Z7-10 (Zynq-7010) FPGA platform, using the Pcam 5C (OV5640) as camera input and HDMI as display output @digilent-zybo@digilent-pcam. Runtime modes are selected via on-board push buttons and control both the filter chain and the final output behavior.

Our work builds on #blink("https://digilent.com/reference/programmable-logic/zybo-z7/demos/pcam-5c")[Digilent's Zybo Z7 Pcam 5C demo], which provides the camera capture, AXI4-Stream Video transport, and display infrastructure @digilent-pcam-demo. Custom processing and control logic is integrated as Vivado IP blocks and communicates exclusively via AXI4-Stream Video to preserve backpressure behavior and frame/line markers.

The active chain converts the incoming RGB stream to grayscale and applies window-based filtering (blur and Sobel edge detection). As a minimum configuration, the system emits a binary black/white edge mask; optional modes overlay the detected edges onto a delayed base image (RGB or grayscale-replicated). This report documents the custom modules for grayscale conversion, changes to the control FSM, and frame composition/stream realignment, together with our cocotb/cocotbext-axi verification harness and Vivado synthesis/implementation utilization results.

Unless stated otherwise, progress is measured in accepted AXI beats (`TVALID && TREADY`); stall cycles do not advance the stream. `TUSER` marks start-of-frame (SOF) and `TLAST` marks end-of-line (EOL). Pixels are encoded as 24-bit `R|B|G` (MSB to LSB), and repository links in this report refer to branch `feat/rollback`.
