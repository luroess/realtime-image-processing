"""Monitor for 8-bit AXI lowpass output stream."""

from __future__ import annotations

import numpy as np
from cocotb.triggers import RisingEdge, SimTimeoutError, with_timeout


class AxisLowpassMonitor:
    """Capture lowpass AXI stream and decode one 8-bit pixel per accepted beat."""

    def __init__(
        self,
        dut,
        i_clk,
        i_rst_n,
        prefix: str = "m_axis_lowpass",
        reset_active_level: int = 0,
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

        self.tready.value = 0

    def _in_reset(self) -> bool:
        return int(self.i_rst_n.value) == self.reset_active_level

    async def recv_image(
        self,
        width: int,
        height: int,
        *,
        timeout_ns: int = 500_000,
        check_sidebands: bool = True,
    ) -> np.ndarray:
        """Receive one output image of size `(height, width)` from AXI stream."""
        if width <= 0 or height <= 0:
            raise ValueError(f"Invalid image size: width={width}, height={height}")

        expected_beats = width * height
        pixels: list[int] = []

        self.tready.value = 1
        try:
            while len(pixels) < expected_beats:
                try:
                    await with_timeout(RisingEdge(self.i_clk), timeout_ns, "ns")
                except SimTimeoutError as exc:
                    raise AssertionError(
                        "Timed out waiting for lowpass output beat "
                        f"{len(pixels) + 1}/{expected_beats}",
                    ) from exc

                if self._in_reset():
                    pixels.clear()
                    continue

                if int(self.tvalid.value) != 1 or int(self.tready.value) != 1:
                    continue

                pixel_value = int(self.tdata.value)
                if pixel_value < 0 or pixel_value > 0xFF:
                    raise AssertionError(f"Received non-8-bit lowpass pixel value: {pixel_value}")

                if check_sidebands:
                    beat_index = len(pixels)
                    expected_sof = 1 if beat_index == 0 else 0
                    observed_sof = int(self.tuser.value)
                    if observed_sof != expected_sof:
                        raise AssertionError(
                            "SOF/TUSER mismatch on lowpass output beat "
                            f"{beat_index}: observed={observed_sof}, expected={expected_sof}",
                        )

                    expected_tlast = 1 if ((beat_index + 1) % width) == 0 else 0
                    observed_tlast = int(self.tlast.value)
                    if observed_tlast != expected_tlast:
                        raise AssertionError(
                            "EOL/TLAST mismatch on lowpass output beat "
                            f"{beat_index}: observed={observed_tlast}, expected={expected_tlast}",
                        )

                pixels.append(pixel_value)
        finally:
            self.tready.value = 0

        return np.asarray(pixels, dtype=np.uint8).reshape(height, width)
