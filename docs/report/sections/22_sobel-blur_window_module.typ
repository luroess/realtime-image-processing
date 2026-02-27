#import "../shared/macros.typ": *

= Component Deep Dive: WINDOW Wrapper Modules (Blur + Sobel)
#component_owner("Lukas Röß")

== Shared wrapper architecture
#repo_link("rtl/BLURR_WINDOW_MODULE/hdl/axi_blurr_window_module.vhd", body: raw("AXI_BlurrWindowModule"), line: 4) and #repo_link("rtl/SOBEL_WINDOW_MODULE/hdl/axi_sobel_window_module.vhd", body: raw("AXI_SobelWindowModule"), line: 4) use the same structural pattern:
$ "output" = "input" " when pass-through, else " F("window(input)") $

Both wrappers instantiate #repo_link("rtl/WINDOW_GENERATOR/hdl/window_generator.vhd", body: raw("window_generator"), line: 5) to form sliding neighborhoods, then apply a filter core through AXI wrappers. In pass-through mode, each wrapper suppresses filter-path `TVALID` and directly forwards the input stream timing.
The detailed derivation of this window formation stage and its buffering model is documented in the dedicated written report by Justin Löber.

== Comparative interface and behavior summary
#figure(
  academic_table(
    columns: (1.3fr, 1.5fr, 2.6fr),
    align: (left, left, left),
    table.header([Aspect], [Modules], [Behavioral interpretation]),
    [Primary wrapper stage],
    [
      #repo_link("rtl/BLURR_WINDOW_MODULE/hdl/axi_blurr_window_module.vhd", body: raw("AXI_BlurrWindowModule"), line: 4)
      #linebreak()
      #repo_link("rtl/SOBEL_WINDOW_MODULE/hdl/axi_sobel_window_module.vhd", body: raw("AXI_SobelWindowModule"), line: 4)
    ],
    [Both modules combine window generation with a selectable filter path and a direct pass-through path.],
    [Filter coupling],
    [
      #repo_link("rtl/BLURR_FILTER/axi_blurr_filter.vhd", body: raw("AXI_BlurrFilter"), line: 4)
      #linebreak()
      #repo_link("rtl/SOBEL_FILTER/axi_sobel_filter.vhd", body: raw("AXI_SobelFilter"), line: 4)
    ],
    [Blur preserves scalar gray output, while Sobel output is replicated to RGB lanes for compositor compatibility.],
    [Bypass logic],
    [
      #repo_link("rtl/BLURR_WINDOW_MODULE/hdl/axi_blurr_window_module.vhd", body: raw("AXI_BlurrWindowModule mux"), line: 111)
      #linebreak()
      #repo_link("rtl/SOBEL_WINDOW_MODULE/hdl/axi_sobel_window_module.vhd", body: raw("AXI_SobelWindowModule mux"), line: 113)
    ],
    [A mode-controlled mux keeps stream continuity and selects either filtered data or direct input samples.],
    [Design constraints],
    [Wrapper assertions],
    [Consistency checks bind dimensions and payload size; in the Sobel path, the active integration is constrained to `3x3` and `8 bit`.],
  ),
  caption: [Combined behavioral comparison of blur and Sobel window wrappers.],
) <tab-window-wrappers>

== Blur wrapper details
The blur wrapper receives `gray8`, builds a `K times K` window, and streams one filtered gray pixel per accepted beat. Coefficient packing is checked before simulation/synthesis (#repo_link("rtl/BLURR_WINDOW_MODULE/hdl/axi_blurr_window_module.vhd", line: 58)). READY returns either from downstream (`pass-through`) or from the internal window path.

== Sobel wrapper details
The Sobel wrapper follows the same input contract but emits RGB payload for compositor compatibility by replicating the Sobel gray value into three channels (#repo_link("rtl/SOBEL_WINDOW_MODULE/hdl/axi_sobel_window_module.vhd", line: 110)).

It forwards only `G_SOBEL_THRESHOLD` to #repo_link("rtl/SOBEL_FILTER/axi_sobel_filter.vhd", body: raw("AXI_SobelFilter"), line: 4) (#repo_link("rtl/SOBEL_WINDOW_MODULE/hdl/axi_sobel_window_module.vhd", line: 90)); adaptive-threshold generics therefore use their defaults unless the wrapper interface is extended.

== Handshake implications for integration
Because both wrappers gate filter-path `TVALID` in pass-through mode (#repo_link("rtl/BLURR_WINDOW_MODULE/hdl/axi_blurr_window_module.vhd", line: 63), #repo_link("rtl/SOBEL_WINDOW_MODULE/hdl/axi_sobel_window_module.vhd", line: 65)), they avoid unnecessary window/filter activity when a stage is bypassed. This reduces internal switching and keeps global AXI beat cadence under external control.

== Typical transaction sequence
#figure(
  image("../figures/generated/seq_window_modules_transaction.png", width: 94%),
  caption: [Combined transaction sequence for #repo_link("rtl/BLURR_WINDOW_MODULE/hdl/axi_blurr_window_module.vhd", body: raw("AXI_BlurrWindowModule"), line: 4) and #repo_link("rtl/SOBEL_WINDOW_MODULE/hdl/axi_sobel_window_module.vhd", body: raw("AXI_SobelWindowModule"), line: 4).],
) <fig-window-modules-seq>

The corresponding behavioral validation is implemented in #repo_link("testbench/tests/test_axi_blurr_window_module.py", body: raw("test_axi_blurr_window_module.py"), line: 1) and #repo_link("testbench/tests/test_axi_sobel_window_module.py", body: raw("test_axi_sobel_window_module.py"), line: 1), with emphasis on pass-through/filter equivalence, expected image response, and AXI handshake robustness.
