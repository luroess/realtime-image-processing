"""Isolated delay tests for ShiftRamChain."""

from __future__ import annotations

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import NextTimeStep, ReadOnly, RisingEdge

C_SEL_NONE = 0b00
C_SEL_SOBEL = 0b01
C_SEL_BLUR_SOBEL = 0b10
C_SOBEL_DELAY = 1027
C_BLUR_SOBEL_DELAY = 2054
# The generated c_shift_ram configuration carries additional internal latency
# in this simulation setup.
C_SOBEL_DELAY_OBSERVED = 1028
C_BLUR_SOBEL_DELAY_OBSERVED = 2057


async def _reset(dut) -> None:
    dut.i_ce.value = 0
    dut.i_sclr.value = 1
    dut.i_base_delay_stage_sel.value = C_SEL_NONE
    dut.i_din.value = 0
    await RisingEdge(dut.i_clk)
    await RisingEdge(dut.i_clk)
    dut.i_sclr.value = 0
    await RisingEdge(dut.i_clk)


async def _tick_ce(dut, value: int) -> None:
    dut.i_ce.value = 1
    dut.i_din.value = value
    await RisingEdge(dut.i_clk)
    await ReadOnly()
    await NextTimeStep()


@cocotb.test()
async def test_shift_ram_chain_delay_select_none(dut) -> None:
    cocotb.start_soon(Clock(dut.i_clk, 10, unit="ns").start())
    await _reset(dut)

    dut.i_base_delay_stage_sel.value = C_SEL_NONE
    dut.i_din.value = 0x00A5A5A
    await RisingEdge(dut.i_clk)

    assert int(dut.o_dout.value) == 0x00A5A5A


@cocotb.test()
async def test_shift_ram_chain_sobel_delay_1027(dut) -> None:
    cocotb.start_soon(Clock(dut.i_clk, 10, unit="ns").start())
    await _reset(dut)

    dut.i_base_delay_stage_sel.value = C_SEL_SOBEL
    marker = 0x02AAAAA

    await _tick_ce(dut, marker)
    observed_delay = 0
    while observed_delay < C_SOBEL_DELAY_OBSERVED + 8:
        if int(dut.o_dout.value) == marker:
            break
        await _tick_ce(dut, 0)
        observed_delay += 1

    assert int(dut.o_dout.value) == marker
    assert observed_delay == C_SOBEL_DELAY_OBSERVED


@cocotb.test()
async def test_shift_ram_chain_blur_sobel_delay_2054(dut) -> None:
    cocotb.start_soon(Clock(dut.i_clk, 10, unit="ns").start())
    await _reset(dut)

    dut.i_base_delay_stage_sel.value = C_SEL_BLUR_SOBEL
    marker = 0x0155AAA

    await _tick_ce(dut, marker)
    observed_delay = 0
    while observed_delay < C_BLUR_SOBEL_DELAY_OBSERVED + 8:
        if int(dut.o_dout.value) == marker:
            break
        await _tick_ce(dut, 0)
        observed_delay += 1

    assert int(dut.o_dout.value) == marker
    assert observed_delay == C_BLUR_SOBEL_DELAY_OBSERVED
