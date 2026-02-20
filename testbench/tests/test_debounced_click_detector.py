"""Combined Debouncer + ClickDetector checks for BTN1/BTN2 behavior."""

from __future__ import annotations

import cocotb
from cocotb.clock import Clock

from drivers.click_detection_driver import ClickDetectionDriver
from drivers.debouncing_driver import DebouncingDriver

CLK_PERIOD_NS = 10   # 100 MHz
DEBOUNCE_WAIT_NS = 130


@cocotb.test()
async def test_debounced_click_detection(dut) -> None:
    """Validate debounced BTN1/BTN2 interaction with click-detection FSMs."""
    debouncing_driver = DebouncingDriver(dut)
    click_driver = ClickDetectionDriver(dut)

    cocotb.start_soon(Clock(dut.i_clk, CLK_PERIOD_NS, unit="ns").start())
    await debouncing_driver.apply_reset()

    # Reset state: ST_PASS_ALL + ST_ZEROS.
    await debouncing_driver.check_debounced(0, 0, output_index=0)
    await debouncing_driver.check_debounced(0, 0, output_index=1)
    await click_driver.check_output(
        0,
        1,
        1,
        wait_duration_ns=20,
        expected_pass_fast=1,
        expected_overlay_zeros=1,
    )

    # BTN1 click: PASS_ALL -> BLUR.
    await debouncing_driver.simulate_bouncing(0, button_index=0, output_index=0)
    await debouncing_driver.set_button_value_and_wait(0, 1, DEBOUNCE_WAIT_NS)
    await debouncing_driver.check_debounced(1, 0, output_index=0)
    await click_driver.check_output(0, 0, 1, 20, expected_pass_fast=1, expected_overlay_zeros=1)

    await debouncing_driver.simulate_bouncing(1, button_index=0, output_index=0)
    await debouncing_driver.set_button_value_and_wait(0, 0, DEBOUNCE_WAIT_NS)
    await debouncing_driver.check_debounced(0, 0, output_index=0)

    # BTN1 click: BLUR -> SOBEL.
    await debouncing_driver.simulate_bouncing(0, button_index=0, output_index=0)
    await debouncing_driver.set_button_value_and_wait(0, 1, DEBOUNCE_WAIT_NS)
    await debouncing_driver.check_debounced(1, 0, output_index=0)
    await click_driver.check_output(0, 1, 0, 20, expected_pass_fast=1, expected_overlay_zeros=1)

    await debouncing_driver.simulate_bouncing(1, button_index=0, output_index=0)
    await debouncing_driver.set_button_value_and_wait(0, 0, DEBOUNCE_WAIT_NS)
    await debouncing_driver.check_debounced(0, 0, output_index=0)

    # BTN2 click in SOBEL: ZEROS -> RGB.
    await debouncing_driver.simulate_bouncing(0, button_index=1, output_index=1)
    await debouncing_driver.set_button_value_and_wait(1, 1, DEBOUNCE_WAIT_NS)
    await debouncing_driver.check_debounced(1, 0, output_index=1)
    await click_driver.check_output(1, 1, 0, 20, expected_pass_fast=1, expected_overlay_zeros=0)

    await debouncing_driver.simulate_bouncing(1, button_index=1, output_index=1)
    await debouncing_driver.set_button_value_and_wait(1, 0, DEBOUNCE_WAIT_NS)
    await debouncing_driver.check_debounced(0, 0, output_index=1)

    # BTN1 click: SOBEL -> BLUR_SOBEL.
    await debouncing_driver.simulate_bouncing(0, button_index=0, output_index=0)
    await debouncing_driver.set_button_value_and_wait(0, 1, DEBOUNCE_WAIT_NS)
    await debouncing_driver.check_debounced(1, 0, output_index=0)
    await click_driver.check_output(1, 0, 0, 20, expected_pass_fast=1, expected_overlay_zeros=0)

    await debouncing_driver.simulate_bouncing(1, button_index=0, output_index=0)
    await debouncing_driver.set_button_value_and_wait(0, 0, DEBOUNCE_WAIT_NS)
    await debouncing_driver.check_debounced(0, 0, output_index=0)

    # BTN1 click: BLUR_SOBEL -> FAST.
    await debouncing_driver.simulate_bouncing(0, button_index=0, output_index=0)
    await debouncing_driver.set_button_value_and_wait(0, 1, DEBOUNCE_WAIT_NS)
    await debouncing_driver.check_debounced(1, 0, output_index=0)
    await click_driver.check_output(1, 1, 1, 20, expected_pass_fast=0, expected_overlay_zeros=0)

    await debouncing_driver.simulate_bouncing(1, button_index=0, output_index=0)
    await debouncing_driver.set_button_value_and_wait(0, 0, DEBOUNCE_WAIT_NS)
    await debouncing_driver.check_debounced(0, 0, output_index=0)
