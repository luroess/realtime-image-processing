"""Stimuli layer: AXI4-Stream binary/grayscale source built on cocotbext-axi."""

from __future__ import annotations

import logging

import numpy as np
from cocotbext.axi import (  # type: ignore[missing-imports]
    AxiStreamBus,
    AxiStreamFrame,
    AxiStreamSource,
)


class _KnownIdleAxiStreamSource(AxiStreamSource):
    """AxiStreamSource variant that avoids X-initialization on idle outputs."""

    _init_x = False


class AxiGray8StreamSource:
    """Drive gray/binary AXI4-Stream frames with SOF on TUSER and EOL on TLAST."""

    def __init__(
        self,
        dut,
        i_clk,
        i_rst_n,
        prefix: str = "s_axis_video_edges",
        reset_active_level: bool = True,
    ) -> None:
        bus = AxiStreamBus.from_prefix(dut, prefix)
        byte_size = 1 if len(bus.tdata) == 1 else None
        self._source = _KnownIdleAxiStreamSource(
            bus=bus,
            clock=i_clk,
            reset=i_rst_n,
            reset_active_level=reset_active_level,
            byte_size=byte_size,
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

    def _validate_plane(self, edge_plane: np.ndarray) -> None:
        """Validate edge mask plane shape and source width assumptions."""
        if edge_plane.ndim != 2:
            raise ValueError(
                "edge_plane must have shape (height, width) for binary mask pixels.",
            )

        if self._byte_size not in (1, 8):
            raise AssertionError(
                "AxiGray8StreamSource currently supports binary(1-bit) or byte-wide(8-bit) edges; "
                f"got byte_size={self._byte_size}.",
            )

        if self._byte_lanes <= 0:
            raise AssertionError(
                f"AxiGray8StreamSource detected invalid byte lane count: {self._byte_lanes}.",
            )

    async def send_plane(self, edge_plane: np.ndarray) -> None:
        """Send one gray8 plane as AXI4-Video: one AXI packet per line."""
        self._validate_plane(edge_plane=edge_plane)

        plane_u8 = edge_plane.astype(np.uint8, copy=False)
        height, width = plane_u8.shape

        for y in range(height):
            line = plane_u8[y]
            line_bytes = bytearray((int(v) != 0) & 0xFF for v in line)

            expected_bytes = width
            if len(line_bytes) != expected_bytes:
                raise AssertionError(
                    "Line length mismatch in edge plane serialization: "
                    f"line={y}, got={len(line_bytes)}, expected={expected_bytes}",
                )

            if len(line_bytes) % self._byte_lanes != 0:
                raise AssertionError(
                    "AXI4-Stream line byte count must align to beat size when tkeep is not modeled: "
                    f"line={y}, line_bytes={len(line_bytes)}, byte_lanes={self._byte_lanes}.",
                )

            if y == 0 and len(line_bytes) > 0:
                tuser = [1] + ([0] * (len(line_bytes) - 1))
            else:
                tuser = [0] * len(line_bytes)

            await self._source.send(AxiStreamFrame(tdata=line_bytes, tuser=tuser))

        await self._source.wait()
        self._drive_idle_known()
