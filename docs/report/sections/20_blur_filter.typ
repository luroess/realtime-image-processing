#import "../shared/macros.typ": *

= Component Deep Dive: BLURR_FILTER
#component_owner("Lukas Röß")

== Architectural role
#repo_link("rtl/BLURR_FILTER/axi_blurr_filter.vhd", body: raw("AXI_BlurrFilter"), line: 4) consumes a flattened $K times K$ grayscale window stream and returns one filtered gray pixel per accepted beat. The arithmetic kernel is implemented by #repo_link("rtl/BLURR_FILTER/blurr_core.vhd", body: raw("E_BlurrCore"), line: 5), while the AXI wrapper forwards `TUSER`/`TLAST` timing and READY backpressure.

== Filter model and fixed-point arithmetic
The implemented operation is a weighted sum with optional bias, normalization, rounding, and clipping:
$ y = "clip"((B + sum_(i=0)^(K^2 - 1) p_i c_i) / D, 0, 2^W - 1) $

where `W` is the pixel width, `c_i` are signed tap coefficients, `D` is the normalization divisor, and `B` is the bias term. In #repo_link("rtl/BLURR_FILTER/blurr_core.vhd", line: 46), the core uses integer arithmetic, rounds to nearest before division when `D > 1`, and saturates the result to the output range.

== Computational principle
From a signal-processing view, the blur module is a linear spatial filter with finite support. Each accepted pixel is generated from the local neighborhood by the weighted sum in Eq. (1), followed by scaling and clipping. The coefficients define the filter response, while `G_NORMALIZE_DIVISOR` and `G_BIAS` control overall gain and offset.

The current default coefficients implement a small Gaussian-like low-pass kernel. This configuration preserves large scene structures and suppresses high-frequency detail, so edge transitions become smoother before Sobel processing. Because the implementation is feed-forward and combinational in the filtering stage, no additional algorithmic latency is introduced inside the core itself.

== Typical transaction sequence
#figure(
  image("../figures/generated/seq_blurr_filter_transaction.png", width: 90%),
  caption: [Representative AXI transaction sequence for #repo_link("rtl/BLURR_FILTER/axi_blurr_filter.vhd", body: raw("AXI_BlurrFilter"), line: 4).],
) <fig-blur-seq>

== Interface and parameter contract
#figure(
  academic_table(
    columns: (1.6fr, 0.7fr, 0.85fr, 2.35fr),
    align: (left, left, left, left),
    table.header([Signal/group], [Dir.], [Width], [Purpose]),
    [`G_PIXEL_WIDTH`, `G_KERNEL_SIZE`], [generic], [positive], [Pixel bit width and window dimension.],
    [`G_COEFF_WIDTH`, `G_KERNEL_COEFFS`], [generic], [vector], [Signed coefficient format and packed tap payload.],
    [`G_NORMALIZE_DIVISOR`, `G_BIAS`], [generic], [positive/int], [Post-accumulation scaling and DC offset.],
    [`s_axis_window_*`], [in/out], [AXI video], [Input window stream (`K^2 * G_PIXEL_WIDTH` payload).],
    [`m_axis_filter8_*`], [out/in], [AXI video], [Filtered gray stream with propagated SOF/EOL timing.],
  ),
  caption: [Interface summary of #repo_link("rtl/BLURR_FILTER/axi_blurr_filter.vhd", body: raw("AXI_BlurrFilter"), line: 4).],
) <tab-blur-if>

The wrapper validates coefficient-payload sizing with an elaboration-time assertion (#repo_link("rtl/BLURR_FILTER/axi_blurr_filter.vhd", line: 44)). The core performs the same consistency check (#repo_link("rtl/BLURR_FILTER/blurr_core.vhd", line: 42)).

The blur implementation is not limited to the default Gaussian coefficients. Any $K times K$ signed kernel can be mapped through `G_KERNEL_COEFFS` as long as the packed vector length matches `G_KERNEL_SIZE * G_KERNEL_SIZE * G_COEFF_WIDTH` (#repo_link("rtl/BLURR_FILTER/blurr_core.vhd", line: 42)). This enables smoothing, sharpening, and custom spatial filters with the same wrapper/core structure.

== AXI handshake behavior
The data path is combinational, so the accepted-beat rate is set by downstream readiness. In the wrapper, `s_axis_window_tready` follows `m_axis_filter8_tready` when reset is inactive (#repo_link("rtl/BLURR_FILTER/axi_blurr_filter.vhd", line: 63)). Output payload and sidebands are forced to zero whenever `TVALID=0` (#repo_link("rtl/BLURR_FILTER/axi_blurr_filter.vhd", line: 70)).

This behavior stays aligned with the project AXI4-Stream video rules for beat acceptance and SOF/EOL timing carriage.@UG934

#figure(
  grid(
    columns: (1fr, 1fr),
    gutter: 0.45cm,
    image("../../figures/lenna_512_512_out_gray_rgb.png", width: 100%),
    image("../figures/generated/tb_blurr_window_output.png", width: 100%),
  ),
  caption: [Side-by-side comparison of grayscale input (left) and blur output (right). With the default $3 times 3$ Gaussian-like kernel, the visual change is intentionally small and mainly reduces local high-frequency noise.],
) <fig-blur-vs-gray>
