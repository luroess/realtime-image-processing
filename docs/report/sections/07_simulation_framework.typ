#import "../shared/macros.typ": *

= Simulation Framework using cocotb and cocotbext-axi
#component_owner("Lukas Röß, Jan Duchscherer")

This chapter documents the reusable verification framework in #repo_link("testbench/README.md", line: 1). It excludes detailed explanations of DUT-specific test cases, which are documented in the corresponding component chapters.

== Framework scope and structure
All RTL blocks are verified in a shared cocotb harness under `testbench/`. This framework combines a central target registry, a Python runner, reusable AXI stream drivers and sinks, and shared comparison utilities. Simulation targets are registered in #repo_link("testbench/targets.toml", line: 1, branch: "feat/rollback"), which binds simulator selection, HDL sources, generic overrides, and the cocotb test module to a target key. The `tb-sim` runner (#repo_link("testbench/sim/run.py", body: raw("testbench/sim/run.py"), line: 194, branch: "feat/rollback")) resolves this metadata, compiles the VHDL sources, executes the test (default: GHDL), and stores per-run artifacts under `testbench/sim_build/`.

The harness is organized as reusable stimulus, monitor, and verification layers: drivers under `drivers/` serialize image frames into the project AXI4-Stream Video format, the selected RTL toplevel is built and simulated under `tb-sim --target <key>`, and protocol-aware sinks under `monitors/` deserialize the received output and feed it into reference-model and scoreboard checks (`verification/scoreboard.py`). @fig-tb-arch shows the shared signal-level harness used across targets.

