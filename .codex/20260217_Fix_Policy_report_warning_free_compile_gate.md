# Fix Policy: report_warning_free_compile_gate

Date: 20260217
Category: Fix
Type: Policy
Label: report_warning_free_compile_gate

## Context

- Requirement: report compilation must always be free of Typst errors and warnings.
- Need enforceable workflow, not manual best-effort.

## Objective

- Add a repo command that fails on any report compile diagnostics.
- Persist the quality gate in `.codex/AGENTS.md`.

## Notes

- Added `make report-check` that compiles in both invocation styles:
  - from repo root with `--root .`
  - from `docs/report/`
- Gate treats any emitted compile diagnostics as failure.

## Actions

1. Updated `Makefile` with `report-check` target.
2. Updated `.codex/AGENTS.md` with a required report compile quality gate section.
3. Verified gate result:
   - `make report-check` => `OK: report compile is warning-free in both modes.`
