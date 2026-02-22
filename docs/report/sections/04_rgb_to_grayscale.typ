#import "../shared/macros.typ": repo_link

= Component Deep Dive: RGB_TO_GRAYSCALE
`AXI_RgbToGrayscale` (#repo_link("rtl/RGB_TO_GRAYSCALE/hdl/axi_rgb_to_grayscale.vhd", line: 4)) wraps the grayscale core `E_RgbToGrayscale` (#repo_link("rtl/RGB_TO_GRAYSCALE/hdl/rgb_to_grayscale.vhd", line: 5)) and emits two synchronized output branches: a grayscale stream (`gray8`) and an RGB stream (`rbg888`) that can either forward the original pixel or replicate grayscale data, depending on `i_pass_through`.

#figure(
  image("../../figures/AXI_Bayer2RGB_Gamma_Corr2Gray.png", width: 95%),
  caption: [Vivado block context showing AXI_RgbToGrayscale insertion and interfaces.],
) <fig-rgb2gray-vivado>

#figure(
  table(
    columns: 4,
    table.header([Signal/group], [Dir.], [Width], [Purpose]),
    [`G_COMPONENT_WIDTH`], [generic], [default `8`], [Per-channel component width.],
    [`i_aclk`, `i_aresetn`], [in], [1], [Clock/reset for AXI stream logic.],
    [`i_pass_through`], [in], [1], [Selects original RGB forwarding versus grayscale-replicated RGB.],
    [`s_axis_video_*`], [in/out], [AXI video], [Input AXI4-Stream video channel (R|B|G payload order).],
    [`m_axis_rbg888_*`], [out/in], [AXI video], [RGB/RBG output branch for pipeline base stream.],
    [`m_axis_gray8_*`], [out/in], [AXI video], [Gray8 output branch for filter pipeline.],
  ),
  caption: [AXI_RgbToGrayscale interface overview from #repo_link("rtl/RGB_TO_GRAYSCALE/hdl/axi_rgb_to_grayscale.vhd", line: 4).],
) <tab-rgb2gray-if>

== Conversion formulas and implementation tradeoff
A common luminance-weighted floating-point model is:
$ Y_"float" = 0.299 R + 0.587 G + 0.114 B $

A fixed-point integer approximation suitable for 8-bit hardware is:
$ Y_"fix8" = (77R + 150G + 29B + 128) / 256 $

The implemented RTL uses a shift/add approximation:
$ Y_"rtl" approx (R/4) + (G/2) + (B/4) $

This avoids multipliers and keeps the stage fully combinational (`E_RgbToGrayscale`), while `AXI_RgbToGrayscale` handles dual-branch handshake decoupling with a pending-beat register.

== Typical transaction sequence
#figure(
  image("../figures/generated/seq_rgb_to_grayscale_transaction.png", width: 92%),
  caption: [Typical dual-branch transaction for AXI_RgbToGrayscale under optional RGB-branch backpressure.],
) <fig-rgb2gray-seq>

== Timing diagram from cocotb VCD/GHW run
#figure(
  image("../figures/generated/timing_rgb_to_grayscale.png", width: 94%),
  caption: [Measured AXI handshake timing for RGB_TO_GRAYSCALE from testbench VCD extraction.],
) <fig-rgb2gray-timing>

Key observations from the waveform include:
- accepted input beats only when the internal slot is free,
- branch-level backpressure propagation to `s_axis_video_tready`,
- retained SOF/EOL alignment between RGB and gray branches.
