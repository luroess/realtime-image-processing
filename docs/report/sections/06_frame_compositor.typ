#import "../shared/macros.typ": *

= Component: FRAME_COMPOSITOR
#component_owner("Jan Duchscherer")

== Conceptual introduction
The `AXI_FrameCompositor` (#repo_link("rtl/FRAME_COMPOSITOR/hdl/axi_frame_compositor.vhd", line: 4)) is the timing-owning output wrapper at the end of the image pipeline. It consumes a base RGB stream and a processed gray/mask stream, aligns base pixels through delay taps, and emits the final RGB output.

Two runtime modes are implemented. In merge mode (`i_overlay_zeros = 0`), delayed base RGB is merged with the gray-derived edge mask through `FrameCompositor` (#repo_link("rtl/FRAME_COMPOSITOR/hdl/frame_compositor.vhd", line: 5)); in binary mode (`i_overlay_zeros = 1`), output bypasses base RGB composition and emits a white/black mask image.

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
      [`s_axis_video_rbg888_*`],
      [in/out],
      [AXIS video],
      [Base RGB stream; accepted beats advance `ShiftRamChain` (`i_ce`).],
      [`s_axis_video_gray8_*`],
      [in/out],
      [AXIS video],
      [Gray/mask stream; timing reference for output `tvalid`, `tuser`, and `tlast`.],
      [`m_axis_video_rbg888_*`],
      [out/in],
      [AXIS video],
      [Final RGB output (binary mask or composed delayed-base image).],
    ),
  ),
  caption: [AXI_FrameCompositor interface and control contract from #repo_link("rtl/FRAME_COMPOSITOR/hdl/axi_frame_compositor.vhd", line: 4).],
) <tab-frame-if>

== Runtime control semantics
`i_overlay_zeros` selects merge mode (`0`, delayed base RGB plus edge overlay) versus binary mode (`1`, white/black mask output). `i_base_delay_stage_sel` takes values `0,1,2,3` in both cocotb and synthesis, with identical encoding semantics but context-dependent delays; the selector-to-delay map below enumerates the corresponding taps and effective FIFO lengths derived from the delay equations that follow.

== Delay theory and effective tap latency
For odd kernel sizes, warm-up delay in accepted beats is modeled as:
$ D(W, K) = (W + 1) ((K - 1) / 2) $

For this pipeline, Sobel and Blur+Sobel taps are:
$ D_"sobel" = D(W, K_"sobel") $
$ D_"blur+sobel" = D(W, K_"blur") + D(W, K_"sobel") $

