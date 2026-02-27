#import "../shared/macros.typ": *

= Simulation Framework using cocotb and cocotbext-axi
#component_owner("Jan Duchscherer, Lukas Röss, Valentin Bumeder, Justin Löber")

All RTL blocks are verified in a shared cocotb harness under `testbench/`. Simulation targets are registered in #repo_link("testbench/targets.toml", line: 1, branch: "feat/rollback"), which binds simulator selection, HDL sources, generic overrides, and the cocotb test module to a target key. The `tb-sim` runner (#repo_link("testbench/sim/run.py", body: raw("testbench/sim/run.py"), line: 194, branch: "feat/rollback")) executes these targets (default: GHDL) and stores per-run artifacts under `testbench/sim_build/`.

#figure(
  academic_table(
    columns: (auto, auto, auto),
    align: (left, left, left),
    table.header([Stimulus], [DUT], [Checks]),
    [`drivers/axis_*_source.py`],
    [RTL toplevel under `tb-sim --target ...`],
    [`monitors/axis_*_sink.py` + `verification/scoreboard.py`],
    [custom serialization to project AXI wire order],
    [AXI4-Stream video handshake + control],
    [golden reference comparison and protocol assertions],
  ),
  caption: [Testbench structure: Source (+ serialization) #sym.arrow UUT #sym.arrow Sink (+ deserialization) with scoreboard checks.],
) <tab-tb-architecture>

The reusable layers in @tab-tb-architecture map onto a shared signal-level harness around the DUT, shown in @fig-tb-arch.

#figure(
  image("../../figures/tb_pipeline.png", width: 82%),
  caption: [Common cocotbext-axi AXI4-Stream video harness used across targets: per-line packet source #sym.arrow DUT #sym.arrow sink with protocol checks and golden-reference comparison.],
) <fig-tb-arch>

At the stream interface, `AxiVideoStreamSource` drives `s_axis_video` (`TDATA/TVALID/TUSER/TLAST`, `TUSER=SOF`, `TLAST=EOL`) and can throttle `TVALID`; the DUT applies backpressure via `TREADY`. Output traffic is captured by `AxiVideoStreamSink`, which can deassert `TREADY` to create controlled stalls and decodes the project wire-order (`TDATA[23:0] = R|B|G`) into `(R,G,B)` pixels. Protocol checkers inside DUT-local test modules track `VALID/READY` statistics and assert invariants such as `SOF`/`EOL` placement and stall-stability. Expected frames are computed in Python reference models and compared against received frames in `verification/scoreboard.py` (first-mismatch reporting). Common utilities include deterministic reset (`common/reset.py`), configurable pause patterns (`common/pause.py`), and cocotb `with_timeout` wrappers to turn missing output progress into actionable failures.

== Active target snapshot and purpose
#figure(
  academic_table(
    columns: (auto, auto, auto),
    align: (left, left, left),
    table.header([Target key], [Primary DUT], [Purpose / stress focus]),
    [axi_rgb_to_grayscale],
    [AXI_RgbToGrayscale],
    [Dual-branch handshake correctness and SOF/EOL alignment under branch backpressure.],
    [test_click_detector],
    [ClickDetector],
    [BTN-edge FSM sequencing and output decode checks for processing/base mode controls.],
    [shift_ram_chain],
    [ShiftRamChain],
    [Delay-tap progression and accepted-beat accounting across chunked shift-RAM stages.],
    [axi_frame_compositor],
    [AXI_FrameCompositor],
    [Prefill gating, merge-mode lockstep behavior, and gray-timed output ownership.],
    [axi_gray_blurr_sobel_ #linebreak() overlay_pipeline_ #linebreak() downscaled],
    [AXI_RgbGrayBlurrSobel #linebreak() OverlayPipeline],
    [Integrated reset/mode/backpressure regression on a bounded 64x64 frame workload.],
  ),
  caption: [Representative target mapping from #repo_link("testbench/targets.toml", line: 1, branch: "feat/rollback"); `targets.toml` remains source-of-truth for the full registry.],
) <tab-target-overview>

// #figure(
//   image("../figures/generated/fig_test_runtime_by_target.png", width: 82%),
//   caption: [Stored runtime distribution by simulation target.],
// ) <fig-runtime>

// #figure(
//   image("../figures/generated/fig_testcase_count_by_module.png", width: 82%),
//   caption: [Stored testcase distribution by module area.],
// ) <fig-testcount>
For each run, cocotb writes `results.xml` and (optionally) waveform dumps (`.ghw`/`.vcd`) plus output image artifacts into `testbench/sim_build/`. Targets are invoked via `tb-sim --target <key>`; the full registry can be inspected via `tb-sim --list-targets` and remains centralized in `targets.toml`.
