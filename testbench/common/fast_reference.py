"""Shared FAST reference-model helpers for cocotb test modules."""

from __future__ import annotations

from typing import Any

import cocotb
import numpy as np

# TODO(offset-parity): Keep this offset ordering synchronized with RTL FAST ring indexing.
FAST_RING_OFFSETS: tuple[tuple[int, int], ...] = (
    (0, -3),
    (1, -3),
    (2, -2),
    (3, -1),
    (3, 0),
    (3, 1),
    (2, 2),
    (1, 3),
    (0, 3),
    (-1, 3),
    (-2, 2),
    (-3, 1),
    (-3, 0),
    (-3, -1),
    (-2, -2),
    (-1, -3),
)
FAST_PRECHECK_INDICES: tuple[int, ...] = (0, 8, 4, 12)
DEFAULT_FAST_THRESHOLD = 20
DEFAULT_FAST_N = 9
DEFAULT_FAST_ENABLE_NMS = False


def _gray_from_rgb(image: Any) -> np.ndarray:
    # FIXME(color-order): Preserve channel interpretation parity between image tuples and wire ordering assumptions.
    pixels_u16 = image.pixels.astype(np.uint16)
    r = pixels_u16[:, :, 0]
    g = pixels_u16[:, :, 1]
    b = pixels_u16[:, :, 2]
    return ((r >> 2) + (g >> 1) + (b >> 2)).astype(np.uint8)


def _read_positive_generic(dut: Any, name: str, default: int) -> int:
    # TODO(generic-robustness): Keep simulator-handle coercion resilient across cocotb backend variants.
    handle = getattr(dut, name, None)
    if handle is None:
        return default

    raw_value = getattr(handle, "value", handle)
    try:
        value = int(raw_value)
    except (TypeError, ValueError):
        integer_value = getattr(raw_value, "integer", None)
        if integer_value is None:
            value = int(handle)
        else:
            value = int(integer_value)

    if value <= 0:
        raise AssertionError(f"Expected positive generic value for {name}, got {value}")
    return value


def _read_binary_generic(dut: Any, name: str, default: bool) -> bool:
    # TODO(generic-bool-robustness): Keep 0/1 generic reads consistent across simulators.
    handle = getattr(dut, name, None)
    if handle is None:
        return default

    raw_value = getattr(handle, "value", handle)
    try:
        value = int(raw_value)
    except (TypeError, ValueError):
        integer_value = getattr(raw_value, "integer", None)
        if integer_value is None:
            value = int(handle)
        else:
            value = int(integer_value)

    if value not in (0, 1):
        raise AssertionError(f"Expected binary generic value for {name}, got {value}")
    return bool(value)


def _fast_scores(
    gray_plane: np.ndarray,
    *,
    threshold: int = DEFAULT_FAST_THRESHOLD,
    n_contiguous: int = DEFAULT_FAST_N,
) -> np.ndarray:
    # TODO(golden-model): Keep this software score model equivalent to FAST RTL implementation.
    height, width = gray_plane.shape
    padded = np.pad(gray_plane.astype(np.int16), ((3, 3), (3, 3)), mode="constant")
    score_map = np.zeros((height, width), dtype=np.uint16)

    threshold_i = int(np.clip(threshold, 0, 255))
    for y in range(height):
        for x in range(width):
            center = int(padded[y + 3, x + 3])
            ring = [
                int(padded[y + 3 + dy, x + 3 + dx]) for (dx, dy) in FAST_RING_OFFSETS
            ]

            hi = center + threshold_i
            lo = center - threshold_i

            best_score = 0
            for start in range(16):
                bright_run = True
                dark_run = True
                bright_score = 0
                dark_score = 0

                for offset in range(n_contiguous):
                    idx = (start + offset) % 16
                    value = ring[idx]

                    if value > hi:
                        bright_score += value - hi
                    else:
                        bright_run = False

                    if value < lo:
                        dark_score += lo - value
                    else:
                        dark_run = False

                if bright_run:
                    best_score = max(best_score, bright_score)
                if dark_run:
                    best_score = max(best_score, dark_score)

            score_map[y, x] = np.uint16(best_score)

    return score_map


def _fast_nms_mask(scores: np.ndarray) -> np.ndarray:
    # FIXME(nms-policy): Revisit strict-maximum semantics if RTL NMS tie policy changes.
    height, width = scores.shape
    padded = np.pad(scores.astype(np.int32), ((1, 1), (1, 1)), mode="constant")
    mask = np.zeros((height, width), dtype=np.uint8)

    for y in range(height):
        for x in range(width):
            center = int(padded[y + 1, x + 1])
            if center == 0:
                continue

            neighborhood = padded[y : y + 3, x : x + 3].copy()
            neighborhood[1, 1] = -1
            if np.all(center > neighborhood):
                mask[y, x] = 255

    return mask


