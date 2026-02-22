#import "../shared/macros.typ": repo_link

= Component Deep Dive: CLICK_DETECTOR Control FSM
The control path consists of `DebouncedClickDetector` (#repo_link("rtl/CLICK_DETECTOR/hdl/debounced_click_detector.vhd", line: 4)) and `ClickDetector` (#repo_link("rtl/CLICK_DETECTOR/hdl/click_detection.vhd", line: 5)). BTN1 cycles processing stages, while BTN2 cycles base-image behavior.

#figure(
  image("../../figures/vivado_block_wiring.png", width: 76%),
  caption: [Vivado integration view showing debounced click-detector control IP in the processing system context.],
) <fig-click-vivado>

#figure(
  table(
    columns: 4,
    table.header([Signal/group], [Dir.], [Width], [Purpose]),
    [`G_CLK_FREQ_HZ`, `G_DEBOUNCE_NS`], [generic], [integer], [Debounce timing configuration in `DebouncedClickDetector`.],
    [`i_btn[3:0]`], [in], [4], [Physical button inputs before debounce.],
    [`o_btn_debounced`, `o_btn2_debounced`], [out], [1 each], [Edge-detected FSM trigger sources after debounce.],
    [`o_pass_grayscale`], [out], [1], [Base-stream selection: RGB passthrough vs gray replication.],
    [`o_pass_blurr_filter`, `o_pass_sobel`], [out], [1 each], [Processing-mode bypass controls.],
    [`o_overlay_zeros`], [out], [1], [Force binary-only overlay output mode.],
    [`o_led[3:0]`], [out], [4], [Runtime mode indicators.],
  ),
  caption: [Click-detector control interfaces from #repo_link("rtl/CLICK_DETECTOR/hdl/debounced_click_detector.vhd", body: raw("debounced_click_detector.vhd"), line: 4) and #repo_link("rtl/CLICK_DETECTOR/hdl/click_detection.vhd", body: raw("click_detection.vhd"), line: 5).],
) <tab-click-if>

== FSM style classification (Mealy vs Moore)
Both FSM partitions in `ClickDetector` are Moore-style with respect to output behavior: output controls are derived from current state registers (`s_current_state`, `s_base_current_state`), while button edges only affect next-state transitions.

#figure(
  image("../figures/generated/state_click_detector.png", width: 74%),
  caption: [BTN1 processing-state FSM with output mode mapping and BTN2 independence note.],
) <fig-click-state>

#figure(
  table(
    columns: 5,
    table.header([FSM], [State], [`o_pass_blurr_filter`], [`o_pass_sobel`], [Base/overlay outcome]),
    [processing], [`ST_PASS_ALL`], [`1`], [`1`], [Bypass blur and sobel; upstream grayscale stage remains available.],
    [processing], [`ST_SOBEL`], [`1`], [`0`], [Sobel active without blur pre-stage.],
    [processing], [`ST_BLUR_SOBEL`], [`0`], [`0`], [Blur + Sobel cascade active.],
    [base], [`ST_RGB`], [`-`], [`-`], [`o_pass_grayscale=1`, `o_overlay_zeros=0`: RGB base shown.],
    [base], [`ST_GRAY`], [`-`], [`-`], [`o_pass_grayscale=0`, `o_overlay_zeros=0`: gray-replicated base shown.],
    [base], [`ST_ZEROS`], [`-`], [`-`], [`o_pass_grayscale=0`, `o_overlay_zeros=1`: base suppressed, binary overlay-only view.],
  ),
  caption: [State/output matrix for processing and base-image FSM partitions.],
) <tab-click-states>
