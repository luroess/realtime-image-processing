# Research Report: VHDL Parsing Libraries

Date: 2026-02-17
Category: Research
Type: Report
Label: vhdl_parsing_libraries

## Scope
Compare practical Python options for extracting VHDL usage patterns for this repository.

## Options
- `pyVHDLParser`: strong VHDL semantics, style-analysis-friendly, optional dependency.
- `hdlConvertor`: broad HDL parsing support but heavier install/toolchain cost.
- `tree-sitter-vhdl`: fast syntax tree traversal, lighter semantics.
- Regex extractor: lowest friction, suitable for phase-1 pattern indexing.

## Recommendation
- Phase 1: implement regex backend for immediate portability and no extra dependency.
- Phase 2 hook: add optional `pyvhdlparser` backend via explicit switch and graceful fallback.

## Risks
- Regex misses deep AST cases and can produce false positives.

## Mitigation
- Keep rules targeted and transparent.
- Record exact matched line and text for auditability.
- Add backend abstraction to upgrade parser depth later.
