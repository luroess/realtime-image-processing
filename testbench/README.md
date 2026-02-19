# Testbench Framework

This folder contains a reusable cocotb verification base for AXI4-Video image-stream modules.
Current setup verifies RGB24 stream pixels with AXI wire format `TDATA[23:0] = R|B|G` (MSB to LSB), while Python models and scoreboards operate on `(R,G,B)` tuples.

## Structure

- `common/`: reset and pause helpers used by multiple tests.
- `drivers/`: reusable AXI traffic generators (`axis_video_source`, `axis_gray_source`, `axis_window_gray_source`, `axi_stream_driver`).
- `monitors/`: protocol-aware capture modules (`axis_video_sink`, `axis_gray_sink`, `axis_window_sink`, `axi_stream_monitor`).
- `models/`: image model and image file conversion.
- `verification/`: scoreboards and comparison logic.
- `tests/`: cocotb test cases mapped per DUT target.
- `sim/`: Python runner implementation (`tb-sim`, alias for `sim.run:main`).
- `targets.toml`: simulation target registry consumed by `tb-sim`.
- `sim_build/`: generated build artifacts, waveforms, and optional output images.

## RTL Component Layout

RTL is organized by component for Vivado IP packaging:

Components:
- `../rtl/RGB_TO_GRAYSCALE/hdl/*.vhd`
- `../rtl/WINDOW_GENERATOR/hdl/*.vhd`
- `../rtl/BLURR_FILTER/*.vhd`
- `../rtl/BLURR_WINDOW_MODULE/hdl/*.vhd`
- `../rtl/SOBEL_FILTER/*.vhd`
- `../rtl/SOBEL_WINDOW_MODULE/hdl/*.vhd`
Testing:
- `../rtl/PIPELINE/hdl/*.vhd`
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
cd testbench
uv sync
uv run tb-sim
```
`uv run tb-sim` without `--target` now executes all registered targets in sorted order.

### Target + DUT selection (recommended)

Use `testbench/targets.toml` (or `targets.toml` from `testbench/`) as the single source of truth for simulation targets.

```bash
uv run tb-sim --list-targets
uv run tb-sim --target example_passthrough
uv run tb-sim --target test_example
uv run tb-sim --target axi_rgb_to_grayscale
uv run tb-sim --target window_generator
uv run tb-sim --target axi_blurr_window_module
uv run tb-sim --target axi_sobel_filter
uv run tb-sim --target axi_sobel_window_module
uv run tb-sim --target axi_pipeline
uv run tb-sim --target test_debouncer
uv run tb-sim --target test_click_detector
uv run tb-sim --target test_debounced_click_detector
uv run tb-sim --toplevel example_passthrough
```

`--target` selects a single full config bundle (`sim`, `toplevel`, `test_module`, `sources`).
`--toplevel` overrides only the HDL toplevel entity/module while keeping the selected/default target.

No other CLI options are supported by design. Keep configuration in `testbench/targets.toml`.

### Add a new target

Add an entry in `testbench/targets.toml`:

```toml
[targets.my_block]
description = "AXI4-Video DUT target"
toplevel = "my_block_top"
test_module = "tests.test_my_block"
sources = ["rtl/MY_BLOCK/hdl/*.vhd"]
```

Then run:

```bash
uv run tb-sim --target my_block
```

For non-passthrough DUTs, set `test_module` to a DUT-specific cocotb module that computes the expected transformed output.
Signal names/prefixes are hard-coded inside each test module.

### Waveforms for Surfer
[Surfer install instructions](https://github.com/ripopov/surfer)

Wave dumps are configured via `waves` in `testbench/targets.toml` (default is enabled).

With `SIM=ghdl`, cocotb writes `<toplevel>.ghw` under:
`testbench/sim_build/<test_module>/<target_key>_<toplevel>/build/`

Example:

```bash
surfer testbench/sim_build/test_passthrough/example_passthrough_example_passthrough/build/example_passthrough.ghw
```

Result XML for each run is written in the same `.../build/` directory as waveform artifacts.

## Testbench Flow

1. `tests/test_example.py` creates source/sink endpoints.
2. `drivers/axis_video_source.py` drives AXI4-Video traffic via `cocotbext-axi`.
3. `monitors/axis_video_sink.py` captures AXI4-Video output and decodes AXI wire-order data into `(R,G,B)` tuples.
4. `verification/scoreboard.py` compares input and output pixels.
5. cocotb reports pass/fail in `results.xml` (and the PNG test also writes `sim_build/lenna_512_512_out_rgb.png`).
