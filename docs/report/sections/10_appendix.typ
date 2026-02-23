= Appendix

== CLICK_DETECTOR: FAST-enabled FSM variants
The figures in this appendix capture the `origin/feat/frame-compositor` control extension of `ClickDetector`, where FAST is integrated as an explicit processing mode and base-mode forcing during `ST_BLUR` is made explicit in the guarded transition structure.

#figure(
  image("../figures/generated/state_click_detector_frame_compositor_processing_colored.svg", width: 95%),
  caption: [`origin/feat/frame-compositor` BTN1 Moore FSM with FAST support (`ST_FAST`) and per-state output decode values.],
) <fig-app-click-state-processing-fc>

#figure(
  image("../figures/generated/state_click_detector_frame_compositor_base_colored.svg", width: 95%),
  caption: [`origin/feat/frame-compositor` BTN2 Moore FSM including `ST_BLUR`-driven force-to-`ST_ZEROS` behavior and `ST_PASS_ALL` base-mode restriction.],
) <fig-app-click-state-base-fc>
