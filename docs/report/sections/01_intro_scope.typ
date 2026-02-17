= Project Scope and Objectives

The system target is a live camera-to-HDMI pipeline where all active video processing happens in AXI4-Stream form. The currently implemented processing sequence in this repository is:

$ "RGB" arrow.r "Grayscale" arrow.r "3x3 Window" arrow.r "Sobel" arrow.r "Overlay/Threshold" $ <eq-main-pipeline>

#figure(
  image("../figures/generated/arch_typst.png", width: 100%),
  caption: [High-level realtime image-processing architecture used throughout this report.],
) <fig-scope-arch>

@fig-scope-arch defines the logical data flow boundaries used in RTL and cocotb verification. While the Vivado block design includes additional camera, DDR, and output timing infrastructure, this report focuses on repository-owned modules under `rtl/` and `testbench/`.

== In-Scope Implementations

- AXI4-Stream passthrough and protocol baseline validation.
- Grayscale conversion core and AXI wrapper (`RGB_TO_GRAYSCALE`).
- Sliding window generation for neighborhood-based filtering (`WINDOW_GENERATOR`).
- Sobel edge extraction and composition wrapper (`SOBEL_FILTER`, `FILTER_WRAPPER`).
- RGB edge overlay composition (`EDGE_OVERLAY`).
- Button interaction control path (`DEBOUNCER`, `CLICK_DETECTOR`, `BUTTON_EXAMPLE`).
- cocotb target-based regressions and artifact generation (`testbench/sim_build`).

== Out-of-Scope in This Report

- Full hardware/software runtime profiling on board.
- Final timing closure and post-route utilization sign-off analysis.
- Software application UX workflows outside this FPGA repository.

The guiding acceptance criterion for all in-scope blocks is AXI4-Stream protocol correctness under both continuous flow and stall conditions.
