= Scope and Revision Intent
== In scope
- RTL modules and wrappers in `rtl/` for grayscale conversion, blur/sobel processing, compositing, and pipeline integration.
- cocotb verification framework in `testbench/`, including reusable AXI stream drivers/monitors and target-based execution.
- AXI4-Stream framing correctness, backpressure behavior, and frame-boundary control semantics.
- Vivado-backed synthesis/implementation utilization evidence for key modules and full-system placement.

== Out of scope
- Board-level timing closure sign-off and full hardware performance profiling.
- Non-repository software UX flows.
- Legacy FAST-specific implementation details that are not part of the current active integration branch.

== Draft corrections applied
Compared to previous draft snapshots, this revision:
- removes stale naming and ownership claims around deprecated wrappers,
- centers integration ownership on `FRAME_COMPOSITOR` and the current pipeline wrapper,
- replaces stale aggregate testcase statements with command-backed evidence,
- adds explicit notes where regressions/noise remain open rather than implying full closure.
