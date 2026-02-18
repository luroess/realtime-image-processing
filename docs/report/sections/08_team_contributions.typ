#import "../shared/macros.typ": *

= Team Contributions and Timeline

#component_owner("All team members")

Contribution analytics are generated from canonicalized git history and optional manual overlays. This first draft uses git-derived rows only (#repo_link("docs/report/data/team_contrib_overrides.csv", body: raw("team_contrib_overrides.csv")) is intentionally empty).

#figure(
  image("../figures/generated/fig_team_contribution_gantt.svg", width: 98%),
  caption: [Contribution timeline by team member and workstream (git-derived).],
) <fig-team-gantt>

#figure(
  image("../figures/generated/fig_team_commit_density.svg", width: 88%),
  caption: [Daily commit density grouped by team member.],
) <fig-team-density>

#academic_grouped_table(
  columns: (1.6fr, 0.9fr, 1fr, 2.4fr),
  align: (left, center, center, left),
  group_header: table.header(
    [*Member*],
    table.cell(colspan: 2)[*Contribution summary*],
    [*Primary contribution domains*],
  ),
  sub_header: table.header([], [*Git commits*], [*Workstreams*], []),
  cmid_start: 1,
  cmid_end: 3,
  [Lukas Roess], [41], [4], [Verification framework, Window Generator, Sobel + Filter Wrapper, docs integration],
  [Jan Duchscherer], [41], [5], [Documentation/integration, RGB2Gray, verification orchestration, overlay touch points],
  [Valentin Bumeder], [61], [3], [Debounce/click control path, integration work, verification support],
  [Justin Loeber], [6], [2], [Window Generator feature increments and matching verification support],
)

Interpretation:

- Workstream overlaps confirm parallel development of datapath RTL, verification, and integration docs.
- The timeline in @fig-team-gantt highlights concentrated ownership windows for each component family.
- Commit density in @fig-team-density indicates ramp-up around integration and final verification phases.
