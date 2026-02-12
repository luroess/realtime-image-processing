import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
# from cocotb.result import SimFailure


async def check_debounced(dut, expected, duration_ns):
    """
    Wait duration_ns and check that the debounced output is stable.
    """
    if duration_ns != 0:
        await Timer(duration_ns, unit="ns")
    if dut.o_btn_debounced.value != expected:
        raise Exception(
            f"Debounced output mismatch! Expected {expected}, got {int(dut.o_btn_debounced.value)}"
        )


@cocotb.test()
async def debouncer_test(dut):
    """Cocotb testbench for Debouncer with automatic checking"""

    # --------------------------------------------------
    # Parameters
    # --------------------------------------------------
    CLK_PERIOD_NS = 20           # 50 MHz
    DEBOUNCE_MS = 10
    DEBOUNCE_NS = DEBOUNCE_MS * 1_000_000

    # --------------------------------------------------
    # Clock generation
    # --------------------------------------------------
    cocotb.start_soon(Clock(dut.i_clk, CLK_PERIOD_NS, unit="ns").start())

    # --------------------------------------------------
    # Initial values
    # --------------------------------------------------
    dut.i_btn.value = 0
    await Timer(100, unit="ns")
    await check_debounced(dut, 0, 0)

    # --------------------------------------------------
    # Simulated bouncing during press
    # Bounce pattern: 0/1/0/1/0/1
    # The debounced output should remain 0 during bouncing
    # --------------------------------------------------
    dut.i_btn.value = 1
    await Timer(200, unit="ns")
    dut.i_btn.value = 0
    await Timer(150, unit="ns")
    dut.i_btn.value = 1
    await Timer(180, unit="ns")
    dut.i_btn.value = 0
    await Timer(120, unit="ns")
    dut.i_btn.value = 1
    await Timer(160, unit="ns")

    # Check debounced output still 0 (bouncing hasn't stabilized)
    await check_debounced(dut, 0, 0)

    # Now stable pressed
    dut.i_btn.value = 1
    # Wait for debounce time + a little margin
    await check_debounced(dut, 1, DEBOUNCE_NS + 1_000_000)  # 11 ms

    # Keep stable pressed
    await Timer(10_000_000, unit="ns")  # 10 ms
    await check_debounced(dut, 1, 0)

    # --------------------------------------------------
    # Bouncing during release
    # --------------------------------------------------
    dut.i_btn.value = 0
    await Timer(200, unit="ns")
    dut.i_btn.value = 1
    await Timer(150, unit="ns")
    dut.i_btn.value = 0
    await Timer(180, unit="ns")
    dut.i_btn.value = 1
    await Timer(120, unit="ns")
    dut.i_btn.value = 0
    await Timer(160, unit="ns")

    # Debounced output should still be 1 during bouncing
    await check_debounced(dut, 1, 1)

    # Now stable released
    dut.i_btn.value = 0
    await check_debounced(dut, 0, DEBOUNCE_NS + 1_000_000)  # 11 ms

    # --------------------------------------------------
    # End simulation
    # --------------------------------------------------
    await Timer(5_000_000, unit="ns")  # 5 ms
    dut._log.info("Simulation completed successfully")
