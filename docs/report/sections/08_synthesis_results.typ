#import "../shared/macros.typ": *

= Synthesis and Implementation Results
#component_owner("Engineering review")

This section uses Typst file I/O (`csv(...)`) over cleaned artifacts generated from Vivado reports in `docs/report/data/`.

#let resource_rows = csv("../data/resource_utilization.csv", row-type: dictionary)
#let share_rows = csv("../data/resource_relative_share_vs_system.csv", row-type: dictionary)

#let module_name(module) = {
  if module == "rgb_to_grayscale_axi_ooc" {
    [RGB_TO_GRAYSCALE (AXI OOC)]
  } else if module == "frame_compositor_core_ooc" {
    [FRAME_COMPOSITOR core (OOC)]
  } else if module == "pl_pipeline_ip_ooc" {
    [Integrated pipeline IP (OOC)]
  } else if module == "system_wrapper_placed" {
    [Entire system (placed)]
  } else {
    [#module]
  }
}

#let pct_bar(value, color: rgb("#1f77b4")) = {
  let v = float(value)
  let clamped = calc.min(v, 100.0)
  box(
    width: clamped * 0.06cm,
    height: 0.28cm,
    fill: color,
    stroke: none,
    radius: 1.5pt,
    inset: 0pt,
  )
}

#figure(
  academic_table(
    columns: (1.75fr, 0.55fr, 0.55fr, 0.55fr, 0.55fr, 2.2fr),
    align: (left, center, center, center, center, left),
    table.header([Module], [LUT], [FF], [BRAM], [DSP], [Evidence source]),
    ..resource_rows.map(row => (
      [#module_name(row.module)],
      [#row.lut],
      [#row.ff],
      [#row.bram],
      [#row.dsp],
      [#row.report_path],
    )).flatten(),
  ),
  caption: [Resource utilization extracted from Vivado synthesis/implementation reports.],
) <tab-resource-abs>

#figure(
  academic_table(
    columns: (1.75fr, 1.5fr, 1.5fr),
    align: (left, left, left),
    table.header([Module], [LUT share vs system], [FF share vs system]),
    ..share_rows.map(row => (
      [#module_name(row.module)],
      [#pct_bar(row.vs_system_lut_pct) #h(0.4em) #row.vs_system_lut_pct%],
      [#pct_bar(row.vs_system_ff_pct, color: rgb("#ff7f0e")) #h(0.4em) #row.vs_system_ff_pct%],
    )).flatten(),
  ),
  caption: [Relative LUT/FF share versus placed `system_wrapper` (CSV-driven bars rendered directly in Typst).],
) <tab-resource-share>

Observed snapshot in this revision:
- `RGB_TO_GRAYSCALE (AXI OOC)` and `FRAME_COMPOSITOR core (OOC)` are lightweight compared to full system placement,
- the integrated pipeline IP (`system_AXI_RgbGrayBlurrSobe_0_0`) dominates module-local logic among the measured design blocks,
- BRAM usage is concentrated outside these two small OOC component cuts in this snapshot.
