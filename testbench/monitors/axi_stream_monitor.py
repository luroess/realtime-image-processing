"""Transport layer: AXI4-Stream sink monitor with frame reconstruction."""

from __future__ import annotations

import numpy as np
from cocotb.queue import Queue
from cocotb.triggers import RisingEdge, SimTimeoutError, with_timeout

from models.image_model import Image


class AxiStreamMonitor:
    def __init__(self, dut, clk, rst, width: int, height: int, prefix: str = "m_axis") -> None:
        self.dut = dut
        self.clk = clk
        self.rst = rst
        self.width = width
        self.height = height

        self.tvalid = getattr(dut, f"{prefix}_tvalid")
        self.tready = getattr(dut, f"{prefix}_tready")
        self.tdata = getattr(dut, f"{prefix}_tdata")
        self.tlast = getattr(dut, f"{prefix}_tlast")
        self.tuser = getattr(dut, f"{prefix}_tuser")

        self._frames: Queue[Image] = Queue()

    @staticmethod
    def _unpack_rgb(word: int) -> tuple[int, int, int]:
        r = (word >> 16) & 0xFF
        g = (word >> 8) & 0xFF
        b = word & 0xFF
        return (r, g, b)

    async def run(self) -> None:
        in_frame = False
        pixels: list[tuple[int, int, int]] = []
        line_pixels = 0

        while True:
            await RisingEdge(self.clk)

            if int(self.rst.value) == 1:
                in_frame = False
                pixels = []
                line_pixels = 0
                continue

            if int(self.tvalid.value) != 1 or int(self.tready.value) != 1:
                continue

            if int(self.tuser.value) == 1:
                in_frame = True
                pixels = []
                line_pixels = 0

            if not in_frame:
                continue

            pixels.append(self._unpack_rgb(int(self.tdata.value)))
            line_pixels += 1

            if int(self.tlast.value) == 1:
                if line_pixels != self.width:
                    self.dut._log.warning(
                        "Monitor saw line with %d pixels, expected %d", line_pixels, self.width
                    )
                line_pixels = 0

            if len(pixels) == self.width * self.height:
                frame = np.asarray(pixels, dtype=np.uint8).reshape(self.height, self.width, 3)
                await self._frames.put(Image(frame))
                in_frame = False

    async def get_frame(self, timeout_ns: int = 100_000) -> Image:
        try:
            return await with_timeout(self._frames.get(), timeout_ns, "ns")
        except SimTimeoutError as exc:
            raise AssertionError(f"Timed out waiting for output frame ({timeout_ns} ns)") from exc
