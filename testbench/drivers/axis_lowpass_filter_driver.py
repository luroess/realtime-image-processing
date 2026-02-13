"""AXI4-Stream source driver for 3x3 8-bit pixel windows (LowpassFilter input)."""

from __future__ import annotations

from collections.abc import Iterable, Sequence
from pathlib import Path

import numpy as np
from cocotb.triggers import RisingEdge
from PIL import Image as PILImage


class AxisLowpassFilterDriver:
    """Drive `s_axis_lowpass_*` with one 3x3 grayscale window per accepted beat.

    Packing convention (row-major, little-endian byte lanes):
    - Lane 0 / `tdata[7:0]`   = window[0][0] (top-left)
    - Lane 1 / `tdata[15:8]`  = window[0][1]
    - ...
    - Lane 8 / `tdata[71:64]` = window[2][2] (bottom-right)
    """

    WINDOW_SIZE = 3
    PIXELS_PER_WINDOW = WINDOW_SIZE * WINDOW_SIZE
    PIXEL_MASK = 0xFF
    _SUPPORTED_EXTENSIONS = {".png", ".jpg", ".jpeg", ".bmp", ".tif", ".tiff"}

    def __init__(
        self,
        dut,
        i_clk,
        i_rst_n=None,
        prefix: str = "s_axis_lowpass",
        reset_active_level: int = 1,
    ) -> None:
        self.dut = dut
        self.i_clk = i_clk
        self.i_rst_n = i_rst_n
        self.reset_active_level = int(reset_active_level)

        self.tvalid = getattr(dut, f"{prefix}_tvalid")
        self.tready = getattr(dut, f"{prefix}_tready")
        self.tdata = getattr(dut, f"{prefix}_tdata")
        self.tlast = getattr(dut, f"{prefix}_tlast")
        self.tuser = getattr(dut, f"{prefix}_tuser")

        self._drive_idle()

    def _drive_idle(self) -> None:
        self.tvalid.value = 0
        self.tdata.value = 0
        self.tlast.value = 0
        self.tuser.value = 0

    def _in_reset(self) -> bool:
        if self.i_rst_n is None:
            return False
        return int(self.i_rst_n.value) == self.reset_active_level

    async def _wait_while_reset(self) -> None:
        while self._in_reset():
            await RisingEdge(self.i_clk)

    @classmethod
    def pack_window(cls, window: Sequence[Sequence[int]]) -> int:
        """Pack one 3x3 uint8 window to a 72-bit AXI word.

        Expected shape is exactly ``3 x 3`` with values in ``[0, 255]``.
        """
        if len(window) != cls.WINDOW_SIZE:
            raise ValueError(
                f"window must have {cls.WINDOW_SIZE} rows, got {len(window)}",
            )

        packed = 0
        lane_index = 0
        for row in window:
            if len(row) != cls.WINDOW_SIZE:
                raise ValueError(
                    f"each row must have {cls.WINDOW_SIZE} columns, got {len(row)}",
                )
            for pixel in row:
                pixel_value = int(pixel)
                if pixel_value < 0 or pixel_value > cls.PIXEL_MASK:
                    raise ValueError(
                        f"pixel must be 8-bit unsigned (0..255), got {pixel_value}",
                    )
                packed |= (pixel_value & cls.PIXEL_MASK) << (lane_index * 8)
                lane_index += 1

        return packed

    async def send_window(
        self,
        window: Sequence[Sequence[int]],
        *,
        sof: bool = False,
        eol: bool = False,
    ) -> None:
        """Send one 3x3 window beat and wait until handshake accepts it."""
        await self._wait_while_reset()

        self.tvalid.value = 1
        self.tdata.value = self.pack_window(window)
        self.tuser.value = 1 if sof else 0
        self.tlast.value = 1 if eol else 0

        while True:
            await RisingEdge(self.i_clk)
            if int(self.tready.value) == 1:
                break

        self._drive_idle()

    async def send_windows(
        self,
        windows: Iterable[Sequence[Sequence[int]]],
    ) -> None:
        """Send multiple windows; asserts SOF on first beat and TLAST on last beat."""
        windows_list = list(windows)
        if not windows_list:
            return

        last_idx = len(windows_list) - 1
        for idx, window in enumerate(windows_list):
            await self.send_window(
                window,
                sof=(idx == 0),
                eol=(idx == last_idx),
            )

    @classmethod
    def load_grayscale_image(cls, image_path: str | Path) -> np.ndarray:
        """Load an image file and return grayscale pixels as `uint8` array `(H, W)`."""
        path = Path(image_path)
        if not path.exists() or not path.is_file():
            raise FileNotFoundError(f"Image file not found: {path}")

        with PILImage.open(path) as image:
            gray = image.convert("L")
            pixels = np.asarray(gray, dtype=np.uint8)

        if pixels.ndim != 2:
            raise ValueError(f"Expected grayscale image shape (H, W), got {pixels.shape}")

        return pixels

    @classmethod
    def _resolve_image_in_folder(
        cls,
        folder_path: str | Path,
        file_name: str | None = None,
    ) -> Path:
        folder = Path(folder_path)
        if not folder.exists() or not folder.is_dir():
            raise FileNotFoundError(f"Image folder not found: {folder}")

        if file_name is not None:
            candidate = folder / file_name
            if not candidate.exists() or not candidate.is_file():
                raise FileNotFoundError(f"Image file not found in folder: {candidate}")
            return candidate

        candidates = sorted(
            p
            for p in folder.iterdir()
            if p.is_file() and p.suffix.lower() in cls._SUPPORTED_EXTENSIONS
        )
        if not candidates:
            raise FileNotFoundError(
                f"No supported image files in {folder}. Supported: {sorted(cls._SUPPORTED_EXTENSIONS)}",
            )
        return candidates[0]

    @classmethod
    def iter_3x3_windows(
        cls,
        gray_pixels: np.ndarray,
    ) -> Iterable[tuple[list[list[int]], bool, bool]]:
        """Yield `(window, sof, eol)` tuples over valid 3x3 windows (drop-border mode)."""
        if gray_pixels.ndim != 2:
            raise ValueError(
                f"Expected grayscale array with shape (H, W), got {gray_pixels.shape}",
            )

        height, width = int(gray_pixels.shape[0]), int(gray_pixels.shape[1])
        if width < cls.WINDOW_SIZE or height < cls.WINDOW_SIZE:
            raise ValueError(
                "Input image is too small for 3x3 windows: "
                f"got {width}x{height}, need at least 3x3",
            )

        out_width = width - (cls.WINDOW_SIZE - 1)
        out_height = height - (cls.WINDOW_SIZE - 1)

        for y in range(out_height):
            for x in range(out_width):
                patch = gray_pixels[y : y + cls.WINDOW_SIZE, x : x + cls.WINDOW_SIZE]
                window = [[int(patch[row, col]) for col in range(cls.WINDOW_SIZE)] for row in range(cls.WINDOW_SIZE)]
                linear_idx = y * out_width + x
                sof = linear_idx == 0
                eol = (x + 1) == out_width
                yield window, sof, eol

    async def send_grayscale_image(self, gray_pixels: np.ndarray) -> None:
        """Convert grayscale image to 3x3 windows and stream them over AXI."""
        for window, sof, eol in self.iter_3x3_windows(gray_pixels):
            await self.send_window(window, sof=sof, eol=eol)

    async def send_image_file(self, image_path: str | Path) -> None:
        """Load image from file, grayscale it, and stream as 3x3 AXI windows."""
        gray_pixels = self.load_grayscale_image(image_path)
        await self.send_grayscale_image(gray_pixels)

    async def send_image_from_folder(
        self,
        folder_path: str | Path,
        file_name: str | None = None,
    ) -> None:
        """Load image from folder, grayscale it, and stream as 3x3 AXI windows.

        If `file_name` is omitted, the lexicographically first supported image file is used.
        """
        image_path = self._resolve_image_in_folder(folder_path, file_name=file_name)
        await self.send_image_file(image_path)
