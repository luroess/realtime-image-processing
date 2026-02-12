"""Test layer: single-frame AXI4-Stream RGB passthrough verification."""

from __future__ import annotations

from pathlib import Path

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge
from drivers.axi_stream_driver import AxiStreamDriver
from models.image_model import Image
from monitors.axi_stream_monitor import AxiStreamMonitor
from verification.scoreboard import Scoreboard

TESTBENCH_ROOT = Path(__file__).resolve().parents[1]
S_AXIS_PREFIX = "s_axis_video"
M_AXIS_PREFIX = "m_axis_video"
RESET_ACTIVE_LEVEL = True


def _get_first_attr(dut, names: tuple[str, ...]):
    for name in names:
        if hasattr(dut, name):
            return getattr(dut, name)
    raise AttributeError(f"DUT has none of the expected signals: {', '.join(names)}")


async def apply_reset(dut, clk, rst, cycles: int = 5) -> None:
    rst.value = int(RESET_ACTIVE_LEVEL)
    getattr(dut, f"{S_AXIS_PREFIX}_tvalid").value = 0
    getattr(dut, f"{S_AXIS_PREFIX}_tdata").value = 0
    getattr(dut, f"{S_AXIS_PREFIX}_tlast").value = 0
    getattr(dut, f"{S_AXIS_PREFIX}_tuser").value = 0
    getattr(dut, f"{M_AXIS_PREFIX}_tready").value = 1

    for _ in range(cycles):
        await RisingEdge(clk)

    rst.value = int(not RESET_ACTIVE_LEVEL)
    await RisingEdge(clk)


async def run_frame_test(dut, image: Image, output_path: Path | None = None) -> None:
    clk = _get_first_attr(dut, ("clk", "i_clk"))
    rst = _get_first_attr(dut, ("rst", "i_rst_n"))

    rst.value = int(RESET_ACTIVE_LEVEL)
    getattr(dut, f"{S_AXIS_PREFIX}_tvalid").value = 0
    getattr(dut, f"{S_AXIS_PREFIX}_tdata").value = 0
    getattr(dut, f"{S_AXIS_PREFIX}_tlast").value = 0
    getattr(dut, f"{S_AXIS_PREFIX}_tuser").value = 0
    getattr(dut, f"{M_AXIS_PREFIX}_tready").value = 1

    cocotb.start_soon(Clock(clk, 10, unit="ns").start())
    await apply_reset(dut=dut, clk=clk, rst=rst)

    driver = AxiStreamDriver(dut=dut, i_clk=clk, i_rst_n=rst, prefix=S_AXIS_PREFIX)
    monitor = AxiStreamMonitor(
        dut=dut,
        i_clk=clk,
        i_rst_n=rst,
        width=image.width,
        height=image.height,
        prefix=M_AXIS_PREFIX,
    )
    scoreboard = Scoreboard()

    cocotb.start_soon(monitor.run())

    await driver.send_frame(image)
    min_timeout_ns = image.width * image.height * 40
    received_image = await monitor.get_frame(timeout_ns=max(200_000, min_timeout_ns))

    if output_path is not None:
        received_image.to_png(output_path)

    scoreboard.compare(expected=image, received=received_image)


@cocotb.test()
async def test_passthrough_single_frame(dut) -> None:
    await run_frame_test(dut=dut, image=Image.gradient(width=8, height=8))


@cocotb.test()
async def test_passthrough_image_file_roundtrip(dut) -> None:
    input_path = TESTBENCH_ROOT / "images" / "lenna_512_512.png"
    output_path = TESTBENCH_ROOT / "sim_build" / "lenna_512_512_out_rgb.png"
    image = Image.from_png(input_path)

    await run_frame_test(dut=dut, image=image, output_path=output_path)
