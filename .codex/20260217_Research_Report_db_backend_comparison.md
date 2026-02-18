# Research Report: DB Backend Comparison

Date: 2026-02-17
Category: Research
Type: Report
Label: db_backend_comparison

## Candidates
- SQLite FTS5
- DuckDB
- Whoosh
- JSON-only indices

## Decision
SQLite FTS5 selected.

## Rationale
- Built into Python runtime (`sqlite3`) with no server process.
- Supports relational metadata + full-text search in one artifact.
- Simple operational model for local skill usage.

## Policy
- Store generated DB under `.codex/skills/fpga-vivado-vitis-structure/references/.cache/`.
- Do not commit generated DB snapshots.
- Rebuild using script from canonical markdown/index sources.
