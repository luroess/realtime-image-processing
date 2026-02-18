# Issue Log

Last updated: 2026-02-17

## Goal

Keep the active FPGA video pipeline correct and testable:
`RGB -> Grayscale -> 3x3 Line Buffer/Window -> Sobel (Gx/Gy) -> Threshold`.

## Heavy Stress Test Snapshot

Commands used:

```bash
cd testbench
uv sync
uv run tb-sim --list-targets
timeout 240s uv run tb-sim --target <target>
```

```bash
cd /tmp/ghdl-rtl-check
ghdl -a --std=08 <all rtl/**/*.vhd>
ghdl -e --std=08 <each top entity>
```

Target outcomes:

- `example_passthrough`: PASS
- `test_example`: FAIL (timeout, rc=124)
- `axi_rgb_to_grayscale`: PASS
- `window_generator`: PASS
- `test_debouncer`: PASS
- `test_click_detector`: PASS
- `test_debounced_click_detector`: FAIL (build/elab error)
- `axi_sobel_filter`: PASS
- `axi_filter_wrapper`: PASS

Full RTL compile/elaboration with ordered `ghdl` sources: PASS.

## Latest full-target sweep (2026-02-17)

Commands used:

```bash
cd testbench
uv run tb-sim --list-targets
timeout 240s uv run tb-sim --target <each registered target>
```

Outcome:
- PASS (11): `axi_edge_overlay_pipeline`, `axi_fast_filter`, `axi_filter_wrapper`, `axi_rgb_to_grayscale`, `axi_sobel_filter`, `example_passthrough`, `test_click_detector`, `test_debounced_click_detector`, `test_debouncer`, `test_example`, `window_generator`
- FAIL (2): `axi_filter_wrapper_fast`, `axi_filter_wrapper_stress`

Current blocking root cause for the two failures:
- `rtl/FAST_FILTER/hdl/fast_core.vhd:45` -> syntax error (`missing ";" at end of object declaration`).

## Confirmed Issues

1. `CRITICAL`: Legacy AXI stream driver blocks forever after reset deassertion.
- Evidence: `testbench/drivers/axi_stream_driver.py:37` waits while `i_rst_n == 1`.
- Repro: `timeout 240s uv run tb-sim --target test_example` timed out at first test.
- Impact: `tests.test_example` cannot drive any frame traffic.

2. `HIGH`: `test_debounced_click_detector` target is missing `Debouncer` source dependency.
- Evidence: `testbench/targets.toml:49` includes only `rtl/CLICK_DETECTOR/hdl/*.vhd`.
- Dependency: `rtl/CLICK_DETECTOR/hdl/debounced_click_detector.vhd:27` instantiates `work.Debouncer`.
- Observed error: `unit "debouncer" not found in library "top"` during GHDL elaboration.

3. `HIGH`: Reset polarity semantics are inconsistent despite `_n` naming.
- `rtl/EXAMPLE_PASSTHROUGH/hdl/example_passthrough.vhd:26` treats `i_rst_n='1'` as reset-active.
- `rtl/DEBOUNCER/hdl/debouncing.vhd:33` and `rtl/CLICK_DETECTOR/hdl/click_detection.vhd:32` treat `i_rst_n='0'` as reset-active.
- Impact: integration/testbench confusion and latent deadlocks/false failures when reset helpers are reused.

4. `HIGH`: `window_generator` is parameterized as generic `G_KERNEL_SIZE` but implementation is hard-coded to 3x3 taps.
- Generic declaration: `rtl/WINDOW_GENERATOR/hdl/window_generator.vhd:10`.
- Hard-coded tap mapping: `rtl/WINDOW_GENERATOR/hdl/window_generator.vhd:227`.
- Impact: any `G_KERNEL_SIZE /= 3` configuration yields incorrect or partially unassigned window lanes.

5. `HIGH`: AXI handshake robustness risk in grayscale wrapper due `TVALID` depending on downstream `TREADY`.
- Evidence: `rtl/RGB_TO_GRAYSCALE/hdl/axi_rgb_to_grayscale.vhd:62` and `rtl/RGB_TO_GRAYSCALE/hdl/axi_rgb_to_grayscale.vhd:67`.
- Impact: can deadlock in ready-on-valid sink topologies and violates robust AXI stream design practice.

6. `MEDIUM`: Edge overlay wrapper uses tightly coupled dual-stream ready/valid gating.
- Evidence: `rtl/EDGE_OVERLAY/hdl/axi_edge_overlay.vhd:69` and `rtl/EDGE_OVERLAY/hdl/axi_edge_overlay.vhd:73`.
- Impact: any upstream source that is not independently valid-driven can stall lockstep progress.

7. `MEDIUM`: Legacy stream helper uses RGB packing order, while project video wire order is `R|B|G`.
- Pack path: `testbench/drivers/axi_stream_driver.py:34`.
- Unpack path: `testbench/monitors/axi_stream_monitor.py:30`.
- Impact: legacy tests can pass while silently validating the wrong byte-lane mapping.

8. `LOW`: Simulation-only pragma typo in edge overlay.
- Evidence: `rtl/EDGE_OVERLAY/hdl/axi_edge_overlay.vhd:86` uses `sythesis translate_off` (misspelled).
- Impact: tool-dependent handling of intended simulation-only assertion block.

