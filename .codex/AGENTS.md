# AGENTS

## Project baseline

- Use `.external/FPGA-based-Sobel-Edge-Detection-Pipeline-with-VHDL-Simulation-Benchmark/README.md` as the Sobel reference flow.
- Core pipeline stays: `RGB -> Grayscale -> 3x3 Line Buffer/Window -> Sobel (Gx/Gy) -> Threshold`.
- Track active investigation findings in `.codex/ISSUES.md`.

## Heavy stress test mode (required when explicitly requested)

- Trigger: any explicit request for "heavy stress test", "super heavy testing", or equivalent.
- Sequence requirement: perform a first reasoning/evidence pass, then update `AGENTS.md`/docs with the resulting process updates.
- Required execution flow:
  - run `cd testbench && uv sync`
  - run `uv run tb-sim --list-targets`
  - run every target with bounded timeout (recommended `timeout 240s uv run tb-sim --target <name>`)
  - run ordered RTL compile/elaboration smoke checks with `ghdl -a` and `ghdl -e` over `rtl/**/*.vhd`
  - log failures and root causes in `.codex/ISSUES.md` with file/line evidence and repro command
- Temporary stress artifacts (scratch tests/logs) should stay outside tracked source paths unless explicitly requested to commit.

## Context snapshot workflow (required)

- Always run `make context` from repository root during initialization.
- Treat `make context` as a required init step before code exploration or edits.
- `make context` prints the current project context to stdout.
- The snapshot uses `tree` and includes:
  - docs markdown + figures under `docs/`,
  - markdown + VHDL under `rtl/`,
  - important Vivado/Vitis anchors (BD source, generated structural view, bitstream/handoff/launch metadata).

## Session bootstrap workflow (required)

- Start each new substantial task by reading:
  - `.codex/AGENTS.md`
  - `README.md`
  - `.codex/Questions.md`
  - relevant docs under `docs/` and references under `.codex/skills/fpga-vivado-vitis-structure/references/`
- Before deeper exploration or edits, create a new `.codex` note file using:
  - `python3 .codex/skills/fpga-vivado-vitis-structure/scripts/new_codex_note.py --category <Category> --type <Type> --label <unique_label>`
- Enforced filename format is:
  - `YYYYMMDD_<Category>_<Type>_<Label>.md`

## Local RTL source tree (required)

- The local `rtl/` directory is the primary source of truth for active RTL development.
- Prefer editing and reviewing modules under `rtl/` before using generated Vivado netlists or external reference code.
- Current local structure:
  - `rtl/EXAMPLE_PASSTHROUGH/hdl/example_passthrough.vhd`: AXI passthrough reference DUT.
  - `rtl/RGB_TO_GRAYSCALE/hdl/axi_rgb_to_grayscale.vhd`: AXI4-Stream wrapper for grayscale conversion.
  - `rtl/RGB_TO_GRAYSCALE/hdl/rgb_to_grayscale.vhd`: Core RGB to grayscale conversion logic.
  - `rtl/WINDOW_GENERATOR/hdl/window_generator.vhd`: Sliding window generator core.

## VHDL style (required)

- Prefixes: `i_`, `o_`, `s_`, `v_`, `P_`, `U_`, `G_`, `C_`, `*_t`.
- Casing: entities/packages `PascalCase`, architectures `A_Rtl|A_Sim|A_Tb`, enum literals `ST_*`.
- Active-low nets must use `_n` suffix.
- Use `ieee.numeric_std.all`; do not use `std_logic_arith`, `std_logic_unsigned`, `std_logic_signed`.
- Use explicit `unsigned`/`signed` conversions.
- Separate register and combinational logic into `P_REG_*` and `P_COMB_*`; split FSM state register and next-state logic.
- Refer to `.codex/vhdl-attributes.md` for attribute usage.

## Edit constraints

- Prefer minimal diffs and preserve existing interfaces unless change is required.
- Keep reset behavior explicit in every clocked process.
- For resolution changes, update line-buffer bounds and any paired conversion/testbench assumptions together.

