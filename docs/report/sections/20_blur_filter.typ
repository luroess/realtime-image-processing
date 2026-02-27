#import "../shared/macros.typ": *

= Component Deep Dive: BLURR_FILTER
#component_owner("Lukas Röß")

== Architectural role
#repo_link("rtl/BLURR_FILTER/axi_blurr_filter.vhd", body: raw("AXI_BlurrFilter"), line: 4) consumes a flattened $K times K$ grayscale window stream and returns one filtered gray pixel per accepted beat. The arithmetic kernel is implemented by #repo_link("rtl/BLURR_FILTER/blurr_core.vhd", body: raw("E_BlurrCore"), line: 5), while the AXI wrapper forwards `TUSER`/`TLAST` timing and READY backpressure.

== Filter model and fixed-point arithmetic
The implemented operation is a weighted sum with optional bias, normalization, rounding, and clipping:
$ y = "clip"((B + sum_(i=0)^(K^2 - 1) p_i c_i) / D, 0, 2^W - 1) $

where `W` is the pixel width, `c_i` are signed tap coefficients, `D` is the normalization divisor, and `B` is the bias term. In #repo_link("rtl/BLURR_FILTER/blurr_core.vhd", line: 46), the core uses integer arithmetic, rounds to nearest before division when `D > 1`, and saturates the result to the output range.

== Core module elements: `E_BlurrCore`
The arithmetic behavior is fully defined in #repo_link("rtl/BLURR_FILTER/blurr_core.vhd", body: raw("E_BlurrCore"), line: 5). The core is combinational (`A_RtlComb`) and contains one function plus one main process.

#figure(
  academic_table(
    columns: (1.35fr, 1.1fr, 2.55fr),
    align: (left, left, left),
    table.header([Element], [Location], [Role]),
    [Tap-count/range constants], [#repo_link("rtl/BLURR_FILTER/blurr_core.vhd", line: 29)], [Defines the loop bounds (`C_NUM_TAPS`) and output clip ceiling (`C_MAX_PIXEL`).],
    [Coefficient decode function], [#repo_link("rtl/BLURR_FILTER/blurr_core.vhd", body: raw("f_coeff_at"), line: 32)], [Extracts one signed coefficient from packed `G_KERNEL_COEFFS` using bit slices.],
    [Generic guards], [#repo_link("rtl/BLURR_FILTER/blurr_core.vhd", line: 39)], [Checks kernel size validity and packed coefficient length consistency.],
    [MAC + normalize + clip process], [#repo_link("rtl/BLURR_FILTER/blurr_core.vhd", line: 46)], [Implements multiply-accumulate, sign-aware rounding, division, saturation, and cast to output vector.],
  ),
  caption: [Core implementation elements in #repo_link("rtl/BLURR_FILTER/blurr_core.vhd", body: raw("blurr_core.vhd"), line: 1).],
) <tab-blur-core-elements>

The process sequence is:
1. Initialize accumulator with `G_BIAS`.
2. For each tap, unpack pixel and coefficient, then accumulate `v_sum += pixel * coeff`.
3. Apply optional normalization by `G_NORMALIZE_DIVISOR` with round-to-nearest.
4. Saturate to `[0, 2^W - 1]` and cast to `std_logic_vector`.

This mapping keeps the core simple and deterministic, and it matches the parameterized filter equation above.

== Typical transaction sequence
#figure(
  image("../figures/generated/seq_blurr_filter_transaction.png", width: 90%),
  caption: [Representative AXI transaction sequence for #repo_link("rtl/BLURR_FILTER/axi_blurr_filter.vhd", body: raw("AXI_BlurrFilter"), line: 4).],
) <fig-blur-seq>

== Interface and parameter contract
#figure(
  academic_table(
    columns: (1.6fr, 0.7fr, 0.85fr, 2.35fr),
    align: (left, left, left, left),
    table.header([Signal/group], [Dir.], [Width], [Purpose]),
    [`G_PIXEL_WIDTH`, `G_KERNEL_SIZE`], [generic], [positive], [Pixel bit width and window dimension.],
    [`G_COEFF_WIDTH`, `G_KERNEL_COEFFS`], [generic], [vector], [Signed coefficient format and packed tap payload.],
    [`G_NORMALIZE_DIVISOR`, `G_BIAS`], [generic], [positive/int], [Post-accumulation scaling and DC offset.],
    [`s_axis_window_*`], [in/out], [AXI video], [Input window stream (`K^2 * G_PIXEL_WIDTH` payload).],
    [`m_axis_filter8_*`], [out/in], [AXI video], [Filtered gray stream with propagated SOF/EOL timing.],
  ),
  caption: [Interface summary of #repo_link("rtl/BLURR_FILTER/axi_blurr_filter.vhd", body: raw("AXI_BlurrFilter"), line: 4).],
) <tab-blur-if>

The wrapper validates coefficient-payload sizing with an elaboration-time assertion (#repo_link("rtl/BLURR_FILTER/axi_blurr_filter.vhd", line: 44)). The core performs the same consistency check (#repo_link("rtl/BLURR_FILTER/blurr_core.vhd", line: 42)).

== AXI handshake behavior
The data path is combinational, so the accepted-beat rate is set by downstream readiness. In the wrapper, `s_axis_window_tready` follows `m_axis_filter8_tready` when reset is inactive (#repo_link("rtl/BLURR_FILTER/axi_blurr_filter.vhd", line: 63)). Output payload and sidebands are forced to zero whenever `TVALID=0` (#repo_link("rtl/BLURR_FILTER/axi_blurr_filter.vhd", line: 70)).

This behavior stays aligned with the project AXI4-Stream video rules for beat acceptance and SOF/EOL timing carriage.@UG934

== Verification with cocotb testbench
The blur chapter is verified through the wrapper target because no standalone `AXI_BlurrFilter` target is registered in #repo_link("testbench/targets.toml", line: 1). The executed target was `axi_blurr_window_module` (`tests.test_axi_blurr_window_module`) from #repo_link("testbench/tests/test_axi_blurr_window_module.py", line: 1).

Executed command:
```bash
cd testbench
uv run tb-sim --target axi_blurr_window_module
```

Observed result from `results.xml`:
- testcases: `3`
- failures: `0`
- errors: `0`

Main checks in the test module:
- Gaussian-window expected output and shape checks (#repo_link("testbench/tests/test_axi_blurr_window_module.py", line: 63))
- pass-through mode behavior (#repo_link("testbench/tests/test_axi_blurr_window_module.py", line: 156))
- timeout-bounded sink receive (#repo_link("testbench/tests/test_axi_blurr_window_module.py", line: 125))

#figure(
  image("../figures/generated/tb_blurr_window_output.png", width: 75%),
  caption: [Output image produced by `axi_blurr_window_module` test run (`lenna_512_512_out_window_module_blurr.png`).],
) <fig-tb-blur-output>
