# FAST Visual Acceptance Resolution (2026-02-17)

## Problem
FAST artifact images are currently protocol-pass but visually non-interpretable (Issue 10 in `.codex/ISSUES.md`).

## Evidence baseline
- Affected outputs:
  - `testbench/sim_build/test_axi_fast_filter/axi_fast_filter_axi_fastfilter/build/lenna_512_512_out_fast.png`
  - `testbench/sim_build/test_axi_filter_wrapper_fast/axi_filter_wrapper_fast_axi_filterwrapper/build/lenna_out_wrapper_fast.png`
- Prior behavior: top-left `128x128` Lenna crop produced only `11` white pixels.

## Resolution status
1. `DONE` Use representative image region for artifact tests.
- Lenna was switched from top-left crop to center crop in:
  - `testbench/tests/test_axi_fast_filter.py`
  - `testbench/tests/test_axi_filter_wrapper_fast.py`

2. `DONE` Re-run FAST targets and measure interpretability.
- Commands:
  - `cd testbench && uv run tb-sim --target axi_fast_filter`
  - `cd testbench && uv run tb-sim --target axi_filter_wrapper_fast`
- Result: both targets pass (`7/7`, `6/6`).
- Regenerated outputs now show `219/16384` non-zero pixels (`1.3367%`) instead of `11/16384`.

3. `DONE` Add explicit visual acceptance guards.
- Lenna tests now assert:
  - minimum corner-density ratio,
  - minimum interior-corner ratio,
  - maximum border-corner fraction.
- OpenCV interior IoU check remains as optional compatibility signal.

## Follow-up
- Revisit acceptance thresholds if test geometry changes from the current `128x128` artifact resolution.
