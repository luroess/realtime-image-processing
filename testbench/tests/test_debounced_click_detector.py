"""Test layer: Execute combined test for debouncer and click detection."""

from __future__ import annotations

import cocotb
from cocotb.clock import Clock
from drivers.click_detection_driver import ClickDetectionDriver
from drivers.debouncing_driver import DebouncingDriver

# CONSTANTS
CLK_PERIOD_NS = 10  # 100 MHz
CLK_TIMER_NS = 140  # debounce + settling margin


@cocotb.test()
async def test_debounced_click_detection(dut) -> None:
    """Test debounced BTN1/BNT2 behavior through DebouncedClickDetector."""
    debouncing_driver = DebouncingDriver(dut)
    click_detection_driver = ClickDetectionDriver(dut)

    # --------------------------------------------------
    # Reset
    # --------------------------------------------------

    cocotb.start_soon(Clock(dut.i_clk, CLK_PERIOD_NS, unit="ns").start())
    await debouncing_driver.apply_reset()
    await click_detection_driver.check_output(
        1, 1, 1, expected_overlay_zeros=0, wait_duration_ns=20
    )

    async def click_btn0() -> None:
        await debouncing_driver.simulate_bouncing(0)
        await debouncing_driver.set_i_btn_value_and_wait(1, CLK_TIMER_NS)
        await debouncing_driver.check_debounced(1, 0)
        await debouncing_driver.set_i_btn_value_and_wait(0, CLK_TIMER_NS)
        await debouncing_driver.check_debounced(0, 0)

    async def click_btn1() -> None:
        await debouncing_driver.set_i_btn_value_and_wait(2, CLK_TIMER_NS)
        if int(dut.o_btn2_debounced.value) != 1:
            raise AssertionError(
                f"Debounced BTN2 mismatch! Expected 1, got {int(dut.o_btn2_debounced.value)}",
            )
        await debouncing_driver.set_i_btn_value_and_wait(0, CLK_TIMER_NS)
        if int(dut.o_btn2_debounced.value) != 0:
            raise AssertionError(
                f"Debounced BTN2 mismatch! Expected 0, got {int(dut.o_btn2_debounced.value)}",
            )

    # BTN2 base FSM in ST_PASS_ALL: RGB -> GRAY -> ZEROS.
    print("Transition base mode to ST_GRAY")
    await click_btn1()
    await click_detection_driver.check_output(
        0, 1, 1, expected_overlay_zeros=0, wait_duration_ns=20
    )

    print("Transition base mode to ST_ZEROS")
    await click_btn1()
    await click_detection_driver.check_output(
        0, 1, 1, expected_overlay_zeros=1, wait_duration_ns=20
    )

    # BTN1 processing FSM: PASS_ALL -> SOBEL.
    print("Transition to state ST_SOBEL")
    await click_btn0()
    await click_detection_driver.check_output(
        0, 1, 0, expected_overlay_zeros=1, wait_duration_ns=20
    )

    # BTN2 in ST_SOBEL: ZEROS -> RGB.
    print("Transition base mode to ST_RGB")
    await click_btn1()
    await click_detection_driver.check_output(
        1, 1, 0, expected_overlay_zeros=0, wait_duration_ns=20
    )

    # SOBEL -> BLUR_SOBEL.
    print("Transition to state ST_BLUR_SOBEL")
    await click_btn0()
    await click_detection_driver.check_output(
        1, 0, 0, expected_overlay_zeros=0, wait_duration_ns=20
    )

    # BTN2 in ST_BLUR_SOBEL: RGB -> GRAY.
    print("Transition base mode to ST_GRAY")
    await click_btn1()
    await click_detection_driver.check_output(
        0, 0, 0, expected_overlay_zeros=0, wait_duration_ns=20
    )

    # BLUR_SOBEL -> PASS_ALL.
    print("Transition to state ST_PASS_ALL")
    await click_btn0()
    await click_detection_driver.check_output(
        0, 1, 1, expected_overlay_zeros=0, wait_duration_ns=20
    )
