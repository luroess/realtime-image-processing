"""Stimuli helpers for AXI stream pause/backpressure patterns."""

from __future__ import annotations


def repeating_pause(pattern: tuple[int, ...] = (0, 0, 1, 0)):
    """
    Yield an infinite pause pattern for cocotbext-axi pause generators.

    0 -> not paused, 1 -> paused
    """
    if not pattern:
        raise ValueError("Pause pattern must contain at least one element.")

    while True:
        for value in pattern:
            yield bool(value)