def _fast_expected(
    gray_plane: np.ndarray,
    *,
    threshold: int = DEFAULT_FAST_THRESHOLD,
    n_contiguous: int = DEFAULT_FAST_N,
    enable_nms: bool = DEFAULT_FAST_ENABLE_NMS,
) -> np.ndarray:
    # TODO(expected-compose): Keep expected-map composition centralized for shared test behavior.
    scores = _fast_scores(
        gray_plane,
        threshold=threshold,
        n_contiguous=n_contiguous,
    )
    if enable_nms:
        return _fast_nms_mask(scores)
    return np.where(scores > 0, 255, 0).astype(np.uint8)


def _assert_plane_equal(expected: np.ndarray, received: np.ndarray) -> None:
    # TODO(diff-reporting): Extend diagnostics if repeated mismatches require neighborhood-level debugging.
    if expected.shape != received.shape:
        raise AssertionError(
            f"Shape mismatch: expected={expected.shape}, received={received.shape}",
        )
    if np.array_equal(expected, received):
        return

    y, x = np.argwhere(expected != received)[0]
    raise AssertionError(
        f"First mismatch at (x={int(x)}, y={int(y)}): "
        f"expected={int(expected[y, x])}, received={int(received[y, x])}",
    )


def _random_pause_pattern(
    rng: np.random.Generator,
    *,
    min_len: int,
    max_len: int,
) -> tuple[int, ...]:
    # TODO(pause-diversity): Preserve mixed 0/1 pause generation to exercise backpressure dynamics.
    if min_len < 2:
        raise ValueError("Pause pattern min_len must be >= 2.")
    if max_len < min_len:
        raise ValueError("Pause pattern max_len must be >= min_len.")

    while True:
        length = int(rng.integers(min_len, max_len + 1))
        pattern = tuple(int(v) for v in rng.integers(0, 2, size=length))
        if any(pattern) and not all(pattern):
            return pattern


def _center_crop(gray_plane: np.ndarray, *, width: int, height: int) -> np.ndarray:
    # TODO(crop-consistency): Keep deterministic center-crop behavior for reproducible artifact comparison.
    if gray_plane.shape[0] < height or gray_plane.shape[1] < width:
        raise ValueError(
            "Input plane smaller than requested crop: "
            f"input={gray_plane.shape}, crop={(height, width)}",
        )
    y0 = (gray_plane.shape[0] - height) // 2
    x0 = (gray_plane.shape[1] - width) // 2
    return gray_plane[y0 : y0 + height, x0 : x0 + width]


def _opencv_fast_mask(
    gray_plane: np.ndarray,
    *,
    threshold: int = DEFAULT_FAST_THRESHOLD,
    nonmax_suppression: bool = DEFAULT_FAST_ENABLE_NMS,
) -> np.ndarray | None:
    # FIXME(opencv-parity): Keep detector parameters pinned to reduce version-to-version drift in cross-check results.
    try:
        import cv2
    except ModuleNotFoundError:
        return None

    detector = cv2.FastFeatureDetector_create(
        threshold=threshold,
        nonmaxSuppression=nonmax_suppression,
        type=cv2.FAST_FEATURE_DETECTOR_TYPE_9_16,
    )
    keypoints = detector.detect(gray_plane, None)

    mask = np.zeros_like(gray_plane, dtype=np.uint8)
    for keypoint in keypoints:
        x = int(round(float(keypoint.pt[0])))
        y = int(round(float(keypoint.pt[1])))
        if 0 <= x < mask.shape[1] and 0 <= y < mask.shape[0]:
            mask[y, x] = 255
    return mask


def _assert_matches_opencv_interior(
    *,
    gray_plane: np.ndarray,
    hw_mask: np.ndarray,
    threshold: int = DEFAULT_FAST_THRESHOLD,
    enable_nms: bool = DEFAULT_FAST_ENABLE_NMS,
    border: int = 3,
    min_iou: float = 0.55,
) -> None:
    # TODO(crosscheck-scope): Keep interior-region comparison to avoid expected border-policy differences.
    opencv_mask = _opencv_fast_mask(
        gray_plane,
        threshold=threshold,
        nonmax_suppression=enable_nms,
    )
    if opencv_mask is None:
        cocotb.log.info(
            "OpenCV not installed; skipping optional FAST interior cross-check.",
        )
        return

    if hw_mask.shape != opencv_mask.shape:
        raise AssertionError(
            "OpenCV/RTL mask shape mismatch: "
            f"opencv={opencv_mask.shape}, rtl={hw_mask.shape}",
        )

    if hw_mask.shape[0] <= (2 * border) or hw_mask.shape[1] <= (2 * border):
        return

    interior = (slice(border, -border), slice(border, -border))
    hw_inner = hw_mask[interior]
    opencv_inner = opencv_mask[interior]
    inter = int(np.count_nonzero((hw_inner > 0) & (opencv_inner > 0)))
    union = int(np.count_nonzero((hw_inner > 0) | (opencv_inner > 0)))
    iou = 1.0 if union == 0 else (inter / union)

    cocotb.log.info(
        "OpenCV interior comparison: iou=%.4f (inter=%d, union=%d)",
        iou,
        inter,
        union,
    )
    if iou < min_iou:
        raise AssertionError(
            "OpenCV FAST interior IoU below threshold: "
            f"iou={iou:.4f}, min_iou={min_iou:.4f}",
        )
