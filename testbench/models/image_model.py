"""Image model layer: frame container and pixel indexing helpers."""

from __future__ import annotations

from dataclasses import dataclass


@dataclass
class Image:
    width: int
    height: int
    pixels: list[int]

    def __post_init__(self) -> None:
        expected = self.width * self.height
        if len(self.pixels) != expected:
            raise ValueError(f"Expected {expected} pixels, got {len(self.pixels)}")
        for value in self.pixels:
            if value < 0 or value > 255:
                raise ValueError(f"Pixel value out of range [0, 255]: {value}")

    @classmethod
    def gradient(cls, width: int, height: int) -> "Image":
        """Generate a deterministic 8-bit gradient-style test frame."""
        pixels = [(y * width + x) % 256 for y in range(height) for x in range(width)]
        return cls(width=width, height=height, pixels=pixels)

    def index(self, x: int, y: int) -> int:
        if x < 0 or x >= self.width or y < 0 or y >= self.height:
            raise IndexError(f"Pixel coordinate out of bounds: ({x}, {y})")
        return y * self.width + x

    def pixel_at(self, x: int, y: int) -> int:
        return self.pixels[self.index(x, y)]

    @staticmethod
    def is_first_pixel(index: int) -> bool:
        return index == 0

    def is_last_in_line(self, index: int) -> bool:
        return ((index + 1) % self.width) == 0
