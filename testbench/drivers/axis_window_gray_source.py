"""Stimuli layer: AXI4-Stream source for KxK gray window streams."""

from __future__ import annotations

import logging
from typing import TYPE_CHECKING

import numpy as np
from cocotbext.axi import AxiStreamBus, AxiStreamFrame, AxiStreamSource

if TYPE_CHECKING:
    from collections.abc import Iterable


class _KnownIdleAxiStreamSource(AxiStreamSource):
    """AxiStreamSource variant that avoids X-initialization on sidebands."""

    _init_x = False


class AxiWindowGraySource:
    """Send a gray image as a stream of KxK zero-padded windows."""

    def __init__(
        self,
        dut,
        i_clk,
        i_rst_n,
        prefix: str = "s_axis_video",
        reset_active_level: bool = False,
        wndw_size: int = 3,
    ) -> None:
        if wndw_size < 3 or (wndw_size % 2) == 0:
            raise ValueError(f"Expected odd wndw_size >= 3, got {wndw_size}")

        self._wndw_size = int(wndw_size)
        self._wndw_pixels = self._wndw_size * self._wndw_size

        self._source = _KnownIdleAxiStreamSource(
            bus=AxiStreamBus.from_prefix(dut, prefix),
            clock=i_clk,
            reset=i_rst_n,
            reset_active_level=reset_active_level,
        )
        self._byte_lanes = int(self._source.byte_lanes)
        self._source.log.setLevel(logging.WARNING)
        self._drive_idle_known()

        if self._byte_lanes != self._wndw_pixels:
            raise AssertionError(
                "Expected byte lanes to match wndw_size * wndw_size. "
                f"wndw_size={self._wndw_size}, byte_lanes={self._byte_lanes}",
            )

    def _drive_idle_known(self) -> None:
        self._source.bus.tdata.value = 0
        if hasattr(self._source.bus, "tlast"):
            self._source.bus.tlast.value = 0
        if hasattr(self._source.bus, "tuser"):
            self._source.bus.tuser.value = 0

    def set_pause_generator(self, generator: Iterable[bool] | None = None) -> None:
        """Apply optional TVALID throttling pattern."""
        self._source.set_pause_generator(generator)

    def set_pause(self, paused: bool) -> None:
        """Directly control source pause (`True` holds TVALID low)."""
        self._source.pause = bool(paused)

    async def send_gray_image(
        self,
        gray_plane: np.ndarray,
        *,
        tail_padding_windows: int = 0,
    ) -> None:
        if gray_plane.ndim != 2:
            raise ValueError(
                f"Expected gray plane with shape (H, W), got shape={gray_plane.shape}",
            )

        height, width = gray_plane.shape
        pad = self._wndw_size // 2
        padded = np.pad(
            gray_plane,
            ((pad, pad), (pad, pad)),
            mode="constant",
            constant_values=0,
        )

        for y in range(height):
            line_bytes = bytearray()
            for x in range(width):
                window = padded[y : y + self._wndw_size, x : x + self._wndw_size]
                line_bytes.extend(int(v) & 0xFF for v in window.reshape(-1))

            tuser = [0] * len(line_bytes)
            if y == 0 and tuser:
                tuser[0 : self._wndw_pixels] = [1] * min(self._wndw_pixels, len(tuser))

            await self._source.send(
                AxiStreamFrame(tdata=bytes(line_bytes), tuser=tuser),
            )

        if tail_padding_windows > 0:
            pad_bytes = bytearray(
                0 for _ in range(tail_padding_windows * self._wndw_pixels)
            )
            await self._source.send(
                AxiStreamFrame(tdata=bytes(pad_bytes), tuser=[0] * len(pad_bytes)),
            )

        await self._source.wait()
        self._drive_idle_known()
