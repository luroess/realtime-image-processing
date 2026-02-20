"""Transport layer: helper methods for click-detector stimuli and checks."""

from cocotb.triggers import FallingEdge, RisingEdge, Timer
from cocotb.utils import get_sim_time


class ClickDetectionDriver:
    def __init__(self, dut) -> None:
        self.dut = dut
        self.i_clk = dut.i_clk
        self.i_rst_n = dut.i_rst_n
        self.i_btn1 = getattr(dut, "i_btn_debounced", None)
        self.i_btn2 = getattr(dut, "i_btn2_debounced", None)

    async def apply_reset(self, cycles: int = 5) -> None:
        """Apply reset and validate reset outputs."""
        self.i_rst_n.value = 0
        if self.i_btn1 is not None:
            self.i_btn1.value = 0
        if self.i_btn2 is not None:
            self.i_btn2.value = 0

        for _ in range(cycles):
            await RisingEdge(self.i_clk)

        self.i_rst_n.value = 1
        await RisingEdge(self.i_clk)

        # Reset state: ST_PASS_ALL + base ST_ZEROS.
        await self.check_output(
            expected_pass_grayscale=0,
            expected_pass_blurr_filter=1,
            expected_pass_sobel=1,
            expected_pass_fast=1,
            expected_overlay_zeros=1,
            wait_duration_ns=10,
        )

    async def check_output(
        self,
        expected_pass_grayscale: int,
        expected_pass_blurr_filter: int,
        expected_pass_sobel: int,
        wait_duration_ns: int = 0,
        stable_duration_ns: int = 0,
        expected_pass_fast: int = 1,
        expected_overlay_zeros: int = 1,
    ) -> None:
        """Wait and check that outputs match expected values."""
        print(f"Check Output: {get_sim_time(unit='ns')} ns")

        if wait_duration_ns != 0:
            await Timer(wait_duration_ns, unit="ns")

        if int(self.dut.o_pass_grayscale.value) != expected_pass_grayscale:
            raise AssertionError(
                f"Pass Grayscale mismatch! Expected {expected_pass_grayscale}, got {int(self.dut.o_pass_grayscale.value)}",
            )
        if int(self.dut.o_pass_blurr_filter.value) != expected_pass_blurr_filter:
            raise AssertionError(
                f"Pass Blurr mismatch! Expected {expected_pass_blurr_filter}, got {int(self.dut.o_pass_blurr_filter.value)}",
            )
        if int(self.dut.o_pass_sobel.value) != expected_pass_sobel:
            raise AssertionError(
                f"Pass Sobel mismatch! Expected {expected_pass_sobel}, got {int(self.dut.o_pass_sobel.value)}",
            )
        if (
            hasattr(self.dut, "o_pass_fast")
            and int(self.dut.o_pass_fast.value) != expected_pass_fast
        ):
            raise AssertionError(
                f"Pass Fast mismatch! Expected {expected_pass_fast}, got {int(self.dut.o_pass_fast.value)}",
            )
        if (
            hasattr(self.dut, "o_overlay_zeros")
            and int(self.dut.o_overlay_zeros.value) != expected_overlay_zeros
        ):
            raise AssertionError(
                f"Overlay zeros mismatch! Expected {expected_overlay_zeros}, got {int(self.dut.o_overlay_zeros.value)}",
            )

        if stable_duration_ns != 0:
            await self.check_output(
                expected_pass_grayscale=expected_pass_grayscale,
                expected_pass_blurr_filter=expected_pass_blurr_filter,
                expected_pass_sobel=expected_pass_sobel,
                wait_duration_ns=stable_duration_ns,
                expected_pass_fast=expected_pass_fast,
                expected_overlay_zeros=expected_overlay_zeros,
            )

    async def transition_btn1_state(self, pulse_cycles: int = 1) -> None:
        """Generate one BTN1 edge for click FSM transition."""
        if self.i_btn1 is None:
            raise RuntimeError("DUT has no i_btn_debounced port")
        await FallingEdge(self.i_clk)
        self.i_btn1.value = 1
        for _ in range(pulse_cycles):
            await RisingEdge(self.i_clk)

        await FallingEdge(self.i_clk)
        self.i_btn1.value = 0
        await RisingEdge(self.i_clk)

    async def transition_btn2_state(self, pulse_cycles: int = 1) -> None:
        """Generate one BTN2 edge for base-mode FSM transition."""
        if self.i_btn2 is None:
            raise RuntimeError("DUT has no i_btn2_debounced port")
        await FallingEdge(self.i_clk)
        self.i_btn2.value = 1
        for _ in range(pulse_cycles):
            await RisingEdge(self.i_clk)

        await FallingEdge(self.i_clk)
        self.i_btn2.value = 0
        await RisingEdge(self.i_clk)
