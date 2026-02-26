#import "../shared/macros.typ": *

= Synthesis and Implementation Results
#component_owner("Jan Duchscherer")

This section summarizes synthesis and implementation utilization as reported in Vivado's Sythesis Summary for our full Pipeline as implemented on branch `feat/rollback`. Since we did not manage to sucessfully integrate and test both overlay and filtering features into a single bitstream, the following results must be regared with caution as full functionality of the integrated system was only verified for both development branches in isolation, but not together. Hence, it is not guaranteed that the synthesis snapshot reflects the resource usage of the fully integrated design with all features enabled.

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
  caption: [Placed-system utilization split by primitive class, separating the AXI pipeline contribution from other system components.],
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
  caption: [Numerical companion to @fig-resource-system-vs-pipeline with placed-system and pipeline split counters.],
) <tab-resource-system-split>

@fig-resource-system-vs-pipeline and @tab-resource-system-split highlight LUTRAM as the primarily utilized primitive: the pipeline uses 3571 LUTRAM (#fmt_pct_1dp(3571 / 6000 * 100)), while overall LUTRAM utilization reaches #fmt_pct_1dp(3862 / 6000 * 100). By contrast, utilization of FFs and regular LUTs is lower, and our additions to the overall system did _not_ affect the number f

Within the integrated AXI pipeline, @fig-resource-pipeline-instance-split breaks down LUT/LUTRAM/FF usage across direct child instances; @tab-resource-pipeline-instance-split provides the exact counters.

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
  caption: [Per-instance resource counters parsed from the hierarchical pipeline utilization report.],
) <tab-resource-pipeline-instance-split>

The internal split in @fig-resource-pipeline-instance-split and @tab-resource-pipeline-instance-split localizes most area to `U_AxiFrameCompositor`, `U_AxiSobelWindowModule`, and `U_AxiBlurrWindowModule`, while `U_DebouncedClickDetector` and `U_AxiRgbToGrayscale` remain lightweight. This distribution matches the architecture, where delay-line-heavy stream alignment and windowed filtering dominate over control logic and simple pixel conversion.

