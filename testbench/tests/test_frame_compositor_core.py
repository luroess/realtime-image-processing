"""Isolated exhaustive checks for FrameCompositor core logic."""

from __future__ import annotations

import cocotb
from cocotb.triggers import Timer

C_SOBEL_COLOR = 0xFF0000


def _expected_rgb(*, base_rgb: int, edge_mask: int) -> int:
    return C_SOBEL_COLOR if edge_mask else base_rgb


@cocotb.test(timeout_time=2, timeout_unit="ms")
async def test_frame_compositor_all_input_combinations(dut) -> None:
    base_samples = (0x000000, 0x123456, 0xABCDEF, 0xFFFFFF)
    case_count = 0

    for base_rgb in base_samples:
        for edge_mask in (0, 1):
            dut.i_rgb888.value = base_rgb
            dut.i_edge_mask.value = edge_mask

            await Timer(5, unit="ns")

            observed = int(dut.o_rgb888.value)
            expected = _expected_rgb(
                base_rgb=base_rgb,
                edge_mask=edge_mask,
            )

            dut._log.info(
                "core case=%d base=0x%06X edge=%d -> out=0x%06X expected=0x%06X",
                case_count,
                base_rgb,
                edge_mask,
                observed,
                expected,
            )

            assert observed == expected, (
                f"Mismatch at case={case_count}: "
                f"base=0x{base_rgb:06X}, edge={edge_mask}, "
                f"observed=0x{observed:06X}, expected=0x{expected:06X}"
            )
            case_count += 1

    assert case_count == len(base_samples) * 2
