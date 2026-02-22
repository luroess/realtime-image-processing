#set page(
  paper: "a4",
  margin: (x: 2.2cm, y: 2.0cm),
  numbering: "1",
)
#set text(font: "Libertinus Serif", size: 10.8pt)
#set heading(numbering: "1.")
#set par(justify: true)
#set math.equation(numbering: "(1)")

#let project = [Realtime Streaming Image Processing on FPGA]
#let subtitle = [Revised Implementation Report: AXI4-Stream Pipeline and Verification Status]
#let team = [Lukas Roess, Valentin Bumeder, Jan Duchscherer, Justin Loeber]

#align(center)[
  #text(size: 18pt, weight: "bold")[#project]
  #v(0.3em)
  #text(size: 11pt)[#subtitle]
  #v(0.9em)
  #team
  #linebreak()
  Embedded Systems, Academic Year 2025-2026
  #linebreak()
  Revision date: 2026-02-21
]

#v(1.1em)

= Abstract
This revised draft aligns the report with the current repository state and removes stale references to legacy integration paths. The active programmable-logic chain covered in this report is `RGB -> Grayscale -> 3x3 windowed filtering -> Sobel -> Frame compositor output selection`, integrated with button-driven control and cocotb verification.

The revision focuses on repository-owned implementation details in `rtl/` and `testbench/`, protocol behavior under AXI4-Stream backpressure, and a reproducible validation snapshot from current target runs. Video stream semantics follow UG934 (`TUSER[0]=SOF`, `TLAST=EOL`) and related AMD guidance.@ug934 @pg232

#figure(
  image("../figures/AXI_Bayer2RGB_Gamma_Corr2Gray.png", width: 94%),
  caption: [Vivado pipeline context around Bayer-to-RGB, gamma correction, and RGB-to-grayscale insertion.],
) <fig-arch>

= Scope and Revision Intent
== In scope
- RTL modules and wrappers in `rtl/` for grayscale conversion, blur/sobel processing, compositing, and pipeline integration.
- cocotb verification framework in `testbench/`, including reusable AXI stream drivers/monitors and target-based execution.
- AXI4-Stream framing correctness and stall safety.

== Out of scope
- Board-level timing closure sign-off and full hardware profiling.
- Non-repository software UX flows.
- Legacy FAST-specific implementation details that are not part of the current active pipeline branch.

== Draft corrections applied
Compared to the previous PDF-only draft, this revision removes stale wording around deprecated wrapper paths, re-centers the integration narrative on `FRAME_COMPOSITOR`, and updates validation status from direct command evidence in the current workspace.

== Prior draft findings addressed in this revision
- Replaced stale module naming (`EDGE_OVERLAY`, `axi_filter_wrapper`) with current active integration ownership (`FRAME_COMPOSITOR` and pipeline composition path).
- Removed hard-coded aggregate testcase claims that were not re-verified during this revision session; replaced with command-backed validation snapshot.
- Marked noisy/unbounded regression behavior explicitly instead of presenting partial execution as complete evidence.

= Protocol Contract and Architecture
The stream transfer contract used in RTL and cocotb scoreboards is:
$ "transfer"_k = "tvalid"_k and "tready"_k $ <eq-transfer>

Under UG934, the following are treated as non-negotiable for active video beats:@ug934
- `TUSER[0]` marks start of frame.
- `TLAST` marks end of line.
- Payload and sidebands stay stable while stalled.
- Only active pixels are transferred over AXI4-Stream video.

The camera and display system context follows Zybo/Pcam platform guidance, while custom logic is implemented in PL stream stages.

= Component Status (Current Repository)
== RGB_TO_GRAYSCALE
`E_RgbToGrayscale` computes grayscale using shift-add arithmetic and emits both `gray8` and replicated `rbg888`. The approximation is:
$ Y approx (R/4) + (G/2) + (B/4) $ <eq-gray>

