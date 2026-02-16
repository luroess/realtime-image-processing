"""Monitor layer: AXI4-Video sink built on cocotbext-axi."""

from __future__ import annotations

import logging
from typing import Literal

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
        frame_type: Literal["rgb888", "gray8"] = "rgb888",
        pixel_order: Literal["rgb", "rbg"] = "rbg",
    ) -> None:
        if frame_type not in ("rgb888", "gray8"):
            raise ValueError(f"Unsupported frame_type: {frame_type}")
        if pixel_order not in ("rgb", "rbg"):
            raise ValueError(f"Unsupported pixel_order: {pixel_order}")

        self._sink = AxiStreamSink(
            bus=AxiStreamBus.from_prefix(dut, prefix),
            clock=i_clk,
            reset=i_rst_n,
            reset_active_level=reset_active_level,
        )
        self._byte_lanes = int(self._sink.byte_lanes)
        self._pixel_order = pixel_order
        self._sink.log.setLevel(logging.WARNING)

    def set_pause_generator(self, generator=None) -> None:
        """Apply optional TREADY backpressure pattern."""
        self._sink.set_pause_generator(generator)

    def set_pause(self, paused: bool) -> None:
        """Directly control sink pause (`True` stalls by deasserting TREADY)."""
        self._sink.pause = bool(paused)

    @staticmethod
    def _decode_rgb888_line(
        frame,
        width: int,
        *,
        byte_lanes: int,
        pixel_order: Literal["rgb", "rbg"],
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
            if pixel_order == "rgb":
                b = int(data[base + 0])
                g = int(data[base + 1])
            else:
                # Wire order R|B|G packs bytes as (G,B,R) for little-endian AXIS lanes.
                g = int(data[base + 0])
                b = int(data[base + 1])
            r = int(data[base + 2])
            pixels.append((r, g, b))

        return pixels

    @staticmethod
    def _decode_gray8_line(
        frame,
        width: int,
        *,
        byte_lanes: int,
        line_index: int,
    ) -> list[int]:
        if byte_lanes != 1:
            raise AssertionError(
                "AxiVideoStreamSink currently supports gray8 input only with 1 byte lane; "
                f"got byte_lanes={byte_lanes}.",
            )
        expected_bytes = width
        data = bytes(frame.tdata)
        if len(data) != expected_bytes:
            raise AssertionError(
                f"Line length mismatch on AXI stream: got {len(data)} bytes, expected {expected_bytes}",
            )
        if frame.tuser is None:
            raise AssertionError(
                "Gray8 output does not provide TUSER for SOF tracking.",
            )
        if isinstance(frame.tuser, int):
            tuser_values = [int(frame.tuser)]
        else:
            try:
                tuser_values = [int(v) for v in frame.tuser]
            except TypeError as exc:
                raise AssertionError(
                    "Gray8 TUSER format is not iterable or an integer.",
                ) from exc

        if len(tuser_values) != expected_bytes:
            raise AssertionError(
                "Gray8 TUSER length mismatch on AXI stream: "
                f"got {len(tuser_values)} bytes, expected {expected_bytes}.",
            )

        for idx, tuser in enumerate(tuser_values):
            expected_tuser = 1 if line_index == 0 and idx == 0 else 0
            if int(tuser) != expected_tuser:
                raise AssertionError(
                    "Gray8 SOF/TUSER mismatch on AXI stream: "
                    f"byte={idx}, observed={int(tuser)}, expected={expected_tuser}.",
                )

        return [int(v) for v in data]

    def _decode_line(
        self,
        frame,
        width: int,
        *,
        byte_lanes: int,
        frame_type: Literal["rgb888", "gray8"] = "rgb888",
        line_index: int = 0,
    ) -> list[tuple[int, int, int]] | list[int]:
        if frame_type == "rgb888":
            return AxiVideoStreamSink._decode_rgb888_line(
                frame,
                width,
                byte_lanes=byte_lanes,
                pixel_order=self._pixel_order,
            )

        if frame_type == "gray8":
            return AxiVideoStreamSink._decode_gray8_line(
                frame,
                width,
                byte_lanes=byte_lanes,
                line_index=line_index,
            )

        raise ValueError(f"Unsupported frame_type: {frame_type}")

    async def recv_image(
        self,
        width: int,
        height: int,
        timeout_ns: int = 100_000,
        frame_type: Literal[
            "rgb888",
            "gray8",
        ] = "rgb888",
    ) -> Image | np.ndarray:
        if frame_type not in ("rgb888", "gray8"):
            raise ValueError(f"Unsupported frame_type: {frame_type}")

        lines: list[list[tuple[int, int, int]] | list[int]] = []

        try:
            for y in range(height):
                frame = await with_timeout(
                    self._sink.recv(compact=False),
                    timeout_ns,
                    "ns",
                )
                pixels = self._decode_line(
                    frame=frame,
                    width=width,
                    byte_lanes=self._byte_lanes,
                    frame_type=frame_type,
                    line_index=y,
                )

                lines.append(pixels)
        except SimTimeoutError as exc:
            raise AssertionError(
                f"Timed out waiting for output frame ({width}x{height}, {timeout_ns} ns per line)",
            ) from exc

        frame_array = np.asarray(lines, dtype=np.uint8)
        if frame_type == "rgb888":
            return Image(frame_array)
        return frame_array