Because `ShiftRamChain` (#repo_link("rtl/FRAME_COMPOSITOR/hdl/shift_ram_chain.vhd", line: 10)) splits delays into 1024-beat `c_shift_ram_0` chunks, effective tap latency includes one extra beat per additional chunk:
$ D_"effective" = D_"requested" + (N_"chunks" - 1) $

With default generics (`G_LINE_WIDTH = 1280`, `G_SOBEL_KERNEL_SIZE = 3`, `G_BLUR_KERNEL_SIZE = 3`), $D_"sobel" = 1281$ splits into 2 chunks for $D_"sobel,eff" = 1282$, and $D_"blur+sobel" = 2562$ splits into 4 total chunks for $D_"blur+sobel,eff" = 2565$. These effective taps are used by `s_base_valid_pipe` / `s_base_delayed_valid` prefill gating in AXI_FrameCompositor (#repo_link("rtl/FRAME_COMPOSITOR/hdl/axi_frame_compositor.vhd", line: 241)).

#figure(
  academic_table(
    columns: (auto, auto, auto, auto, auto, auto),
    align: (left, center, left, center, center, center),
    table.header(
      [Context],
      [`i_base_delay_stage_sel`],
      [Selected tap],
      [Requested FIFO length (beats)],
      [Actual delay (beats)],
      [Shift-RAM stages in selected path],
    ),
    [TB (`targets.shift_ram_chain`)],
    [`0 (00)`],
    [Bypass (`i_din`)],
    [`0`],
    [`0`],
    [0 #sym.times c_shift_ram_0_model],
    [TB (`targets.shift_ram_chain`)],
    [`1 (01)`],
    [Sobel tap],
    [`3`],
    [`3`],
    [1 #sym.times c_shift_ram_0_model],
    [TB (`targets.shift_ram_chain`)],
    [`2 (10)`],
    [Blur+Sobel tap],
    [`5`],
    [`6`],
    [2 #sym.times c_shift_ram_0_model],
    [TB (`targets.shift_ram_chain`)],
    [`3 (11)`],
    [Reserved #sym.arrow Sobel alias],
    [`3`],
    [`3`],
    [1 #sym.times c_shift_ram_0_model],

    [Synthesis (`AXI_FrameCompositor` defaults)],
    [`0 (00)`],
    [Bypass (`i_din`)],
    [`0`],
    [`0`],
    [0 #sym.times c_shift_ram_0],
    [Synthesis (`AXI_FrameCompositor` defaults)],
    [`1 (01)`],
    [Sobel tap],
    [`1281`],
    [`1282`],
    [2 #sym.times c_shift_ram_0],
    [Synthesis (`AXI_FrameCompositor` defaults)],
    [`2 (10)`],
    [Blur+Sobel tap],
    [`2562`],
    [`2565`],
    [4 #sym.times c_shift_ram_0],
    [Synthesis (`AXI_FrameCompositor` defaults)],
    [`3 (11)`],
    [Reserved #sym.arrow Sobel alias],
    [`1281`],
    [`1282`],
    [2 #sym.times c_shift_ram_0],
  ),
  caption: [Selector-to-delay map for `ShiftRamChain`: compact testbench target and synthesis/default AXI wrapper configuration (accepted-beat domain).],
) <tab-shiftram-sel-map>

== ShiftRamChain AXI/FIFO sequence
#figure(
  image("../figures/generated/seq_shift_ram_chain_transaction.png", width: 96%),
  caption: [Sequence view of AXI_FrameCompositor + ShiftRamChain interaction: `s_*_tready` generation, `i_ce`/`i_sclr` effects, selector-driven tap behavior, and `m_*_tvalid` emission. Rendered from Mermaid with `mmdc -s 2`.],
) <fig-shiftram-seq>

== ShiftRamChain GHW evidence (target `shift_ram_chain`)
#figure(
  image("../figures/ghw/shift_ram_chain.png", width: 96%),
  caption: [Waveform excerpt from cocotb target `shift_ram_chain`: control-driven delay-line behavior and representative `s_mem` movement inside Sobel/extra chunks.],
) <fig-shiftram-ghw>

What is visible in this waveform is that `u_sobelchunka.a = 0x002` and `u_extrachunka.a = 0x001` are constant per-instance delay settings (TB generics `G_SOBEL_DELAY=3`, `G_BLUR_SOBEL_DELAY=5`) rather than runtime controls. `i_ce` gates FIFO advancement so `s_mem` rows and the delayed output hold when `i_ce=0` and shift when `i_ce=1`, while `i_sclr` clears delayed state and forces taps to `0` until refill. `i_base_delay_stage_sel` selects the output tap (`00` bypass, `01` Sobel, `10` blur+sobel, `11` reserved alias to Sobel), and the shown `s_mem` rows are representative internal storage lines that demonstrate write/shift/hold behavior without implying extra pipeline stages beyond the configured chunks.

The cocotb test that produces the trace (#repo_link("testbench/tests/test_shift_ram_chain.py", line: 152)) initializes and resets the chain, runs bypass checks with `sel=00` under both `ce=0` and `ce=1`, clears and refills the Sobel tap to demonstrate the 3-beat effective delay, inserts `ce=0` stall windows to prove delayed output and internal memories hold, switches to the blur+sobel tap to verify the deeper path, exercises the reserved selector alias, and performs a flush/refill to show taps returning to zero after clear and repopulating on accepted beats.

== AXI datapath and handshake implementation
The wrapper packs each accepted base beat as `{TUSER, TLAST, RGB24}` into a fixed 26-bit word (`s_base_word_in`) for `ShiftRamChain` (#repo_link("rtl/FRAME_COMPOSITOR/hdl/axi_frame_compositor.vhd", line: 229)). Delay progression is acceptance-accurate because `i_ce` is driven only by accepted base beats:
$ "s_base_accept" = "s_axis_video_rbg888_tvalid" and "s_axis_rbg888_tready" $

Merge-vs-binary mode is decoded from `i_overlay_zeros`, and prefill completion is derived from the selected delayed-valid tap:
$ "s_need_rgb" = 1 $ when `i_overlay_zeros = 0`, else $0$
$ "s_prefill_done" = (not "s_need_rgb") or "s_base_delayed_valid" $

The gray stream is the timing reference for output framing, and gray READY is intentionally permissive while merge prefill is incomplete to avoid deadlock during delay-line warm-up (#repo_link("rtl/FRAME_COMPOSITOR/hdl/axi_frame_compositor.vhd", line: 307)). This behavior is implemented as a gated piecewise rule:
$ "s_axis_video_gray8_tready" = "m_axis_video_rbg888_tready" $ when `s_need_rgb = 0`
$ "s_axis_video_gray8_tready" = 1 $ when `s_need_rgb = 1` and `s_axis_video_gray8_tvalid = 0`
$ "s_axis_video_gray8_tready" = "m_axis_video_rbg888_tready" and "s_prefill_done" $ when `s_need_rgb = 1` and `s_axis_video_gray8_tvalid = 1`

Base-stream READY is handled separately: binary mode drains RGB unconditionally, merge mode consumes base beats for prefill, and lockstep is enforced after prefill so delayed RGB and gray remain aligned:
$ "s_axis_rbg888_tready" = 1 $ when `s_need_rgb = 0` or `s_prefill_done = 0`
$ "s_axis_rbg888_tready" = "m_axis_video_rbg888_tready" and "s_axis_video_gray8_tvalid" $ when `s_need_rgb = 1` and `s_prefill_done = 1`

Output validity is then gated by gray timing and delayed-base availability:
$ "s_required_valid" = "s_axis_video_gray8_tvalid" and ("s_base_delayed_valid" or (not "s_need_rgb")) $
$ "m_axis_video_rbg888_tvalid" = "s_required_valid" $ for `i_aresetn = 1`

The output data path is a 2:1 mux, not a demux: it selects between binary mask RGB and composed RGB before driving the single `m_axis_video_rbg888_tdata` bus.
$ "s_rgb_mux" = "s_binary_rgb" $ when `i_overlay_zeros = 1`, else $ "s_out_rgb" $
$ "m_axis_video_rbg888_tdata" = "s_rgb_mux" $ when `i_aresetn = 1` and `s_required_valid = 1`, else $0$

The RTL also contains simulation guards that warn on mid-frame control changes (`i_overlay_zeros`, `i_base_delay_stage_sel`), reserved delay selector usage, and SOF/EOL mismatch between gray timing and delayed base while merge mode is active.

== Lower-level cores: FrameCompositor and ShiftRamChain
#figure(
  grid(
    columns: (1fr, 1fr),
    gutter: 10pt,
    image("../../figures/ip-cores/FrameCompositor.png", width: 100%),
    image("../../figures/ip-cores/ShiftRamChain.png", width: 100%),

    text(size: 9pt)[(a) `FrameCompositor` low-level core that selects overlay mode and emits the final RGB24 pixel.],
    text(size: 9pt)[(b) `ShiftRamChain` low-level delay-line core providing selectable delayed RGB taps for alignment.],
  ),
  caption: [Low-level block-design views of the two internal cores used by AXI_FrameCompositor.],
) <fig-frame-cores>

The top-level wrapper composes these two cores in sequence. `ShiftRamChain` first applies delay alignment to the base RGB beat, and `FrameCompositor` then applies edge-color overlay to the delayed base pixel.

`FrameCompositor` is fully combinational and implements a single mask-controlled mux (#repo_link("rtl/FRAME_COMPOSITOR/hdl/frame_compositor.vhd", line: 44)):
$ "o_rgb888" = "G_EDGE_COLOR" $ when `i_edge_mask = 1`, else $ "i_rgb888" $

`ShiftRamChain` builds two cascaded delay segments from 1024-beat chunks, with selector-driven tap muxing at its output (#repo_link("rtl/FRAME_COMPOSITOR/hdl/shift_ram_chain.vhd", line: 155)):
$ "o_dout" = "i_din" $ for `sel = 00`
$ "o_dout" = "sobel_tap" $ for `sel = 01`
$ "o_dout" = "blur_sobel_tap" $ for `sel = 10`
$ "o_dout" = "sobel_tap" $ for `sel = 11` (reserved alias with warning)

== Testbench evidence for implementation behavior
#let test_id(content) = text(font: "DejaVu Sans Mono", size: 8.2pt)[#content]

#figure(
  academic_table(
    columns: (1.25fr, 1.25fr, 1.75fr, 3fr),
    align: (left, left, left, left),
    table.header([Target (`targets.toml`)], [Test file], [Test case], [Concise implementation check]),
    [#test_id("frame_compositor_core")],
    [#test_id("test_frame_compositor_core.py")],
    [#test_id("test_frame_compositor_all_input_combinations")],
    [FrameCompositor combinational decode: mask-active output selects edge color, mask-inactive output forwards base RGB.],

    table.cell(rowspan: 2)[#test_id("shift_ram_chain")],
    table.cell(rowspan: 2)[#test_id("test_shift_ram_chain.py")],
    [
      #test_id("test_shift_ram_chain_minimal_cycle_")
      #linebreak()
      #test_id("functional_behaviour")
    ],
    [ShiftRamChain functional checks for selector behavior, `i_ce`/`i_sclr` effects, and reserved-selector aliasing against the reference model.],
    [
      #test_id("test_shift_ram_chain_delay_lengths_")
      #linebreak()
      #test_id("match_effective_taps")
    ],
    [Measured Sobel and Blur+Sobel tap delays match the effective-delay equations, including chunk overhead.],

    table.cell(rowspan: 3)[#test_id("axi_frame_compositor")],
    table.cell(rowspan: 3)[#test_id("test_axi_frame_compositor.py")],
    [
      #test_id("test_axi_frame_compositor_multiframe_")
      #linebreak()
      #test_id("sync_with_gray_delay_and_backpressure")
    ],
    [Multi-frame AXI handshake correctness under backpressure, including SOF/EOL discipline and payload stability while stalled.],
    [
      #test_id("test_axi_frame_compositor_delay_stage_")
      #linebreak()
      #test_id("sweep_with_backpressure")
    ],
    [Delay-stage sweep verifies Sobel versus Blur+Sobel alignment when gray start delay matches effective tap latency.],
    [
      #test_id("test_axi_frame_compositor_binary_mode_")
      #linebreak()
      #test_id("not_blocked_by_rgb")
    ],
    [Binary mode remains gray-driven and non-blocking even when RGB-source consumption pressure is absent.],
  ),
  caption: [Compositional cocotb evidence for FRAME_COMPOSITOR: targets from `targets.toml`, then file-level test cases and implementation checks.],
) <tab-frame-tests>

== Typical transaction sequence
#figure(
  image("../figures/generated/seq_frame_compositor_transaction.png", width: 88%),
  caption: [Representative AXI_FrameCompositor transaction showing mode-dependent output and prefill gating.],
) <fig-frame-seq>

== Timing diagram from cocotb VCD/GHW run
#figure(
  image("../figures/generated/timing_frame_compositor.png", width: 94%),
  caption: [Measured FRAME_COMPOSITOR handshake behavior under periodic gray-stream backpressure.],
) <fig-frame-timing>

Waveform interpretation confirms that merge mode waits for selected delayed-base tap validity before full lockstep emission, that the gray stream remains the output timing reference, and that READY behavior prevents deadlock during delay prefill while preserving beat-domain alignment.
