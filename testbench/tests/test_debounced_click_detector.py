"""Test layer: Execute combined test for debouncer and click detection."""

from __future__ import annotations

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import FallingEdge, RisingEdge, Timer
from cocotb.utils import get_sim_time

from drivers.debouncing_driver import DebouncingDriver
from drivers.click_detection_driver import ClickDetectionDriver


# CONSTANTS
CLK_PERIOD_NS = 10  # 100 MHz
CLK_TIMER_NS = 100  # 100 ns (10 cycles) for simulation

@cocotb.test()
async def test_debounced_click_detection(dut) -> None:
    """Test debounced Click Detection."""
    i_clk = getattr(dut, "i_clk")
    i_rst = getattr(dut, 'i_rst_n')
    debouncing_driver = DebouncingDriver(dut)
    click_detection_driver = ClickDetectionDriver(dut)


    # --------------------------------------------------
    # Reset
    # --------------------------------------------------

    cocotb.start_soon(Clock(dut.i_clk, CLK_PERIOD_NS, unit="ns").start())
    await debouncing_driver.apply_reset()

    # --------------------------------------------------
    # Transition to ST_GRAYSCALE
    # --------------------------------------------------
    print(f"Transition to state ST_GRAYSCALE")
    await debouncing_driver.simulate_bouncing(0)
    await click_detection_driver.check_output(1, 1, 1, 0)
    await debouncing_driver.set_i_btn_value_and_wait(1, CLK_TIMER_NS)
    await click_detection_driver.check_output(0, 1, 1, 20)
    await debouncing_driver.simulate_bouncing(1)
    await debouncing_driver.set_i_btn_value_and_wait(0, CLK_TIMER_NS)
    await click_detection_driver.check_output(0, 1, 1, 20)

    # # --------------------------------------------------
    # # Transition to ST_BLURR
    # # --------------------------------------------------
    print(f"Transition to state ST_BLURR")
    await debouncing_driver.simulate_bouncing(0)
    await click_detection_driver.check_output(0, 1, 1, 0)
    await debouncing_driver.set_i_btn_value_and_wait(1, CLK_TIMER_NS)
    await click_detection_driver.check_output(0, 0, 1, 20)
    await debouncing_driver.simulate_bouncing(1)
    await debouncing_driver.set_i_btn_value_and_wait(0, CLK_TIMER_NS)
    await click_detection_driver.check_output(0, 0, 1, 20)

    # # --------------------------------------------------
    # # Transition to ST_SOBEL
    # # --------------------------------------------------
    print(f"Transition to state ST_SOBEL")
    await debouncing_driver.simulate_bouncing(0)
    await click_detection_driver.check_output(0, 0, 1, 0)
    await debouncing_driver.set_i_btn_value_and_wait(1, CLK_TIMER_NS)
    await click_detection_driver.check_output(0, 0, 0, 20)
    await debouncing_driver.simulate_bouncing(1)
    await debouncing_driver.set_i_btn_value_and_wait(0, CLK_TIMER_NS)
    await click_detection_driver.check_output(0, 0, 0, 20)

    # # --------------------------------------------------
    # # Transition to ST_PASSTHROUGH
    # # --------------------------------------------------
    print(f"Transition to state ST_PASSTHROUGH")
    await debouncing_driver.simulate_bouncing(0)
    await click_detection_driver.check_output(0, 0, 0, 0)
    await debouncing_driver.set_i_btn_value_and_wait(1, CLK_TIMER_NS)
    await click_detection_driver.check_output(1, 1, 1, 20)
    await debouncing_driver.simulate_bouncing(1)
    await debouncing_driver.set_i_btn_value_and_wait(0, CLK_TIMER_NS)
    await click_detection_driver.check_output(1, 1, 1, 20)
