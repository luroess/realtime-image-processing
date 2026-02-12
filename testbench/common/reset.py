"""Common reset and startup helpers for cocotb tests."""

from __future__ import annotations

from cocotb.triggers import RisingEdge


async def apply_reset(
    dut,
    clk,
    rst,
    cycles: int = 3,
    stream_input_prefix: str = "s_axis_video",
    reset_active_level: bool = True,
) -> None:
    rst.value = int(reset_active_level)

    getattr(dut, f"{stream_input_prefix}_tvalid").value = 0
    getattr(dut, f"{stream_input_prefix}_tdata").value = 0
    getattr(dut, f"{stream_input_prefix}_tlast").value = 0
    getattr(dut, f"{stream_input_prefix}_tuser").value = 0

    for _ in range(cycles):
        await RisingEdge(clk)

    rst.value = int(not reset_active_level)
    await RisingEdge(clk)
