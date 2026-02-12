"""Verification layer: minimal frame scoreboard."""

from __future__ import annotations

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
