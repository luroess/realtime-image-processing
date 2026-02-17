# Research Report: jan_contributions_bibtex

Date: 20260217
Category: Research
Type: Report
Label: jan_contributions_bibtex

## Context

- Requested: review all report sections and add valid BibTeX citations focused on Jan Duchscherer contributions.
- Reviewed sections:
  - `00_abstract.typ` through `10_conclusion.typ`
  - `report.typ` and shared macros.

## Objective

- Add source-backed citations for protocol, verification, grayscale/luma math, and control-path debouncing claims.
- Keep report compiling from both repository root and `docs/report/`.

## Notes

- Jan-owned or Jan-linked sections updated:
  - `03_verification_framework.typ`
  - `04_component_rgb2gray.typ`
  - `06_component_edge_overlay_and_control.typ`
- FAST theoretical section also received paper citations for algorithm claims.
- Added standalone bibliography file `docs/report/references.bib`.
- Section-by-section review outcome:
  - No structural Typst errors found.
  - Main quality gap was missing source attribution for standards/algorithms; addressed with citations.
  - Report compiles from both root and `docs/report`.

## Actions

1. Researched primary sources:
   - AMD UG934 (AXI4-Stream Video)
   - ITU-R BT.601-7 (luma coefficients)
   - cocotb stable docs (writing testbenches, timing model)
   - cocotbext-axi repository docs
   - Jack Ganssle debounce reference
   - FAST papers (ECCV 2006, TPAMI 2010)
2. Inserted inline citations across sections 02, 03, 04, 06, and 09.
3. Added bibliography emission at end of `docs/report/report.typ`.
4. Verified successful builds:
   - `typst compile --root . docs/report/report.typ docs/report/build/report.pdf`
   - `cd docs/report && typst compile report.typ build/report_from_report_dir.pdf`