## Commit workflow (required)

- For multi-block implementation tasks, create short conventional commits autonomously after each finished block.
- Preferred commit format: `<type>: <short summary>` with concise subjects, for example:
  - `feat: add global doc query scope`
  - `test: add regression checks for skill scripts`
  - `chore: run isort on testbench python`
- Do not squash unrelated blocks into one commit.

## Testbench workflow (required)

The `testbench` directory is the cocotb verification package for AXI4-Stream video RTL blocks in `rtl/`. Use it as the default validation entrypoint for Python-based simulation.

- `testbench/common/`: reset and pause helpers used across tests.
- `testbench/drivers/`: AXI stimuli sources (`axis_video_source`, `axis_kxk_source`, `axi_stream_driver`).
- `testbench/monitors/`: AXI sinks/monitors (`axis_video_sink`, `axis_window_sink`, `axis_kxk_sink`, `axi_stream_monitor`).
- `testbench/models/`: image data model and file conversion helpers.
- `testbench/verification/`: scoreboarding and expected-vs-observed comparisons.
- `testbench/tests/`: DUT-specific cocotb test modules.
- `testbench/sim/`: runner implementation (`sim.run:main`) for `tb-sim`.
- `testbench/targets.toml`: simulation target registry used by `tb-sim`.
- `testbench/sim_build/`: generated artifacts (waveforms, XML results, rendered output images).

Quickstart:

```bash
cd testbench
uv sync
uv run tb-sim --list-targets
uv run tb-sim --target example_passthrough
uv run tb-sim --target axi_rgb_to_grayscale
uv run tb-sim --target window_generator
```

- Supported runner CLI options are only `--list-targets`, `--target`, and `--toplevel`.
- Artifact locations: `testbench/sim_build/<test_module>/<target_key>_<toplevel>/build/results.xml` and `.../build/<toplevel>.ghw` (when waves are enabled).
- Current RGB24 AXI wire order for testbench video streams is `TDATA[23:0] = R|B|G`; Python image tuples and scoreboards compare pixels as `(R,G,B)`.
- For full operational detail and examples, see `testbench/README.md`.


## Cocotb docs workflow (required)

- Before changing any Cocotb Python testbench, query Context7 docs first.
- Resolved Context7 library ID for stable docs: `/websites/cocotb_en_stable`.
- Resolved Context7 library ID for cocotbext-axi docs: `/websites/deepwiki_alexforencich_cocotbext-axi`.
- Retrieve and align with at least these topics before implementation: `writing_testbenches`, `timing_model` (triggers), clock/reset sequencing, assertions/timeouts, and regression/runner flow.
- All interfaces must be typed.

## Documentation diagram docs workflow (required)

- Before creating or changing Mermaid-based documentation/presentation diagrams, query Context7 docs first.
- Resolved Context7 library ID for Mermaid docs: `/mermaid-js/mermaid`.
- Retrieve and align with at least these topics before implementation: `flowchart`, `sequenceDiagram`, `timeline`/`gantt`, `theme/init`, and slide readability constraints (node count, label length, orientation).

## AXI video protocol reference (required)

- Authoritative protocol reference: `amd-docs/ug934_axi_videoIP.pdf` (UG934).
- Persisted project summary: `docs/pl_video_stream.md`.
- Before changing AXI4-Stream video interfaces or pipeline framing, review both files.
- Non-negotiable protocol points:
  - `TUSER[0]` marks `SOF` and `TLAST` marks `EOL`.
  - Transfer only active pixels over AXI4-Stream video.
  - Do not encode periodic sync/blanking metadata in `TUSER` or pixel payload.

## External code references

```
╰─ tree .external -P "*.vhd" -I "*_Project"
.external
└── FPGA-based-Sobel-Edge-Detection-Pipeline-with-VHDL-Simulation-Benchmark
    ├── image_processor_top.vhd
    ├── line_buffer.vhd
    ├── rgb_to_gray.vhd
    ├── sobel_core.vhd
    └── tb_image_processor.vhd
```
