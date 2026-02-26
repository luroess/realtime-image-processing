
= Abstract
This revision aligns the implementation report with the current repository state and the TODO requirements for component-level technical depth. The active processing chain covered in this version is RGB #sym.arrow Grayscale #sym.arrow 3x3 line-buffer/window #sym.arrow Sobel #sym.arrow Frame compositor, with runtime control handled by the debounced click-detector path.

The report focuses on repository-owned assets under `rtl/`, `testbench/`, and `docs/report/analysis/`. In particular, this draft adds protocol background, per-component interface contracts, waveform-backed transaction timing, and synthesis evidence extracted from Vivado reports into CSV/JSON that are directly consumed by Typst in this document.

Standards-oriented claims for AXI4-Stream Video semantics and cocotb timing/driver behavior are tied to primary references from AMD, cocotb, and Digilent.@UG934 @cocotb-writing @cocotb-timing @digilent-zybo

= Scope

- RTL modules and wrappers in `rtl/` for grayscale conversion, blur/sobel processing, compositing, and pipeline integration.
- cocotb verification framework in `testbench/`, including reusable AXI stream drivers/monitors and target-based execution.
- AXI4-Stream framing correctness, backpressure behavior, and frame-boundary control semantics.
- Vivado-backed synthesis/implementation utilization evidence for key modules and full-system placement.

