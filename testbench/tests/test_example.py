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


async def apply_reset(dut, cycles: int = 5) -> None:
    dut.rst.value = 1
    dut.s_axis_tvalid.value = 0
    dut.s_axis_tdata.value = 0
    dut.s_axis_tlast.value = 0
    dut.s_axis_tuser.value = 0
    dut.m_axis_tready.value = 1

    for _ in range(cycles):
        await RisingEdge(dut.clk)

    dut.rst.value = 0
    await RisingEdge(dut.clk)


async def run_frame_test(dut, image: Image, output_path: Path | None = None) -> None:
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    await apply_reset(dut)

    driver = AxiStreamDriver(dut=dut, clk=dut.clk, rst=dut.rst, prefix="s_axis")
    monitor = AxiStreamMonitor(
        dut=dut,
        clk=dut.clk,
        rst=dut.rst,
        width=image.width,
        height=image.height,
        prefix="m_axis",
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
