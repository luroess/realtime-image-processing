"""Isolated exhaustive checks for FrameCompositor core logic."""

from __future__ import annotations

import cocotb
from cocotb.triggers import Timer

C_OVERLAY_NONE = 0b00
C_OVERLAY_FAST = 0b01
C_OVERLAY_SOBEL = 0b10
C_OVERLAY_OTHER = 0b11

C_SOBEL_COLOR = 0xFF0000
C_FAST_COLOR = 0x0000FF


def _expected_rgb(
    *,
    overlay_mode: int,
    base_rgb: int,
    sobel_edge: int,
    fast_edge: int,
) -> int:
    if overlay_mode == C_OVERLAY_SOBEL and sobel_edge == 1:
        return C_SOBEL_COLOR
    if overlay_mode == C_OVERLAY_FAST and fast_edge == 1:
        return C_FAST_COLOR
    return base_rgb


@cocotb.test(timeout_time=2, timeout_unit="ms")
async def test_frame_compositor_all_input_combinations(dut) -> None:
    base_samples = (0x000000, 0x123456, 0xABCDEF, 0xFFFFFF)
    mode_samples = (C_OVERLAY_NONE, C_OVERLAY_FAST, C_OVERLAY_SOBEL, C_OVERLAY_OTHER)
    case_count = 0

    for base_rgb in base_samples:
        for overlay_mode in mode_samples:
            for sobel_edge in (0, 1):
                for fast_edge in (0, 1):
                    dut.i_overlay_mode.value = overlay_mode
                    dut.i_rgb888.value = base_rgb
                    dut.i_sobel_edge.value = sobel_edge
                    dut.i_fast_edge.value = fast_edge

                    await Timer(5, unit="ns")

                    observed = int(dut.o_rgb888.value)
                    expected = _expected_rgb(
                        overlay_mode=overlay_mode,
                        base_rgb=base_rgb,
                        sobel_edge=sobel_edge,
                        fast_edge=fast_edge,
                    )

                    dut._log.info(
                        "core case=%d mode=0b%s base=0x%06X sobel=%d fast=%d -> out=0x%06X expected=0x%06X",
                        case_count,
                        format(overlay_mode, "02b"),
                        base_rgb,
                        sobel_edge,
                        fast_edge,
                        observed,
                        expected,
                    )

                    assert observed == expected, (
                        f"Mismatch at case={case_count}: "
                        f"mode=0b{overlay_mode:02b}, base=0x{base_rgb:06X}, "
                        f"sobel={sobel_edge}, fast={fast_edge}, "
                        f"observed=0x{observed:06X}, expected=0x{expected:06X}"
                    )
                    case_count += 1

    assert case_count == len(base_samples) * len(mode_samples) * 2 * 2
