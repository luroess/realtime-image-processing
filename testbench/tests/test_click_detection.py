"""Test layer: Detect number of Button Clicks and activate different outputs based on count."""

from __future__ import annotations

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import FallingEdge, RisingEdge, Timer
from cocotb.utils import get_sim_time

# CONSTANTS
CLK_PERIOD_NS = 10  # 100 MHz
CLK_TIMER_NS = 100  # 100 ns (10 cycles) for simulation


async def apply_reset(dut, cycles: int = 5) -> None:
    """Apply Reset"""
    dut.i_rst_n.value = 0
    dut.i_btn_debounced.value = 0

    for _ in range(cycles):
        await RisingEdge(dut.i_clk)

    dut.i_rst_n.value = 1
    await RisingEdge(dut.i_clk)

    await check_output(dut, 1, 1, 1, 10)


async def check_output(
    dut,
    expected_pass_grayscale,
    expected_pass_lowpass_filter,
    expected_pass_sobel,
    wait_duration_ns=0,
    stable_duration_ns=0,
):
    """Wait duration_ns and check that the debounced output is stable."""
    print(f"Check Output: {get_sim_time(unit='ns')} ns")

    if wait_duration_ns != 0:
        await Timer(wait_duration_ns, unit="ns")
    if dut.o_pass_grayscale.value != expected_pass_grayscale:
        raise AssertionError(
            f"Pass Grayscale is not correct! Expected {expected_pass_grayscale} , got {int(dut.o_pass_grayscale.value)}",
        )
    if dut.o_pass_lowpass_filter.value != expected_pass_lowpass_filter:
        raise AssertionError(
            f"Pass Lowpass is not correct! Expected {expected_pass_lowpass_filter} , got {int(dut.o_pass_lowpass_filter.value)}",
        )
    if dut.o_pass_sobel.value != expected_pass_sobel:
        raise AssertionError(
            f"Pass Sobel is not correct! Expected {expected_pass_sobel} , got {int(dut.o_pass_sobel.value)}",
        )

    if stable_duration_ns != 0:
        await check_output(
            dut,
            expected_pass_grayscale,
            expected_pass_lowpass_filter,
            expected_pass_sobel,
            stable_duration_ns,
        )


async def transistion_state(
    dut,
    pulse_cycles: int = 1,
):
    """Transition State by activating i_btn_debounced active for 1 cycle."""
    await FallingEdge(dut.i_clk)
    dut.i_btn_debounced.value = 1
    for _ in range(pulse_cycles):
        await RisingEdge(dut.i_clk)

    await FallingEdge(dut.i_clk)
    dut.i_btn_debounced.value = 0
    await RisingEdge(dut.i_clk)


@cocotb.test()
async def test_click_state_machine(dut) -> None:
    """Test Click Detection Logic."""
    # --------------------------------------------------
    # Reset
    # --------------------------------------------------

    cocotb.start_soon(Clock(dut.i_clk, CLK_PERIOD_NS, unit="ns").start())
    await apply_reset(dut)

    # --------------------------------------------------
    # Transition to ST_GRAYSCALE
    # --------------------------------------------------
    print(f"Transition to state ST_GRAYSCALE")
    await transistion_state(dut, 1)
    await check_output(dut, 0, 1, 1, 10, 50)

    # --------------------------------------------------
    # Transition to ST_LOWPASS
    # --------------------------------------------------
    print(f"Transition to state ST_LOWPASS")
    await transistion_state(dut, 1)
    await check_output(dut, 0, 0, 1, 10, 50)

    # --------------------------------------------------
    # Transition to ST_SOBEL
    # --------------------------------------------------
    print(f"Transition to state ST_SOBEL")
    await transistion_state(dut, 1)
    await check_output(dut, 0, 0, 0, 10, 50)

    # --------------------------------------------------
    # Transition to ST_PASSTHROUGH
    # --------------------------------------------------
    print(f"Transition to state ST_PASSTHROUGH")
    await transistion_state(dut, 1)
    await check_output(dut, 1, 1, 1, 10, 50)



    