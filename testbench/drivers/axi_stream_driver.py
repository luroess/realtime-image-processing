"""Transport layer: AXI4-Stream source driver for one frame."""

from __future__ import annotations

from cocotb.triggers import RisingEdge
from models.image_model import Image


class AxiStreamDriver:
    def __init__(self, dut, clk, rst=None, prefix: str = "s_axis") -> None:
        self.dut = dut
        self.clk = clk
        self.rst = rst

        self.tvalid = getattr(dut, f"{prefix}_tvalid")
        self.tready = getattr(dut, f"{prefix}_tready")
        self.tdata = getattr(dut, f"{prefix}_tdata")
        self.tlast = getattr(dut, f"{prefix}_tlast")
        self.tuser = getattr(dut, f"{prefix}_tuser")

        self._drive_idle()

    def _drive_idle(self) -> None:
        self.tvalid.value = 0
        self.tdata.value = 0
        self.tlast.value = 0
        self.tuser.value = 0

    @staticmethod
    def _pack_rgb(pixel) -> int:
        r = int(pixel[0]) & 0xFF
        g = int(pixel[1]) & 0xFF
        b = int(pixel[2]) & 0xFF
        return (r << 16) | (g << 8) | b

    async def send_frame(self, image: Image) -> None:
        while self.rst is not None and int(self.rst.value) == 1:
            await RisingEdge(self.clk)

        for idx, pixel in enumerate(image.flat_pixels()):
            self.tvalid.value = 1
            self.tdata.value = self._pack_rgb(pixel)
            self.tuser.value = 1 if image.is_first_pixel(idx) else 0
            self.tlast.value = 1 if image.is_last_in_line(idx) else 0

            while True:
                await RisingEdge(self.clk)
                if int(self.tready.value) == 1:
                    break

        self._drive_idle()
        await RisingEdge(self.clk)
