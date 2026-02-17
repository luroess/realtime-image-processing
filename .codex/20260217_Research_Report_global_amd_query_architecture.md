# Research Report: Global AMD Query Architecture

Date: 2026-02-17
Category: Research
Type: Report
Label: global_amd_query_architecture

## Current State
- `query_doc.py` requires one `--doc` and loads one `index.json`.
- All doc profiles are centrally defined in `doc_profiles.DOCS`.

## Target Architecture
- Add `--doc all` to aggregate all configured doc indices.
- Add doc subset filter (`--docs`) and entry-kind scope (`sections|chapters|all`).
- Preserve existing single-doc behavior.
- Prefix results with `[doc_id][kind]`.

## Special Handling
- When `--scope sections` and a doc has no sections, auto-fallback to chapters with warning tag.

## Backward Compatibility
- Existing invocations remain valid.
- `--include-chapters` retained as compatibility flag mapped to `--scope all`.
