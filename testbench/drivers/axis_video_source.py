"""Stimuli layer: AXI4-Video source built on cocotbext-axi."""

from __future__ import annotations

import logging

from cocotbext.axi import (  # type: ignore[missing-imports]
    AxiStreamBus,
    AxiStreamFrame,
    AxiStreamSource,
)
from models.image_model import Image


class _KnownIdleAxiStreamSource(AxiStreamSource):
    """AxiStreamSource variant that avoids X-initialization on non-handshake signals."""

    _init_x = False


class AxiVideoStreamSource:
    """Drive AXI4-Stream video frames with SOF on TUSER and EOL on TLAST."""

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

    def set_pause_generator(self, generator=None) -> None:
        """Apply optional TVALID throttling pattern."""
        self._source.set_pause_generator(generator)

    def _drive_idle_known(self) -> None:
        """Force deterministic idle values on source sideband/data outputs."""
        self._source.bus.tdata.value = 0
        if hasattr(self._source.bus, "tlast"):
            self._source.bus.tlast.value = 0
        if hasattr(self._source.bus, "tuser"):
            self._source.bus.tuser.value = 0

    def _validate_line_geometry(
        self,
        line_bytes_len: int,
        *,
        image_width: int,
        line_index: int,
    ) -> None:
        if self._byte_size != 8:
            raise AssertionError(
                "AxiVideoStreamSource currently requires an 8-bit AXI byte size; "
                f"got byte_size={self._byte_size}.",
            )

        if self._byte_lanes <= 0:
            raise AssertionError(
                f"AxiVideoStreamSource detected invalid AXI byte lane count: {self._byte_lanes}.",
            )

        if line_bytes_len % self._byte_lanes != 0:
            raise AssertionError(
                "AXI4-Stream line byte count must align to beat size when tkeep is not modeled: "
                f"line={line_index}, width={image_width}, line_bytes={line_bytes_len}, "
                f"byte_lanes={self._byte_lanes}.",
            )

    def _build_line_tuser(self, line_bytes_len: int, *, line_index: int) -> list[int]:
        """Build TUSER=SOF pattern for the first pixel of the frame."""
        if line_index != 0 or line_bytes_len == 0:
            return [0] * line_bytes_len

        # Mark all bytes of beat 0 as SOF to avoid byte-index ambiguity in sideband packing.
        first_beat_len = min(self._byte_lanes, line_bytes_len)
        return [1] * first_beat_len + [0] * (line_bytes_len - first_beat_len)

    async def send_image(self, image: Image) -> None:
        """Send one image as AXI4-Video: one AXI packet per line."""
        for y in range(image.height):
            line_bytes = bytearray()

            for x in range(image.width):
                r, g, b = (int(v) & 0xFF for v in image.pixels[y, x])
                # cocotbext-axi packs lane 0 into TDATA[7:0], lane 1 into [15:8], lane 2 into [23:16].
                line_bytes.extend((b, g, r))

            self._validate_line_geometry(
                line_bytes_len=len(line_bytes),
                image_width=image.width,
                line_index=y,
            )
            tuser = self._build_line_tuser(len(line_bytes), line_index=y)

            await self._source.send(AxiStreamFrame(tdata=line_bytes, tuser=tuser))

        await self._source.wait()
        self._drive_idle_known()
