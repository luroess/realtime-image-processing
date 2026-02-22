#import "../shared/macros.typ": *

= Component Deep Dive: CLICK_DETECTOR Control FSM
#component_owner("Valentin Bumeder, Jan Duchscherer")

== Conceptual introduction
The control path consists of `DebouncedClickDetector` (#repo_link("rtl/CLICK_DETECTOR/hdl/debounced_click_detector.vhd", line: 4)) and `ClickDetector` (#repo_link("rtl/CLICK_DETECTOR/hdl/click_detection.vhd", line: 5)). BTN1 cycles processing stages, while BTN2 cycles base-image behavior.

== Vivado interface view
#figure(
  image("../../figures/vivado_block_wiring.png", width: 76%),
  caption: [Vivado integration view showing debounced click-detector control IP in the processing system context.],
) <fig-click-vivado>

== Interface ports and generics
#figure(
  academic_table(
    columns: (1.7fr, 0.65fr, 0.85fr, 2.45fr),
    align: (left, left, left, left),
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

== Sequence of transitions and output changes
#figure(
  image("../figures/generated/seq_click_detector_control.png", width: 82%),
  caption: [Representative BTN1-driven state transitions and corresponding processing output updates; BTN2 base FSM cycles independently.],
) <fig-click-seq>

The sequence in @fig-click-seq matches the implemented edge-driven transition pattern in #repo_link("rtl/CLICK_DETECTOR/hdl/click_detection.vhd", line: 66) and output decode in #repo_link("rtl/CLICK_DETECTOR/hdl/click_detection.vhd", line: 148).

== Interface state/output matrix
#figure(
  academic_grouped_table(
    columns: (0.9fr, 1.2fr, 0.75fr, 0.75fr, 0.75fr, 0.75fr, 2.0fr),
    align: (left, left, center, center, center, center, left),
    group_header: table.header(
      [FSM],
      [State],
      table.cell(colspan: 2)[Processing outputs],
      table.cell(colspan: 2)[Base/overlay outputs],
      [Effect],
    ),
    sub_header: table.header(
      [],
      [],
      [`o_pass_blurr_filter`],
      [`o_pass_sobel`],
      [`o_pass_grayscale`],
      [`o_overlay_zeros`],
      [],
    ),
    cmid_start: 3,
    cmid_end: 6,
    [processing], [`ST_PASS_ALL`], [`1`], [`1`], [`-`], [`-`], [Bypass blur and sobel; upstream grayscale stage remains available.],
    [processing], [`ST_SOBEL`], [`1`], [`0`], [`-`], [`-`], [Sobel active without blur pre-stage.],
    [processing], [`ST_BLUR_SOBEL`], [`0`], [`0`], [`-`], [`-`], [Blur + Sobel cascade active.],
    [base], [`ST_RGB`], [`-`], [`-`], [`1`], [`0`], [RGB base shown.],
    [base], [`ST_GRAY`], [`-`], [`-`], [`0`], [`0`], [Gray-replicated base shown.],
    [base], [`ST_ZEROS`], [`-`], [`-`], [`0`], [`1`], [Base suppressed; binary overlay-only view.],
  ),
  caption: [State/output matrix for processing and base-image FSM partitions in `ClickDetector`.],
) <tab-click-states>
