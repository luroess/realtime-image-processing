#import "../shared/macros.typ": *

= Component: Control FSM \~ CLICK_DETECTOR
#component_owner("Valentin Bumeder, Jan Duchscherer")

== Conceptual introduction
The control path consists of `DebouncedClickDetector` (#repo_link("rtl/CLICK_DETECTOR/hdl/debounced_click_detector.vhd", line: 4)) and `ClickDetector` (#repo_link("rtl/CLICK_DETECTOR/hdl/click_detection.vhd", line: 5)). BTN1 cycles processing stages, while BTN2 cycles base-image behavior.

#figure(
  image("../../figures/ip-cores/DebouncedClickDet.png", width: 35%),
  caption: [DebouncedClickDetector top-level control IP with button-debounce inputs and runtime mode-control outputs.],
) <fig-click-vivado>

== Interface ports and generics
#figure(
  interface_table(
    generics: (
      [`G_CLK_FREQ_HZ`, `G_DEBOUNCE_NS`],
      [generic],
      [integer],
      [Debounce timing configuration in `DebouncedClickDetector`.],
    ),
    ports: (
      [`i_btn[3:0]`],
      [in],
      [4],
      [Physical button inputs before debounce.],
      [`o_btn_debounced`, `o_btn2_debounced`],
      [out],
      [1 each],
      [Edge-detected FSM trigger sources after debounce.],
      [`o_pass_grayscale`],
      [out],
      [1],
      [Base-stream selection: RGB passthrough vs gray replication.],
      [`o_pass_blurr_filter`, `o_pass_sobel`],
      [out],
      [1 each],
      [Processing-mode bypass controls.],
      [`o_overlay_zeros`],
      [out],
      [1],
      [Force binary-only overlay output mode.],
      [`o_led[3:0]`],
      [out],
      [4],
      [Runtime mode indicators.],
    ),
  ),
  caption: [Click-detector control interfaces from #repo_link("rtl/CLICK_DETECTOR/hdl/debounced_click_detector.vhd", body: raw("debounced_click_detector.vhd"), line: 4) and #repo_link("rtl/CLICK_DETECTOR/hdl/click_detection.vhd", body: raw("click_detection.vhd"), line: 5).],
) <tab-click-if>

== Control FSM structure and state encoding
Both FSM partitions in `ClickDetector` are Moore-style with respect to output behavior: output controls are derived from current state registers (`s_current_state`, `s_base_current_state`), while button edges only affect next-state transitions.

#figure(
  image("../figures/generated/state_click_detector_current_processing_colored.svg", width: 95%),
  caption: [Current workspace BTN1 Moore FSM (`ClickDetector` processing partition). State labels include output decode values.],
) <fig-click-state>

#figure(
  image("../figures/generated/state_click_detector_current_base_colored.svg", width: 95%),
  caption: [Current workspace BTN2 Moore FSM (`ClickDetector` base-image partition). In `ST_PASS_ALL`, the base-mode cycle is restricted to `ST_RGB` and `ST_GRAY` as indicated by the guarded transition labels.],
) <fig-click-state-base-current>

The control logic is split into two orthogonal Moore partitions. The BTN1 processing FSM in @fig-click-state advances deterministically through `ST_PASS_ALL`, `ST_SOBEL`, and `ST_BLUR_SOBEL`, while `o_pass_blurr_filter`, `o_pass_sobel`, and `o_led[2:0]` are decoded solely from the active state register. This makes each button edge a pure mode step: transition conditions depend on debounced rising-edge detection, and output changes occur only after the next registered state is committed.

The BTN2 base-image FSM in @fig-click-state-base-current applies guarded transitions that depend on the processing mode context. When `proc = ST_PASS_ALL`, BTN2 cycles between `ST_RGB` and `ST_GRAY` to toggle the displayed base stream without forcing overlay-only output. When `proc != ST_PASS_ALL`, BTN2 transitions are directed toward `ST_ZEROS`, ensuring that processed binary features are shown without base-image blending. This coupling keeps each FSM locally Moore while enforcing a globally coherent user-visible mode behavior.

For completeness, the extended `origin/feat/frame-compositor` variants that add FAST support and the `ST_BLUR`-dependent base-force behavior are documented in Appendix @fig-app-click-state-processing-fc and @fig-app-click-state-base-fc.
