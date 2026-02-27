#import "../shared/macros.typ": *


== Verification: RGB2GRAY-related cocotb tests
<sec-rgb2gray-verification>

All tests referenced below live on branch `feat/rollback`. The `tb-sim` target mapping is defined in #repo_link("testbench/targets.toml", branch: "feat/rollback").
The RGB2GRAY stage is covered both directly and as part of the full RGB-entry pipeline.

#text(size: 9pt)[
  *UUT: AXI_RgbToGrayscale*
  - #repo_link(
      "testbench/tests/test_axi_rgb_to_grayscale.py",
      body: [`test_axi_rgb_to_grayscale_with_backpressure_three_cycle_breaks`],
      line: 386,
      branch: "feat/rollback",
    ): READY/valid stress + handshake assertions.
  - #repo_link(
      "testbench/tests/test_axi_rgb_to_grayscale.py",
      body: [`test_axi_rgb_to_grayscale_image_file_roundtrip`],
      line: 399,
      branch: "feat/rollback",
    ): image roundtrip + saved artifact.
  - #repo_link(
      "testbench/tests/test_axi_rgb_to_grayscale.py",
      body: [`test_axi_rgb_to_grayscale_passthrough_mode`],
      line: 409,
      branch: "feat/rollback",
    ): `i_pass_through=1` yields bit-exact passthrough.

  *UUT: AXI_RgbToGrayscale + AXI_FrameCompositor (minimal integration)*
  - #repo_link(
      "testbench/tests/test_axi_rgb2gray_frame_compositor_minimal.py",
      body: [`test_axi_rgb2gray_frame_compositor_minimal_3x2_two_frames_with_gray_warmup`],
      line: 207,
      branch: "feat/rollback",
    ): 3x2 two-frame integration into `AXI_FrameCompositor`: bounded gray warm-up + 1-cycle post-warm-up cadence.

]

Used test harness components (Python):
- Source: #repo_link("testbench/drivers/axis_video_source.py", body: [`AxiVideoStreamSource`], line: 22, branch: "feat/rollback")
- Sink: #repo_link("testbench/monitors/axis_video_sink.py", body: [`AxiVideoStreamSink`], line: 14, branch: "feat/rollback")
- Reset/pause helpers: #repo_link("testbench/common/reset.py", body: [`apply_reset`], line: 8, branch: "feat/rollback"), #repo_link("testbench/common/pause.py", body: [`drive_sink_pause`], line: 17, branch: "feat/rollback"), #repo_link("testbench/common/pause.py", body: [`repeating_pause`], line: 35, branch: "feat/rollback")
- Image model / checking: #repo_link("testbench/models/image_model.py", body: [`Image`], line: 13, branch: "feat/rollback"), #repo_link("testbench/verification/scoreboard.py", body: [`Scoreboard`], line: 10, branch: "feat/rollback")

RTL components exercised in these tests:
- RGB2GRAY core/wrapper: #repo_link("rtl/RGB_TO_GRAYSCALE/hdl/rgb_to_grayscale.vhd", line: 5, branch: "feat/rollback"), #repo_link("rtl/RGB_TO_GRAYSCALE/hdl/axi_rgb_to_grayscale.vhd", line: 4, branch: "feat/rollback")
- Downstream integration: #repo_link("rtl/FRAME_COMPOSITOR/hdl/axi_frame_compositor.vhd", line: 4, branch: "feat/rollback"), #repo_link("rtl/PIPELINE/hdl/axi_rgb_gray_blurr_sobel_overlay_pipeline.vhd", line: 4, branch: "feat/rollback")


== Verification: Frame-Compositor-related tests
<sec-frame-comp-verification>
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

== CLICK_DETECTOR: FSM variants with FAST extension
The figures in this appendix capture the #blink("https://github.com/luroess/realtime-image-processing/tree/feat/frame-compositor")[`feat/frame-compositor`] control extension of `ClickDetector`, where FAST is integrated as an explicit processing mode and base-mode forcing during `ST_BLUR` is made explicit in the guarded transition structure.

Implementation references (branch `feat/frame-compositor`): #repo_link("rtl/CLICK_DETECTOR/hdl/click_detection.vhd", body: [`ClickDetector`], line: 5, branch: "feat/frame-compositor"), #repo_link("rtl/CLICK_DETECTOR/hdl/debounced_click_detector.vhd", body: [`DebouncedClickDetector`], line: 4, branch: "feat/frame-compositor"), #repo_link("rtl/FRAME_COMPOSITOR/hdl/axi_frame_compositor.vhd", body: [`AXI_FrameCompositor (FAST delay tap + color family)`], line: 4, branch: "feat/frame-compositor").

