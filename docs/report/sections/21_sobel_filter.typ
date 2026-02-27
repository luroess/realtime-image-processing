#import "../shared/macros.typ": *

= Component Deep Dive: SOBEL_FILTER
#component_owner("Lukas Röß")

== Architectural role
#repo_link("rtl/SOBEL_FILTER/axi_sobel_filter.vhd", body: raw("AXI_SobelFilter"), line: 4) is the AXI wrapper for edge extraction from a flattened $3 times 3$ grayscale window. It delegates gradient and threshold logic to #repo_link("rtl/SOBEL_FILTER/sobel_core.vhd", body: raw("E_SobelCore"), line: 5) and forwards AXI timing sidebands.

== Sobel operator implementation
The core computes horizontal and vertical gradients with standard Sobel masks:
$ G_x = (p_3 + 2p_6 + p_9) - (p_1 + 2p_4 + p_7) $
$ G_y = (p_1 + 2p_2 + p_3) - (p_7 + 2p_8 + p_9) $

The magnitude estimate is L1-based:
$ M = |G_x| + |G_y| $

The implementation is visible in #repo_link("rtl/SOBEL_FILTER/sobel_core.vhd", line: 101), with clamping to the internal magnitude range at #repo_link("rtl/SOBEL_FILTER/sobel_core.vhd", line: 128).

== Core module elements: `E_SobelCore`
The detailed detector behavior is defined in #repo_link("rtl/SOBEL_FILTER/sobel_core.vhd", body: raw("E_SobelCore"), line: 5). The core is split into utility functions, combinational datapath logic, and one clocked adaptation process.

