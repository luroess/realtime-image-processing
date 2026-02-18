"""Typed stress-test helpers for cocotb test modules."""

from __future__ import annotations

import os
import random
from dataclasses import dataclass
from typing import Literal

import numpy as np
from models.image_model import Image

StressTier = Literal["fast", "heavy"]
PausePatternKind = Literal["burst", "alternating", "random"]
GrayFramePattern = Literal["gradient", "checkerboard", "impulse", "noise"]

TB_STRESS_TIER = "TB_STRESS_TIER"
TB_STRESS_SEED = "TB_STRESS_SEED"
TB_STRESS_CASES = "TB_STRESS_CASES"

DEFAULT_STRESS_SEED = 0x5EED


@dataclass(frozen=True, slots=True)
class StressConfig:
    """Resolved stress execution settings from testbench environment."""

    tier: StressTier
    seed: int
    cases: int

    @property
    def is_heavy(self) -> bool:
        return self.tier == "heavy"


def _parse_env_int(
    *,
    env_name: str,
    default: int,
    minimum: int = 0,
) -> int:
    raw_value = os.getenv(env_name)
    if raw_value is None or raw_value.strip() == "":
        return default

    try:
        value = int(raw_value, 0)
    except ValueError as exc:
        raise ValueError(
            f"{env_name} must be an integer, got {raw_value!r}.",
        ) from exc

    if value < minimum:
        raise ValueError(f"{env_name} must be >= {minimum}, got {value}.")

    return value


def stress_tier(default: StressTier = "fast") -> StressTier:
    """Resolve stress tier from `TB_STRESS_TIER` with `fast` default."""
    raw_value = os.getenv(TB_STRESS_TIER)
    if raw_value is None or raw_value.strip() == "":
        return default

    value = raw_value.strip().lower()
    if value in {"fast", "smoke"}:
        return "fast"
    if value in {"heavy", "full", "stress"}:
        return "heavy"

    raise ValueError(
        f"{TB_STRESS_TIER} must be one of: fast|heavy|smoke|full|stress; got {raw_value!r}.",
    )


def stress_seed(default: int = DEFAULT_STRESS_SEED) -> int:
    """Resolve deterministic stress seed from `TB_STRESS_SEED`."""
    return _parse_env_int(env_name=TB_STRESS_SEED, default=default, minimum=0)


def stress_cases(
    *,
    tier: StressTier,
    default_fast: int = 4,
    default_heavy: int = 24,
) -> int:
    """Resolve stress case count from `TB_STRESS_CASES`."""
    default = default_heavy if tier == "heavy" else default_fast
    return _parse_env_int(env_name=TB_STRESS_CASES, default=default, minimum=1)


def stress_config(
    *,
    default_fast_cases: int = 4,
    default_heavy_cases: int = 24,
    default_seed: int = DEFAULT_STRESS_SEED,
) -> StressConfig:
    """Read all stress controls from environment."""
    tier = stress_tier()
    seed = stress_seed(default=default_seed)
    cases = stress_cases(
        tier=tier,
        default_fast=default_fast_cases,
        default_heavy=default_heavy_cases,
    )
    return StressConfig(tier=tier, seed=seed, cases=cases)


def derived_seed(*, base_seed: int, salt: str) -> int:
    """Derive a stable 32-bit seed from a base seed and string salt."""
    mixed = base_seed & 0xFFFFFFFF
    for byte in salt.encode("utf-8"):
        mixed = ((mixed * 131) + byte) & 0xFFFFFFFF
    return mixed


def seeded_random(*, base_seed: int, salt: str) -> random.Random:
    """Create a deterministic `random.Random` instance."""
    return random.Random(derived_seed(base_seed=base_seed, salt=salt))


def build_pause_pattern(
    *,
    kind: PausePatternKind,
    seed: int,
    length: int = 8,
    burst_pause_cycles: int = 3,
    burst_run_cycles: int = 3,
    random_pause_probability: float = 0.35,
) -> tuple[int, ...]:
    """Create deterministic sink pause patterns (`1`=pause, `0`=ready)."""
    if length < 1:
        raise ValueError(f"Pause pattern length must be >= 1, got {length}.")

    if kind == "burst":
        if burst_pause_cycles < 1 or burst_run_cycles < 1:
            raise ValueError(
                "Burst pause/run cycles must both be >= 1 "
                f"(pause={burst_pause_cycles}, run={burst_run_cycles}).",
            )
        base = ([1] * burst_pause_cycles) + ([0] * burst_run_cycles)
        repeats = (length + len(base) - 1) // len(base)
        return tuple((base * repeats)[:length])

    if kind == "alternating":
        return tuple(1 if (idx % 2) else 0 for idx in range(length))

    if kind == "random":
        if not (0.0 <= random_pause_probability <= 1.0):
            raise ValueError(
                f"random_pause_probability must be in [0.0, 1.0], got {random_pause_probability}.",
            )
        rng = random.Random(seed)
        values = [
            1 if (rng.random() < random_pause_probability) else 0 for _ in range(length)
        ]
        if all(v == 0 for v in values):
            values[0] = 1
        if all(v == 1 for v in values):
            values[-1] = 0
        return tuple(values)

    raise ValueError(f"Unsupported pause pattern kind: {kind}")


def _gray_to_rgb(gray_plane: np.ndarray) -> Image:
    rgb = np.stack((gray_plane, gray_plane, gray_plane), axis=2).astype(np.uint8)
    return Image(rgb)


def _checkerboard_plane(*, width: int, height: int, seed: int) -> np.ndarray:
    tile_size = 1 + (seed % 4)
    y, x = np.indices((height, width), dtype=np.uint16)
    board = (((x // tile_size) + (y // tile_size)) & 0x1) * 255
    return board.astype(np.uint8)


def _impulse_plane(*, width: int, height: int, seed: int) -> np.ndarray:
    rng = random.Random(seed)
    plane = np.zeros((height, width), dtype=np.uint8)
    impulse_x = rng.randrange(width)
    impulse_y = rng.randrange(height)
    plane[impulse_y, impulse_x] = 255
    return plane


def _noise_plane(*, width: int, height: int, seed: int) -> np.ndarray:
    rng = np.random.default_rng(seed)
    return rng.integers(0, 256, size=(height, width), dtype=np.uint8)


def build_gray_frame(
    *,
    pattern: GrayFramePattern,
    width: int,
    height: int,
    seed: int,
) -> Image:
    """Build deterministic grayscale RGB frame patterns for stress tests."""
    if width < 1 or height < 1:
        raise ValueError(f"Image dimensions must be >= 1, got width={width}, height={height}.")

    if pattern == "gradient":
        return Image.gradient_gray(width=width, height=height)
    if pattern == "checkerboard":
        return _gray_to_rgb(_checkerboard_plane(width=width, height=height, seed=seed))
    if pattern == "impulse":
        return _gray_to_rgb(_impulse_plane(width=width, height=height, seed=seed))
    if pattern == "noise":
        return _gray_to_rgb(_noise_plane(width=width, height=height, seed=seed))

    raise ValueError(f"Unsupported gray frame pattern: {pattern}")
