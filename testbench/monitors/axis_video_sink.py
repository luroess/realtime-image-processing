"""Monitor layer: AXI4-Video sink built on cocotbext-axi."""

from __future__ import annotations

import logging

import numpy as np
from cocotb.triggers import SimTimeoutError, with_timeout
from cocotbext.axi import AxiStreamBus, AxiStreamSink
from models.image_model import Image


class AxiVideoStreamSink:
    """Capture AXI4-Video frames and decode RGB payload."""

    def __init__(
        self,
        dut,
        i_clk,
        i_rst_n,
        prefix: str = "m_axis_video",
        reset_active_level: bool = True,
    ) -> None:
        self._sink = AxiStreamSink(
            bus=AxiStreamBus.from_prefix(dut, prefix),
            clock=i_clk,
            reset=i_rst_n,
            reset_active_level=reset_active_level,
        )
        self._byte_lanes = int(self._sink.byte_lanes)
        self._sink.log.setLevel(logging.WARNING)

    def set_pause_generator(self, generator=None) -> None:
        """Apply optional TREADY backpressure pattern."""
        self._sink.set_pause_generator(generator)

    def set_pause(self, paused: bool) -> None:
        """Directly control sink pause (`True` stalls by deasserting TREADY)."""
        self._sink.pause = bool(paused)

    @staticmethod
    def _decode_line(
        frame,
        width: int,
        *,
        byte_lanes: int,
    ) -> list[tuple[int, int, int]]:
        data = bytes(frame.tdata)
        if byte_lanes != 3:
            raise AssertionError(
                "AxiVideoStreamSink currently supports packed RGB24 only (3 byte lanes); "
                f"got byte_lanes={byte_lanes}.",
            )
        expected_bytes = width * 3
        if len(data) != expected_bytes:
            raise AssertionError(
                f"Line length mismatch on AXI stream: got {len(data)} bytes, expected {expected_bytes}",
            )
        if byte_lanes <= 0:
            raise AssertionError(f"Invalid AXI byte lane count: {byte_lanes}")

        pixels: list[tuple[int, int, int]] = []

        for x in range(width):
            base = x * 3
            b = int(data[base + 0])
            g = int(data[base + 1])
            r = int(data[base + 2])
            pixels.append((r, g, b))

        return pixels

    async def recv_image(
        self,
        width: int,
        height: int,
        timeout_ns: int = 100_000,
    ) -> Image:
        lines: list[list[tuple[int, int, int]]] = []

        try:
            for y in range(height):
                frame = await with_timeout(self._sink.recv(), timeout_ns, "ns")
                pixels = self._decode_line(
                    frame=frame,
                    width=width,
                    byte_lanes=self._byte_lanes,
                )

                lines.append(pixels)
        except SimTimeoutError as exc:
            raise AssertionError(
                f"Timed out waiting for output frame ({width}x{height}, {timeout_ns} ns per line)",
            ) from exc

        frame_array = np.asarray(lines, dtype=np.uint8)
        return Image(frame_array)
