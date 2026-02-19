"""Monitor layer: AXI4-Stream sink for gray8 image output."""

from __future__ import annotations

import logging

import numpy as np
from cocotb.triggers import SimTimeoutError, with_timeout
from cocotbext.axi import AxiStreamBus, AxiStreamSink


class AxiGrayStreamSink:
    """Receive gray8 image data as (H, W) uint8 plane."""

    def __init__(
        self,
        dut,
        i_clk,
        i_rst_n,
        prefix: str = "m_axis_window",
        reset_active_level: bool = False,
    ) -> None:
        self._sink = AxiStreamSink(
            bus=AxiStreamBus.from_prefix(dut, prefix),
            clock=i_clk,
            reset=i_rst_n,
            reset_active_level=reset_active_level,
        )
        self._byte_lanes = int(self._sink.byte_lanes)
        self._sink.log.setLevel(logging.WARNING)

        if self._byte_lanes != 1:
            raise AssertionError(
                f"Expected 1 byte lane for gray8 output, got {self._byte_lanes}",
            )

    def set_pause_generator(self, generator=None) -> None:
        """Apply optional TREADY backpressure pattern."""
        self._sink.set_pause_generator(generator)

    def set_pause(self, paused: bool) -> None:
        """Directly control sink pause (`True` stalls by deasserting TREADY)."""
        self._sink.pause = bool(paused)

    async def recv_plane(self, width: int, height: int, timeout_ns: int = 100_000) -> np.ndarray:
        lines: list[list[int]] = []

        try:
            for _ in range(height):
                frame = await with_timeout(self._sink.recv(compact=False), timeout_ns, "ns")
                line = list(bytes(frame.tdata))

                if len(line) != width:
                    raise AssertionError(
                        f"Line length mismatch: got {len(line)} bytes, expected {width}",
                    )

                lines.append(line)
        except SimTimeoutError as exc:
            raise AssertionError(
                f"Timed out waiting for gray frame ({width}x{height}, {timeout_ns} ns per line)",
            ) from exc

        return np.asarray(lines, dtype=np.uint8)