`AXI_RgbToGrayscale` decouples dual outputs using per-branch sent flags and a pending-beat slot, avoiding combinational `TVALID <-> TREADY` loops between RGB and gray branches.

== FRAME_COMPOSITOR
`AXI_FrameCompositor` is the active output-composition owner. It aligns delayed RGB base data with gray timing/mask streams using selectable delay stages (`NONE`, `SOBEL`, `BLUR_SOBEL`) and an internal validity conveyor.

The compositor includes:
- control-stability assertions across frame boundaries,
- guarded fallback for reserved delay selector values,
- prefill-aware ready logic to avoid deadlock during delay warm-up.

#figure(
  image("figures/frame_compositor_architecture_trimmed.png", width: 84%),
  caption: [Frame compositor architecture used for output mux/overlay behavior.],
) <fig-compositor>

== PIPELINE integration
`AXI_RgbGrayBlurrSobelOverlayPipeline` latches runtime control bits on accepted input SOF and routes final output through `AXI_FrameCompositor`. This ensures mode selection changes at frame boundaries and keeps output ownership centralized.

== Button/control path
`DebouncedClickDetector` provides debounced control outputs and overlay/base-mode signals consumed by the pipeline. Control semantics are therefore part of integration correctness, not only UI behavior.

= Verification Framework
The regression flow is target-driven through `tb-sim` (`testbench/sim/run.py`) and target registry metadata in `testbench/targets.toml`.

The cocotb framework uses typed helpers and protocol-aware endpoints:@cocotb-writing @cocotb-timing
- source drivers (`axis_video_source`, `axis_gray_source`),
- sinks/monitors (`axis_video_sink`, `axis_gray_sink`, `axis_window_sink`),
- scoreboarding and image-model comparisons,
- per-target artifacts (`results.xml`, optional `.ghw`, output images).

Important project-specific wire-order note used consistently in tests:
- AXI wire order: `TDATA[23:0] = R|B|G`.
- Python-side tuples and scoreboards: `(R, G, B)` after decode.

= Validation Snapshot (2026-02-21)
Command evidence from this revision session:

- `uv run tb-sim --list-targets`: 16 registered targets.
- `uv run tb-sim --target axi_rgb_to_grayscale`: `PASS 3/3`.
- `uv run tb-sim --target frame_compositor_core`: `PASS 1/1`.
- `uv run tb-sim --target shift_ram_chain`: `PASS 4/4`.
- `uv run tb-sim --target axi_gray_blurr_sobel_overlay_pipeline_downscaled`: `PASS 2/2`.

#figure(
  image("figures/generated/fig_test_runtime_by_target.png", width: 84%),
  caption: [Stored runtime distribution chart from generated report artifacts.],
) <fig-runtime>

#figure(
  image("figures/generated/fig_testcase_count_by_module.png", width: 84%),
  caption: [Stored testcase distribution by module area.],
) <fig-count>

Caveat: an unbounded `axi_frame_compositor` run produced excessive simulator warnings in this session; bounded compositor targets were used for deterministic reporting.

= Risks and Open Gaps
Current open issues tracked in `.codex/ISSUES.md` include:
- click-detector expectation drift in one legacy-aligned test,
- runtime sensitivity for large full-pipeline regression targets,
- bootstrap gaps (`.codex/Questions.md` and note-generator script availability),
- potential overlay-mode prefill deadlock in `AXI_FrameCompositor` + `AXI_RgbToGrayscale` handshake coupling (needs dedicated non-passthrough stress tests),
- synthesis portability risk from `ShiftRamChain` dependency on packaged `c_shift_ram_0` IP.

These are process, portability, and coverage concerns. They do not invalidate the passing focused evidence above, but should be closed before final publication.

= Next Steps
1. Add the missing editable source workflow permanently (`report.typ` + build command) so future edits are reviewable.
2. Re-run the full pipeline target with explicit wall-time budget and capture its final artifact summary.
3. Resolve bootstrap gaps and keep AGENTS requirements synchronized with repository reality.

#bibliography("references.bib", title: [References])