#figure(
  image("../figures/generated/state_click_detector_frame_compositor_processing_colored.svg", width: 95%),
  caption: [`origin/feat/frame-compositor` BTN1 Moore FSM with FAST support (`ST_FAST`) and per-state output decode values.],
) <fig-app-click-state-processing-fc>

#figure(
  image("../figures/generated/state_click_detector_frame_compositor_base_colored.svg", width: 95%),
  caption: [`origin/feat/frame-compositor` BTN2 Moore FSM including `ST_BLUR`-driven force-to-`ST_ZEROS` behavior and `ST_PASS_ALL` base-mode restriction.],
) <fig-app-click-state-base-fc>


== Integration on `feat/frame-compositor` branch

Due issues which manifested simulatenously with our integration of the `FRAME_COMPOSITOR` module, we decided to roll back our main branch to an earlier stable commit and did not manage to reintegrate the `FRAME_COMPOSITOR` and FAST filter in time for the final presentation. \
The step-wise reintegration of various features related to the `WINDOW_GENERATOR`, Sobel, and Gaussian filters, as well as the `FRAME_COMPOSITOR` revealed the issues to be incorrect AXIS intefaces in the aforementioned filter modules, as well as the `RGB_TO_GRAYSCALE` component. These issues however, only surfaced during the integration of the `FRAME_COMPOSITOR` module, which requires functional dual-stream AXIS master ports in `RGB_TO_GRAYSCALE`. Furthermore, experimental features inside the filter instances (like a dynamic thresholding for the sobel filter) caused additional issues which made it difficult to isolate the root cause of the integration issues. \


#figure(
  grid(
    columns: (1fr, 1fr),
    gutter: 0.55cm,
    image("../figures/artifacts/IMG_0659.small750.png", width: 85%),
    image("../figures/artifacts/IMG_0661.small750.png", width: 85%),
  ),
  caption: [`feat/frame-compositor` hardware demo snapshots.],
) <fig-app-demo-overlay>

@fig-app-demo-overlay shows two snapshots from a recent hardware demo of the `feat/frame-compositor` branch, where all functionalities related to the control FSM, and the frame overlay appeared to work correctly, but omni-present salt and pepper noise origination within our image processing branch caused plenty of false positive edges. Furthermore, as can be seen in the binary mask within @fig-app-demo-overlay, pseudo-harmonic artifacts in form of spatial waves of varying intensity can be observed.

== *WIP*: FAST Filter

Branch `feat/frame-compositor` contains a FAST-N corner detector for gray8 streams based on 7x7 windows (16-sample ring, contiguous arc test) @rosten_2006_machine. The filter emits a binary mask (`255` = candidate, `0` otherwise) and forwards SOF/EOL sidebands one-to-one.

- Core: #repo_link("rtl/FAST_FILTER/hdl/fast_core.vhd", body: [`E_FastCore`], line: 20, branch: "feat/frame-compositor") (pure combinational ring + arc test; candidate + score).
- AXI wrapper: #repo_link("rtl/FAST_FILTER/hdl/axi_fast_filter.vhd", body: [`AXI_FastFilter`], line: 22, branch: "feat/frame-compositor") (window-in, mask-out; no NMS due to ressource constraints).
- Window + bypass: #repo_link("rtl/FAST_FILTER/hdl/axi_fast_window_module.vhd", body: [`AXI_FastWindowModule`], line: 4, branch: "feat/frame-compositor") (wraps `window_generator` + FAST; `i_pass_through` bypass keeps internal window alignment).
- Verification: #repo_link("testbench/tests/test_axi_fast_filter.py", body: [`test_axi_fast_filter.py`], line: 1, branch: "feat/frame-compositor") (cocotb regression vs. Python/OpenCV reference model).

To visualize the binary mask output, we manually alpha-blended the cocotb-generated FAST mask (`255` = candidate) onto the corresponding 128x128 grayscale input crops (red = mask = 255).

#figure(
  grid(
    columns: (1fr, 1fr),
    gutter: 0.55cm,
    image("../figures/artifacts/lenna_128_128_input_fast_overlay_tb.png", width: 85%),
    image("../figures/artifacts/mountains_1920_1080_center_input_fast_overlay_tb.png", width: 85%),
  ),
  caption: [FAST mask overlays generated from cocotb regression outputs.],
) <fig-app-fast-overlays>
