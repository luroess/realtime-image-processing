#import "../shared/macros.typ": *

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
