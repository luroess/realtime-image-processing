# Fix Report: citation_integrity_gate_impl

Date: 20260217
Category: Fix
Type: Report
Label: citation_integrity_gate_impl

## Context

- Report compiled, but citation shorthand had an ambiguous token form in `docs/report/sections/06_component_edge_overlay_and_control.typ:47` (`@ganssle_debouncing.`).
- Needed a deterministic local/CI guard to prevent unresolved or malformed bibliography citations in Typst files.

## Objective

- Normalize ambiguous citation syntax.
- Add a strict citation integrity checker for `docs/report/**/*.typ` against `docs/report/references.bib`.
- Enforce citation checks in local `make report-check` and GitHub workflow.

## Notes

- Implemented strict shorthand handling: trailing punctuation on `@key` is rejected and must be written as `#cite(<key>).`.
- Checker also validates explicit forms `#cite(<key>)` and `#cite(label("key"))`.
- Local label refs (`@fig-*`, `@eq-*`, `@alg-*`, `@tbl-*`, `@sec-*`, `@lst-*`) and package imports like `@preview/...` are excluded.

## Actions

- Updated citation in section 06 to `#cite(<ganssle_debouncing>).`.
- Added `docs/report/analysis/check_citations.py`.
- Updated `Makefile` target `report-check` to run citation check before Typst compile passes.
- Added `.github/workflows/report-quality.yml` (citation + compile gates).
- Updated `.codex/AGENTS.md` report quality gate section with mandatory citation command.
