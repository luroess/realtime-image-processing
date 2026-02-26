#import "../shared/macros.typ": *

= Component: Control FSM \~ CLICK_DETECTOR
#component_owner(
  "Valentin Bumeder"
    + text(fill: gray)[ (debouncing, Moore-FSM process structure) ]
    + ", Jan Duchscherer"
    + text(fill: gray)[ (revision, orthogonal FSM partitions) ],
)

== Conceptual introduction
The control path consists of `DebouncedClickDetector` (#repo_link("rtl/CLICK_DETECTOR/hdl/debounced_click_detector.vhd", line: 4, branch: "feat/rollback")), `ClickDetector` (#repo_link("rtl/CLICK_DETECTOR/hdl/click_detection.vhd", line: 5, branch: "feat/rollback")) and bit-wise debouncing modules (#repo_link("rtl/DEBOUNCER/hdl/debouncing.vhd", line: 5, branch: "feat/rollback")).

BTN1 cycles processing stages, while BTN2 cycles base-image behavior.
All RTL references in this chapter point to branch `feat/rollback`.

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
      [Debounce timing configuration.],
    ),
    ports: (
      [`i_btn[3:0]`],
      [in],
      [4],
      [Physical button inputs before debounce.],
      [`o_btn_debounced`, `o_btn2_debounced`],
      [out],
      [1 each],
      [Debounced button levels (synchronized + stable). Rising edges are detected in `ClickDetector`.],
      [`o_pass_grayscale`],
      [out],
      [1],
      [Base-stream selection: RGB vs gray replication.],
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
      [Mode indicators.],
    ),
  ),
  caption: [Click-detector control interfaces from #repo_link("rtl/CLICK_DETECTOR/hdl/debounced_click_detector.vhd", body: raw("debounced_click_detector.vhd"), line: 4) and #repo_link("rtl/CLICK_DETECTOR/hdl/click_detection.vhd", body: raw("click_detection.vhd"), line: 5).],
) <tab-click-if>

== Control FSM structure and state encoding
Both FSM partitions in `ClickDetector` are Moore-style with respect to output behavior: output controls are derived from current state registers (`s_current_state`, `s_base_current_state`), while button edges only affect next-state transitions. In the RTL, this Moore template is implemented as a clocked state/edge register (`P_REG_FSM`, #repo_link("rtl/CLICK_DETECTOR/hdl/click_detection.vhd", line: 45, branch: "feat/rollback")) plus combinational next-state and output decode (`P_COMB_FSM` and `P_COMB_BASE_FSM`, #repo_link("rtl/CLICK_DETECTOR/hdl/click_detection.vhd", line: 62, branch: "feat/rollback") and #repo_link("rtl/CLICK_DETECTOR/hdl/click_detection.vhd", line: 104, branch: "feat/rollback")). The debouncer follows the same register/combinational split (synchronizer `P_SYNC` plus debounce counter `P_REG_DEBOUNCE`, #repo_link("rtl/DEBOUNCER/hdl/debouncing.vhd", line: 29, branch: "feat/rollback")); the Debouncer module and the baseline Moore-FSM process structure used across this control path were implemented by Valentin Bumeder.



#figure(
  image("../figures/generated/state_click_detector_current_processing_colored.svg", width: 95%),
  caption: [Current workspace BTN1 Moore FSM (`ClickDetector` processing partition). State labels include output decode values.],
) <fig-click-state>

#figure(
  image("../figures/generated/state_click_detector_current_base_colored.svg", width: 95%),
  caption: [Current workspace BTN2 Moore FSM (`ClickDetector` base-image partition). State labels include output decode values.],
) <fig-click-state-base-current>

The control logic is split into two orthogonal Moore partitions. The BTN1 processing FSM in @fig-click-state advances deterministically through `ST_PASS_ALL`, `ST_SOBEL`, and `ST_BLUR_SOBEL`, while `o_pass_blurr_filter`, `o_pass_sobel`, and `o_led[1:0]` are decoded solely from the active state register. This makes each button edge a pure mode step: transition conditions depend on debounced rising-edge detection, and output changes occur only after the next registered state is committed.

