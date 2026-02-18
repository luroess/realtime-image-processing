# Verification Docs Index (AXI4-Stream + cocotb)

Use this when the task touches AXI video verification, cocotb testbenches, or cocotbext-axi drivers/monitors.

Context7 library IDs:
- cocotb stable docs: `/websites/cocotb_en_stable`
- cocotbext-axi docs: `/alexforencich/cocotbext-axi`

Required cocotb topics before editing tests:
- `writing_testbenches`
- `timing_model`
- clock/reset sequencing and trigger usage (`RisingEdge`, `ReadOnly`, `ReadWrite`, `Timer`, `ClockCycles`)
- assertions/timeouts (`with_timeout`, `SimTimeoutError`)
- regression/runner flow (`cocotb_tools.runner.get_runner`)

Required cocotbext-axi topics before editing tests:
- `AxiStreamBus.from_prefix`
- `AxiStreamSource`, `AxiStreamSink`, `AxiStreamFrame`
- sideband usage (`tuser`, `tlast`, `tkeep`, `tid`, `tdest`)
- source throttling and sink backpressure (`set_pause_generator`)
- transfer synchronization (`send`, `send_nowait`, `wait`, `recv`)

Best-practice checks:
- AXI4-Stream Video transfer acceptance is on rising `ACLK` with `READY`, `VALID`, `ACLKEN`, and `ARESETn` high.
- `TUSER[0]` is SOF; `TLAST` is EOL.
- SOF/EOL must stay aligned with corresponding accepted pixels under backpressure.
- AXI4-Stream video carries active pixels only.
- Guard waits with `with_timeout(...)`.
- Add no-stall, source-throttle, sink-backpressure, and mixed-stall tests.

Reference links:
- https://docs.cocotb.org/en/stable/writing_testbenches: cocotb testbench authoring model and structure.
- https://docs.cocotb.org/en/stable/timing_model: trigger semantics and simulator scheduling.
- https://docs.cocotb.org/en/stable/library_reference: APIs for clocks, triggers, logging, and utilities.
- https://docs.cocotb.org/en/stable/runner: regression and runner integration patterns.
- https://github.com/alexforencich/cocotbext-axi/blob/master/README.md: AXI stream driver/sink/frame usage patterns.
