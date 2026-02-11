"""Image model layer: frame container and pixel indexing helpers."""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

import numpy as np
from PIL import Image as PILImage


@dataclass
class Image:
    pixels: np.ndarray

    def __post_init__(self) -> None:
        if not isinstance(self.pixels, np.ndarray):
            self.pixels = np.asarray(self.pixels)

        if self.pixels.ndim != 3 or self.pixels.shape[2] != 3:
            raise ValueError(
                f"Expected RGB image array with shape (H, W, 3), got shape={self.pixels.shape}"
            )

        if self.pixels.dtype != np.uint8:
            if np.issubdtype(self.pixels.dtype, np.integer):
                min_value = int(self.pixels.min())
                max_value = int(self.pixels.max())
                if min_value < 0 or max_value > 255:
                    raise ValueError(
                        f"Pixel values out of range [0, 255]: min={min_value}, max={max_value}"
                    )
                self.pixels = self.pixels.astype(np.uint8)
            else:
                raise ValueError(f"Expected integer image dtype, got {self.pixels.dtype}")

    @classmethod
    def gradient(cls, width: int, height: int) -> "Image":
        """Generate a deterministic RGB gradient-style test frame."""
        y, x = np.indices((height, width), dtype=np.uint16)
        r = (x * 7 + y * 3) % 256
        g = (x * 5 + y * 11) % 256
        b = (x * 13 + y * 2) % 256
        pixels = np.stack([r, g, b], axis=2).astype(np.uint8)
        return cls(pixels=pixels)

    @classmethod
    def from_png(cls, path: str | Path) -> "Image":
        image = PILImage.open(path).convert("RGB")
        pixels = np.asarray(image, dtype=np.uint8)
        return cls(pixels=pixels)

    @property
    def width(self) -> int:
        return int(self.pixels.shape[1])

    @property
    def height(self) -> int:
        return int(self.pixels.shape[0])

    @property
    def channels(self) -> int:
        return int(self.pixels.shape[2])

    def flat_pixels(self) -> np.ndarray:
        return self.pixels.reshape(-1, 3)

    def to_png(self, path: str | Path) -> None:
        output_path = Path(path)
        output_path.parent.mkdir(parents=True, exist_ok=True)
        PILImage.fromarray(self.pixels, mode="RGB").save(output_path)

    def index(self, x: int, y: int) -> int:
        if x < 0 or x >= self.width or y < 0 or y >= self.height:
            raise IndexError(f"Pixel coordinate out of bounds: ({x}, {y})")
        return y * self.width + x

    def pixel_at(self, x: int, y: int) -> np.ndarray:
        return self.pixels[y, x]

    @staticmethod
    def is_first_pixel(index: int) -> bool:
        return index == 0

    def is_last_in_line(self, index: int) -> bool:
        return ((index + 1) % self.width) == 0
