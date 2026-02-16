"""Transport layer: self for sending button inputs."""

from cocotb.triggers import Timer, RisingEdge

BOUNCE_NS = 20

class DebouncingDriver:
    def __init__(self, dut) -> None:
        self.dut = dut
        self.i_clk = getattr(dut, 'i_clk')
        self.i_rst_n = getattr(dut, 'i_rst_n')
        self.i_btn = getattr(dut, "i_btn")


    async def set_i_btn_value_and_wait(self, i_btn_value, wait_duration, wait_duration_unit="ns") -> None:
        """Set input button value and wait for defined time."""
        self.i_btn.value = i_btn_value

        if wait_duration != 0:
            await Timer(wait_duration, unit=wait_duration_unit)

    async def apply_reset(self, cycles: int = 5) -> None:
        """Apply Reset"""
        self.i_rst_n.value = 0
        self.i_btn.value = 0

        for _ in range(cycles):
            await RisingEdge(self.dut.i_clk)

        self.i_rst_n.value = 1
        await RisingEdge(self.i_clk)

        await self.check_debounced(0, 10)

    async def check_debounced(self, expected, duration_ns):
        """Wait duration_ns and check that the debounced output is stable."""
        if duration_ns != 0:
            await Timer(duration_ns, unit="ns")
        if self.dut.o_btn_debounced.value != expected:
            raise AssertionError(
                f"Debounced output mismatch! Expected {expected}, got {int(self.dut.o_btn_debounced.value)}",
            )
        
    async def simulate_bouncing(self, expected):
        await self.set_i_btn_value_and_wait(1, BOUNCE_NS * 2)
        await self.check_debounced(expected, 0)
        await self.set_i_btn_value_and_wait(0, BOUNCE_NS * 3)
        await self.check_debounced(expected, 0)
        await self.set_i_btn_value_and_wait(1, BOUNCE_NS * 4)
        await self.check_debounced(expected, 0)
        await self.set_i_btn_value_and_wait(0, BOUNCE_NS)
        await self.check_debounced(expected, 0)
        await self.set_i_btn_value_and_wait(1, BOUNCE_NS)
    
