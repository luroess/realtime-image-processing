#import "../shared/macros.typ": *

= Synthesis and Implementation Results
#component_owner("Jan Duchscherer")

This section summarizes synthesis and implementation utilization as reported in Vivado's "Implementation Summary".

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

@fig-resource-system-vs-pipeline provides a placed-system utilization overview by primitive class. The blue segments isolate the AXI pipeline contribution ("Ours") from the remainder of the system; @tab-resource-system-split lists the corresponding counters.

#figure(
  image("../figures/generated/fig_resource_system_vs_pipeline.png", width: 94%),
  caption: [Placed-system utilization split by primitive class, separating the AXI pipeline contribution from other system components.],
) <fig-resource-system-vs-pipeline>

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

@fig-resource-system-vs-pipeline and @tab-resource-system-split highlight LUTRAM as the primary pressure point: the pipeline uses 3571 LUTRAM (#fmt_pct_1dp(3571 / 6000)), while overall LUTRAM utilization reaches #fmt_pct_1dp(3862 / 6000). By contrast, FF pressure is lower: the pipeline uses 4439 FF (#fmt_pct_1dp(4439 / 35200)), while the full system reaches #fmt_pct_1dp(15406 / 35200). For LUTs, the placed `system_wrapper` uses #fmt_pct_1dp(11944 / 17600), with #fmt_pct_1dp(4189 / 17600) attributable to the AXI pipeline. BRAM, IO, BUFG, and MMCM usage remains outside the pipeline cut in this snapshot.

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

The internal split in @fig-resource-pipeline-instance-split and @tab-resource-pipeline-instance-split localizes most area to `U_AxiFrameCompositor`, `U_AxiSobelWindowModule`, and `U_AxiBlurrWindowModule`, while `U_DebouncedClickDetector` and `U_AxiRgbToGrayscale` remain comparatively lightweight. This distribution matches the architecture, where delay-line-heavy stream alignment and windowed filtering dominate over control logic and simple pixel conversion.

The flat pipeline synthesis report (`pipeline_ip_utilization_synth.rpt`) under `docs/report/data/vivado_ooc/pipeline_ip/` further separates the 4189 LUT total into 618 logic LUTs and 3571 LUT memory/SRL resources, and the hierarchical report (`pipeline_ip_hier_utilization_synth.rpt`) attributes those resources to the same dominant blocks shown above. Taken together, the synthesis and implementation evidence indicates that future optimization leverage is concentrated in memory-based delay structures and window modules rather than in the control-path or grayscale front-end logic.
