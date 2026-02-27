#import "../shared/macros.typ": *

= Component Deep Dive: WINDOW Wrapper Modules (Blur + Sobel)
#component_owner("Lukas Röß")

== Shared wrapper architecture
#repo_link("rtl/BLURR_WINDOW_MODULE/hdl/axi_blurr_window_module.vhd", body: raw("AXI_BlurrWindowModule"), line: 4) and #repo_link("rtl/SOBEL_WINDOW_MODULE/hdl/axi_sobel_window_module.vhd", body: raw("AXI_SobelWindowModule"), line: 4) use the same structural pattern:
$ "output" = "input" " when pass-through, else " F("window(input)") $

Both wrappers instantiate #repo_link("rtl/WINDOW_GENERATOR/hdl/window_generator.vhd", body: raw("window_generator"), line: 5) to form sliding neighborhoods, then apply a filter core through AXI wrappers. In pass-through mode, each wrapper suppresses filter-path `TVALID` and directly forwards the input stream timing.

== Comparative interface and behavior summary
#figure(
  academic_table(
    columns: (1.35fr, 1.45fr, 1.45fr, 2.0fr),
    align: (left, left, left, left),
    table.header([Aspect], [Blur wrapper], [Sobel wrapper], [Notes]),
    [Primary source], [#repo_link("rtl/BLURR_WINDOW_MODULE/hdl/axi_blurr_window_module.vhd", body: raw("AXI_BlurrWindowModule"), line: 4)], [#repo_link("rtl/SOBEL_WINDOW_MODULE/hdl/axi_sobel_window_module.vhd", body: raw("AXI_SobelWindowModule"), line: 4)], [Both are AXI4-Stream wrappers around #repo_link("rtl/WINDOW_GENERATOR/hdl/window_generator.vhd", body: raw("window_generator"), line: 5) plus a filter stage.],
    [Filter instance], [#repo_link("rtl/BLURR_FILTER/axi_blurr_filter.vhd", body: raw("AXI_BlurrFilter"), line: 4)], [#repo_link("rtl/SOBEL_FILTER/axi_sobel_filter.vhd", body: raw("AXI_SobelFilter"), line: 4)], [Blur outputs gray8; Sobel outputs binary gray and is then replicated to RGB lanes.],
    [Output payload], [`m_axis_filter8_tdata` (`gray8`)], [`m_axis_rbg888_tdata` (`gray replicated to 24 bit`)], [Sobel wrapper forms RGB payload by triplicating the gray output.],
    [Pass-through mux], [#repo_link("rtl/BLURR_WINDOW_MODULE/hdl/axi_blurr_window_module.vhd", line: 111)], [#repo_link("rtl/SOBEL_WINDOW_MODULE/hdl/axi_sobel_window_module.vhd", line: 113)], [Top-level mux selects direct input or filter path.],
    [Dimension guards], [Coefficient-length assertion], [Kernel-size and pixel-width assertions], [Sobel wrapper constrains current integration to `3x3` and `8 bit`.],
  ),
  caption: [Combined comparison of blur and Sobel window wrappers.],
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

== Verification with cocotb testbench
This combined chapter uses two dedicated wrapper targets:
- `axi_blurr_window_module` -> #repo_link("testbench/tests/test_axi_blurr_window_module.py", body: raw("tests.test_axi_blurr_window_module"), line: 1)
- `axi_sobel_window_module` -> #repo_link("testbench/tests/test_axi_sobel_window_module.py", body: raw("tests.test_axi_sobel_window_module"), line: 1)

Executed commands:
```bash
cd testbench
uv run tb-sim --target axi_blurr_window_module
uv run tb-sim --target axi_sobel_window_module
```

Observed results from `results.xml`:
- `axi_blurr_window_module`: testcases `3`, failures `0`, errors `0`
- `axi_sobel_window_module`: testcases `3`, failures `0`, errors `0`

Main checks in wrapper tests:
- pass-through versus active-filter path behavior (#repo_link("testbench/tests/test_axi_blurr_window_module.py", line: 156), #repo_link("testbench/tests/test_axi_sobel_window_module.py", line: 153))
- expected output image shape and content checks (#repo_link("testbench/tests/test_axi_blurr_window_module.py", line: 97), #repo_link("testbench/tests/test_axi_sobel_window_module.py", line: 93))
- timeout-bounded receive and handshake progression (#repo_link("testbench/tests/test_axi_blurr_window_module.py", line: 125), #repo_link("testbench/tests/test_axi_sobel_window_module.py", line: 126))

// #figure(
//   image("../figures/generated/tb_sobel_window_output.png", width: 78%),
//   caption: [Output image produced by `axi_sobel_window_module` test run (`lenna_512_512_out_window_module_sobel.png`).],
// ) <fig-tb-sobel-window-output>
