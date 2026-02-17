"""Stimuli layer: AXI4-Stream source for 3x3 gray window streams."""

from __future__ import annotations

import logging

import numpy as np
from cocotbext.axi import AxiStreamBus, AxiStreamFrame, AxiStreamSource


class _KnownIdleAxiStreamSource(AxiStreamSource):
    """AxiStreamSource variant that avoids X-initialization on sidebands."""

    _init_x = False


class AxiWindowGraySource:
    """Send a gray image as a stream of 3x3 zero-padded windows."""

    def __init__(
        self,
        dut,
        i_clk,
        i_rst_n,
        prefix: str = "s_axis_video",
        reset_active_level: bool = False,
    ) -> None:
        self._source = _KnownIdleAxiStreamSource(
            bus=AxiStreamBus.from_prefix(dut, prefix),
            clock=i_clk,
            reset=i_rst_n,
            reset_active_level=reset_active_level,
        )
        self._byte_lanes = int(self._source.byte_lanes)
        self._source.log.setLevel(logging.WARNING)
        self._drive_idle_known()

        if self._byte_lanes != 9:
            raise AssertionError(
                f"Expected 9 byte lanes for 3x3 gray window input, got {self._byte_lanes}",
            )

    def _drive_idle_known(self) -> None:
        self._source.bus.tdata.value = 0
        if hasattr(self._source.bus, "tlast"):
            self._source.bus.tlast.value = 0
        if hasattr(self._source.bus, "tuser"):
            self._source.bus.tuser.value = 0

    async def send_gray_image(self, gray_plane: np.ndarray) -> None:
        if gray_plane.ndim != 2:
            raise ValueError(
                f"Expected gray plane with shape (H, W), got shape={gray_plane.shape}",
            )

        height, width = gray_plane.shape
        padded = np.pad(gray_plane, ((1, 1), (1, 1)), mode="constant", constant_values=0)

        for y in range(height):
            line_bytes = bytearray()
            for x in range(width):
                window = padded[y : y + 3, x : x + 3]
                line_bytes.extend(int(v) & 0xFF for v in window.reshape(-1))

            tuser = [0] * len(line_bytes)
            if y == 0 and tuser:
                tuser[0:9] = [1] * min(9, len(tuser))

            await self._source.send(AxiStreamFrame(tdata=bytes(line_bytes), tuser=tuser))

        await self._source.wait()
        self._drive_idle_known()
