"""Test layer: Detect number of Button Clicks and activate different outputs based on count."""

from __future__ import annotations

import cocotb
from cocotb.clock import Clock
from drivers.click_detection_driver import ClickDetectionDriver

# CONSTANTS
CLK_PERIOD_NS = 10  # 100 MHz


@cocotb.test()
async def test_click_state_machine(dut) -> None:
    """Test BTN1 processing FSM and BTN2 base-image FSM in ClickDetector."""
    driver = ClickDetectionDriver(dut)

    # --------------------------------------------------
    # Reset
    # --------------------------------------------------

    cocotb.start_soon(Clock(dut.i_clk, CLK_PERIOD_NS, unit="ns").start())
    await driver.apply_reset()

    # --------------------------------------------------
    # BTN1: PASS_ALL -> BLUR -> SOBEL -> BLUR_SOBEL -> FAST -> PASS_ALL
    # --------------------------------------------------
    print("Transition to state ST_BLUR")
    await driver.transition_state_btn1(1)
    await driver.check_output(
        0,
        0,
        1,
        expected_pass_fast=1,
        expected_overlay_zeros=1,
        wait_duration_ns=10,
        stable_duration_ns=50,
    )

    print("Transition to state ST_SOBEL")
    await driver.transition_state_btn1(1)
    await driver.check_output(
        0,
        1,
        0,
        expected_pass_fast=1,
        expected_overlay_zeros=1,
        wait_duration_ns=10,
        stable_duration_ns=50,
    )

    # --------------------------------------------------
    # BTN2 is relevant in ST_SOBEL / ST_BLUR_SOBEL:
    # ZEROS -> BRAM_RGB -> BRAM_GRAY -> ZEROS
    # --------------------------------------------------
    print("Transition base mode to ST_BRAM_RGB")
    await driver.transition_state_btn2(1)
    await driver.check_output(
        1,
        1,
        0,
        expected_pass_fast=1,
        expected_overlay_zeros=0,
        wait_duration_ns=10,
        stable_duration_ns=50,
    )

    print("Transition base mode to ST_BRAM_GRAY")
    await driver.transition_state_btn2(1)
    await driver.check_output(
        0,
        1,
        0,
        expected_pass_fast=1,
        expected_overlay_zeros=0,
        wait_duration_ns=10,
        stable_duration_ns=50,
    )

    print("Transition base mode to ST_ZEROS")
    await driver.transition_state_btn2(1)
    await driver.check_output(
        0,
        1,
        0,
        expected_pass_fast=1,
        expected_overlay_zeros=1,
        wait_duration_ns=10,
        stable_duration_ns=50,
    )

    print("Transition to state ST_BLUR_SOBEL")
    await driver.transition_state_btn1(1)
    await driver.check_output(
        0,
        0,
        0,
        expected_pass_fast=1,
        expected_overlay_zeros=1,
        wait_duration_ns=10,
        stable_duration_ns=50,
    )

    print("Transition to state ST_FAST")
    await driver.transition_state_btn1(1)
    await driver.check_output(
        0,
        1,
        1,
        expected_pass_fast=0,
        expected_overlay_zeros=1,
        wait_duration_ns=10,
        stable_duration_ns=50,
    )

    print("Transition to state ST_PASS_ALL")
    await driver.transition_state_btn1(1)
    await driver.check_output(
        1,
        1,
        1,
        expected_pass_fast=1,
        expected_overlay_zeros=0,
        wait_duration_ns=10,
        stable_duration_ns=50,
    )

    # In ST_PASS_ALL, BTN2 toggles RGB passthrough <-> gray-as-RGB without zeros mode.
    print("BTN2 click in ST_PASS_ALL toggles to GRAY mode")
    await driver.transition_state_btn2(1)
    await driver.check_output(
        0,
        1,
        1,
        expected_pass_fast=1,
        expected_overlay_zeros=0,
        wait_duration_ns=10,
        stable_duration_ns=50,
    )
