# Testbench Framework

This folder contains a minimal reusable verification base for FPGA image-stream modules.
Current setup verifies RGB24 AXI4-Stream pixels (`TDATA[23:0]` as `R:G:B`).

## Layers

- Transport layer: `drivers/axi_stream_driver.py`, `monitors/axi_stream_monitor.py`
- Image model layer: `models/image_model.py`
- Verification layer: `verification/scoreboard.py`
- Test layer: `tests/test_example.py`

## Setup

```bash
sudo apt update
sudo apt install -y ghdl make
pip install uv
```

## Run

```bash
uv sync
uv run make SIM=ghdl TOPLEVEL=example_passthrough
```

### Run a specific cocotb module:
```bash
uv run make SIM=ghdl TOPLEVEL=example_passthrough MODULE=tests.test_example
```

### Run one test only:
```bash
uv run make SIM=ghdl TOPLEVEL=example_passthrough COCOTB_TESTCASE=test_passthrough_single_frame
uv run make SIM=ghdl TOPLEVEL=example_passthrough COCOTB_TESTCASE=test_passthrough_image_file_roundtrip
```

## Testbench Flow

1. `tests/test_example.py` sends an RGB image into the DUT.
2. `monitors/axi_stream_monitor.py` captures the DUT output image.
3. `verification/scoreboard.py` compares input and output pixels.
4. cocotb reports pass/fail in `results.xml` (and the PNG test also writes `sim_build/lenna_512_512_out_rgb.png`).
