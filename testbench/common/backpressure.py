"""Deterministic backpressure helpers for AXI stream sinks."""

from __future__ import annotations

import itertools
from typing import Any, Protocol

from cocotb.triggers import FallingEdge


class PauseControllable(Protocol):
    """Interface for objects that expose direct pause control."""

    def set_pause(self, paused: bool) -> None: ...


async def drive_sink_pause(
    *,
    sink: PauseControllable,
    clk: Any,
    pattern: tuple[int, ...],
) -> None:
    """Drive sink pause (`1`=pause, `0`=ready) on falling clock edges."""
    if not pattern:
        raise ValueError("Pause pattern must contain at least one element.")

    sink.set_pause(False)
    pattern_iter = itertools.cycle(pattern)

    while True:
        await FallingEdge(clk)
        sink.set_pause(bool(next(pattern_iter)))
