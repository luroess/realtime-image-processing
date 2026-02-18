"""Transport layer: self for sending button inputs."""

from cocotb.triggers import FallingEdge, RisingEdge, Timer
from cocotb.utils import get_sim_time


class ClickDetectionDriver:
    def __init__(self, dut) -> None:
        self.dut = dut
        self.i_clk = getattr(dut, 'i_clk')
        self.i_rst_n = getattr(dut, 'i_rst_n')
        # self.i_btn_debounced = getattr(dut, "i_btn_debounced")

    async def apply_reset(self, cycles: int = 5) -> None:
        """Apply Reset"""
        self.i_rst_n.value = 0
        self.dut.i_btn_debounced.value = 0

        for _ in range(cycles):
            await RisingEdge(self.i_clk)

        self.i_rst_n.value = 1
        await RisingEdge(self.i_clk)

        await self.check_output(1, 1, 1, 10)


    async def check_output(
        self,
        expected_pass_grayscale,
        expected_pass_lowpass_filter,
        expected_pass_sobel,
        wait_duration_ns=0,
        stable_duration_ns=0,
    ):
        """Wait duration_ns and check that the debounced output is stable."""
        print(f"Check Output: {get_sim_time(unit='ns')} ns")

        if wait_duration_ns != 0:
            await Timer(wait_duration_ns, unit="ns")
        if self.dut.o_pass_grayscale.value != expected_pass_grayscale:
            raise AssertionError(
                f"Pass Grayscale is not correct! Expected {expected_pass_grayscale} , got {int(self.dut.o_pass_grayscale.value)}",
            )
        if self.dut.o_pass_lowpass_filter.value != expected_pass_lowpass_filter:
            raise AssertionError(
                f"Pass Lowpass is not correct! Expected {expected_pass_lowpass_filter} , got {int(self.dut.o_pass_lowpass_filter.value)}",
            )
        if self.dut.o_pass_sobel.value != expected_pass_sobel:
            raise AssertionError(
                f"Pass Sobel is not correct! Expected {expected_pass_sobel} , got {int(self.dut.o_pass_sobel.value)}",
            )

        if stable_duration_ns != 0:
            await self.check_output(
                expected_pass_grayscale,
                expected_pass_lowpass_filter,
                expected_pass_sobel,
                stable_duration_ns,
            )


    async def transistion_state(
        self,
        pulse_cycles: int = 1,
    ):
        """Transition State by activating i_btn_debounced active for 1 cycle."""
        await FallingEdge(self.i_clk)
        self.dut.i_btn_debounced.value = 1
        for _ in range(pulse_cycles):
            await RisingEdge(self.i_clk)

        await FallingEdge(self.i_clk)
        self.dut.i_btn_debounced.value = 0
        await RisingEdge(self.i_clk)
