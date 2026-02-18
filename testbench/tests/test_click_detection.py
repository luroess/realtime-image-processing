"""Test layer: Detect number of Button Clicks and activate different outputs based on count."""

from __future__ import annotations

import cocotb
from cocotb.clock import Clock
from drivers.click_detection_driver import ClickDetectionDriver

# CONSTANTS
CLK_PERIOD_NS = 10  # 100 MHz

@cocotb.test()
async def test_click_state_machine(dut) -> None:
    """Test Click Detection Logic."""
    driver = ClickDetectionDriver(dut)

    # --------------------------------------------------
    # Reset
    # --------------------------------------------------

    cocotb.start_soon(Clock(dut.i_clk, CLK_PERIOD_NS, unit="ns").start())
    await driver.apply_reset()

    # --------------------------------------------------
    # Transition to ST_GRAYSCALE
    # --------------------------------------------------
    print(f"Transition to state ST_GRAYSCALE")
    await driver.transistion_state(1)
    await driver.check_output(0, 1, 1, 10, 50)

    # --------------------------------------------------
    # Transition to ST_LOWPASS
    # --------------------------------------------------
    print(f"Transition to state ST_LOWPASS")
    await driver.transistion_state(1)
    await driver.check_output(0, 0, 1, 10, 50)

    # --------------------------------------------------
    # Transition to ST_SOBEL
    # --------------------------------------------------
    print(f"Transition to state ST_SOBEL")
    await driver.transistion_state(1)
    await driver.check_output(0, 0, 0, 10, 50)

    # --------------------------------------------------
    # Transition to ST_PASSTHROUGH
    # --------------------------------------------------
    print(f"Transition to state ST_PASSTHROUGH")
    await driver.transistion_state(1)
    await driver.check_output(1, 1, 1, 10, 50)
