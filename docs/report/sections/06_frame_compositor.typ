#import "../shared/macros.typ": *
#import "@preview/algorithmic:1.0.7"
#import algorithmic: algorithm-figure

= Component: FRAME_COMPOSITOR <ch-frame-comp>
#component_owner("Jan Duchscherer")

#figure(
  grid(
    columns: (auto, auto, auto),
    figure(image("../figures/pipeline_state2_blur_sobel.png", width: 90%)),
    figure(image("../figures/pipeline_sobel_overlay_on_grayscale.png", width: 90%)),
    figure(image("../figures/pipeline_sobel_overlay_on_rgb888.png", width: 90%)),
  ),
  caption: [Full Pipeline Artifacts: binary mask output (left) and edge overlay on grayscale (middle) or RGB base stream (right).],
) <fig-frame-overlay>

== Overview
The `AXI_FrameCompositor` (#repo_link("rtl/FRAME_COMPOSITOR/hdl/axi_frame_compositor.vhd", line: 4, branch: "feat/rollback")) is responsible for the composition of final output frames, providing functionality to overlay detected edges onto the original RGB image or to emit a binary mask image, depending on the runtime mode.

#figure(
  image("../../figures/ip-cores/AxiFrameCompositor.png", width: 45%),
  caption: [AXI_FrameCompositor top-level IP-core wrapper with dual-stream inputs, delay-stage select, and composed RGB output.],
) <fig-frame-arch>

It receives two AXI4-Stream Video inputs that originate from different branches: a base `rbg888` stream and a processed `gray8` stream that acts as timing reference and carries the edge mask. Because Sobel (and optional Blur+Sobel) are window-based stages, the processed branch exhibits a deterministic warm-up latency after each `SOF`, so the two streams cannot be consumed in lockstep without explicit re-alignment.

