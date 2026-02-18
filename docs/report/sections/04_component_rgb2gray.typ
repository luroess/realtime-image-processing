#import "../shared/macros.typ": *

= Component Deep Dive: RGB-to-Grayscale

#component_owner("Jan Duchscherer")

The grayscale stage is implemented as a lightweight arithmetic core (#repo_link("rtl/RGB_TO_GRAYSCALE/hdl/rgb_to_grayscale.vhd", line: 5)) wrapped by an AXI4-Stream interface module (#repo_link("rtl/RGB_TO_GRAYSCALE/hdl/axi_rgb_to_grayscale.vhd", line: 4)). The wrapper preserves handshake and framing while offering both replicated-RGB and gray8 outputs under UG934 framing rules.@amd_ug934

#figure(
  image("../figures/axi_rgb2gray_ip.svg", width: 74%),
  caption: [AXI RGB-to-grayscale wrapper and core structure.],
) <fig-rgb2gray-ip>

== Input/Output Contract

#academic_table(
  columns: (1.6fr, 2fr, 2fr),
  align: (left, left, left),
  table.header([Signal group], [Direction], [Purpose]),
  [`s_axis_video_*`], [Input], [RGB stream with AXI handshake + `SOF/EOL`],
  [`m_axis_rbg888_*`], [Output], [RGB-format output for pass-through or replicated gray],
  [`m_axis_gray8_*`], [Output], [Single-channel luminance stream for downstream filters],
  [`i_pass_through`], [Input], [Selects direct RGB forwarding vs grayscale emit],
)

Important stream-format alignment note: the effective testbench wire order for RGB24 in this project is `TDATA[23:0] = R|B|G`, while Python-side comparisons use `(R,G,B)` tuples after decode.

== Luminance Approximation and Tradeoff

The current arithmetic uses a shift-add approximation to avoid DSP pressure:

$ Y = (R / 4) + (G / 2) + (B / 4) $ <eq-rgb2gray-shift>

Reference fixed-point alternatives remain compatible when higher luminance fidelity is required.@itu_bt601

$ Y = (77 R + 150 G + 29 B + 128) / 256 $

This implementation is intentionally streaming and stateless per pixel; no line buffer is required in this stage.

== Empirical Output Evidence

#figure(
  grid(
    columns: (1fr, 1fr),
    gutter: 8pt,
    image("../figures/artifacts/lenna_512_512_out_rgb.png", width: 100%),
    image("../figures/artifacts/lenna_512_512_out_gray_rgb.png", width: 100%),
  ),
  caption: [Left: RGB reference frame. Right: grayscale wrapper output artifact.],
) <fig-rgb2gray-output>

@fig-rgb2gray-output confirms expected luminance replication behavior for stored regression artifacts.

== Implementation Notes

- Wrapper `tready` gating keeps RGB and gray fan-out synchronized.
- Sidebands are forwarded beat-aligned with payload.
- `i_pass_through` enables direct protocol-preserving comparison against input data in tests.
