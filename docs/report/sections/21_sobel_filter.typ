#import "../shared/macros.typ": *

= Component Deep Dive: SOBEL_FILTER
#component_owner("Lukas Röß")

== Architectural role
#repo_link("rtl/SOBEL_FILTER/axi_sobel_filter.vhd", body: raw("AXI_SobelFilter"), line: 4) is the AXI wrapper for edge extraction from a flattened $3 times 3$ grayscale window. It delegates gradient and threshold logic to #repo_link("rtl/SOBEL_FILTER/sobel_core.vhd", body: raw("E_SobelCore"), line: 5) and forwards AXI timing sidebands.

== Sobel operator implementation
The core computes horizontal and vertical gradients with standard Sobel masks:
$ G_x = (p_3 + 2p_6 + p_9) - (p_1 + 2p_4 + p_7) $
$ G_y = (p_1 + 2p_2 + p_3) - (p_7 + 2p_8 + p_9) $

The magnitude estimate is L1-based:
$ M = |G_x| + |G_y| $

The implementation is visible in #repo_link("rtl/SOBEL_FILTER/sobel_core.vhd", line: 101), with clamping to the internal magnitude range at #repo_link("rtl/SOBEL_FILTER/sobel_core.vhd", line: 128).

== Detector dynamics
The Sobel stage can be read as a two-part decision system. The first part estimates local contrast by the gradient magnitude $M$. The second part compares $M$ with a threshold. This threshold may stay fixed, or it may follow scene statistics through a running mean. In hardware terms, gradient evaluation is instantaneous for each current window, while mean adaptation evolves only with accepted stream samples.

This separation is important for interpretation of the output: sharp local transitions increase $M$ immediately, but long-term brightness or texture changes alter the threshold only over time.

== Threshold evolution: fixed to adaptive
The first implementation used a constant threshold compare (`M >= G_SOBEL_THRESHOLD`) for binary edge output. The current implementation keeps `G_SOBEL_THRESHOLD` as initial mean value but extends the detector with adaptive thresholding based on a running mean.

Running-mean update (on accepted AXI beats):
$ mu_(n+1) = mu_n + (M_n - mu_n) / 2^S $

Adaptive threshold model:
$ T_n = "clamp"(mu_n * N / D + O, T_"min", T_"max") $

with `S = G_SOBEL_MEAN_SHIFT`, `N/D = G_SOBEL_THRESHOLD_GAIN_NUM / G_SOBEL_THRESHOLD_GAIN_DEN`, and `O = G_SOBEL_THRESHOLD_OFFSET`. These parameters are defined in #repo_link("rtl/SOBEL_FILTER/axi_sobel_filter.vhd", line: 10) and consumed in #repo_link("rtl/SOBEL_FILTER/sobel_core.vhd", line: 147). The final binary output remains:
$ "edge" = 255 " if " M >= T_n ", else 0" $

#figure(
  image("../../figures/3x3_raster_of_images_from_sobel_filter_start_with_threshold_10_mean_shift_8_update_interval_16384.png", width: 86%),
  caption: [Adaptive-threshold progression shown as a 3x3 raster for one input frame under intentionally slow settings (`threshold=10`, `mean_shift=8`, `update_interval=16384`).],
) <fig-sobel-adaptive-raster-slow>

@fig-sobel-adaptive-raster-slow visualizes the adaptation dynamics at a very low update rate. The threshold moves only after long accepted-pixel intervals, which makes the nine snapshots differ only in coarse steps.

#figure(
  image("../../figures/lenna_512_512_out_sobel_iter_theshold_10_mean_shift_4_update_interavl_16384.png", width: 72%),
  caption: [Faster adaptive-threshold response with stronger update step (`mean_shift=4`, `update_interval=16384`) on Lenna.],
) <fig-sobel-adaptive-fast>

