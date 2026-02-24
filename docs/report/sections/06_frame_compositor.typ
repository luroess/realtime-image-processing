#import "../shared/macros.typ": *
#import "@preview/algorithmic:1.0.7"
#import algorithmic: algorithm-figure, style-algorithm

= Component: FRAME_COMPOSITOR
#component_owner("Jan Duchscherer")

== Conceptual introduction
`AXI_FrameCompositor` (#repo_link("rtl/FRAME_COMPOSITOR/hdl/axi_frame_compositor.vhd", line: 4)) is the merge point for the overlay-producing pipeline modes. It receives two AXI4-Stream Video inputs that originate from different branches: a base `rbg888` stream (24-bit payload in project wire order `R|B|G`) and a processed `gray8` stream that acts as timing reference and carries the edge mask. Because Sobel (and optional Blur+Sobel) are window-based stages, the processed branch exhibits a deterministic warm-up latency after each `SOF`, so the two streams cannot be consumed in lockstep without explicit re-alignment.

The module resolves this mismatch by delaying the *base* branch in the accepted-beat domain. Each accepted base beat is packed as `{SOF, EOL, RBG24}` and advanced through `ShiftRamChain` (#repo_link("rtl/FRAME_COMPOSITOR/hdl/shift_ram_chain.vhd", line: 10)) only when `TVALID && TREADY` is true. A runtime selector (`i_base_delay_stage_sel`) chooses which delay tap is used to align the base stream to the current processing mode, while the gray stream remains the sole output framing reference (`TVALID`, `TUSER=SOF`, `TLAST=EOL`). The wrapper therefore emits output beats only when the gray reference is valid and, in merge mode, the selected delayed-base tap is known to contain valid data.

Two output modes are supported. In overlay mode (`i_overlay_zeros = 0`), `FrameCompositor` (#repo_link("rtl/FRAME_COMPOSITOR/hdl/frame_compositor.vhd", line: 5)) overwrites the delayed base pixel with `G_EDGE_COLOR` whenever the mask indicates an edge (`gray8 != 0`). In binary mode (`i_overlay_zeros = 1`), the base stream is not required; the module emits a black/white mask image (white for non-zero mask) while still remaining gray-timed.

To avoid deadlock during delay-line warm-up, READY generation is intentionally asymmetric during prefill: the wrapper permits gray-side progress when `gray_tvalid=0` and drains base beats into the delay RAM until the selected tap becomes valid. Runtime controls are expected to change only at `SOF`; the RTL includes simulation guards for mid-frame control toggles and for SOF/EOL mismatch between gray timing and the delayed base stream (#repo_link("rtl/FRAME_COMPOSITOR/hdl/axi_frame_compositor.vhd", line: 200)).

#figure(
  image("../../figures/ip-cores/AxiFrameCompositor.png", width: 55%),
  caption: [AXI_FrameCompositor top-level IP-core wrapper with dual-stream inputs, delay-stage select, and composed RGB output.],
) <fig-frame-arch>

== Interface ports and generics
#figure(
  interface_table(
    generics: (
      [`G_COMPONENT_WIDTH`],
      [generic],
      [positive],
      [Component width; asserted to `8` for the fixed `{SOF,EOL,RGB24}` shift-RAM payload contract.],
      [`G_EDGE_COLOR`],
      [generic],
      [`slv(23:0)`],
      [Overlay color used by `FrameCompositor` when edge mask is active (default `x"FF0000"`).],
      [`G_LINE_WIDTH`, `G_SOBEL_KERNEL_SIZE`, `G_BLUR_KERNEL_SIZE`],
      [generic],
      [positive],
      [Auto-delay derivation parameters in accepted-beat domain.],
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
      [Delay tap selector (`00` none, `01` sobel, `10` blur+sobel, `11` reserved alias to sobel).],
      [`s_axis_rbg888_*`],
      [in/out],
      [AXIS video],
      [Base RGB stream; accepted beats advance `ShiftRamChain` (`i_ce`).],
      [`s_axis_gray8_*`],
      [in/out],
      [AXIS video],
      [Gray/mask stream; timing reference for output `tvalid`, `tuser`, and `tlast`.],
      [`m_axis_rbg888_*`],
      [out/in],
      [AXIS video],
      [Final RGB output (binary mask or composed delayed-base image).],
    ),
  ),
  caption: [AXI_FrameCompositor interface and control contract from #repo_link("rtl/FRAME_COMPOSITOR/hdl/axi_frame_compositor.vhd", line: 4).],
) <tab-frame-if>

== AXI Interface implementation
`AXI_FrameCompositor` composes `ShiftRamChain` and `FrameCompositor` in series: the base stream is first delay-aligned and then optionally overwritten with an edge color. The gray stream is the timing reference for output emission and framing sidebands; `TUSER` and `TLAST` on the output are therefore forwarded from the gray branch when (and only when) a pixel beat is emitted. The base branch is advanced in the accepted-beat domain by driving `ShiftRamChain.i_ce` with the base handshake pulse `s_base_accept` (#repo_link("rtl/FRAME_COMPOSITOR/hdl/axi_frame_compositor.vhd", line: 229)).

To match the generated `c_shift_ram_0` interface, the wrapper packs each accepted base beat as `{SOF, EOL, RBG24}` into the fixed 26-bit word `s_base_word_in` (#repo_link("rtl/FRAME_COMPOSITOR/hdl/axi_frame_compositor.vhd", line: 229)). Prefill completion is tracked separately through a beat-domain validity conveyor (`s_base_valid_pipe`) clocked only on accepted base beats (#repo_link("rtl/FRAME_COMPOSITOR/hdl/axi_frame_compositor.vhd", line: 238)); merge mode can start only once the selected delayed-base tap is valid.

$
     "s_base_accept" & = "s_axis_rbg888_tvalid" and "s_axis_rbg888_tready" \
    "s_prefill_done" & = ("i_overlay_zeros") or "s_base_delayed_valid" \
  "s_required_valid" & = "s_axis_gray8_tvalid" and ("s_base_delayed_valid" or ("i_overlay_zeros"))
$

The two input READY signals are implemented as explicit priority chains in the RTL (a left-to-right `when ... else` cascade), not as a single symmetric mux. The decision tree below is a direct transcription of the combinational assignments for `s_axis_gray8_tready_i` and `s_axis_rbg888_tready` (#repo_link("rtl/FRAME_COMPOSITOR/hdl/axi_frame_compositor.vhd", line: 307)); it makes the evaluation order explicit: the first matching branch wins.

The intentionally unusual case `gray8_tready = 1` while `gray8_tvalid = 0` does *not* accept any transfer (handshake still requires `TVALID && TREADY`), but it helps avoid combinational `TREADY` deadlock through upstream forked producers while the base delay RAM is being prefilled.

#{
  show: style-algorithm.with(
    caption-style: text,
    caption-align: start,
    breakable: true,
  )
  align(center, box(width: 92%, algorithm-figure(
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
  )))
}

In binary-only mode (`i_overlay_zeros=1`), the module propagates output backpressure to the gray input and drains the RGB input unconditionally. In merge mode (`i_overlay_zeros=0`), the wrapper first pre-fills the selected delayed-base tap (`s_prefill_done=0`) by accepting base beats while stalling gray beats once they appear (`gray8_tvalid=1`), and it then enters steady-state lockstep where both branches advance together under output backpressure and gray validity.

The per-beat muxing behavior is summarized below; it describes only pixel selection (handshake gating is handled by the READY/VALID rules above). In this pseudocode, `sel` denotes `i_base_delay_stage_sel`, `gray8` denotes the current gray payload, and the base candidates correspond to the `ShiftRamChain` bypass input and its two delayed taps.

#{
  show: style-algorithm.with(
    caption-style: text,
    caption-align: start,
    breakable: true,
  )
  align(center, box(width: 92%, algorithm-figure(
    [Per-beat muxing for delay-tap selection and edge overlay (pixel selection only).],
    line-numbers: false,
    {
      import algorithmic: *
      // Suppress explicit block terminators ("end") for report readability.
      let If = If.with(kw3: "")
      let ElseIf = ElseIf.with(kw3: "")
      let Else = Else.with(kw3: "")
      let While = While.with(kw3: "")
      let For = For.with(kw3: "")
      Comment[Assumes a beat is emitted (`s_required_valid = 1`); gray drives SOF/EOL timing.]
      Assign[$"edge_mask"$][$"gray8" != 0$]

      Comment[Select delayed base pixel (`sel`); `11` aliases to Sobel with a warning.]
      If($"sel" = "00"$, { Assign[$"base"$][$"base_in"$] })
      ElseIf($"sel" in {"01", "11"}$, { Assign[$"base"$][$"sobel_tap"$] })
      ElseIf($"sel" = "10"$, { Assign[$"base"$][$"blur_sobel_tap"$] })
      Else({ Assign[$"base"$][$"base_in"$] })

      Comment[Edge overlay (`FrameCompositor`): edge pixels become `G_EDGE_COLOR`, else pass delayed base pixel.]
      If($"edge_mask"$, { Assign[$"composed"$][$"G_EDGE_COLOR"$] })
      Else({ Assign[$"composed"$][$"base"$] })
    },
  )))
}

Conceptually, the wrapper first selects the delay-aligned base pixel, then applies the edge-color overwrite. Binary-only output is handled as a final output selection: when `i_overlay_zeros=1`, the wrapper drives a black/white mask RGB payload instead of the composed pixel (`m_axis_rbg888_tdata` selection in #repo_link("rtl/FRAME_COMPOSITOR/hdl/axi_frame_compositor.vhd", line: 335)). The RTL also includes simulation guards for mid-frame control changes, reserved selector usage, and SOF/EOL mismatches between gray timing and delayed-base timing.

// #figure(
//   academic_test_table(
//     target: "axi_frame_compositor",
//     test_file: "test_axi_frame_compositor.py",
//     cases: (
//       academic_test_case(
//         name: "test_axi_frame_compositor_multiframe_sync_with_gray_delay_and_backpressure",
//         check: [Multi-frame AXI handshake correctness under backpressure, including SOF/EOL discipline and payload stability while stalled.],
//       ),
//       academic_test_case(
//         name: "test_axi_frame_compositor_delay_stage_sweep_with_backpressure",
//         check: [Delay-stage sweep verifies Sobel versus Blur+Sobel alignment when gray start delay matches effective tap latency.],
//       ),
//       academic_test_case(
//         name: "test_axi_frame_compositor_binary_mode_not_blocked_by_rgb",
//         check: [Binary mode remains gray-driven and non-blocking even when RGB-source consumption pressure is absent.],
//       ),
//     ),
//   ),
//   caption: [Cocotb evidence for AXI_FrameCompositor: handshake, alignment, and mode behavior under backpressure and gray-start delays.],
// ) <tab-frame-tests-axi>


Waveform interpretation confirms that merge mode waits for selected delayed-base tap validity before entering steady-state lockstep emission, that the gray stream remains the output timing reference, and that READY behavior prevents deadlock during delay prefill while preserving beat-domain alignment.

== Core: FrameCompositor
#figure(
  image("../../figures/ip-cores/FrameCompositor.png", width: 55%),
  caption: [`FrameCompositor` core: combinational edge-overlay pixel selection.],
) <fig-frame-framecompositor>

`FrameCompositor` is a purely combinational pixel composer that overwrites the base RGB pixel whenever an edge mask bit is active. The overlay color is provided as the packed generic `G_EDGE_COLOR` and expanded to the configured component width through the helper function `f_expand_color` (#repo_link("rtl/FRAME_COMPOSITOR/hdl/frame_compositor.vhd", line: 25)). For compatibility with the project stream order, `G_EDGE_COLOR` is interpreted as `R[23:16] | B[15:8] | G[7:0]` and then repacked to the internal `rbg` bus layout (#repo_link("rtl/FRAME_COMPOSITOR/hdl/frame_compositor.vhd", line: 26)).

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
  image("../../figures/ip-cores/ShiftRamChain.png", width: 55%),
  caption: [`ShiftRamChain` core: selectable accepted-beat delay taps built from cascaded `c_shift_ram_0` chunks.],
) <fig-frame-shiftramchain>

`ShiftRamChain` implements BRAM-based shift-register chains to delay the packed base stream by a selectable number of accepted AXI beats (#repo_link("rtl/FRAME_COMPOSITOR/hdl/shift_ram_chain.vhd", line: 5)). It splits each requested delay into 1024-beat chunks to fit the generated `c_shift_ram_0` primitive and optionally cascades a second "extra" chain behind the Sobel tap to reach the Blur+Sobel tap. Delay advancement is controlled by `i_ce` and must be driven by the base-stream handshake (`TVALID && TREADY`) to keep delay behavior acceptance-accurate (#repo_link("rtl/FRAME_COMPOSITOR/hdl/shift_ram_chain.vhd", line: 20)). A reserved selector value (`11`) warns once and aliases to the Sobel tap.

Conceptually, `ShiftRamChain` behaves like a RAM-based *delay line* (often informally called a "FIFO" in streaming datapaths): on every asserted `i_ce` pulse, one packed beat enters the chain and all internal state advances by exactly one accepted beat. There is no independent read pointer and no runtime-programmable depth; instead, a set of fixed taps is provided at synthesis time. This makes the delay deterministic and acceptance-accurate: when `i_ce=0`, all taps hold their previous values, so the delay counts accepted transfers rather than raw clock cycles.

Internally, the delay line is built from cascaded instances of `c_shift_ram_0`, a generated BRAM-based shift-register primitive with a fixed delay configured by its constant input `A` (#repo_link("rtl/FRAME_COMPOSITOR/hdl/shift_ram_chain.vhd", line: 40)). Because `A` is 10-bit, a single instance can delay at most 1024 beats; longer delays are therefore implemented by splitting the requested delay into a sequence of full-sized 1024-beat chunks plus one residual chunk (the last stage). The first chain (`s_sobel_pipe`) realizes the Sobel-alignment tap, and the optional second chain (`s_blur_pipe`) extends the Sobel tap to the deeper Blur+Sobel tap by adding only the *extra* delay beyond Sobel.

#figure(
  image("../figures/generated/block_shift_ram_chain_arch.png", width: 92%),
  caption: [Functional architecture of `ShiftRamChain`: chunked BRAM shift-register chains plus a selector-driven output tap mux.],
) <fig-shiftram-arch>

Delay taps are derived in the wrapper from frame geometry and kernel sizes. For odd kernel sizes, warm-up delay in accepted beats for a K#(sym.times)K window stage is modeled as (#repo_link("rtl/FRAME_COMPOSITOR/hdl/axi_frame_compositor.vhd", line: 68)):

$
         D(W, K) & = (W + 1) ((K - 1) / 2) \
       D_"sobel" & = D(W, K_"sobel") \
  D_"blur+sobel" & = D(W, K_"blur") + D(W, K_"sobel") \
   D_"effective" & = D_"requested" + (N_"chunks" - 1)
$

Table @tab-shiftram-sel-map lists the configured FIFO length and Shift-RAM stage count per selector/tap. In simulation, these stage counts map to a custom `c_shift_ram_0_model` behavioral replacement because using the official behavioral model would require `vsim`. The effective delay used by prefill gating is derived from FIFO length via the stage-overhead term in the equation above: each additional cascaded shift-RAM stage beyond the first contributes +1 beat, i.e. $D_"effective" = D_"requested" + (N_"stages" - 1)$ where $D_"requested"$ is the table's FIFO length. Therefore, paths with one stage (or bypass) show no discrepancy, while multi-stage paths are longer by exactly $N_"stages" - 1$ beats (for example, Sim $10: 5 -> 6$, Synthesis $01: 1281 -> 1282$, Synthesis $10: 2562 -> 2565$). These effective taps are used by the wrapper's prefill gating (`s_base_valid_pipe` / `s_base_delayed_valid`) to prevent underrun at frame start (#repo_link("rtl/FRAME_COMPOSITOR/hdl/axi_frame_compositor.vhd", line: 238)).

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

// #figure(
//   academic_test_table(
//     target: "shift_ram_chain",
//     test_file: "test_shift_ram_chain.py",
//     cases: (
//       academic_test_case(
//         name: "test_shift_ram_chain_minimal_cycle_functional_behaviour",
//         check: [ShiftRamChain functional checks for selector behavior, `i_ce`/`i_sclr` effects, and reserved-selector aliasing against the reference model.],
//       ),
//       academic_test_case(
//         name: "test_shift_ram_chain_delay_lengths_match_effective_taps",
//         check: [Measured Sobel and Blur+Sobel tap delays match the effective-delay equations, including chunk overhead.],
//       ),
//     ),
//   ),
//   caption: [Cocotb evidence for ShiftRamChain: selector semantics and effective delay-length validation in accepted-beat domain.],
// ) <tab-frame-tests-shiftramchain>


// TODO: exclude this figure.
// #figure(
//   image("../figures/generated/seq_shift_ram_chain_transaction.png", width: 96%),
//   caption: [Sequence view of AXI_FrameCompositor + ShiftRamChain interaction: `s_*_tready` generation, `i_ce`/`i_sclr` effects, selector-driven tap behavior, and `m_*_tvalid` emission. Rendered from Mermaid with `mmdc -s 2`.],
// ) <fig-shiftram-seq>

#figure(
  image("../figures/ghw/shift_ram_chain.png", width: 96%),
  caption: [Waveform excerpt from cocotb target `shift_ram_chain`: control-driven delay-line behavior and representative internal memory movement inside Sobel/extra chunks.],
) <fig-shiftram-ghw>

In @fig-shiftram-ghw, `u_sobelchunka.a = 0x002` and `u_extrachunka.a = 0x001` are constant per-instance delay settings (TB generics `G_SOBEL_DELAY=3`, `G_BLUR_SOBEL_DELAY=5`) rather than runtime controls. `i_ce` gates FIFO advancement so the delayed output holds when `i_ce=0` and shifts only on accepted beats (`i_ce=1`), while `i_sclr` clears delayed state and forces taps to `0` until refill. `i_base_delay_stage_sel` selects the output tap (`00` bypass, `01` Sobel, `10` blur+sobel, `11` reserved alias to Sobel).

The cocotb scenario that produces this trace (#repo_link("testbench/tests/test_shift_ram_chain.py", line: 152)) initializes and resets the chain, verifies bypass behavior under both `ce=0` and `ce=1`, clears and refills the Sobel tap to demonstrate the effective delay, inserts stall windows (`ce=0`) to prove hold behavior, switches to the blur+sobel tap to verify the deeper path, exercises the reserved selector alias, and performs a flush/refill to show taps returning to zero after clear and repopulating on subsequent accepted beats.


#pagebreak()
