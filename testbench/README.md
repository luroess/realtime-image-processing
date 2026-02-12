# Testbench Framework

This folder contains a reusable cocotb verification base for AXI4-Video image-stream modules.
Current setup verifies RGB24 stream pixels (`TDATA[23:0]` as `R:G:B`) and uses `cocotbext-axi` for stream driving and capture.

## Structure

- `tests/`: cocotb test cases.
- `drivers/`: reusable traffic generators (AXI4-Video source + pause patterns).
- `monitors/`: protocol-aware capture modules (AXI4-Video sink).
- `models/`: image model and image I/O.
- `verification/`: scoreboards and comparison logic.
- `common/`: reset/startup helpers.
- `sim/`: Python runner (`tb-sim`, alias for `sim.run:main`) that compiles component RTL from `../rtl/<COMPONENT>/hdl`.

## RTL Component Layout

RTL is organized by component for Vivado IP packaging:

- `../rtl/AXI_RGB_TO_GRAY/hdl/*.vhd`
- `../rtl/EXAMPLE_PASSTHROUGH/hdl/*.vhd`

Each component should keep synthesizable HDL in its own `hdl/` subdirectory.

## Setup

```bash
sudo apt update
sudo apt install -y ghdl make
pip install uv
```
[Installation uv](https://docs.astral.sh/uv/getting-started/installation/)
[Installation GHDL](https://github.com/ghdl/ghdl)

## Run

```bash
uv sync
uv run tb-sim
```

### Target + DUT selection (recommended)

Use `sim/targets.toml` as the single source of truth for simulation targets.

```bash
uv run tb-sim --list-targets
uv run tb-sim --target test_example
uv run tb-sim --target example_passthrough
uv run tb-sim --toplevel example_passthrough
```

`--target` selects a full config bundle (`sim`, `component`, `toplevel`, `test_module`).
`--toplevel` overrides only the HDL toplevel entity/module while keeping the selected/default target.

No other CLI options are supported by design. Keep configuration in `sim/targets.toml`.

### Add a new target

Add an entry in `sim/targets.toml`:

```toml
[targets.my_block]
description = "AXI4-Video DUT target"
component = "MY_BLOCK"
toplevel = "my_block_top"
test_module = "tests.test_example"
```

Then run:

```bash
uv run tb-sim --target my_block
```

For non-passthrough DUTs, set `test_module` to a DUT-specific cocotb module that computes the expected transformed output.
Signal names/prefixes are hard-coded inside each test module.

### Waveforms for Surfer
[Surfer install instructions](https://github.com/ripopov/surfer)

Wave dumps are configured via `waves` in `sim/targets.toml` (default is enabled).

With `SIM=ghdl`, cocotb writes `<toplevel>.ghw` under:
`testbench/sim_build/<tb_name>/<component>_<toplevel>/run/`

Example:

```bash
surfer testbench/sim_build/test_example/example_passthrough_example_passthrough/run/example_passthrough.ghw
```

## Testbench Flow

1. `tests/test_example.py` creates source/sink endpoints.
2. `drivers/axis_video_source.py` drives AXI4-Video traffic via `cocotbext-axi`.
3. `monitors/axis_video_sink.py` captures AXI4-Video output via `cocotbext-axi`.
4. `verification/scoreboard.py` compares input and output pixels.
5. cocotb reports pass/fail in `results.xml` (and the PNG test also writes `sim_build/lenna_512_512_out_rgb.png`).
