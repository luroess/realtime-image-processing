# Fix Report: github_repo_links_macro

Date: 20260217
Category: Fix
Type: Report
Label: github_repo_links_macro

## Context

- Requirement: every source file/class referenced in the report must be linkable to GitHub with a shared URL stem.
- Provided stem: `https://github.com/luroess/realtime-image-processing/blob/master/`.

## Objective

- Add reusable Typst link helper(s) and apply them across report references.
- Persist this policy in `.codex/AGENTS.md`.

## Notes

- Implemented `blink` + `repo_link` in `docs/report/shared/macros.typ`.
- `repo_link` supports optional line anchors (`line`, `line_end`) for class/entity references.

## Actions

1. Updated `.codex/AGENTS.md` with a mandatory report source-link policy.
2. Added reusable report macros:
   - `ext_link_blue`
   - `blink(dest, body)`
   - `repo_stem`
   - `repo_link(path, body: none, line: none, line_end: none)`
3. Replaced report source/class references with clickable GitHub links in:
   - `docs/report/sections/01_intro_scope.typ`
   - `docs/report/sections/03_verification_framework.typ`
   - `docs/report/sections/04_component_rgb2gray.typ`
   - `docs/report/sections/06_component_edge_overlay_and_control.typ`
   - `docs/report/sections/07_results_and_metrics.typ`
   - `docs/report/sections/08_team_contributions.typ`
   - `docs/report/sections/09_fast_theoretical_zybo.typ`
   - `docs/report/sections/09_risks_limitations_future.typ`
4. Verified compile success:
   - `typst compile --root . docs/report/report.typ docs/report/build/report.pdf`
   - `cd docs/report && typst compile report.typ build/report_from_report_dir.pdf`
