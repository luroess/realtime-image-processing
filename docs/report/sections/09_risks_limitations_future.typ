#import "../shared/macros.typ": *

= Risks, Limitations, and Next Steps

#component_owner("Engineering review")

The current implementation baseline is functional for repository-level verification artifacts, but full deployment readiness requires additional closure steps.

#academic_table(
  columns: (1.5fr, 1fr, 2.2fr),
  align: (left, center, left),
  table.header([Risk], [Impact], [Mitigation]),
  [Window-generator framing drift under corner reset scenarios], [High], [Add dedicated multi-frame stress vectors with explicit SOF restart assertions and waveform review gates.],
  [Wrapper generic combinations under-exercised], [Medium], [Expand target matrix for resolution/kernel/threshold variations and include automatic parameter sweep summaries.],
  [Legacy artifact targets not registered in active target list], [Medium], [Either re-register `axi_edge_overlay`/`axi_windowed_filter_wrapper` in #repo_link("testbench/targets.toml", body: raw("targets.toml")) or exclude them from current-baseline KPI calculations.],
  [Limited board-level performance evidence], [Medium], [Add hardware runbook with timing/utilization snapshots and in-system throughput counters.],
  [Manual override contribution data currently empty], [Low], [Enable structured non-commit effort entries in #repo_link("docs/report/data/team_contrib_overrides.csv", body: raw("team_contrib_overrides.csv")) for final report revision.],
)

== Limitations of the Current Evidence Set

- Results are derived from stored simulation artifacts, not a freshly re-run full regression in this report build.
- The report currently emphasizes functional correctness and protocol behavior more than synthesis resource economics.
- Some historical artifacts reference legacy target names; these are parsed and retained for traceability.

== Priority Follow-Up Actions

1. Expand stress scenarios for window and wrapper paths at additional frame sizes.
2. Add synthesis/implementation metrics (LUT/FF/BRAM/Fmax) in a dedicated quantitative appendix.
3. Integrate board-level runtime validation with camera live feed and overlay switching controls.
4. Populate manual contribution overrides where design reviews or offline debugging were significant.
