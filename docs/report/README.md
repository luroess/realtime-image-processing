# Report Authoring Workflow (Typst)

The report source of truth is `docs/report/report.typ`.

## Source structure

- Main preamble and includes: `docs/report/report.typ`
- Section files: `docs/report/sections/*.typ`
- Generated analysis scripts: `docs/report/analysis/*.py` and `*.tcl`
- Generated data tables: `docs/report/data/*.csv` and `*.json`
- Generated figures: `docs/report/figures/generated/*`

## Build PDF

```bash
typst compile --root . docs/report/report.typ docs/report/build/report_revised.pdf
```

## Render PDF pages for visual review

Codex image attachment does not support SVG, so use PNG for iterative review.

```bash
pdftocairo -png docs/report/build/report_revised.pdf docs/report/build/report_revised_page
```

## Suggested review loop

1. Edit `docs/report/report.typ` or section files under `docs/report/sections/`.
2. Compile to PDF.
3. Render PDF pages to PNG.
4. Inspect page images for layout/citation/figure quality.
5. Repeat until clean.

## Figure format guidance

- Keep report figures in PNG/PDF for reliable rendering in both Typst and Codex inspection.
- If a source diagram exists as SVG, generate a PNG companion for review workflows.
- Timing SVGs generated from VCD should always have a PNG companion for report review.

## Data and figure generation helpers

- Extract utilization CSV/JSON from Vivado reports:

```bash
python3 docs/report/analysis/extract_resource_data.py
```

- Produce timing SVG from VCD:

```bash
python3 docs/report/analysis/render_vcd_timing_svg.py --help
```

- Run selected cocotb testcase and emit VCD:

```bash
python3 docs/report/analysis/run_target_with_vcd.py --help
```