The BTN2 base-image FSM in @fig-click-state-base-current advances through `ST_RGB`, `ST_GRAY`, and `ST_ZEROS` on each debounced BTN2 rising edge. `o_pass_grayscale` toggles between RGB base stream (`ST_RGB`) and grayscale-replicated RGB (`ST_GRAY`), while `o_overlay_zeros` is asserted only in `ST_ZEROS` to disable the base plane and show overlay-only output. Similar to the processing partition, the BTN2 transition condition is purely edge-driven (`i_btn2_debounced = 1` and `s_btn2_prev = 0`), and the output update is a Moore decode of the registered base state (#repo_link("rtl/CLICK_DETECTOR/hdl/click_detection.vhd", line: 104, branch: "feat/rollback")).

For completeness, the extended `origin/feat/frame-compositor` variants that add FAST support and the `ST_BLUR`-dependent base-force behavior are documented in Appendix @fig-app-click-state-processing-fc and @fig-app-click-state-base-fc.

== Verification: FSM-related test overview


The control state machines are verified with dedicated cocotb targets registered in #repo_link("testbench/targets.toml", line: 30, branch: "feat/rollback"). For simulation, the debounce time is reduced to keep runtimes short (`G_DEBOUNCE_NS = 100` ns in #repo_link("testbench/targets.toml", line: 36, branch: "feat/rollback"), i.e. 10 cycles at 100 MHz).


#text(size: 9pt)[
  - *DUT: ClickDetector* (#repo_link("testbench/tests/test_click_detection.py", branch: "feat/rollback")):
    + #repo_link(
        "testbench/tests/test_click_detection.py",
        body: [`test_click_state_machine`],
        line: 14,
        branch: "feat/rollback",
      ): rising-edge driven BTN1/BTN2 sequencing and Moore output checks for `o_pass_*`, `o_overlay_zeros`, and `o_led`.

  - *DUT: DebouncedClickDetector* (#repo_link("testbench/tests/test_debounced_click_detector.py", branch: "feat/rollback")):
    + #repo_link(
        "testbench/tests/test_debounced_click_detector.py",
        body: [`test_debounced_click_detection`],
        line: 16,
        branch: "feat/rollback",
      ): end-to-end behavior with simulated bouncing on raw `i_btn[3:0]` and verification of debounced outputs and FSM mode progression.

  - *DUT: AXI_RgbGrayBlurrSobelOverlayPipeline*:
    + #repo_link(
        "testbench/tests/test_axi_pipeline_synth_fsm.py",
        body: [`test_pipeline_synthetic_fsm_compositor_modes`],
        line: 249,
        branch: "feat/rollback",
      ): synthetic 8x8 integration that validates RGB/GRAY/ZEROS base-mode outputs (PASS_ALL + BTN2 base-mode cycle).
    + #repo_link(
        "testbench/tests/test_axi_pipeline_synth_fsm.py",
        body: [`test_pipeline_controls_stay_default_without_input_sof`],
        line: 355,
        branch: "feat/rollback",
      ): ensures controls latch only on accepted input `SOF` (`TUSER=1`), not on button edges alone.
    + #repo_link(
        "testbench/tests/test_axi_gray_blurr_sobel_overlay_pipeline_downscaled.py",
        body: [`test_pipeline_full_chain_state_progression`],
        line: 184,
        branch: "feat/rollback",
      ): downscaled lenna passthrough check (reset/default FSM state).
    + #repo_link(
        "testbench/tests/test_axi_gray_blurr_sobel_overlay_pipeline_downscaled.py",
        body: [`test_pipeline_full_chain_smoke_with_backpressure`],
        line: 198,
        branch: "feat/rollback",
      ): smoke: validates output shape and writes overlay artifact.
    + #repo_link(
        "testbench/tests/test_axi_gray_blurr_sobel_overlay_pipeline.py",
        body: [`test_pipeline_full_chain_state_progression`],
        line: 200,
        branch: "feat/rollback",
      ): full-frame lenna passthrough check (reset/default FSM state).
    + #repo_link(
        "testbench/tests/test_axi_gray_blurr_sobel_overlay_pipeline.py",
        body: [`test_pipeline_full_chain_smoke_with_backpressure`],
        line: 216,
        branch: "feat/rollback",
      ): validates output shape and writes reference overlay artifact.
]

#mono_block(
  raw(
    "cd testbench
uv run tb-sim --list-targets
uv run tb-sim --target test_click_detector
uv run tb-sim --target test_debounced_click_detector
uv run tb-sim --target axi_gray_blurr_sobel_overlay_pipeline_synth_fsm_axi",
  ),
)


#pagebreak()
