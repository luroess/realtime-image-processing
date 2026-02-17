"""Testbench for VHDL Entity Debouncer"""

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from drivers.debouncing_driver import DebouncingDriver

CLK_PERIOD_NS = 10  # 100 MHz
DEBOUNCE_TIMER_NS = 100  # 100 ns (10 cycles) for simulation
DEBOUNCE_MARGIN_NS = 30
BOUNCE_NS = 20


@cocotb.test()
async def debouncer_test(dut):
    """Cocotb testbench for Debouncer with automatic checking"""
    driver = DebouncingDriver(dut=dut)

    # --------------------------------------------------
    # Clock generation
    # --------------------------------------------------
    cocotb.start_soon(Clock(dut.i_clk, CLK_PERIOD_NS, unit="ns").start())
    await driver.apply_reset()

    # --------------------------------------------------
    # Initial values
    # --------------------------------------------------
    await driver.set_i_btn_value_and_wait(0, 100)
    await driver.check_debounced(0, 0)

    # --------------------------------------------------
    # Simulated bouncing during press
    # Bounce pattern: 0/1/0/1/0/1
    # The debounced output should remain 0 during bouncing
    # --------------------------------------------------
    await driver.simulate_bouncing(0)

    # Check debounced output still 0 (bouncing hasn't stabilized)
    await driver.check_debounced(0, 0)

    # Now stable pressed
    await driver.set_i_btn_value_and_wait(1, 0)
    await driver.check_debounced(1, DEBOUNCE_TIMER_NS + DEBOUNCE_MARGIN_NS)

    # Keep stable pressed
    await Timer(DEBOUNCE_TIMER_NS, unit="ns")
    await driver.check_debounced(1, 0)

    # --------------------------------------------------
    # Bouncing during release
    # --------------------------------------------------
    await driver.simulate_bouncing(1)

    # Debounced output should still be 1 during bouncing
    await driver.check_debounced(1, 0)

    # Now stable released
    await driver.set_i_btn_value_and_wait(0, 0)
    await driver.check_debounced(0, DEBOUNCE_TIMER_NS + DEBOUNCE_MARGIN_NS)
