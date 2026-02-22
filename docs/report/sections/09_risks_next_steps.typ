= Risks and Open Gaps
Open issues tracked in `.codex/ISSUES.md` that still impact closure quality:
- click-detector expectation drift in a legacy-aligned test target,
- runtime sensitivity for full-size pipeline regressions,
- potential prefill deadlock scenarios requiring dedicated non-passthrough stress tests,
- synthesis portability sensitivity from `ShiftRamChain` dependency on packaged `c_shift_ram_0`,
- process bootstrap gaps (missing `.codex/Questions.md` and missing local `fpga-vivado-vitis-structure` skill manifest/script assets).

These are closure and reproducibility risks; they do not invalidate the passing focused evidence in this revision, but they should be resolved before final publication.

= Next Steps
1. Keep report source modular (`sections/*.typ`) and maintain command-backed evidence updates per revision.
2. Extend stress tests for overlay-mode prefill behavior with explicit deadlock-detection assertions.
3. Re-run full-pipeline regression with bounded wall-time budget and archive final artifact metrics.
4. Stabilize bootstrap/process assets referenced by AGENTS so required workflows are directly executable.
