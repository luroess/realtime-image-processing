"""Test layer: Detect number of Button Clicks and activate different outputs based on count."""

from __future__ import annotations

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.utils import get_sim_time

# CONSTANTS
CLK_PERIOD_NS = 10  # 100 MHz
CLK_TIMER_NS = 100  # 100 ns (10 cycles) for simulation


async def apply_reset(dut, cycles: int = 5) -> None:
    """Apply Reset"""
    dut.i_rst.value = 1
    dut.i_btn_debounced.value = 0

    for _ in range(cycles):
        await RisingEdge(dut.i_clk)

    dut.i_rst.value = 0
    await RisingEdge(dut.i_clk)

    await check_output(dut, 1, 0, 0, 10)


async def check_output(
    dut,
    expected_single_click,
    expected_double_click,
    expected_triple_click,
    wait_duration_ns,
    stable_duration_ns=0,
):
    """Wait duration_ns and check that the debounced output is stable."""
    print(f"Check Output: {get_sim_time(unit='ns')} ns")

    if wait_duration_ns != 0:
        await Timer(wait_duration_ns, unit="ns")
    if dut.o_single_click.value != expected_single_click:
        raise AssertionError(
            f"Single Click output mismatch! Expected {expected_single_click}, {expected_double_click}, {expected_triple_click} , got {int(dut.o_single_click.value)}, {int(dut.o_double_click.value)}, {int(dut.o_triple_click.value)}",
        )
    if dut.o_double_click.value != expected_double_click:
        raise AssertionError(
            f"Double Click output mismatch! Expected {expected_single_click}, {expected_double_click}, {expected_triple_click} , got {int(dut.o_single_click.value)}, {int(dut.o_double_click.value)}, {int(dut.o_triple_click.value)}",
        )
    if dut.o_triple_click.value != expected_triple_click:
        raise AssertionError(
            f"Double Click output mismatch! Expected {expected_single_click}, {expected_double_click}, {expected_triple_click} , got {int(dut.o_single_click.value)}, {int(dut.o_double_click.value)}, {int(dut.o_triple_click.value)}",
        )

    if stable_duration_ns != 0:
        await check_output(
            dut,
            expected_single_click,
            expected_double_click,
            expected_triple_click,
            stable_duration_ns,
        )


async def set_i_btn_debounced_value_and_wait(
    dut,
    i_btn_debounced_value,
    wait_duration,
    wait_duration_unit="ns",
):
    """Set Value for Button Debounced and wait for given time."""
    dut.i_btn_debounced.value = i_btn_debounced_value

    print(f"Button => {i_btn_debounced_value}: {get_sim_time(unit='ns')} ns")

    if wait_duration != 0:
        await Timer(wait_duration, unit=wait_duration_unit)


async def perform_clicks(dut, number_of_clicks):
    """Perform multiple clicks and validate outputs."""
    for i in range(number_of_clicks - 1):
        await set_i_btn_debounced_value_and_wait(dut, 1, 2 * CLK_PERIOD_NS)
        await set_i_btn_debounced_value_and_wait(dut, 0, 0)
        await check_output(dut, 1, 0, 0, 10)

    await set_i_btn_debounced_value_and_wait(dut, 1, 2 * CLK_PERIOD_NS)
    await set_i_btn_debounced_value_and_wait(dut, 0, CLK_TIMER_NS, "ns")


@cocotb.test()
async def test_single_click(dut) -> None:
    """Test Click Detection Logic for single click."""
    # --------------------------------------------------
    # Reset
    # --------------------------------------------------

    cocotb.start_soon(Clock(dut.i_clk, CLK_PERIOD_NS, unit="ns").start())
    await apply_reset(dut)

    # --------------------------------------------------
    # 1 Click
    # --------------------------------------------------
    await perform_clicks(dut, 1)

    await check_output(dut, 1, 0, 0, 10, 50)


@cocotb.test()
async def test_double_click(dut) -> None:
    """Test Click Detection Logic for double click."""
    # --------------------------------------------------
    # Reset
    # --------------------------------------------------

    cocotb.start_soon(Clock(dut.i_clk, CLK_PERIOD_NS, unit="ns").start())
    await apply_reset(dut)

    # --------------------------------------------------
    # 2 Clicks
    # --------------------------------------------------

    await perform_clicks(dut, 2)

    await check_output(dut, 1, 1, 0, 10, 50)


@cocotb.test()
async def test_triple_click(dut) -> None:
    """Test Click Detection Logic for triple click."""
    # --------------------------------------------------
    # Reset
    # --------------------------------------------------

    cocotb.start_soon(Clock(dut.i_clk, CLK_PERIOD_NS, unit="ns").start())
    await apply_reset(dut)

    # --------------------------------------------------
    # 3 Clicks
    # --------------------------------------------------

    await perform_clicks(dut, 3)

    await check_output(dut, 1, 1, 1, 10, 50)


@cocotb.test()
async def test_four_click_overflow(dut) -> None:
    """Test Click Detection Logic for four clicks (Overflow)."""
    # --------------------------------------------------
    # Reset
    # --------------------------------------------------

    cocotb.start_soon(Clock(dut.i_clk, CLK_PERIOD_NS, unit="ns").start())
    await apply_reset(dut)

    # --------------------------------------------------
    # 4 Clicks
    # --------------------------------------------------

    await perform_clicks(dut, 4)

    await check_output(dut, 1, 1, 1, 10, 50)


@cocotb.test()
async def test_single_click_then_double_click(dut) -> None:
    """Test Click Detection Logic for a single click, then pause, then double click."""
    # --------------------------------------------------
    # Reset
    # --------------------------------------------------

    cocotb.start_soon(Clock(dut.i_clk, CLK_PERIOD_NS, unit="ns").start())
    await apply_reset(dut)

    # --------------------------------------------------
    # Single Click
    # --------------------------------------------------

    print("Executing Single Click: ")
    await perform_clicks(dut, 1)

    await check_output(dut, 1, 0, 0, 10, 50)

    # --------------------------------------------------
    # Double Click
    # --------------------------------------------------

    print("Executing Double Click: ")
    await perform_clicks(dut, 2)

    await check_output(dut, 1, 1, 0, 10, 50)
