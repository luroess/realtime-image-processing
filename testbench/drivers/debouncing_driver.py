"""Transport layer: helper methods for driving button inputs."""

from cocotb.triggers import RisingEdge, Timer

BOUNCE_NS = 20


class DebouncingDriver:
    def __init__(self, dut) -> None:
        self.dut = dut
        self.i_clk = getattr(dut, "i_clk")
        self.i_rst_n = getattr(dut, "i_rst_n")
        self.i_btn = getattr(dut, "i_btn")

    def _btn_width(self) -> int:
        try:
            return len(self.i_btn)
        except TypeError:
            return 1

    def _read_btn_value(self) -> int:
        try:
            return int(self.i_btn.value)
        except ValueError:
            return 0

    def _debounced_signal(self, output_index: int = 0):
        if output_index == 0:
            return getattr(self.dut, "o_btn_debounced")
        if output_index == 1 and hasattr(self.dut, "o_btn2_debounced"):
            return getattr(self.dut, "o_btn2_debounced")
        raise AttributeError(f"Debounced output index {output_index} is not available on DUT")

    async def set_i_btn_value_and_wait(self, i_btn_value, wait_duration, wait_duration_unit="ns") -> None:
        """Set full button input value and wait."""
        self.i_btn.value = i_btn_value

        if wait_duration != 0:
            await Timer(wait_duration, unit=wait_duration_unit)

    async def set_button_value_and_wait(
        self,
        button_index: int,
        pressed: int,
        wait_duration: int,
        wait_duration_unit: str = "ns",
    ) -> None:
        """Set one button bit and wait while preserving other button bits."""
        width = self._btn_width()
        if width == 1:
            if button_index != 0:
                raise ValueError("Scalar i_btn supports only button_index=0")
            self.i_btn.value = 1 if pressed else 0
        else:
            current = self._read_btn_value()
            mask = 1 << button_index
            if pressed:
                current |= mask
            else:
                current &= ~mask
            self.i_btn.value = current

        if wait_duration != 0:
            await Timer(wait_duration, unit=wait_duration_unit)

    async def apply_reset(self, cycles: int = 5) -> None:
        """Apply reset and validate primary debounced output reset value."""
        self.i_rst_n.value = 0
        self.i_btn.value = 0

        for _ in range(cycles):
            await RisingEdge(self.dut.i_clk)

        self.i_rst_n.value = 1
        await RisingEdge(self.i_clk)

        await self.check_debounced(0, 10)

    async def check_debounced(self, expected, duration_ns, output_index: int = 0) -> None:
        """Wait and check selected debounced output."""
        if duration_ns != 0:
            await Timer(duration_ns, unit="ns")

        signal = self._debounced_signal(output_index)
        if int(signal.value) != expected:
            raise AssertionError(
                f"Debounced output[{output_index}] mismatch! Expected {expected}, got {int(signal.value)}"
            )

    async def simulate_bouncing(self, expected, button_index: int = 0, output_index: int = 0) -> None:
        """Apply bounce pattern on selected button and check output stability."""
        await self.set_button_value_and_wait(button_index, 1, BOUNCE_NS * 2)
        await self.check_debounced(expected, 0, output_index)
        await self.set_button_value_and_wait(button_index, 0, BOUNCE_NS * 3)
        await self.check_debounced(expected, 0, output_index)
        await self.set_button_value_and_wait(button_index, 1, BOUNCE_NS * 4)
        await self.check_debounced(expected, 0, output_index)
        await self.set_button_value_and_wait(button_index, 0, BOUNCE_NS)
        await self.check_debounced(expected, 0, output_index)
        await self.set_button_value_and_wait(button_index, 1, BOUNCE_NS)
