"""Combined debouncer + mode-cycle tests for DebouncedClickDetector."""

from __future__ import annotations

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

CLK_PERIOD_NS = 10
DEBOUNCE_WAIT_NS = 140

BASE_RGB = 0b00
BASE_GRAY = 0b01
BASE_ZERO = 0b10

OVERLAY_NONE = 0b00
OVERLAY_FAST = 0b01
OVERLAY_SOBEL = 0b10


async def _press_button(dut, *, btn_mask: int) -> None:
    dut.i_btn.value = btn_mask
    await Timer(DEBOUNCE_WAIT_NS, unit="ns")
    dut.i_btn.value = 0
    await Timer(DEBOUNCE_WAIT_NS, unit="ns")


@cocotb.test()
async def test_debounced_click_detection(dut) -> None:
    """Cycle base and overlay modes via debounced button presses."""
    cocotb.start_soon(Clock(dut.i_clk, CLK_PERIOD_NS, unit="ns").start())

    dut.i_rst_n.value = 0
    dut.i_btn.value = 0
    for _ in range(5):
        await RisingEdge(dut.i_clk)

    dut.i_rst_n.value = 1
    for _ in range(3):
        await RisingEdge(dut.i_clk)

    assert int(dut.o_base_mode.value) == BASE_RGB
    assert int(dut.o_overlay_mode.value) == OVERLAY_NONE

    await _press_button(dut, btn_mask=0b0001)
    assert int(dut.o_base_mode.value) == BASE_GRAY
    assert int(dut.o_pass_grayscale.value) == 0

    await _press_button(dut, btn_mask=0b0001)
    assert int(dut.o_base_mode.value) == BASE_ZERO
    assert int(dut.o_pass_grayscale.value) == 1

    await _press_button(dut, btn_mask=0b0001)
    assert int(dut.o_base_mode.value) == BASE_RGB

    await _press_button(dut, btn_mask=0b0010)
    assert int(dut.o_overlay_mode.value) == OVERLAY_FAST
    assert int(dut.o_pass_sobel.value) == 1

    await _press_button(dut, btn_mask=0b0010)
    assert int(dut.o_overlay_mode.value) == OVERLAY_SOBEL
    assert int(dut.o_pass_sobel.value) == 0

    await _press_button(dut, btn_mask=0b0010)
    assert int(dut.o_overlay_mode.value) == OVERLAY_NONE

    await _press_button(dut, btn_mask=0b0001)
    await _press_button(dut, btn_mask=0b0010)
    assert int(dut.o_btn_debounced.value) == 0
