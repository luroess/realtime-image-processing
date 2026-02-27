#import "../shared/macros.typ": *

= Component Deep Dive: RGB-Gray-Blur-Sobel-Overlay Pipeline
#component_owner("Lukas Röß")

== Top-level objective
#repo_link("rtl/PIPELINE/hdl/axi_rgb_gray_blurr_sobel_overlay_pipeline.vhd", body: raw("AXI_RgbGrayBlurrSobelOverlayPipeline"), line: 4) integrates the full real-time stream chain:
`RGB -> grayscale -> blur -> Sobel -> overlay compositor`.

The module keeps one AXI4-Stream input/output interface and exposes runtime mode controls through debounced button logic.

== Processing chain and submodule composition
#figure(
  academic_table(
    columns: (1.15fr, 1.85fr, 2.2fr),
    align: (left, left, left),
    table.header([Stage], [Main module], [Function in chain]),
    [Control], [#repo_link("rtl/CLICK_DETECTOR/hdl/debounced_click_detector.vhd", body: raw("DebouncedClickDetector"), line: 5)], [Generates stable mode bits for stage bypass and overlay style selection.],
    [RGB split], [#repo_link("rtl/RGB_TO_GRAYSCALE/hdl/axi_rgb_to_grayscale.vhd", body: raw("AXI_RgbToGrayscale"), line: 4)], [Produces synchronized RGB base branch and grayscale processing branch.],
    [Blur path], [#repo_link("rtl/BLURR_WINDOW_MODULE/hdl/axi_blurr_window_module.vhd", body: raw("AXI_BlurrWindowModule"), line: 4)], [Optional low-pass stage on grayscale stream.],
    [Sobel path], [#repo_link("rtl/SOBEL_WINDOW_MODULE/hdl/axi_sobel_window_module.vhd", body: raw("AXI_SobelWindowModule"), line: 4)], [Optional edge extraction on gray/blur stream; outputs RGB-formatted edge mask.],
    [Merge], [#repo_link("rtl/FRAME_COMPOSITOR/hdl/axi_frame_compositor.vhd", body: raw("AXI_FrameCompositor"), line: 4)], [Aligns delayed base RGB with edge timing and composes final RGB output.],
  ),
  caption: [Structural decomposition of #repo_link("rtl/PIPELINE/hdl/axi_rgb_gray_blurr_sobel_overlay_pipeline.vhd", body: raw("AXI_RgbGrayBlurrSobelOverlayPipeline"), line: 4).],
) <tab-pipeline-chain>

== Typical transaction sequence
#figure(
  image("../figures/generated/seq_pipeline_blurr_sobel_transaction.png", width: 94%),
  caption: [Integrated transaction sequence for #repo_link("rtl/PIPELINE/hdl/axi_rgb_gray_blurr_sobel_overlay_pipeline.vhd", body: raw("AXI_RgbGrayBlurrSobelOverlayPipeline"), line: 4).],
) <fig-pipeline-seq>

== Frame-consistent runtime control
The pipeline latches mode control values only at accepted start-of-frame beats:
$ "sof_accept" = "TVALID" and "TREADY" and "TUSER" $

This is implemented in `s_input_sof_accept` and `P_REG_FRAME_CTRL_LATCH` (#repo_link("rtl/PIPELINE/hdl/axi_rgb_gray_blurr_sobel_overlay_pipeline.vhd", line: 143)). As a result, control changes do not tear a frame in the middle of active video.

== Delay alignment and compositor coupling
The base RGB branch is always connected to the compositor input, while the Sobel branch provides timing and edge mask data (#repo_link("rtl/PIPELINE/hdl/axi_rgb_gray_blurr_sobel_overlay_pipeline.vhd", line: 249)). Delay tap selection is mode-dependent:
- `C_DELAY_SEL_NONE` for pass-through output,
- `C_DELAY_SEL_SOBEL` for grayscale+Sobel overlay,
- `C_DELAY_SEL_BLUR_SOBEL` for grayscale+blur+Sobel overlay.

These selections are generated in `s_fc_delay_stage_sel` (#repo_link("rtl/PIPELINE/hdl/axi_rgb_gray_blurr_sobel_overlay_pipeline.vhd", line: 167)) and consumed by #repo_link("rtl/FRAME_COMPOSITOR/hdl/axi_frame_compositor.vhd", body: raw("AXI_FrameCompositor"), line: 4).

== Sobel-threshold integration note
The top-level generic set exposes `G_SOBEL_THRESHOLD` (#repo_link("rtl/PIPELINE/hdl/axi_rgb_gray_blurr_sobel_overlay_pipeline.vhd", line: 20)) and forwards it to #repo_link("rtl/SOBEL_WINDOW_MODULE/hdl/axi_sobel_window_module.vhd", body: raw("AXI_SobelWindowModule"), line: 4) (#repo_link("rtl/PIPELINE/hdl/axi_rgb_gray_blurr_sobel_overlay_pipeline.vhd", line: 225)).

Historically, the project used a fixed Sobel threshold. The current Sobel core supports adaptive thresholding through running-mean parameters in #repo_link("rtl/SOBEL_FILTER/axi_sobel_filter.vhd", body: raw("AXI_SobelFilter"), line: 10) and #repo_link("rtl/SOBEL_FILTER/sobel_core.vhd", body: raw("E_SobelCore"), line: 12). In the present top-level wrapper, these adaptive controls are not yet promoted to the pipeline generic interface.

== Output ownership and ready propagation
The compositor is the final owner of `m_axis_video_rbg888_*`, and READY propagation follows this ownership:
- RGB branch READY is driven from compositor RGB READY.
- Sobel branch READY is driven from compositor gray READY.

This coupling is implemented at #repo_link("rtl/PIPELINE/hdl/axi_rgb_gray_blurr_sobel_overlay_pipeline.vhd", line: 263) and keeps both branches synchronized in accepted-beat space.

== Verification with cocotb testbench
Pipeline-level verification is defined by:
- #repo_link("testbench/tests/test_axi_gray_blurr_sobel_overlay_pipeline.py", body: raw("tests.test_axi_gray_blurr_sobel_overlay_pipeline"), line: 1)
- #repo_link("testbench/tests/test_axi_gray_blurr_sobel_overlay_pipeline_downscaled.py", body: raw("tests.test_axi_gray_blurr_sobel_overlay_pipeline_downscaled"), line: 1)
- target configuration in #repo_link("testbench/targets.toml", line: 106) and #repo_link("testbench/targets.toml", line: 143)

Executed command for this report update:
```bash
cd testbench
uv run tb-sim --target axi_gray_blurr_sobel_overlay_pipeline_downscaled
```

Current status in this checkout:
- target result: `FAIL`
- root cause: missing source file #repo_link("testbench/tests/vhdl/c_shift_ram_0_model.vhd")
- failure appears before simulation build (`results.xml` not generated for this run)

Even with this open issue, the pipeline test area already contains generated image artifacts from prior pipeline simulations under `testbench/sim_build/`. The latest available overlay artifact is shown below.

#figure(
  image("../figures/generated/tb_pipeline_overlay_output.png", width: 86%),
  caption: [Latest available pipeline simulation artifact (`pipeline_full_chain_state3_sobel.png`) from `testbench/sim_build/test_axi_gray_blurr_sobel_overlay_pipeline/.../build/`.],
) <fig-tb-pipeline-output>
