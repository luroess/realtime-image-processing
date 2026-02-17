"""Stimuli layer: AXI4-Stream gray8 source built on cocotbext-axi."""

from __future__ import annotations

import logging

from cocotbext.axi import AxiStreamBus, AxiStreamFrame, AxiStreamSource
from models.image_model import Image


class _KnownIdleAxiStreamSource(AxiStreamSource):
    """AxiStreamSource variant that avoids X-initialization on sidebands."""

    _init_x = False


class AxiGrayStreamSource:
    """Drive AXI4-Stream gray8 frames with SOF on TUSER and EOL on TLAST."""

    def __init__(
        self,
        dut,
        i_clk,
        i_rst_n,
        prefix: str = "s_axis_video",
        reset_active_level: bool = True,
    ) -> None:
        bus = AxiStreamBus.from_prefix(dut, prefix)
        self._source = _KnownIdleAxiStreamSource(
            bus=bus,
            clock=i_clk,
            reset=i_rst_n,
            reset_active_level=reset_active_level,
        )
        self._byte_lanes = int(self._source.byte_lanes)
        self._byte_size = int(self._source.byte_size)
        self._source.log.setLevel(logging.WARNING)
        self._drive_idle_known()

        if self._byte_size != 8:
            raise AssertionError(
                "AxiGrayStreamSource requires 8-bit AXI byte size; "
                f"got byte_size={self._byte_size}.",
            )
        if self._byte_lanes != 1:
            raise AssertionError(
                "AxiGrayStreamSource requires one byte lane for gray8; "
                f"got byte_lanes={self._byte_lanes}.",
            )

    def _drive_idle_known(self) -> None:
        self._source.bus.tdata.value = 0
        if hasattr(self._source.bus, "tlast"):
            self._source.bus.tlast.value = 0
        if hasattr(self._source.bus, "tuser"):
            self._source.bus.tuser.value = 0

    def _build_line_tuser(self, line_bytes_len: int, *, line_index: int) -> list[int]:
        if line_index != 0 or line_bytes_len == 0:
            return [0] * line_bytes_len
        return [1] + [0] * (line_bytes_len - 1)

    async def send_padding_pixels(self, count: int, value: int = 0) -> None:
        if count <= 0:
            return
        pixel = int(value) & 0xFF
        tdata = bytearray(pixel for _ in range(count))
        tuser = [0] * count
        await self._source.send(AxiStreamFrame(tdata=tdata, tuser=tuser))

    async def send_image(self, image: Image, *, tail_padding_pixels: int = 0) -> None:
        """Send one gray image (uses channel 0) as AXI4-Video line packets."""
        for y in range(image.height):
            line_bytes = bytearray(int(image.pixels[y, x, 0]) & 0xFF for x in range(image.width))
            tuser = self._build_line_tuser(len(line_bytes), line_index=y)
            await self._source.send(AxiStreamFrame(tdata=line_bytes, tuser=tuser))

        await self.send_padding_pixels(count=tail_padding_pixels, value=0)
        await self._source.wait()
        self._drive_idle_known()
