#import "../shared/macros.typ": repo_link

= Simulation Framework using cocotb and cocotbext-axi
The verification stack is organized as reusable source/sink/model/scoreboard layers in `testbench/` and executed through target registration in #repo_link("testbench/targets.toml", line: 1), with runner entrypoint #repo_link("testbench/sim/run.py", body: raw("testbench/sim/run.py"), line: 194).

#figure(
  table(
    columns: 3,
    table.header([Stimulus], [DUT], [Checks]),
    [`drivers/axis_*_source.py`], [RTL toplevel under `tb-sim --target ...`], [`monitors/axis_*_sink.py` + `verification/scoreboard.py`],
    [custom serialization to project AXI wire order], [AXI4-Stream video handshake + control], [golden reference comparison and protocol assertions],
  ),
  caption: [Testbench structure: Source (+ serialization) -> UUT -> Sink (+ deserialization) with scoreboard checks.],
) <tab-tb-architecture>

Framework elements aligned with cocotb timing/writing guidance:@cocotb-writing @cocotb-timing @cocotbext-axi
- deterministic reset/startup helper (`common/reset.py`),
- configurable backpressure generation (`common/pause.py`),
- typed AXI stream drivers and sinks for RGB and gray paths,
- per-target artifact generation (`results.xml`, `.ghw`/`.vcd`, output images).

Stress dimensions covered by active targets include:
- backpressure/stall robustness,
- reset and initialization transitions,
- frame-boundary correctness (`SOF`/`EOL`),
- mode/control transitions through button-driven FSM paths,
- timeout handling via cocotb `with_timeout` wrappers in sink APIs.

#figure(
  image("../figures/generated/fig_test_runtime_by_target.png", width: 82%),
  caption: [Stored runtime distribution by simulation target.],
) <fig-runtime>

#figure(
  image("../figures/generated/fig_testcase_count_by_module.png", width: 82%),
  caption: [Stored testcase distribution by module area.],
) <fig-testcount>
