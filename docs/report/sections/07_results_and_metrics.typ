#import "../shared/macros.typ": *

= Quantitative Results and Verification Metrics

#component_owner("Repository-wide regression evidence")

This section is generated from #repo_link("docs/report/data/junit_metrics.csv") and Plotly charts exported by #repo_link("docs/report/analysis/build_report_assets.py").

#let junit = csv("../data/junit_metrics.csv", row-type: dictionary)
#let total_tests = junit.len()
#let failed_tests = junit.filter(it => it.status != "pass").len()
#let pass_tests = total_tests - failed_tests

#section_kpis((
  (title: "Total testcases", value: str(total_tests), note: "Across all discovered results.xml files"),
  (title: "Passing", value: str(pass_tests), note: "Artifact snapshot used by this report"),
  (title: "Failing", value: str(failed_tests), note: "Expected to remain 0 for current baseline"),
))

#figure(
  grid(
    columns: (1fr, 1fr),
    gutter: 8pt,
    image("../figures/generated/fig_test_runtime_by_target.svg", width: 100%),
    image("../figures/generated/fig_testcase_count_by_module.svg", width: 100%),
  ),
  caption: [Left: summed wall runtime per target. Right: testcase distribution by module area.],
) <fig-runtime-and-count>

#figure(
  image("../figures/generated/fig_testcase_wall_vs_sim.svg", width: 90%),
  caption: [Wall-time versus simulated-time distribution by module area.],
) <fig-wall-vs-sim>

== Target Coverage Table

#let targets = (
  "example_passthrough",
  "axi_rgb_to_grayscale",
  "window_generator",
  "axi_sobel_filter",
  "axi_filter_wrapper",
  "axi_filter_wrapper_stress",
  "axi_edge_overlay",
  "test_debouncer",
  "test_click_detector",
)

#let count_for = key => junit.filter(row => row.target_key == key).len()

Registry status is evaluated against #repo_link("testbench/targets.toml").

#academic_grouped_table(
  columns: (2.1fr, 0.9fr, 1.3fr),
  align: (left, center, left),
  group_header: table.header([*Target key*], table.cell(colspan: 2)[*Evidence provenance*]),
  sub_header: table.header([], [*Recorded count*], [*Registry status*]),
  cmid_start: 1,
  cmid_end: 3,
  [example_passthrough], [#str(count_for("example_passthrough"))],
  [registered in #repo_link("testbench/targets.toml", body: raw("targets.toml"))],
  [axi_rgb_to_grayscale], [#str(count_for("axi_rgb_to_grayscale"))],
  [registered in #repo_link("testbench/targets.toml", body: raw("targets.toml"))],
  [window_generator], [#str(count_for("window_generator"))],
  [registered in #repo_link("testbench/targets.toml", body: raw("targets.toml"))],
  [axi_sobel_filter], [#str(count_for("axi_sobel_filter"))],
  [registered in #repo_link("testbench/targets.toml", body: raw("targets.toml"))],
  [axi_filter_wrapper], [#str(count_for("axi_filter_wrapper"))],
  [registered in #repo_link("testbench/targets.toml", body: raw("targets.toml"))],
  [axi_filter_wrapper_stress], [#str(count_for("axi_filter_wrapper_stress"))],
  [registered in #repo_link("testbench/targets.toml", body: raw("targets.toml"))],
  [axi_edge_overlay], [#str(count_for("axi_edge_overlay"))],
  [artifact-only target in stored `sim_build`],
  [axi_windowed_filter_wrapper], [#str(count_for("axi_windowed_filter_wrapper"))],
  [artifact-only target in stored `sim_build`],
  [test_debouncer], [#str(count_for("test_debouncer"))],
  [registered in #repo_link("testbench/targets.toml", body: raw("targets.toml"))],
  [test_click_detector], [#str(count_for("test_click_detector"))],
  [registered in #repo_link("testbench/targets.toml", body: raw("targets.toml"))],
)

The runtime profile in @fig-runtime-and-count shows that wrapper-level Sobel regressions dominate wall-clock execution due to end-to-end image and stress scenarios, while pure protocol tests remain lightweight.
