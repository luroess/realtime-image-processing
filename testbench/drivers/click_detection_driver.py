"""Transport layer: self for sending button inputs."""

from __future__ import annotations

from cocotb.triggers import FallingEdge, RisingEdge, Timer
from cocotb.utils import get_sim_time


class ClickDetectionDriver:
    def __init__(self, dut) -> None:
        self.dut = dut
        self.i_clk = dut.i_clk
        self.i_rst_n = dut.i_rst_n
        self.i_btn1_debounced = getattr(dut, "i_btn_debounced", None)
        self.i_btn2_debounced = getattr(dut, "i_btn2_debounced", None)

    async def apply_reset(self, cycles: int = 5) -> None:
        """Apply Reset"""
        self.i_rst_n.value = 0
        if self.i_btn1_debounced is not None:
            self.i_btn1_debounced.value = 0
        if self.i_btn2_debounced is not None:
            self.i_btn2_debounced.value = 0

        for _ in range(cycles):
            await RisingEdge(self.i_clk)

        self.i_rst_n.value = 1
        await RisingEdge(self.i_clk)

        await self.check_output(
            0,
            1,
            1,
            expected_pass_fast=1,
            expected_overlay_zeros=1,
            wait_duration_ns=10,
        )

    async def check_output(
        self,
        expected_pass_grayscale: int,
        expected_pass_blurr_filter: int,
        expected_pass_sobel: int,
        *,
        expected_pass_fast: int | None = None,
        expected_overlay_zeros: int | None = None,
        wait_duration_ns: int = 0,
        stable_duration_ns: int = 0,
    ) -> None:
        """Wait duration_ns and check that the debounced output is stable."""
        print(f"Check Output: {get_sim_time(unit='ns')} ns")

        if wait_duration_ns != 0:
            await Timer(wait_duration_ns, unit="ns")
        if self.dut.o_pass_grayscale.value != expected_pass_grayscale:
            raise AssertionError(
                f"Pass Grayscale is not correct! Expected {expected_pass_grayscale} , got {int(self.dut.o_pass_grayscale.value)}",
            )
        if self.dut.o_pass_blurr_filter.value != expected_pass_blurr_filter:
            raise AssertionError(
                f"Pass Blurr is not correct! Expected {expected_pass_blurr_filter} , got {int(self.dut.o_pass_blurr_filter.value)}",
            )
        if self.dut.o_pass_sobel.value != expected_pass_sobel:
            raise AssertionError(
                f"Pass Sobel is not correct! Expected {expected_pass_sobel} , got {int(self.dut.o_pass_sobel.value)}",
            )

        if (
            expected_pass_fast is not None
            and int(self.dut.o_pass_fast.value) != expected_pass_fast
        ):
            raise AssertionError(
                f"Pass FAST is not correct! Expected {expected_pass_fast}, got {int(self.dut.o_pass_fast.value)}",
            )

        if (
            expected_overlay_zeros is not None
            and int(self.dut.o_overlay_zeros.value) != expected_overlay_zeros
        ):
            raise AssertionError(
                f"Overlay zeros is not correct! Expected {expected_overlay_zeros}, got {int(self.dut.o_overlay_zeros.value)}",
            )

        if stable_duration_ns != 0:
            await self.check_output(
                expected_pass_grayscale,
                expected_pass_blurr_filter,
                expected_pass_sobel,
                expected_pass_fast=expected_pass_fast,
                expected_overlay_zeros=expected_overlay_zeros,
                wait_duration_ns=stable_duration_ns,
            )

    async def transistion_state(
        self,
        pulse_cycles: int = 1,
    ) -> None:
        """Backward-compatible alias for BTN1 transition."""
        await self.transition_state_btn1(pulse_cycles=pulse_cycles)

    async def transition_state_btn1(
        self,
        pulse_cycles: int = 1,
    ) -> None:
        """Transition BTN1 FSM by pulsing i_btn_debounced."""
        if self.i_btn1_debounced is None:
            raise RuntimeError("i_btn_debounced is not available on this DUT")

        await FallingEdge(self.i_clk)
        self.i_btn1_debounced.value = 1
        for _ in range(pulse_cycles):
            await RisingEdge(self.i_clk)

        await FallingEdge(self.i_clk)
        self.i_btn1_debounced.value = 0
        await RisingEdge(self.i_clk)

    async def transition_state_btn2(
        self,
        pulse_cycles: int = 1,
    ) -> None:
        """Transition BTN2 base-image FSM by pulsing i_btn2_debounced."""
        if self.i_btn2_debounced is None:
            raise RuntimeError("i_btn2_debounced is not available on this DUT")

        await FallingEdge(self.i_clk)
        self.i_btn2_debounced.value = 1
        for _ in range(pulse_cycles):
            await RisingEdge(self.i_clk)

        await FallingEdge(self.i_clk)
        self.i_btn2_debounced.value = 0
        await RisingEdge(self.i_clk)
