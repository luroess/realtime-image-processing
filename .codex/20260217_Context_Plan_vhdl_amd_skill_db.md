# Context Plan: VHDL + AMD Skill DB

Date: 2026-02-17
Category: Context
Type: Plan
Label: vhdl_amd_skill_db

## Goal
Implement a structured local knowledge system under `.codex/skills/fpga-vivado-vitis-structure` with:
- Global AMD doc querying across local UG indices.
- SQLite FTS5 knowledge database for AMD doc segments and VHDL usage patterns.
- Persistent bootstrap workflow policy for `.codex` operations.

## Baseline Findings
- Existing skill already has extraction/splitting/query pipelines for `ug934`, `ug835`, `ug892`, `ug896`, and `ug1118`.
- Existing query script is single-doc scoped.
- Existing references include full/split markdown and index metadata.
- Local environment includes Python `sqlite3` and `markitdown`.

## Implementation Decisions
- Extend existing skill, no new separate skill.
- Use SQLite FTS5 as primary backend.
- Query scope in phase 1 is all locally indexed UGs from `doc_profiles.DOCS`.
- Generated DB artifact remains untracked and rebuilt on demand.

## Deliverables
- Updated `query_doc.py` with global search and scope filters.
- New scripts: `build_skill_db.py`, `query_skill_db.py`, `new_codex_note.py`.
- Updated `.codex/AGENTS.md` and skill `SKILL.md` with bootstrap workflow.
- Updated structure map docs with usage examples.
