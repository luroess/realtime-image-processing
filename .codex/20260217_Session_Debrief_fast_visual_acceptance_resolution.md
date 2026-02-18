# Session Debrief: fast_visual_acceptance_resolution

Date: 20260217
Category: Session
Type: Debrief
Label: fast_visual_acceptance_resolution

## Context
- Prior FAST artifact acceptance reported protocol PASS while output images were visually sparse/non-interpretable.
- Affected artifacts:
  - `testbench/sim_build/test_axi_fast_filter/axi_fast_filter_axi_fastfilter/build/lenna_512_512_out_fast.png`
  - `testbench/sim_build/test_axi_filter_wrapper_fast/axi_filter_wrapper_fast_axi_filterwrapper/build/lenna_out_wrapper_fast.png`

## Objective
- Resolve artifact interpretability failure and ensure it is enforced by automated tests.

## Notes
- Root cause identified: Lenna path used top-left `128x128` crop with low texture, producing only `11` corners.
- Resolution approach:
  - switch Lenna crop to center crop in both FAST test modules,
  - add explicit visual acceptance assertions (corner ratio, interior ratio, border fraction),
  - re-run full FAST and wrapper FAST targets.

## Actions
- Changed files:
  - `testbench/tests/test_axi_fast_filter.py`
  - `testbench/tests/test_axi_filter_wrapper_fast.py`
  - `.codex/ISSUES.md`
  - `.codex/TODOS/20260217_fast_visual_acceptance_resolution.md`
  - `.codex/20260217_Session_Debrief_fast_visual_acceptance_resolution.md`
- Validation commands and outcomes:
  - `cd testbench && uv run tb-sim --target axi_fast_filter` => PASS (`7/7`)
  - `cd testbench && uv run tb-sim --target axi_filter_wrapper_fast` => PASS (`6/6`)
  - Artifact stats check (python image script): both Lenna outputs now `219/16384` corners (`1.3367%`), interior `153`, border `66`, border fraction `0.301370`.
- Open failures:
  - none in this resolution block.
