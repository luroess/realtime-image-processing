#import "../shared/macros.typ": *

= Conclusion

In this project, we extended Digilent's Zybo Z7 Pcam 5C reference design with a real-time AXI4-Stream Video processing chain and runtime control on the Zybo Z7-10 platform. \
While we managed to implement the planned features, we did not succeed in verifying the correctnes of a single end-to-end streaming pipeline on the HW with all components integrated before the project deadline.
The main blockers were toolchain complexity (Vivado/Vitis), the time spent making the projects version-control-friendly, and the learning curve around correct AXI4-Stream Video behavior and verification.

Despite these challenges, we gained a much deeper understanding of the AXI4 protocols, the Vivado design flow, general HW design principles and tradeoffs, and the cocotb verification framework.
