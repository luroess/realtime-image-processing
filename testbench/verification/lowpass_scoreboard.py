"""Verification helpers for lowpass 8-bit output images."""

from __future__ import annotations

import numpy as np


class LowpassScoreboard:
    """Compare expected vs received lowpass grayscale outputs."""

    @staticmethod
    def compare(expected: np.ndarray, received: np.ndarray) -> None:
        expected_u8 = np.asarray(expected, dtype=np.uint8)
        received_u8 = np.asarray(received, dtype=np.uint8)

        if expected_u8.ndim != 2 or received_u8.ndim != 2:
            raise AssertionError(
                "Lowpass scoreboard expects 2D grayscale arrays; "
                f"got expected.ndim={expected_u8.ndim}, received.ndim={received_u8.ndim}",
            )

        if expected_u8.shape != received_u8.shape:
            raise AssertionError(
                "Lowpass output dimensions mismatch: "
                f"expected={expected_u8.shape}, received={received_u8.shape}",
            )

        if np.array_equal(expected_u8, received_u8):
            return

        mismatch_indices = np.argwhere(expected_u8 != received_u8)
        y, x = mismatch_indices[0]
        exp_px = int(expected_u8[y, x])
        got_px = int(received_u8[y, x])
        idx = int(y) * int(expected_u8.shape[1]) + int(x)

        raise AssertionError(
            f"First lowpass mismatch at index={idx} (x={int(x)}, y={int(y)}): "
            f"expected={exp_px}, received={got_px}",
        )