#figure(
  academic_table(
    columns: (auto, auto, auto),
    align: (left, left, left),
    table.header([Framework block], [Main implementation], [Technical role]),
    [Target registry],
    [#repo_link("testbench/targets.toml", body: raw("testbench/targets.toml"), line: 1)],
    [Binds `sim`, `toplevel`, `test_module`, source list, and generic parameters to each target key.],
    [Runner and orchestration],
    [#repo_link("testbench/sim/run.py", body: raw("testbench/sim/run.py"), line: 147)],
    [Parses CLI options, loads one target, resolves sources, and runs `build` plus `test`.],
    [AXI4-Stream stimulus],
    [#repo_link("testbench/drivers/axis_video_source.py", body: raw("axis_video_source.py"), line: 22)],
    [Sends frame lines with `TUSER` as SOF and optional source-side pause patterns.],
    [AXI4-Stream capture],
    [#repo_link("testbench/monitors/axis_video_sink.py", body: raw("axis_video_sink.py"), line: 14)],
    [Receives line packets, checks line shape, and reconstructs pixel tuples from AXI wire order.],
    [Shared utilities],
    [
      #repo_link("testbench/common/reset.py", body: raw("common/reset.py"), line: 8)
      #linebreak()
      #repo_link("testbench/common/pause.py", body: raw("common/pause.py"), line: 17)
    ],
    [Provides deterministic reset sequencing and repeatable sink backpressure generation.],
    [Reference model and checks],
    [
      #repo_link("testbench/models/image_model.py", body: raw("models/image_model.py"), line: 12)
      #linebreak()
      #repo_link("testbench/verification/scoreboard.py", body: raw("verification/scoreboard.py"), line: 10)
    ],
    [Holds image data and reports first mismatch location for frame or window comparisons.],
  ),
  caption: [Reusable testbench framework blocks in #repo_link("testbench", body: raw("testbench/")) without DUT-specific testcases.],
) <tab-sim-framework>

#figure(
  image("../../figures/tb_pipeline.png", width: 82%),
  caption: [Common simulation harness: AXI4-Stream source #sym.arrow DUT #sym.arrow AXI4-Stream sink with shared scoreboard checks.],
) <fig-tb-arch>

== Custom sources, sinks, and helpers
At the stream interface, `AxiVideoStreamSource` drives `s_axis_video` (`TDATA/TVALID/TUSER/TLAST`, `TUSER=SOF`, `TLAST=EOL`) and can throttle `TVALID`; the DUT applies backpressure via `TREADY`. Output traffic is captured by `AxiVideoStreamSink`, which can deassert `TREADY` to create controlled stalls and decodes the project wire-order (`TDATA[23:0] = R|B|G`) into `(R,G,B)` pixels.

Protocol checkers inside DUT-local test modules track `VALID/READY` statistics and assert AXI4-Stream Video invariants such as `SOF`/`EOL` alignment. Expected frames are computed in Python reference models and compared against received frames in `verification/scoreboard.py` with first-mismatch reporting.

#let tb_group_row(label) = table.cell(
  colspan: 2,
  fill: luma(240),
  inset: (x: 4pt, y: 2pt),
  align: left,
)[#text(size: 9pt, weight: "bold", fill: rgb("#475569"))[#label]]

#figure(
  academic_table(
    columns: (auto, 1fr),
    align: (left, left),
    table.header([Implementation], [Description]),
    tb_group_row("Sources"),
    [#repo_link("testbench/drivers/axis_video_source.py", body: raw("AxiVideoStreamSource"), line: 22)],
    [Line-wise AXI4-Stream Video stimulus (`TUSER=SOF`, `TLAST=EOL`) with project wire-order packing.],
    [#repo_link("testbench/drivers/axis_gray_source.py", body: raw("AxiGrayStreamSource"), line: 17)],
    [Gray8 stimulus for single-lane streams using the same framing convention.],
    [#repo_link("testbench/drivers/axis_window_gray_source.py", body: raw("AxiWindowGraySource"), line: 17)],
    [Produces flattened 3#(sym.times)3 windows from a zero-padded gray plane for window-based DUT inputs.],
    tb_group_row("Sinks"),
    [#repo_link("testbench/monitors/axis_video_sink.py", body: raw("AxiVideoStreamSink"), line: 14)],
    [Receives line packets and decodes RGB24 or gray8 output into frames or planes; supports `TREADY` backpressure.],
    [#repo_link("testbench/monitors/axis_gray_sink.py", body: raw("AxiGrayStreamSink"), line: 12)],
    [Receives gray8 output into `(H, W)` `uint8` planes with timeout guards.],
    [#repo_link("testbench/monitors/axis_window_sink.py", body: raw("AxiWindowStreamSink"), line: 13)],
    [Decodes byte-packed window streams into NumPy windows for direct model comparison.],
    tb_group_row("Helpers"),
    [#repo_link("testbench/common/reset.py", body: raw("apply_reset"), line: 8)],
    [Applies deterministic reset and drives known idle values on stream inputs during startup.],
    [#repo_link("testbench/common/pause.py", body: raw("drive_sink_pause"), line: 17)],
    [Drives repeatable sink stall patterns; `repeating_pause` provides a pause generator for cocotbext endpoints.],
    [#repo_link("testbench/models/image_model.py", body: raw("Image"), line: 13)],
    [Canonical `(H, W, 3)` `uint8` image container with indexing and PNG I/O helpers.],
    [#repo_link("testbench/verification/scoreboard.py", body: raw("Scoreboard"), line: 10)],
    [Pixel-exact comparison for full frames and window-list comparisons for window-generator outputs.],
  ),
  caption: [Reusable cocotb harness modules implemented in #repo_link("testbench", body: raw("testbench/")) and reused across verification targets.],
) <tab-tb-components>

== Runtime flow and artifacts
Each run starts from a target key in #repo_link("testbench/targets.toml", line: 1). The runner then resolves and validates target fields (#repo_link("testbench/sim/run.py", line: 159)), compiles the selected source set (#repo_link("testbench/sim/run.py", line: 228)), and executes the cocotb test module (#repo_link("testbench/sim/run.py", line: 237)).

The framework writes regression outputs to #repo_link("testbench/sim_build", body: raw("testbench/sim_build/")). This includes `results.xml`, optional waveform files, and image artifacts emitted by test modules.
