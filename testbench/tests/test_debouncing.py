""" Testbench for VHDL Entity Debouncer """
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

CLK_PERIOD_NS = 10           # 100 MHz
DEBOUNCE_MS = 10
DEBOUNCE_NS = DEBOUNCE_MS * 1_000_000

async def apply_reset(dut, cycles: int = 5) -> None:
    """Apply Reset"""
    dut.i_rst.value = 1
    dut.i_btn.value = 0

    for _ in range(cycles):
        await RisingEdge(dut.i_clk)

    dut.i_rst.value = 0
    await RisingEdge(dut.i_clk)

    await check_debounced(dut, 0, 10)


async def check_debounced(dut, expected, duration_ns):
    """ Wait duration_ns and check that the debounced output is stable. """
    if duration_ns != 0:
        await Timer(duration_ns, unit="ns")
    if dut.o_btn_debounced.value != expected:
        raise AssertionError(
            f"Debounced output mismatch! Expected {expected}, got {int(dut.o_btn_debounced.value)}"
        )

async def set_i_btn_value_and_wait(dut, i_btn_value, wait_duration, wait_duration_unit='ns'):
    """ Set input button value and wait for defined time. """
    dut.i_btn.value = i_btn_value

    if wait_duration != 0:
        await Timer(wait_duration, unit=wait_duration_unit)


@cocotb.test()
async def debouncer_test(dut):
    """Cocotb testbench for Debouncer with automatic checking"""

    # --------------------------------------------------
    # Clock generation
    # --------------------------------------------------
    cocotb.start_soon(Clock(dut.i_clk, CLK_PERIOD_NS, unit="ns").start())
    await apply_reset(dut)

    # --------------------------------------------------
    # Initial values
    # --------------------------------------------------
    await set_i_btn_value_and_wait(dut, 0, 100)
    await check_debounced(dut, 0, 0)

    # --------------------------------------------------
    # Simulated bouncing during press
    # Bounce pattern: 0/1/0/1/0/1
    # The debounced output should remain 0 during bouncing
    # --------------------------------------------------
    await set_i_btn_value_and_wait(dut, 1, 200)
    await set_i_btn_value_and_wait(dut, 0, 150)
    await set_i_btn_value_and_wait(dut, 1, 180)
    await set_i_btn_value_and_wait(dut, 0, 120)
    await set_i_btn_value_and_wait(dut, 1, 160)

    # Check debounced output still 0 (bouncing hasn't stabilized)
    await check_debounced(dut, 0, 0)

    # Now stable pressed
    await set_i_btn_value_and_wait(dut, 1, 0)
    await check_debounced(dut, 1, DEBOUNCE_NS + 1_000_000)  # 11 ms

    # Keep stable pressed
    await Timer(10_000_000, unit="ns")  # 10 ms
    await check_debounced(dut, 1, 0)

    # --------------------------------------------------
    # Bouncing during release
    # --------------------------------------------------
    await set_i_btn_value_and_wait(dut, 0, 200)
    await set_i_btn_value_and_wait(dut, 1, 150)
    await set_i_btn_value_and_wait(dut, 0, 180)
    await set_i_btn_value_and_wait(dut, 1, 120)
    await set_i_btn_value_and_wait(dut, 0, 160)

    # Debounced output should still be 1 during bouncing
    await check_debounced(dut, 1, 1)

    # Now stable released
    await set_i_btn_value_and_wait(dut, 0, 0)
    await check_debounced(dut, 0, DEBOUNCE_NS + 1_000_000)  # 11 ms
