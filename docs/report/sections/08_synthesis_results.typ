#import "../shared/macros.typ": *

= Synthesis and Implementation Results
#component_owner("Jan Duchscherer")

This section summarizes resource utilization as reported by Vivado for the `feat/rollback` snapshot. The results are indicative: overlay and filtering were validated on separate development branches and were not jointly verified in a single integrated bitstream, so the utilization snapshot may not exactly match a fully feature-complete build.

#let system_split_rows = csv("../data/resource_split_system_vs_pipeline.csv", row-type: dictionary)
#let instance_split_rows = csv("../data/resource_split_pipeline_instances.csv", row-type: dictionary)

#let fmt_count(value) = {
  let n = float(value)
  let i = int(n)
  if n == i { [#i] } else { [#n] }
}

#let fmt_pct_1dp(value) = {
  let rounded = calc.round(float(value) * 10) / 10
  let s = str(rounded)
  if s.contains(".") { [#s%] } else { [#s.0%] }
}



#figure(
  image("../figures/generated/fig_resource_system_vs_pipeline.png", width: 94%),
  caption: [Utilization split by primitive class, ours (blue) vs. rest (gray).],
) <fig-resource-system-vs-pipeline>

@fig-resource-system-vs-pipeline provides a full-system utilization overview by primitive class. The blue segments isolate our AXI pipeline, containing all other IP cores that were created in the context of this project, from the remainder of the system; @tab-resource-system-split lists the corresponding counters and percentages.

#figure(
  academic_table(
    columns: (auto, auto, auto, auto, auto, auto),
    align: (left, right, right, right, right, right),
    table.header([Primitive], [System], [Ours], [Others], [Available], [System util.]),
    ..system_split_rows
      .map(row => (
        [#row.primitive],
        [#fmt_count(row.system_used)],
        [#fmt_count(row.our_used)],
        [#fmt_count(row.other_used)],
        [#fmt_count(row.available)],
        [#fmt_pct_1dp(row.total_pct)],
      ))
      .flatten(),
  ),
  caption: [Placed-system and pipeline split counters.],
) <tab-resource-system-split>

@fig-resource-system-vs-pipeline and @tab-resource-system-split highlight LUT memory as the dominant resource: the pipeline uses 3571 LUT-memory cells (#fmt_pct_1dp(3571 / 6000 * 100)), while overall utilization reaches #fmt_pct_1dp(3862 / 6000 * 100). This is expected because the line buffers and delay lines are implemented as LUT-based shift registers (SRLs), which Vivado counts under `LUT as Memory` rather than BRAM.

Board-level signals such as `btn[3:0]` and `led[3:0]` are bound only at full `system_wrapper` implementation level; their I/O usage is included in the placed-system total and therefore appears under `Others` in this system-vs-pipeline decomposition.

Within the integrated AXI pipeline, @fig-resource-pipeline-instance-split breaks down LUT/LUTRAM/FF usage across direct child instances; @tab-resource-pipeline-instance-split provides the exact counters. For consistency with Vivado's `LUT as Memory` category, the LUTRAM column includes both LUTRAMs and SRLs from the hierarchical report.

#figure(
  image("../figures/generated/fig_resource_pipeline_instance_split.png", width: 94%),
  caption: [Hierarchical synthesis split of the integrated AXI pipeline IP across direct child instances.],
) <fig-resource-pipeline-instance-split>

#figure(
  academic_table(
    columns: (auto, auto, auto, auto, auto),
    align: (left, left, right, right, right),
    table.header([Instance], [Component], [LUT], [LUTRAM], [FF]),
    ..instance_split_rows
      .map(row => (
        [#row.instance],
        [#row.component],
        [#fmt_count(row.lut)],
        [#fmt_count(row.lutram)],
        [#fmt_count(row.ff)],
      ))
      .flatten(),
  ),
  caption: [Per-instance resource usage.],
) <tab-resource-pipeline-instance-split>

The internal split in @fig-resource-pipeline-instance-split and @tab-resource-pipeline-instance-split localizes most area to `U_AxiFrameCompositor`, `U_AxiSobelWindowModule`, and `U_AxiBlurrWindowModule`, while `U_DebouncedClickDetector` and `U_AxiRgbToGrayscale` remain lightweight. This distribution matches the architecture, where delay-line-heavy stream alignment and windowed filtering dominate over control logic and simple pixel conversion.

For `U_AxiFrameCompositor`, the memory-heavy contribution is expected from `ShiftRamChain` (cascaded `c_shift_ram_0` stages). With odd kernel size, the warm-up delay can pe computed as per @eq:delay.\
For `K=3` and `W=1280` (line width), this gives `D_sobel=1281` and `D_blur+sobel=2562`, implemented as chunk delays `[1024, 257, 1024, 257]`. With 26-bit payload (`{SOF,EOL,RGB24}`) and SRL32-based mapping(SRLC32E, 32-deep shift-register LUT) @xilinx_pg122_c_shift_ram_v12_0, a first-order storage estimate is
$
  N_"SRL32,est" = 26 sum_i ceil((D_i - 1) / 32) = 26 (32 + 8 + 32 + 8) = 2080,
$
which is close to the measured `2049` SRL-class primitives (reported here under the LUT-memory bucket). For beat alignment, the wrapper uses
$
  D_"effective" = D_"requested" + (N_"stages" - 1),
$
thus the effective taps are `1282` for Sobel (`1281 + (2 - 1)`) and `2565` for Blur+Sobel (`2562 + (4 - 1)`). This adjusts alignment timing, but not the storage estimate above. Since `c_shift_ram_0` enables `RegLastBit`, FFs are expected in addition to SRL-based LUT memory, along with wrapper control registers.
