#import "../shared/macros.typ": *

= Synthesis and Implementation Results
#component_owner("Engineering review")

This section reports synthesis and implementation utilization from cleaned Vivado artifacts under `docs/report/data/`. The numbers are loaded directly via Typst `csv(...)` so the tables and figures stay synchronized with regenerated analysis outputs.

#let resource_rows = csv("../data/resource_utilization.csv", row-type: dictionary)
#let system_split_rows = csv("../data/resource_split_system_vs_pipeline.csv", row-type: dictionary)
#let instance_split_rows = csv("../data/resource_split_pipeline_instances.csv", row-type: dictionary)

#let module_name(module) = {
  if module == "rgb_to_grayscale_axi_ooc" {
    [RGB_TO_GRAYSCALE (AXI OOC)]
  } else if module == "frame_compositor_core_ooc" {
    [FRAME_COMPOSITOR core (OOC)]
  } else if module == "pl_pipeline_ip_ooc" {
    [Integrated AXI pipeline IP (OOC)]
  } else if module == "system_wrapper_placed" {
    [Entire system (`system_wrapper`, placed)]
  } else {
    [#module]
  }
}

#figure(
  academic_table(
    columns: (auto, auto, auto, auto, auto),
    align: (left, center, center, center, center),
    table.header([Design context], [LUT], [FF], [BRAM], [DSP]),
    ..resource_rows
      .map(row => ([#module_name(row.module)], [#row.lut], [#row.ff], [#row.bram], [#row.dsp]))
      .flatten(),
  ),
  caption: [Module-level utilization snapshot from OOC synthesis reports and placed system implementation report.],
) <tab-resource-abs>

Table @tab-resource-abs establishes the baseline footprint used throughout this report. The integrated AXI pipeline contributes 4189 LUT and 4439 FF in OOC synthesis, while the placed `system_wrapper` reaches 11944 LUT, 15406 FF, and 10.5 BRAM tiles. By contrast, the isolated RGB_TO_GRAYSCALE and FRAME_COMPOSITOR core cuts remain small, which is consistent with their narrow local functionality outside full pipeline integration.

#figure(
  image("../figures/generated/fig_resource_system_vs_pipeline.png", width: 94%),
  caption: [Placed-system utilization split by primitive class, separating the AXI pipeline contribution from other system components.],
) <fig-resource-system-vs-pipeline>

#figure(
  academic_table(
    columns: (auto, auto, auto, auto, auto, auto),
    align: (left, right, right, right, right, right),
    table.header([Primitive], [System used], [Pipeline used], [Other used], [Available], [System util.]),
    ..system_split_rows
      .map(row => ([#row.primitive], [#row.system_used], [#row.our_used], [#row.other_used], [#row.available], [#row.total_pct%]))
      .flatten(),
  ),
  caption: [Numerical companion to @fig-resource-system-vs-pipeline with placed-system and pipeline split counters.],
) <tab-resource-system-split>

The placed-design split in @fig-resource-system-vs-pipeline and @tab-resource-system-split shows that the pipeline dominates LUTRAM pressure (3571 out of 6000 available LUTRAM, 59.517% of device capacity) while contributing a smaller share of total FF capacity (4439 out of 35200, 12.611%). LUT usage is shared between the pipeline and the remainder of the design, with the full system at 67.864% LUT utilization and the pipeline accounting for 23.801 percentage points of that total. BRAM, IO, BUFG, and MMCM usage remains outside the pipeline cut in this snapshot.

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
      .map(row => ([#row.instance], [#row.component], [#row.lut], [#row.lutram], [#row.ff]))
      .flatten(),
  ),
  caption: [Per-instance resource counters parsed from the hierarchical pipeline utilization report.],
) <tab-resource-pipeline-instance-split>

The internal split in @fig-resource-pipeline-instance-split and @tab-resource-pipeline-instance-split localizes most area to `U_AxiFrameCompositor`, `U_AxiSobelWindowModule`, and `U_AxiBlurrWindowModule`, while `U_DebouncedClickDetector` and `U_AxiRgbToGrayscale` remain comparatively lightweight. This distribution matches the architecture, where delay-line-heavy stream alignment and windowed filtering dominate over control logic and simple pixel conversion.

The flat pipeline synthesis report (`pipeline_ip_utilization_synth.rpt`) under `docs/report/data/vivado_ooc/pipeline_ip/` further separates the 4189 LUT total into 618 logic LUTs and 3571 LUT memory/SRL resources, and the hierarchical report (`pipeline_ip_hier_utilization_synth.rpt`) attributes those resources to the same dominant blocks shown above. Taken together, the synthesis and implementation evidence indicates that future optimization leverage is concentrated in memory-based delay structures and window modules rather than in the control-path or grayscale front-end logic.
