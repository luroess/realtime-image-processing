# Testbench Framework

This folder contains a minimal reusable verification base for FPGA image-stream modules.

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

## Testbench Flow

1. The test (`tests/test_example.py`) builds an input image and sends it into the DUT over AXI
2. The monitor captures the DUT output frame
3. The scoreboard (`verification/scoreboard.py`) compares input vs output pixels
4. If everything matches, the test passes. If not, it fails at the first mismatch
5. cocotb writes the run result to `testbench/results.xml`
