"""ClickDetector state-machine checks (BTN1 processing FSM + BTN2 base FSM)."""

from __future__ import annotations

import cocotb
from cocotb.clock import Clock

from drivers.click_detection_driver import ClickDetectionDriver

CLK_PERIOD_NS = 10  # 100 MHz


@cocotb.test()
async def test_click_state_machine(dut) -> None:
    """Verify direct ClickDetector transitions and output controls."""
    driver = ClickDetectionDriver(dut)

    cocotb.start_soon(Clock(dut.i_clk, CLK_PERIOD_NS, unit="ns").start())
    await driver.apply_reset()

    # BTN2 base FSM in ST_PASS_ALL: ZEROS -> RGB -> GRAY -> ZEROS.
    await driver.transition_btn2_state()
    await driver.check_output(1, 1, 1, 10, 30, expected_pass_fast=1, expected_overlay_zeros=0)

    await driver.transition_btn2_state()
    await driver.check_output(0, 1, 1, 10, 30, expected_pass_fast=1, expected_overlay_zeros=0)

    await driver.transition_btn2_state()
    await driver.check_output(0, 1, 1, 10, 30, expected_pass_fast=1, expected_overlay_zeros=1)

    # BTN1 processing FSM: PASS_ALL -> BLUR.
    await driver.transition_btn1_state()
    await driver.check_output(0, 0, 1, 10, 30, expected_pass_fast=1, expected_overlay_zeros=1)

    # BTN2 is ignored in BLUR (forced ZEROS).
    await driver.transition_btn2_state()
    await driver.check_output(0, 0, 1, 10, 30, expected_pass_fast=1, expected_overlay_zeros=1)

    # BLUR -> SOBEL, then enable RGB base via BTN2.
    await driver.transition_btn1_state()
    await driver.check_output(0, 1, 0, 10, 30, expected_pass_fast=1, expected_overlay_zeros=1)

    await driver.transition_btn2_state()
    await driver.check_output(1, 1, 0, 10, 30, expected_pass_fast=1, expected_overlay_zeros=0)

    # SOBEL -> BLUR_SOBEL -> FAST -> PASS_ALL.
    await driver.transition_btn1_state()
    await driver.check_output(1, 0, 0, 10, 30, expected_pass_fast=1, expected_overlay_zeros=0)

    await driver.transition_btn1_state()
    await driver.check_output(1, 1, 1, 10, 30, expected_pass_fast=0, expected_overlay_zeros=0)

    await driver.transition_btn1_state()
    await driver.check_output(1, 1, 1, 10, 30, expected_pass_fast=1, expected_overlay_zeros=0)
