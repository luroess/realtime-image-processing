"""Test layer: single-frame AXI4-Stream passthrough verification."""

from __future__ import annotations

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge

from drivers.axi_stream_driver import AxiStreamDriver
from models.image_model import Image
from monitors.axi_stream_monitor import AxiStreamMonitor
from verification.scoreboard import Scoreboard


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


@cocotb.test()
async def test_passthrough_single_frame(dut) -> None:
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    await apply_reset(dut)

    image = Image.gradient(width=8, height=8)

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
    received_image = await monitor.get_frame(timeout_ns=200_000)

    scoreboard.compare(expected=image, received=received_image)
