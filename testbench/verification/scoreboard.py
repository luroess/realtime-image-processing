"""Verification layer: minimal frame scoreboard."""

from __future__ import annotations

from models.image_model import Image


class Scoreboard:
    def compare(self, expected: Image, received: Image) -> None:
        if expected.width != received.width or expected.height != received.height:
            raise AssertionError(
                "Image dimensions mismatch: "
                f"expected={expected.width}x{expected.height}, "
                f"received={received.width}x{received.height}"
            )

        for idx, (exp_px, got_px) in enumerate(zip(expected.pixels, received.pixels)):
            if exp_px != got_px:
                y, x = divmod(idx, expected.width)
                raise AssertionError(
                    f"First pixel mismatch at index={idx} (x={x}, y={y}): "
                    f"expected={exp_px}, received={got_px}"
                )
