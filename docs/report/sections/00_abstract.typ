#import "../shared/macros.typ": *

= Abstract

This report documents the implementation status of a real-time image-processing pipeline on Zybo Z7-10 with Pcam 5C input and AXI4-Stream video processing in programmable logic. The integrated processing chain is `RGB -> Grayscale -> 3x3 Window -> Sobel -> Threshold/Overlay`, verified with cocotb and GHDL using protocol-aware scoreboards and image-model based reference checks.

The current repository contains implemented RTL and verification assets for passthrough, grayscale conversion, window generation, Sobel filtering, filter wrapping, edge overlay, and the button control path (debounce/click detection). The report combines architecture rationale, implementation details, AXI framing guarantees, and simulation evidence extracted from generated JUnit results and output image artifacts.

The project objective is not only feature completeness but deterministic stream behavior under backpressure. Therefore, the verification strategy emphasizes `TVALID/TREADY` stability, `SOF`/`EOL` alignment, and multi-module interoperability at frame boundaries.

#let junit = csv("../data/junit_metrics.csv", row-type: dictionary)
#let total_tests = junit.len()
#let passed_tests = junit.filter(it => it.status == "pass").len()
#let module_areas = (
  "Example Passthrough",
  "RGB2Gray",
  "Window Generator",
  "Sobel + Filter Wrapper",
  "Edge Overlay",
  "Debounce/Click/Button path",
)
#let module_count = module_areas.len()

#section_kpis((
  (title: "Recorded testcases", value: str(total_tests), note: "Parsed from JUnit XML artifacts in simulation builds"),
  (title: "Passing testcases", value: str(passed_tests), note: "Current stored artifact set"),
  (title: "Module areas covered", value: str(module_count), note: "RTL + control + wrapper scope"),
))

The remaining sections provide a module-by-module implementation review and conclude with contribution analytics and prioritized risks.