The module resolves this phase-mismatch by buffering the *base* branch. Each accepted base beat is packed as `{SOF, EOL, RBG24}` and propagated through a chain of RAM-based shift registers (`ShiftRamChain`, #repo_link("rtl/FRAME_COMPOSITOR/hdl/shift_ram_chain.vhd", line: 10, branch: "feat/rollback")) only when `TVALID && TREADY` is true. A runtime selector (`i_base_delay_stage_sel`) chooses which delay tap is used to align the base stream to the current processing mode, while the gray stream remains the sole output framing reference (`TVALID`, `TUSER=SOF`, `TLAST=EOL`). The wrapper therefore emits output beats only when the gray reference is valid and, in merge mode, the selected delayed-base tap contains valid data.

Two output modes are supported in the implementation on branch `feat/rollback`. In overlay mode (`i_overlay_zeros = 0`), `FrameCompositor` overwrites the delayed base pixel#footnote([which may be color or grayscale-replicated based on `*_pass_grayscale`]) with `G_EDGE_COLOR` whenever the mask indicates an edge (`gray8 != 0`). In binary mode (`i_overlay_zeros = 1`), the base stream is not required; the module emits a black/white mask image (white for non-zero mask) while still remaining gray-timed. Note that on branch #blink("https://github.com/luroess/realtime-image-processing/tree/feat/frame-compositor")[`feat/frame-compositor`], the `FRAME_COMPOSITOR` is also capable of emitting the blur-only stream.

To avoid deadlock during warm-up, READY generation is _asymmetric_ during prefill: while the gray stream is idle (`s_axis_gray8_tvalid=0`), the wrapper keeps gray `TREADY` high and shifts base beats through `ShiftRamChain` until the selected tap becomes valid. Once `s_axis_gray8_tvalid=1`, the wrapper stalls gray until prefill completes. Runtime controls are expected to change only at `SOF`; the RTL includes simulation guards for mid-frame control toggles and for SOF/EOL mismatch between gray timing and the delayed base stream (#repo_link("rtl/FRAME_COMPOSITOR/hdl/axi_frame_compositor.vhd", line: 200, branch: "feat/rollback")).

== Interface ports and generics
#figure(
  interface_table(
    generics: (
      [`G_COMPONENT_WIDTH`],
      [generic],
      [positive],
      [Component width for the fixed `{SOF, EOL, RBG24}` shift-RAM payload contract.],
      [`G_EDGE_COLOR`],
      [generic],
      [`slv(23:0)`],
      [Overlay color used by `FrameCompositor` when edge mask is active (default `x"FF0000"`).],
      [`G_LINE_WIDTH`, `G_SOBEL_KERNEL_SIZE`, `G_BLUR_KERNEL_SIZE`],
      [generic],
      [positive],
      [Branch-wise delay derivation parameters.],
      [`G_SOBEL_DELAY_OVERRIDE`, `G_BLUR_SOBEL_DELAY_OVERRIDE`],
      [generic],
      [natural],
      [Optional non-zero override for derived delay taps.],
    ),
    ports: (
      [`i_overlay_zeros`],
      [in],
      [1],
      [Select binary output (`1`) vs delayed-base overlay compose (`0`).],
      [`i_base_delay_stage_sel[1:0]`],
      [in],
      [2],
      [Delay tap selector (`00` none, `01` sobel, `10` blur+sobel, `11` reserved alias to sobel, intended for FAST).],
      [`s_axis_rbg888_*`],
      [in/out],
      [AXI4-Stream Video],
      [Base RGB stream; accepted beats advance `ShiftRamChain` (`i_ce`).],
      [`s_axis_gray8_*`],
      [in/out],
      [AXI4-Stream Video],
      [Gray/mask stream; timing reference for output `tvalid`, `tuser`, and `tlast`.],
      [`m_axis_rbg888_*`],
      [out/in],
      [AXI4-Stream Video],
      [Final RGB output (binary mask or composed delayed-base image).],
    ),
  ),
  caption: [AXI_FrameCompositor interface and control contract from #repo_link("rtl/FRAME_COMPOSITOR/hdl/axi_frame_compositor.vhd", line: 4, branch: "feat/rollback").],
) <tab-frame-if>

== AXI Interface implementation
`AXI_FrameCompositor` composes `ShiftRamChain` and `FrameCompositor` in series: the base stream is first synchronized and then optionally overwritten with an edge color. The gray stream is the timing reference for output emission and framing signals; `TUSER` and `TLAST` on the output are therefore forwarded from the gray branch when (and only when) valid transmission occurs. The base branch is advanced by driving `ShiftRamChain.i_ce` with the base handshake pulse `s_base_accept` (#repo_link("rtl/FRAME_COMPOSITOR/hdl/axi_frame_compositor.vhd", line: 229, branch: "feat/rollback")).

For readability, we omit the `_video_` infix used in the RTL entity port names (e.g. `s_axis_rbg888_*` refers to `s_axis_video_rbg888_*`).

$
  "s_base_accept" & = "s_axis_rbg888_tvalid" and "s_axis_rbg888_tready"
$

The wrapper packs each accepted base beat as `{SOF, EOL, RBG24}` into fixed 26-bit word `s_base_word_in` (#repo_link("rtl/FRAME_COMPOSITOR/hdl/axi_frame_compositor.vhd", line: 229, branch: "feat/rollback")). Prefill completion is tracked separately through `s_base_valid_pipe` which is clocked only on accepted base beats (#repo_link("rtl/FRAME_COMPOSITOR/hdl/axi_frame_compositor.vhd", line: 238, branch: "feat/rollback")):
$
  "s_prefill_done" & = "i_overlay_zeros" or "s_base_delayed_valid"
$
Merge mode can start only once the selected delayed-base tap is valid:

$
  "s_required_valid" & = "s_axis_gray8_tvalid" and ("s_base_delayed_valid" or "i_overlay_zeros").
$

The decision tree below depicts the combinational assignments for `s_axis_gray8_tready` and `s_axis_rbg888_tready` (#repo_link("rtl/FRAME_COMPOSITOR/hdl/axi_frame_compositor.vhd", line: 307, branch: "feat/rollback")).
#{
  show: style-algorithm-compact.with(
    caption-style: text,
    caption-align: start,
    breakable: true,
    width: 76%,
  )
  align(center, box(width: auto, text(size: 10pt, algorithm-figure(
    [Combinational READY computation (equivalent to RTL `when ... else` priority chains).],
    line-numbers: false,
    {
      import algorithmic: *
      // Suppress explicit block terminators ("end") for report readability.
      let If = If.with(kw3: "")
      let ElseIf = ElseIf.with(kw3: "")
      let Else = Else.with(kw3: "")
      let While = While.with(kw3: "")
      let For = For.with(kw3: "")
      If([$not$ i_aresetn], {
        Assign[s_axis_gray8_tready][0]
        Assign[s_axis_rbg888_tready][0]
      })
      ElseIf([i_overlay_zeros], {
        Assign[s_axis_gray8_tready][m_axis_rbg888_tready]
        Assign[s_axis_rbg888_tready][1]
      })
      Else({
        If([$not$ s_axis_gray8_tvalid], {
          Assign[s_axis_gray8_tready][1]
        })
        Else({
          Assign[s_axis_gray8_tready][m_axis_rbg888_tready $and$ s_prefill_done]
        })

        If([$not$ s_prefill_done], {
          Assign[s_axis_rbg888_tready][1]
        })
        Else({
          Assign[s_axis_rbg888_tready][m_axis_rbg888_tready $and$ s_axis_gray8_tvalid]
        })
      })
    },
  ))))
}

In binary-only mode (`i_overlay_zeros=1`), the module propagates output backpressure to the gray input and drains the RGB input unconditionally. In merge mode (`i_overlay_zeros=0`), the wrapper first pre-fills the selected delayed-base tap (`s_prefill_done=0`) by accepting base beats while stalling gray beats once they appear (`s_axis_gray8_tvalid=1`), and it then enters lockstep where both branches advance synchronously.

Per-beat composition follows the `i_base_delay_stage_sel` tap selection and the edge mask derived from the gray payload (`edge_mask = (gray8 != 0)`). The final pixel is either the selected base pixel or the generic edge color, depending on whether the mask is active. When `i_overlay_zeros=1`, the output is forced to a binary black/white value based on the mask, regardless of the base pixel.


// Waveform interpretation confirms that merge mode waits for selected delayed-base tap validity before entering steady-state lockstep emission, that the gray stream remains the output timing reference, and that READY behavior prevents deadlock during delay prefill while preserving beat-domain alignment.

== Core: FrameCompositor
#figure(
  image("../../figures/ip-cores/FrameCompositor.png", width: 45%),
  caption: [`FrameCompositor` core: combinational edge-overlay pixel selection.],
) <fig-frame-framecompositor>

The `FrameCompositor` is a purely combinational pixel composer that overwrites the base RGB pixel whenever an edge mask bit is active. The overlay color is provided as the packed generic `G_EDGE_COLOR` and expanded to the configured component width.
// #figure(
//   academic_test_table(
//     target: "frame_compositor_core",
//     test_file: "test_frame_compositor_core.py",
//     cases: (
//       academic_test_case(
//         name: "test_frame_compositor_all_input_combinations",
//         check: [FrameCompositor combinational decode: mask-active output selects edge color, mask-inactive output forwards base RGB.],
//       ),
//     ),
//   ),
//   caption: [Cocotb evidence for FrameCompositor: exhaustive combinational checks across representative RGB samples and mask values.],
// ) <tab-frame-tests-framecompositor>

Because the core is combinational, no timing waveform is required here; correctness is validated directly by input-to-output comparisons in the cocotb test.

== Core: ShiftRamChain
#figure(
  image("../../figures/ip-cores/ShiftRamChain.png", width: 45%),
  caption: [`ShiftRamChain` core: selectable delay taps built from cascaded `c_shift_ram_0` IP cores.],
) <fig-frame-shiftramchain>

`ShiftRamChain` provides selectable fixed delay taps for the base stream as a BRAM-based shift-register chain (#repo_link("rtl/FRAME_COMPOSITOR/hdl/shift_ram_chain.vhd", line: 5, branch: "feat/rollback")). It advances with each accepted beat of the base stream: the chain shifts one word per `i_ce=1` pulse (base-stream AXI handshake `TVALID && TREADY`) (#repo_link("rtl/FRAME_COMPOSITOR/hdl/shift_ram_chain.vhd", line: 20, branch: "feat/rollback")).

Delays are implemented by cascading instances of `c_shift_ram_0`, a generated BRAM shift-register primitive with an adjustable per-instance delay configured via its `A` input (#repo_link("rtl/FRAME_COMPOSITOR/hdl/shift_ram_chain.vhd", line: 40, branch: "feat/rollback")). Because `A` is 10-bit, each stage provides at most 1024 beats of delay; longer delays are realized as a sequence of full 1024-beat stages plus one final residual stage. The first chain (`s_sobel_pipe`) provides the Sobel-alignment tap, and the optional second chain (`s_blur_pipe`) appends only the additional delay beyond Sobel to reach the Blur+Sobel tap.

@fig-shiftram-arch summarizes the resulting datapath and control contract. The packed base word enters as `i_din[25:0] = {SOF, EOL, RBG24}` and is advanced only on `i_ce = s_base_accept` (accepted-beat domain). A synchronous clear (`i_sclr = not i_aresetn`) resets the stored state, forcing taps to zero until refilled. The tap mux selects `o_dout` from either the bypass path (`sel=00`), the Sobel tap (`sel=01/11`), or the Blur+Sobel tap (`sel=10`), matching the selector semantics summarized later in @tab-shiftram-sel-map.

#figure(
  image("../figures/generated/block_shift_ram_chain_arch.png", width: 55%),
  caption: [Functional architecture of `ShiftRamChain`: accepted-beat gated BRAM shift-register chains (Sobel + optional extra) with selector-driven tap mux (`sel`).],
) <fig-shiftram-arch>

Delay taps are derived in the wrapper from frame geometry and kernel sizes. For odd kernel sizes, warm-up delay in accepted beats for a K#(sym.times)K window stage is modeled as (#repo_link("rtl/FRAME_COMPOSITOR/hdl/axi_frame_compositor.vhd", line: 68, branch: "feat/rollback")):

$
         D(W, K) & = (W + 1) ((K - 1) / 2) \
       D_"sobel" & = D(W, K_"sobel") \
  D_"blur+sobel" & = D(W, K_"blur") + D(W, K_"sobel") \
   D_"effective" & = D_"requested" + (N_"stages" - 1)
$

@tab-shiftram-sel-map lists the configured FIFO length ($D_"requested"$) and the number of instantiated shift-RAM stages per selector/tap. In simulation, these stages map to a custom `c_shift_ram_0_model` behavioral replacement (avoids `vsim`). Because each additional cascaded stage beyond the first contributes a single beat handoff latency, the wrapper uses an effective delay of $D_"effective" = D_"requested" + (N_"stages" - 1)$ for non-bypass paths (and $D_"effective"=0$ for bypass), e.g. `2562` with `4` stages yields `2565`. These effective taps are used by the wrapper's prefill gating (`s_base_valid_pipe` / `s_base_delayed_valid`) to prevent underrun at frame start (#repo_link("rtl/FRAME_COMPOSITOR/hdl/axi_frame_compositor.vhd", line: 238, branch: "feat/rollback")).

#figure(
  academic_table(
    columns: (auto, auto, auto, auto, auto),
    align: (left, center, left, center, center),
    table.header(
      [Context],
      [`sel`],
      [Selected tap],
      [FIFO length],
      [\# Shift-RAMs],
    ),
    [Sim],
    [`00`],
    [Bypass (`i_din`)],
    [`0`],
    [`0`],
    [Sim],
    [`01`],
    [Sobel tap],
    [`3`],
    [`1`],
    [Sim],
    [`10`],
    [Blur+Sobel tap],
    [`5`],
    [`2`],
    [Sim],
    [`11`],
    [Reserved #sym.arrow Sobel alias],
    [`3`],
    [`1`],
    [Synthesis],
    [`00`],
    [Bypass (`i_din`)],
    [`0`],
    [`0`],
    [Synthesis],
    [`01`],
    [Sobel tap],
    [`1281`],
    [`2`],
    [Synthesis],
    [`10`],
    [Blur+Sobel tap],
    [`2562`],
    [`4`],
    [Synthesis],
    [`11`],
    [Reserved #sym.arrow Sobel alias],
    [`1281`],
    [`2`],
  ),
  caption: [Selector-to-FIFO map for ShiftRamChain: configured FIFO lengths and Shift-RAM stage counts for simulation and synthesis/default AXI-wrapper settings (accepted-beat domain).],
) <tab-shiftram-sel-map>

Because each cascaded stage contributes a one-beat handoff latency, the effective tap length is $D_"effective" = D_"requested" + (N_"stages" - 1)$ for non-bypass delays; the cocotb target #repo_link("testbench/tests/test_shift_ram_chain.py", line: 33, branch: "feat/rollback") models and asserts this behavior.

#figure(
  image("../figures/ghw/shift_ram_chain.png", width: 96%),
  caption: [Waveform excerpt from cocotb target `shift_ram_chain`: control-driven delay-line behavior and representative internal memory movement inside Sobel/extra chunks.],
) <fig-shiftram-ghw>

In @fig-shiftram-ghw, `u_sobelchunka.a = 0x002` and `u_extrachunka.a = 0x001` are constant per-instance delay settings (TB generics `G_SOBEL_DELAY=3`, `G_BLUR_SOBEL_DELAY=5`), not runtime controls. The trace highlights `i_ce` gating, `i_sclr` clearing, and `i_base_delay_stage_sel` tap selection (see @tab-shiftram-sel-map).

== Verification: frame-compositor-related test overview
The `FRAME_COMPOSITOR` chapter is covered by dedicated unit/integration cocotb tests and by pipeline-level regressions that exercise compositor behavior in the full chain.

#text(size: 9pt)[
  *UUT: FrameCompositor*
  - #repo_link(
      "testbench/tests/test_frame_compositor_core.py",
      body: [`test_frame_compositor_all_input_combinations`],
      line: 16,
      branch: "feat/rollback",
    ): exhaustive combinational decode checks for mask-active edge-color overwrite vs base-pixel passthrough.

  *UUT: ShiftRamChain*
  - #repo_link(
      "testbench/tests/test_shift_ram_chain.py",
      body: [`test_shift_ram_chain_minimal_cycle_functional_behaviour`],
      line: 280,
      branch: "feat/rollback",
    ): selector behavior, `i_ce`/`i_sclr` effects, and reserved-selector alias checks.
  - #repo_link(
      "testbench/tests/test_shift_ram_chain.py",
      body: [`test_shift_ram_chain_delay_lengths_match_effective_taps`],
      line: 289,
      branch: "feat/rollback",
    ): validates Sobel and Blur+Sobel tap lengths against the effective-delay model.

  *UUT: AXI_FrameCompositor*
  - #repo_link(
      "testbench/tests/test_axi_frame_compositor.py",
      body: [`test_axi_frame_compositor_multiframe_sync_with_gray_delay_and_backpressure`],
      line: 406,
      branch: "feat/rollback",
    ): multi-frame sync under gray warm-up latency and branch backpressure.
  - #repo_link(
      "testbench/tests/test_axi_frame_compositor.py",
      body: [`test_axi_frame_compositor_downscaled_real_image_sequence`],
      line: 517,
      branch: "feat/rollback",
    ): downscaled real-image sequence regression for frame-level correctness.
  - #repo_link(
      "testbench/tests/test_axi_frame_compositor.py",
      body: [`test_axi_frame_compositor_small_mode_matrix_with_backpressure_and_gray_delays`],
      line: 598,
      branch: "feat/rollback",
    ): compact mode-matrix sweep with gray delays and output backpressure.
  - #repo_link(
      "testbench/tests/test_axi_frame_compositor.py",
      body: [`test_axi_frame_compositor_delay_stage_sweep_with_backpressure`],
      line: 748,
      branch: "feat/rollback",
    ): verifies selector-dependent delay taps under active backpressure.
  - #repo_link(
      "testbench/tests/test_axi_frame_compositor.py",
      body: [`test_axi_frame_compositor_delay_alignment_multi_seed_backpressure`],
      line: 856,
      branch: "feat/rollback",
    ): alignment robustness across randomized backpressure seeds.
  - #repo_link(
      "testbench/tests/test_axi_frame_compositor.py",
      body: [`test_axi_frame_compositor_binary_mode_not_blocked_by_rgb`],
      line: 891,
      branch: "feat/rollback",
    ): binary mode progress is independent of RGB-branch availability.
  - #repo_link(
      "testbench/tests/test_axi_frame_compositor.py",
      body: [`test_axi_frame_compositor_binary_mode_active_rgb_backpressure_lockstep`],
      line: 940,
      branch: "feat/rollback",
    ): binary mode remains lockstep-correct under active RGB backpressure.

  *UUT: AXI_RgbGrayBlurrSobelOverlayPipeline*
  - #repo_link(
      "testbench/tests/test_axi_gray_blurr_sobel_overlay_pipeline.py",
      body: [`test_pipeline_full_chain_state_progression`],
      line: 200,
      branch: "feat/rollback",
    ): full-frame passthrough progression check with compositor integrated in the chain.
  - #repo_link(
      "testbench/tests/test_axi_gray_blurr_sobel_overlay_pipeline.py",
      body: [`test_pipeline_full_chain_smoke_with_backpressure`],
      line: 216,
      branch: "feat/rollback",
    ): smoke + backpressure regression that writes the overlay artifact set.
]

== Verification: pipeline-level output artifacts
The end-to-end pipeline behavior (including overlay composition and base-mode toggles) is evaluated by #repo_link("testbench/tests/test_axi_gray_blurr_sobel_overlay_pipeline.py", branch: "feat/rollback"), which writes representative output images that are compared against references computed in Python following the same computational rules. The aforementioned test was utilized to generate the three artifact outputs @fig-frame-overlay.