9. `HIGH`: Direct RGB/edge branch integration can drift due line-buffer warm-up latency.
- Evidence: `uv run tb-sim --target axi_edge_overlay_pipeline` initially failed with `AxiEdgeOverlay: prolonged one-sided valid observed`.
- Root cause: Sobel path (`window_generator` warm-up) produced fewer beats than RGB branch without explicit flush/delay alignment.
- Mitigation landed:
  - Added RGB branch delay FIFO in `rtl/EDGE_OVERLAY_PIPELINE/hdl/axi_edge_overlay_pipeline.vhd`.
  - Added optional tail-padding traffic in `testbench/drivers/axis_video_source.py` and used it in `testbench/tests/test_axi_edge_overlay_pipeline.py`.
  - Post-fix repro: `uv run tb-sim --target axi_edge_overlay_pipeline` => PASS.

10. `RESOLVED`: FAST Lenna artifacts were sparse due non-representative crop plus missing visual acceptance gates.
- Root cause:
  - Lenna tests previously used top-left crop (`gray[:height, :width]`), which is low-feature and yielded only `11` corners.
  - Existing checks focused on protocol/oracle parity and did not gate visual corner density/distribution.
- Fix landed:
  - switched Lenna path to deterministic center crop in:
    - `testbench/tests/test_axi_fast_filter.py`
    - `testbench/tests/test_axi_filter_wrapper_fast.py`
  - added explicit visual acceptance assertions in both Lenna tests:
    - minimum corner ratio,
    - minimum interior-corner ratio,
    - maximum border-corner fraction.
- Evidence after fix:
  - regenerated artifacts:
    - `testbench/sim_build/test_axi_fast_filter/axi_fast_filter_axi_fastfilter/build/lenna_512_512_out_fast.png`
    - `testbench/sim_build/test_axi_filter_wrapper_fast/axi_filter_wrapper_fast_axi_filterwrapper/build/lenna_out_wrapper_fast.png`
  - both now report `219/16384` non-zero corners (`1.3367%`), with `153` interior corners and `66` border corners (`30.1%` border fraction).
  - regression re-run:
    - `cd testbench && uv run tb-sim --target axi_fast_filter` => PASS (`7/7`)
    - `cd testbench && uv run tb-sim --target axi_filter_wrapper_fast` => PASS (`6/6`)
- Residual risk:
  - acceptance thresholds are calibrated for current `128x128` artifact geometry and should be revisited if fixture resolution changes.

## FAST-9 + NMS Integration Findings (2026-02-17)

Note: protocol/regression PASS alone is not sufficient for quality sign-off; Lenna FAST tests now enforce additional visual acceptance checks from resolved Issue 10.

1. `RESOLVED`: `window_generator` generic hard-coding is removed; odd `G_KERNEL_SIZE >= 3` now works.
- Evidence:
  - `rtl/WINDOW_GENERATOR/hdl/window_generator.vhd` now uses generic KxK tap extraction and zero-padding loops.
  - Regression repro:
    - `cd testbench && uv run tb-sim --target window_generator` => PASS.
    - `cd testbench && uv run tb-sim --target axi_sobel_filter` => PASS.
    - `cd testbench && uv run tb-sim --target axi_filter_wrapper` => PASS.

2. `RESOLVED`: wrapper compile dependency on FAST unit for non-FAST targets.
- Root cause: `AXI_FilterWrapper` now directly instantiates `AXI_FastFilter` in a generate branch, so GHDL compile set must include FAST files even for `G_FILTER_SELECT=0`.
- Fix: added FAST RTL files to `axi_filter_wrapper` and `axi_filter_wrapper_stress` source lists in `testbench/targets.toml`.
- Repro before fix: `cd testbench && uv run tb-sim --target axi_filter_wrapper` failed with `unit "axi_fastfilter" not found`.
- Repro after fix: same command => PASS.

3. `VERIFIED`: FAST targets and stress wrappers are green.
- Target runs:
  - `cd testbench && uv run tb-sim --target axi_fast_filter` => PASS.
  - `cd testbench && uv run tb-sim --target axi_filter_wrapper_fast` => PASS.
  - `cd testbench && uv run tb-sim --target axi_filter_wrapper_stress` => PASS.
- Pipeline wrappers:
  - `cd testbench && uv run pytest pytest/test_pipeline_fast.py -m fast -q` => `1 passed`.
  - `cd testbench && uv run pytest pytest/test_pipeline_heavy.py -m heavy -q` => `1 passed`.

4. `VERIFIED`: waveform-level AXI behavior for FAST path and wrapper FAST path.
- VCD probe runs (single targeted backpressure tests with `--vcd`):
  - `probe_fast_filter.vcd` from `test_axi_fast_filter_checkerboard_backpressure_handshake`
  - `probe_wrapper_fast.vcd` from `test_axi_filter_wrapper_fast_backpressure_handshake_only`
- Observed metrics (parsed from VCD):
  - FAST filter:
    - accepted beats: input `16514`, score stream `16514`, NMS window output `16384`, final output `16384`.
    - first accepted input at cycle `11` (`100 ns`), first output at cycle `142` (`1410 ns`), warm-up latency `131` cycles.
    - framing: `SOF` count `1`, `TLAST` periodicity mismatches `0` for width `128`.
    - stalls: max READY-low run `3` cycles, payload changes while stalled `0`.
  - Wrapper FAST:
    - accepted beats: gray input `16514`, wrapper window stream `16514`, score stream `16514`, final output `16384`.
    - first accepted input at cycle `400` (`3990 ns`), first output at cycle `531` (`5300 ns`), warm-up latency `131` cycles.
    - framing: `SOF` count `1`, `TLAST` periodicity mismatches `0` for width `128`.
    - stalls: max READY-low run `1` cycle, payload changes while stalled `0`.