In @fig-sobel-adaptive-fast the step size is larger because `mean_shift=4`, so threshold locking appears as visible block segments. The utility clamp (`f_clamp`) bounds magnitude and threshold to valid ranges and limits extreme outliers. In that sense it helps against noise spikes, but it is a safety bound, not a dedicated denoiser.

== Typical transaction sequence
#figure(
  image("../figures/generated/seq_sobel_filter_transaction.png", width: 90%),
  caption: [Representative AXI transaction sequence for #repo_link("rtl/SOBEL_FILTER/axi_sobel_filter.vhd", body: raw("AXI_SobelFilter"), line: 4).],
) <fig-sobel-seq>

== Interface and handshake contract
#figure(
  academic_table(
    columns: (1.7fr, 0.7fr, 0.85fr, 2.25fr),
    align: (left, left, left, left),
    table.header([Signal/group], [Dir.], [Width], [Purpose]),
    [`G_PIXEL_WIDTH`, `G_KERNEL_SIZE`], [generic], [positive], [Window and output format (`G_KERNEL_SIZE` constrained to `3`).],
    [`G_SOBEL_*`, `G_THRESHOLD_*`], [generic], [natural/int], [Adaptive-threshold initialization, gain, and bounds.],
    [`s_axis_window_*`], [in/out], [AXI video], [Input window stream with SOF/EOL timing.],
    [`m_axis_filter8_*`], [out/in], [AXI video], [Binary edge stream (`gray8`) with forwarded timing signals.],
  ),
  caption: [Interface summary of #repo_link("rtl/SOBEL_FILTER/axi_sobel_filter.vhd", body: raw("AXI_SobelFilter"), line: 4).],
) <tab-sobel-if>

The wrapper constrains operation to 3x3 windows using an elaboration assertion (#repo_link("rtl/SOBEL_FILTER/axi_sobel_filter.vhd", line: 47)). READY is propagated from output to input (#repo_link("rtl/SOBEL_FILTER/axi_sobel_filter.vhd", line: 74)), and the core updates adaptation state only on accepted beats (`TVALID && TREADY`) at #repo_link("rtl/SOBEL_FILTER/sobel_core.vhd", line: 156).

The behavioral validation is implemented in #repo_link("testbench/tests/test_axi_sobel_filter.py", body: raw("test_axi_sobel_filter.py"), line: 1) with model-based comparisons and stress patterns under AXI backpressure.

== Hardware discrepancy and rollback decision
During integration of adaptive thresholding into the full image path, a regression was observed on hardware: strong visual artifacts appeared and the resulting pattern looked like signal oversteering across large image regions. The effect was not limited to the final overlay view; artifacts were already visible in intermediate frames associated with the Blur Filter processing chain.

#figure(
  image("../../figures/visual-artifacts-of-bug-2.jpg", width: 72%),
  caption: [Observed hardware artifact pattern during adaptive-threshold integration in the full pipeline.],
) <fig-sobel-hw-artifact>

To isolate the issue, I used a dedicated Sobel testcase `test_axi_sobel_filter_white_3x3_zero_padded_windows` in #repo_link("testbench/tests/test_axi_sobel_filter.py", line: 341).

#figure(
  image("../../figures/test-sobel_filter_white_3x3_zero_padded-surfer-overview-signal-flow.png", width: 92%),
  caption: [Surfer signal-flow view for testcase `test_axi_sobel_filter_white_3x3_zero_padded_windows`.],
) <fig-sobel-surfer-3x3>

@fig-sobel-surfer-3x3 shows the signal flow of a simple zero-padded $3 times 3$ raster. In this pattern, only the center pixel is not classified as an edge. The red-marked position therefore shows output `00` for this single sample, while neighboring samples stay at edge level. This matched the simulation model and confirmed correct Sobel decision behavior for the written testcase.

The adaptive threshold also behaved as expected in simulation, so the result remained a simulation-versus-device mismatch. Because the physical root cause could not be isolated before the deadline, the project rolled back to the previously device-stable revision for the final hardware demonstration.
