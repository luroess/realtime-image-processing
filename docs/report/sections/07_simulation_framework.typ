#import "../shared/macros.typ": *

= Simulation Framework using cocotb and cocotbext-axi
#component_owner("Lukas Roess, Jan Duchscherer, Valentin Bumeder, Justin Loeber")

The verification stack is organized as reusable source/sink/model/scoreboard layers in `testbench/` and executed through target registration in #repo_link("testbench/targets.toml", line: 1), with runner entrypoint #repo_link("testbench/sim/run.py", body: raw("testbench/sim/run.py"), line: 194).

#figure(
  academic_table(
    columns: (1.55fr, 1.75fr, 1.9fr),
    align: (left, left, left),
    table.header([Stimulus], [DUT], [Checks]),
    [`drivers/axis_*_source.py`], [RTL toplevel under `tb-sim --target ...`], [`monitors/axis_*_sink.py` + `verification/scoreboard.py`],
    [custom serialization to project AXI wire order], [AXI4-Stream video handshake + control], [golden reference comparison and protocol assertions],
  ),
  caption: [Testbench structure: Source (+ serialization) -> UUT -> Sink (+ deserialization) with scoreboard checks.],
) <tab-tb-architecture>

Framework elements aligned with cocotb timing/writing guidance:@cocotb-writing @cocotb-timing @cocotbext-axi
- deterministic reset/startup helper (`common/reset.py`),
- configurable backpressure generation (`common/pause.py`),
- typed AXI stream drivers and sinks for RGB and gray paths,
- per-target artifact generation (`results.xml`, `.ghw`/`.vcd`, output images).

Stress dimensions covered by active targets include:
- backpressure/stall robustness,
- reset and initialization transitions,
- frame-boundary correctness (`SOF`/`EOL`),
- mode/control transitions through button-driven FSM paths,
- timeout handling via cocotb `with_timeout` wrappers in sink APIs.

== Active target snapshot and purpose
#figure(
  academic_table(
    columns: (1.25fr, 1.2fr, 2.1fr),
    align: (left, left, left),
    table.header([Target key], [Primary DUT], [Purpose / stress focus]),
    [axi_rgb_to_grayscale], [AXI_RgbToGrayscale], [Dual-branch handshake correctness and SOF/EOL alignment under branch backpressure.],
    [test_click_detector], [ClickDetector], [BTN-edge FSM sequencing and output decode checks for processing/base mode controls.],
    [shift_ram_chain], [ShiftRamChain], [Delay-tap progression and accepted-beat accounting across chunked shift-RAM stages.],
    [axi_frame_compositor], [AXI_FrameCompositor], [Prefill gating, merge-mode lockstep behavior, and gray-timed output ownership.],
    [axi_gray_blurr_sobel_ #linebreak() overlay_pipeline_ #linebreak() downscaled], [AXI_RgbGrayBlurrSobel #linebreak() OverlayPipeline], [Integrated reset/mode/backpressure regression on a bounded 64x64 frame workload.],
  ),
  caption: [Representative target mapping from #repo_link("testbench/targets.toml", line: 1); the full target registry remains source-of-truth in `targets.toml`.],
) <tab-target-overview>

#figure(
  image("../figures/generated/fig_test_runtime_by_target.png", width: 82%),
  caption: [Stored runtime distribution by simulation target.],
) <fig-runtime>

#figure(
  image("../figures/generated/fig_testcase_count_by_module.png", width: 82%),
  caption: [Stored testcase distribution by module area.],
) <fig-testcount>
