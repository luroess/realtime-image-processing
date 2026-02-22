#import "../shared/macros.typ": *

= Component Deep Dive: FRAME_COMPOSITOR
#component_owner("Valentin Bumeder, Justin Loeber")

== Conceptual introduction
`AXI_FrameCompositor` (#repo_link("rtl/FRAME_COMPOSITOR/hdl/axi_frame_compositor.vhd", line: 4)) is the output owner for final RGB888 stream selection. It synchronizes delayed base RGB data with gray/mask timing and decides between binary-mask output or overlay compositing through `FrameCompositor` (#repo_link("rtl/FRAME_COMPOSITOR/hdl/frame_compositor.vhd", line: 5)).

== Vivado interface view
#figure(
  image("../figures/frame_compositor_architecture_trimmed.png", width: 90%),
  caption: [Frame compositor architecture and signal path used for delayed-base alignment and output ownership.],
) <fig-frame-arch>

== Interface ports and generics
#figure(
  academic_table(
    columns: (1.8fr, 0.65fr, 0.85fr, 2.4fr),
    align: (left, left, left, left),
    table.header([Signal/group], [Dir.], [Width], [Purpose]),
    [`G_LINE_WIDTH`, `G_SOBEL_KERNEL_SIZE`, `G_BLUR_KERNEL_SIZE`], [generic], [positive], [Delay derivation parameters.],
    [`G_SOBEL_DELAY_OVERRIDE`, `G_BLUR_SOBEL_DELAY_OVERRIDE`], [generic], [natural], [Optional manual tap override.],
    [`i_overlay_zeros`], [in], [1], [Select binary-only output (`1`) or overlay compose (`0`).],
    [`i_base_delay_stage_sel[1:0]`], [in], [2], [Tap selector (`00` none, `01` sobel, `10` blur+sobel, `11` reserved-alias).],
    [`s_axis_video_rbg888_*`], [in/out], [AXI video], [Base stream input used for delayed RGB alignment.],
    [`s_axis_video_gray8_*`], [in/out], [AXI video], [Gray/mask reference stream driving output timing.],
    [`m_axis_video_rbg888_*`], [out/in], [AXI video], [Composited output stream.],
  ),
  caption: [AXI_FrameCompositor interface and control contract from #repo_link("rtl/FRAME_COMPOSITOR/hdl/axi_frame_compositor.vhd", line: 4).],
) <tab-frame-if>

== Delay theory for stream synchronization
For odd kernel sizes, warm-up delay in accepted beats is modeled as:
$ D_"stage"(W, K) = (W + 1) ((K - 1) / 2) $

For this pipeline, Sobel and Blur+Sobel taps are:
$ D_"sobel" = D_"stage"(W, K_"sobel") $
$ D_"blur+sobel" = D_"stage"(W, K_"blur") + D_"stage"(W, K_"sobel") $

Because delays are chunked over 1024-beat `c_shift_ram_0` segments, effective tap latency includes segment-boundary overhead:
$ D_"effective" = D_"requested" + (N_"chunks" - 1) $

This delay model is reflected by `ShiftRamChain` (#repo_link("rtl/FRAME_COMPOSITOR/hdl/shift_ram_chain.vhd", line: 10)) and consumed by `AXI_FrameCompositor` prefill gating (`s_prefill_done`, `s_base_delayed_valid`).

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

Waveform interpretation confirms:
- merge mode waits for selected delayed-base tap validity before full lockstep emission,
- gray stream remains the output timing reference,
- READY behavior prevents deadlock during delay prefill while preserving beat-domain alignment.
