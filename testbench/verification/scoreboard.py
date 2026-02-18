"""Verification layer: minimal frame scoreboard."""

from __future__ import annotations

from typing import List

import numpy as np
from models.image_model import Image


class Scoreboard:
    def compare(self, expected: Image, received: Image) -> None:
        if (
            expected.width != received.width
            or expected.height != received.height
            or expected.channels != received.channels
        ):
            raise AssertionError(
                "Image dimensions mismatch: "
                f"expected={expected.width}x{expected.height}x{expected.channels}, "
                f"received={received.width}x{received.height}x{received.channels}",
            )

        if np.array_equal(expected.pixels, received.pixels):
            return

        mismatch_indices = np.argwhere(expected.pixels != received.pixels)
        y, x, c = mismatch_indices[0]
        idx = int(y) * expected.width + int(x)
        exp_px = int(expected.pixels[y, x, c])
        got_px = int(received.pixels[y, x, c])
        channel_names = ("R", "G", "B")
        ch = channel_names[int(c)] if int(c) < len(channel_names) else str(int(c))

        raise AssertionError(
            f"First pixel mismatch at index={idx} (x={int(x)}, y={int(y)}, ch={ch}): "
            f"expected={exp_px}, received={got_px}",
        )

    def compare_windows(
        self,
        expected: List[np.ndarray],
        received: List[np.ndarray],
    ) -> List[int]:
        """
        Compare two lists of windows and return a list of indices where
        the windows differ.

        Returns:
            A list of indices i such that w1[i] != w2[i].
        """

        len1 = len(expected)
        len2 = len(received)
        if len1 != len2:
            raise AssertionError(
                "Window list length mismatch: "
                f"expected={len1}, received={len2}",
            )

        limit = len1
        mismatches = []

        for i in range(limit):
            if not np.array_equal(expected[i], received[i]):
                mismatches.append(i)

        if len(mismatches) > 0:
            raise AssertionError(
                f"Window mismatch(es) at {mismatches}"
            )
