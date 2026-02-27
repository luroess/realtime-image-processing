#import "../shared/macros.typ": *

= Simulation Framework using cocotb and cocotbext-axi
#component_owner("Jan Duchscherer, Lukas Röss, Valentin Bumeder, Justin Löber")

All RTL blocks are verified in a shared cocotb harness under `testbench/`. Simulation targets are registered in #repo_link("testbench/targets.toml", line: 1, branch: "feat/rollback"), which binds simulator selection, HDL sources, generic overrides, and the cocotb test module to a target key. The `tb-sim` runner (#repo_link("testbench/sim/run.py", body: raw("testbench/sim/run.py"), line: 194, branch: "feat/rollback")) executes these targets (default: GHDL) and stores per-run artifacts under `testbench/sim_build/`.

The harness is organized as reusable stimulus, monitor, and verification layers: drivers under `drivers/` serialize image frames into the project AXI4-Stream Video format, the selected RTL toplevel is built and simulated under `tb-sim --target <key>`, and protocol-aware sinks under `monitors/` deserialize the received output and feed it into reference-model and scoreboard checks (`verification/scoreboard.py`). @fig-tb-arch illustrates the shared signal-level harness used across targets.

#figure(
  image("../../figures/tb_pipeline.png", width: 82%),
  caption: [Common cocotbext-axi AXI4-Stream video harness used across targets: per-line packet source #sym.arrow DUT #sym.arrow sink with protocol checks and golden-reference comparison.],
) <fig-tb-arch>


== Custom sources, sinks, and helpers
At the stream interface, `AxiVideoStreamSource` drives `s_axis_video` (`TDATA/TVALID/TUSER/TLAST`, `TUSER=SOF`, `TLAST=EOL`) and can throttle `TVALID`; the DUT applies backpressure via `TREADY`. Output traffic is captured by `AxiVideoStreamSink`, which can deassert `TREADY` to create controlled stalls and decodes the project wire-order (`TDATA[23:0] = R|B|G`) into `(R,G,B)` pixels. Protocol checkers inside DUT-local test modules track `VALID/READY` statistics and assert AXIS-Video specific signals such as `SOF`/`EOL` synchronization. Expected frames are computed in Python reference models and compared against received frames in `verification/scoreboard.py` (first-mismatch reporting). Common utilities include deterministic reset (`common/reset.py`), configurable pause patterns (`common/pause.py`), and cocotb `with_timeout` wrappers to turn missing output progress into actionable failures.
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
    [#repo_link(
      "testbench/drivers/axis_video_source.py",
      body: [`AxiVideoStreamSource`],
      line: 22,
      branch: "feat/rollback",
    )],
    [Line-wise AXI4-Stream Video stimulus (`TUSER=SOF`, `TLAST=EOL`) with RGB24 packing in project wire order (`pixel_order`: `rbg`/`rgb`).],
    [#repo_link(
      "testbench/drivers/axis_gray_source.py",
      body: [`AxiGrayStreamSource`],
      line: 17,
      branch: "feat/rollback",
    )],
    [Gray8 stimulus for single-lane streams; mirrors the same `SOF`/`EOL` sideband convention.],
    [#repo_link(
      "testbench/drivers/axis_window_gray_source.py",
      body: [`AxiWindowGraySource`],
      line: 17,
      branch: "feat/rollback",
    )],
    [Produces flattened 3#(sym.times)3 windows (9 lanes) from a zero-padded gray plane for window-based DUT inputs.],
    tb_group_row("Sinks"),
    [#repo_link(
      "testbench/monitors/axis_video_sink.py",
      body: [`AxiVideoStreamSink`],
      line: 14,
      branch: "feat/rollback",
    )],
    [Receives line packets and decodes RGB24/gray8 output into frames/planes with per-line timeouts; provides direct `TREADY` pause control to create backpressure.],
    [#repo_link(
      "testbench/monitors/axis_gray_sink.py",
      body: [`AxiGrayStreamSink`],
      line: 12,
      branch: "feat/rollback",
    )],
    [Receives gray8 output into a `(H, W)` `uint8` plane; supports `TREADY` throttling and timeouts.],
    [#repo_link(
      "testbench/monitors/axis_window_sink.py",
      body: [`AxiWindowStreamSink`],
      line: 13,
      branch: "feat/rollback",
    )],
    [Decodes byte-packed window streams into a flat list of NumPy windows for comparison against reference models.],
    tb_group_row("Helpers"),
    [#repo_link("testbench/common/reset.py", body: [`apply_reset`], line: 8, branch: "feat/rollback")],
    [Applies deterministic reset and drives known idle values on stream inputs during startup.],
    [#repo_link("testbench/common/pause.py", body: [`drive_sink_pause`], line: 17, branch: "feat/rollback")],
    [Drives repeating `TREADY` stall patterns on sinks; `repeating_pause` also exposes a pause generator for cocotbext endpoints.],
    [#repo_link("testbench/models/image_model.py", body: [`Image`], line: 13, branch: "feat/rollback")],
    [Canonical `(H, W, 3)` `uint8` container with pixel indexing helpers and PNG import/export for saved artifacts.],
    [#repo_link("testbench/verification/scoreboard.py", body: [`Scoreboard`], line: 10, branch: "feat/rollback")],
    [Pixel-exact comparison for full frames (first mismatch reporting) and window-list comparisons for window-generator outputs.],
    [#repo_link(
        "testbench/drivers/click_detection_driver.py",
        body: [`ClickDetectionDriver`],
        line: 7,
        branch: "feat/rollback",
      ) #linebreak() #repo_link(
        "testbench/drivers/debouncing_driver.py",
        body: [`DebouncingDriver`],
        line: 8,
        branch: "feat/rollback",
      )],
    [Deterministic button pulse generation and bounce patterns for control-path RTL.],
  ),
  caption: [Reusable cocotb harness modules (endpoints + helpers) implemented in `testbench/` and reused across verification targets.],
) <tab-tb-components>

For each run, cocotb writes `results.xml` and (optionally) waveform dumps (`.ghw`/`.vcd`) plus output image artifacts into `testbench/sim_build/`. Targets are invoked via `tb-sim --target <key>`; the full registry can be inspected via `tb-sim --list-targets` and remains centralized in `targets.toml`.
