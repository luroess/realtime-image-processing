"""Test layer: Detect number of Button Clicks and activate different outputs based on count."""

from __future__ import annotations

from pathlib import Path

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.utils import get_sim_time

from drivers.axi_stream_driver import AxiStreamDriver
from models.image_model import Image
from monitors.axi_stream_monitor import AxiStreamMonitor
from verification.scoreboard import Scoreboard

TESTBENCH_ROOT = Path(__file__).resolve().parents[1]

# CONSTANTS
CLK_PERIOD_NS = 10           # 50 MHz
CLK_TIMER_MS = 10 # TODO: 500 ms
CLK_TIMER_NS = CLK_TIMER_MS * 1_000_000


async def apply_reset(dut, cycles: int = 5) -> None:
    dut.i_rst.value = 1
    dut.i_btn_debounced.value = 0

    for _ in range(cycles):
        await RisingEdge(dut.i_clk)

    dut.i_rst.value = 0
    await RisingEdge(dut.i_clk)

async def check_output(dut, expected_single_click, expected_double_click, wait_duration_ns):
    """
    Wait duration_ns and check that the debounced output is stable.
    """
    if wait_duration_ns != 0:
        await Timer(wait_duration_ns, unit="ns")
    if dut.o_single_click.value != expected_single_click:
        raise Exception(
            f"Single Click output mismatch! Expected {expected_single_click}, got {int(dut.o_single_click.value)}"
        )
    if dut.o_double_click.value != expected_double_click:
        raise Exception(
            f"Double Click output mismatch! Expected {expected_double_click}, got {int(dut.o_double_click.value)}"
        )

@cocotb.test()
async def test_single_click(dut) -> None:
    """Test Click Detection Logic for single click."""

    cocotb.start_soon(Clock(dut.i_clk, CLK_PERIOD_NS, unit="ns").start())
    await apply_reset(dut)

    dut.i_btn_debounced.value = '0'
    await check_output(dut, 0, 0, 100)

    dut.i_btn_debounced.value = '1'
    print(f"Button => 1: {get_sim_time(units='ns')} ns")
    await Timer(50, unit="ns")

    dut.i_btn_debounced.value = '0'
    print(f"Button => 0: {get_sim_time(units='ns')} ns")
    await Timer(CLK_TIMER_MS, unit="ms")
    await RisingEdge(dut.i_clk)
    await RisingEdge(dut.i_clk)
    dut.i_btn_debounced.value = '1'
    print(f"Check Ouput: {get_sim_time(units='ns')} ns")
    await check_output(dut, 1, 0, 0)




    

@cocotb.test()
async def test_double_click(dut) -> None:
    """Test Click Detection Logic for double click."""

    cocotb.start_soon(Clock(dut.i_clk, CLK_PERIOD_NS, unit="ns").start())
    await apply_reset(dut)

    dut.i_btn_debounced.value = '0'
    await check_output(dut, 0, 0, 100)

    dut.i_btn_debounced.value = '1'
    print(f"Button => 1: {get_sim_time(units='ns')} ns")
    await Timer(50, unit="ns")

    dut.i_btn_debounced.value = '0'
    await check_output(dut, 0, 0, 100)

    dut.i_btn_debounced.value = '1'
    print(f"Button => 1: {get_sim_time(units='ns')} ns")
    await Timer(50, unit="ns")

    dut.i_btn_debounced.value = '0'
    print(f"Button => 0: {get_sim_time(units='ns')} ns")
    await Timer(CLK_TIMER_MS, unit="ms")
    await RisingEdge(dut.i_clk)
    await RisingEdge(dut.i_clk)
    dut.i_btn_debounced.value = '1'
    print(f"Check Ouput: {get_sim_time(units='ns')} ns")
    await check_output(dut, 0, 1, 0)