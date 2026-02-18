#import "../shared/macros.typ": *

= Verification Framework and Execution Flow

#component_owner("Lukas Roess, Jan Duchscherer, Valentin Bumeder, Justin Loeber")

The verification environment is cocotb-based and target-driven through #repo_link("testbench/sim/run.py", body: raw("tb-sim"), line: 194).@cocotb_writing_testbenches A target in #repo_link("testbench/targets.toml") declares toplevel HDL, test module, and source set. This keeps DUT selection reproducible and decoupled from command-line complexity.

#figure(
  image("../figures/generated/tb_architecture_typst.png", width: 95%),
  caption: [cocotb verification architecture with drivers, monitors, and scoreboard checks.],
) <fig-tb-architecture>

The testbench combines protocol checks and functional checks using cocotb scheduling/timing semantics and AXI endpoint models.@cocotb_timing_model @cocotbext_axi

- Protocol checks: accepted beat counting, stall stability, `SOF`/`EOL` semantics.
- Functional checks: expected-vs-observed payload comparisons (pixel stream or window stream).
- Artifact checks: per-run `results.xml`, optional waveforms (`.ghw`), and image outputs.

== Operational Sequence (Streamlit-UI style adaptation)

#mono_block([
1) Select simulation target (`tb-sim --target <target-key>`)
2) Resolve sources + toplevel + cocotb module
3) Build and run with simulator backend
4) Drive AXI stream sources under optional backpressure
5) Capture and verify sink outputs in scoreboard
6) Emit XML/wave/image artifacts for reporting
])

== Verification Targets Used in this Report

#academic_table(
  columns: (2fr, 2fr, 1.7fr),
  align: (left, left, left),
  table.header([Target], [DUT focus], [Verification intent]),
  [example_passthrough], [AXI stream pass-through], [baseline protocol and roundtrip],
  [axi_rgb_to_grayscale], [RGB to gray conversion], [functional transform + sideband checks],
  [window_generator], [KxK neighborhood streaming], [window validity + framing],
  [axi_sobel_filter], [edge extraction], [gradient behavior + handshake under load],
  [axi_filter_wrapper], [window+sobel integrated wrapper], [end-to-end streaming integration],
  [test_debouncer/test_click_detector], [button path], [timing and state transitions],
)

Artifact-only targets observed in stored `sim_build` evidence (but not currently listed in #repo_link("testbench/targets.toml", body: raw("targets.toml"))) are `axi_edge_overlay` and `axi_windowed_filter_wrapper`.

The generated evidence used later in Section 8 is parsed directly from #repo_link("testbench/sim_build/", body: raw("testbench/sim_build/**/results.xml")).
