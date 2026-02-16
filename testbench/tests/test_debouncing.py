"""Testbench for VHDL Entity Debouncer"""

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

from drivers.debouncing_driver import DebouncingDriver

CLK_PERIOD_NS = 10  # 100 MHz
DEBOUNCE_TIMER_NS = 100  # 100 ns (10 cycles) for simulation
DEBOUNCE_MARGIN_NS = 30
BOUNCE_NS = 20


# async def apply_reset(dut, cycles: int = 5) -> None:
#     """Apply Reset"""
#     dut.i_rst_n.value = 0
#     dut.i_btn.value = 0

#     for _ in range(cycles):
#         await RisingEdge(dut.i_clk)

#     dut.i_rst_n.value = 1
#     await RisingEdge(dut.i_clk)

#     await check_debounced(dut, 0, 10)


# async def check_debounced(dut, expected, duration_ns):
#     """Wait duration_ns and check that the debounced output is stable."""
#     if duration_ns != 0:
#         await Timer(duration_ns, unit="ns")
#     if dut.o_btn_debounced.value != expected:
#         raise AssertionError(
#             f"Debounced output mismatch! Expected {expected}, got {int(dut.o_btn_debounced.value)}",
#         )


# async def set_i_btn_value_and_wait(
#     dut,
#     i_btn_value,
#     wait_duration,
#     wait_duration_unit="ns",
# ):
#     """Set input button value and wait for defined time."""
#     dut.i_btn.value = i_btn_value

#     if wait_duration != 0:
#         await Timer(wait_duration, unit=wait_duration_unit)


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
