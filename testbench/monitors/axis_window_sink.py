"""Monitor layer: AXI4-Video sink built on cocotbext-axi."""

from __future__ import annotations

import logging

import numpy as np
from cocotb.triggers import SimTimeoutError, with_timeout
from cocotbext.axi import AxiStreamBus, AxiStreamSink
from models.image_model import Image


class AxiWindowStreamSink:
    """Capture AXI4 Convolution frames."""

    def __init__(
        self,
        dut,
        i_clk,
        i_rst_n,
        prefix: str = "m_axis_video",
        reset_active_level: bool = True,
        kernel_size: int = 3,
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

    # @staticmethod
    # def _decode_line(
    #     frame,
    #     pixel_width: int,
    #     *,
    #     window_size: int,
    # ) -> List[np.ndarray]:
    #     data = bytes(frame.tdata)
    #     expected_bytes = (pixel_width * window_size * window_size) / 8
    #     if len(data) != expected_bytes:
    #         raise AssertionError(
    #             f"Line length mismatch on AXI stream: got {len(data)} bytes, expected {expected_bytes}",
    #         )

    #     return

    @staticmethod
    def _decode_line(
        frame,
        width: int,
        *,
        wndw_size: int,
        pxl_width: int,
    ) -> list[np.ndarray]:
        """
        Decode one AXI-stream line containing `width` flattened windows.
        Returns a list of NumPy arrays of shape (wndw_size, wndw_size, 3).
        """

        wndw_pixels = wndw_size * wndw_size
        wndw_bits = wndw_pixels * pxl_width
        if wndw_bits % 8 != 0:
            raise AssertionError(
                f"Unsupported window payload width={wndw_bits} bits (must be byte-aligned)",
            )
        wndw_bytes = wndw_bits // 8
        expected_bytes = width * wndw_bytes

        data = bytes(frame.tdata)
        if len(data) != expected_bytes:
            raise AssertionError(
                "Line length mismatch on AXI stream: "
                f"got {len(data)} bytes, expected {expected_bytes}",
            )

        raw = int.from_bytes(data, byteorder="little")

        windows: list[np.ndarray] = []

        for w in range(width):
            wndw_start = w * wndw_bits
            wndw_val = (raw >> wndw_start) & ((1 << wndw_bits) - 1)

            # Allocate window array
            wndw = np.zeros((wndw_size, wndw_size, 3), dtype=np.uint8)

            for i in range(wndw_pixels):
                p_val = (wndw_val >> (i * pxl_width)) & ((1 << pxl_width) - 1)

                if pxl_width == 24:
                    b = p_val & 0xFF
                    g = (p_val >> 8) & 0xFF
                    r = (p_val >> 16) & 0xFF
                elif pxl_width == 8:
                    y_gray = p_val & 0xFF
                    r = y_gray
                    g = y_gray
                    b = y_gray
                else:
                    raise AssertionError(
                        f"Unsupported pxl_width={pxl_width}; expected 8 or 24",
                    )

                y = i // wndw_size
                x = i % wndw_size
                wndw[y, x] = (r, g, b)

            #print("Curr wndw:", wndw)
            windows.append(wndw)

        return windows

    async def recv_windows(
        self,
        width: int,
        height: int,
        *,
        wndw_size: int,
        pxl_width: int,
        timeout_ns: int = 100_000,
    ) -> list[np.ndarray]:
        """
        Receive an entire window-based image from the AXI stream.
        Returns a flat list of NumPy arrays, each (wndw_size, wndw_size, 3),
        in row-major order — identical to _windows_from_image().
        """

        windows: list[np.ndarray] = []

        try:
            for _y in range(height):
                frame = await with_timeout(self._sink.recv(), timeout_ns, "ns")

                line_windows = self._decode_line(
                    frame=frame,
                    width=width,
                    wndw_size=wndw_size,
                    pxl_width=pxl_width,
                )

                windows.extend(line_windows)

        except SimTimeoutError as exc:
            raise AssertionError(
                f"Timed out waiting for window stream ({width}x{height}, {timeout_ns} ns per line)"
            ) from exc

        return windows