#figure(
  academic_table(
    columns: (1.4fr, 1.1fr, 2.5fr),
    align: (left, left, left),
    table.header([Element], [Location], [Role]),
    [Utility clamp], [#repo_link("rtl/SOBEL_FILTER/sobel_core.vhd", body: raw("f_clamp"), line: 43)], [Bounds magnitude and threshold values to valid integer ranges.],
    [Power-of-two helper], [#repo_link("rtl/SOBEL_FILTER/sobel_core.vhd", body: raw("f_pow2_saturating"), line: 54)], [Builds the adaptation divisor `2^G_SOBEL_MEAN_SHIFT` with overflow protection.],
    [Window unpack], [#repo_link("rtl/SOBEL_FILTER/sobel_core.vhd", line: 90)], [Maps flattened input window to `p1..p9` unsigned pixel signals.],
    [Gradient/magnitude process], [#repo_link("rtl/SOBEL_FILTER/sobel_core.vhd", line: 101)], [Computes `Gx`, `Gy`, absolute values, and L1 magnitude `M`.],
    [Threshold compare process], [#repo_link("rtl/SOBEL_FILTER/sobel_core.vhd", line: 132)], [Builds adaptive threshold and emits binary edge pixel.],
    [Running-mean update], [#repo_link("rtl/SOBEL_FILTER/sobel_core.vhd", body: raw("P_MEAN_UPDATE"), line: 147)], [Updates `s_running_mean` only on accepted AXI beats and selected update interval.],
  ),
  caption: [Core implementation elements in #repo_link("rtl/SOBEL_FILTER/sobel_core.vhd", body: raw("sobel_core.vhd"), line: 1).],
) <tab-sobel-core-elements>

The process split is important for verification:
1. Magnitude generation is combinational and depends only on the current 3x3 window.
2. Threshold decision is combinational and depends on current `s_running_mean` and `s_mag`.
3. Adaptation state (`s_running_mean`, update counter) changes only on `TVALID && TREADY` accepted beats.

== Threshold evolution: fixed to adaptive
The first implementation used a constant threshold compare (`M >= G_SOBEL_THRESHOLD`) for binary edge output. The current implementation keeps `G_SOBEL_THRESHOLD` as initial mean value but extends the detector with adaptive thresholding based on a running mean.

Running-mean update (on accepted AXI beats):
$ mu_(n+1) = mu_n + (M_n - mu_n) / 2^S $

Adaptive threshold model:
$ T_n = "clamp"(mu_n * N / D + O, T_"min", T_"max") $

with `S = G_SOBEL_MEAN_SHIFT`, `N/D = G_SOBEL_THRESHOLD_GAIN_NUM / G_SOBEL_THRESHOLD_GAIN_DEN`, and `O = G_SOBEL_THRESHOLD_OFFSET`. These parameters are defined in #repo_link("rtl/SOBEL_FILTER/axi_sobel_filter.vhd", line: 10) and consumed in #repo_link("rtl/SOBEL_FILTER/sobel_core.vhd", line: 147). The final binary output remains:
$ "edge" = 255 " if " M >= T_n ", else 0" $

== Typical transaction sequence
#figure(
  image("../figures/generated/seq_sobel_filter_transaction.png", width: 90%),
  caption: [Representative AXI transaction sequence for #repo_link("rtl/SOBEL_FILTER/axi_sobel_filter.vhd", body: raw("AXI_SobelFilter"), line: 4).],
) <fig-sobel-seq>

== Interface and handshake contract
#figure(
  academic_table(
    columns: (1.7fr, 0.7fr, 0.85fr, 2.25fr),
    align: (left, left, left, left),
    table.header([Signal/group], [Dir.], [Width], [Purpose]),
    [`G_PIXEL_WIDTH`, `G_KERNEL_SIZE`], [generic], [positive], [Window and output format (`G_KERNEL_SIZE` constrained to `3`).],
    [`G_SOBEL_*`, `G_THRESHOLD_*`], [generic], [natural/int], [Adaptive-threshold initialization, gain, and bounds.],
    [`s_axis_window_*`], [in/out], [AXI video], [Input window stream with SOF/EOL timing.],
    [`m_axis_filter8_*`], [out/in], [AXI video], [Binary edge stream (`gray8`) with forwarded timing signals.],
  ),
  caption: [Interface summary of #repo_link("rtl/SOBEL_FILTER/axi_sobel_filter.vhd", body: raw("AXI_SobelFilter"), line: 4).],
) <tab-sobel-if>

The wrapper constrains operation to 3x3 windows using an elaboration assertion (#repo_link("rtl/SOBEL_FILTER/axi_sobel_filter.vhd", line: 47)). READY is propagated from output to input (#repo_link("rtl/SOBEL_FILTER/axi_sobel_filter.vhd", line: 74)), and the core updates adaptation state only on accepted beats (`TVALID && TREADY`) at #repo_link("rtl/SOBEL_FILTER/sobel_core.vhd", line: 156).

== Verification with cocotb testbench
The Sobel filter is verified directly with target `axi_sobel_filter` (`tests.test_axi_sobel_filter`) in #repo_link("testbench/targets.toml", line: 57) and #repo_link("testbench/tests/test_axi_sobel_filter.py", line: 1).

Executed command:
```bash
cd testbench
uv run tb-sim --target axi_sobel_filter
```

Observed result from `results.xml`:
- testcases: `4`
- failures: `0`
- errors: `0`

Main checks in the test module:
- Sobel golden-model comparison (#repo_link("testbench/tests/test_axi_sobel_filter.py", line: 50))
- explicit window-content assertions (#repo_link("testbench/tests/test_axi_sobel_filter.py", line: 299))
- rotating stimulus and non-identical output behavior (#repo_link("testbench/tests/test_axi_sobel_filter.py", line: 341))
- backpressure/pause robustness case (#repo_link("testbench/tests/test_axi_sobel_filter.py", line: 202))

#figure(
  image("../figures/generated/tb_sobel_filter_output.png", width: 75%),
  caption: [Output image produced by `axi_sobel_filter` test run (`lenna_512_512_out_sobel.png`).],
) <fig-tb-sobel-output>
