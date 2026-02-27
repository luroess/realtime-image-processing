#import "../shared/macros.typ": *

= Component: DEBOUNCER
#component_owner("Valentin Bumeder")

== Overview
The `Debouncer` (#repo_link("rtl/DEBOUNCER/hdl/debouncing.vhd", line: 5, branch: "feat/rollback")) detects button inputs of the FPGA-Boards and generates a clean output signal for the control FSM described below.   
Debouncing is required on FPGA boards because buttons bounce when pressed or released and therefore toggle between 0 and 1 for approximatly 2-3 milliseconds@meyer-baese_embedded_2025.
With the implemented debouncing, such short oscillations are ignored, and a button click is detected only when a state persists for 10 ms. 

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
      [`i_btn`],
      [in],
      [1],
      [Physical button inputs before debounce.],
      [`o_btn_debounced`],
      [out],
      [1],
      [Debounced button level (synchronized + stable). Rising edges are detected in `ClickDetector`.],
    ),
  ),
  caption: [Debouncer interfaces from (#repo_link("rtl/DEBOUNCER/hdl/debouncing.vhd", line: 5, branch: "feat/rollback")).],
) <tab-click-if>

== Implementation

The implementation consists of two synchronous processes in the entity `Debouncer`.

First, process `P_SYNC` samples the button input (`i_btn`) through two flip-flops (`s_sync1`, `s_sync2`) to reduce metastability risk for asynchronous button inputs.

Second, process `P_REG_DEBOUNCE` implements a counter-based stability check. The current stable button level is stored in the signal `s_stable_btn`.
If the synchronized input `s_sync2` differs from stable button level, a counter is incremented each clock cycle until the C_COUNT_MAX is reached. At this point the stable button output is changed. In case the synchronized input equals `s_stable_btn`, the counter is reset to `0`. This reset ensures a steady input signal was detected before the output changes. 

The logic is dependent on the clock frequence because the counter iterates each clock cycle. The clock frequence and the desired stable period can be set via two generics. 

== Testbench
The debouncing testbench (#repo_link("testbench/teststest_debouncing.py", line: 1, branch: "feat/rollback")) simulates bouncing inputs on both the button press and release to verify the functionality of the `Debouncer`.
