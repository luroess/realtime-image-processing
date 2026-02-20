"""AXI window-generator + FAST filter cocotb tests."""

from __future__ import annotations

from pathlib import Path

import cocotb
import numpy as np
from cocotb.clock import Clock
from common.fast_reference import (
    _assert_plane_equal,
    _fast_expected,
    _read_binary_generic,
    _read_positive_generic,
)
from common.reset import apply_reset
from drivers.axis_gray_source import AxiGrayStreamSource
from models.image_model import Image
from monitors.axis_gray_sink import AxiGrayStreamSink

ACLK_SIGNAL = "i_aclk"
ARESETN_SIGNAL = "i_aresetn"
PASS_THROUGH_SIGNAL = "i_pass_through"
S_AXIS_PREFIX = "s_axis_gray8"
M_AXIS_PREFIX = "m_axis_filter8"
RESET_ACTIVE_LEVEL = False

FAST_THRESHOLD = 20
FAST_N = 9
KERNEL_SIZE = 7
FRAME_WIDTH = 128
FRAME_HEIGHT = 128


def _gray_plane_to_image(gray_plane: np.ndarray) -> Image:
    gray_u8 = gray_plane.astype(np.uint8)
    rgb = np.stack((gray_u8, gray_u8, gray_u8), axis=2)
    return Image(rgb)


def _warmup_beats(*, width: int, wndw_size: int) -> int:
    return ((width + 1) * ((wndw_size - 1) // 2)) + 1


def _frame_geometry_from_dut(dut) -> tuple[int, int]:
    width = _read_positive_generic(dut, "G_LINE_WIDTH", FRAME_WIDTH)
    height = _read_positive_generic(dut, "G_NUM_ROW", FRAME_HEIGHT)
    return width, height


def _fast_mode_from_dut(dut) -> tuple[int, int, bool]:
    threshold = _read_positive_generic(dut, "G_FAST_THRESHOLD", FAST_THRESHOLD)
    n_contiguous = _read_positive_generic(dut, "G_FAST_N", FAST_N)
    enable_nms = _read_binary_generic(dut, "G_FAST_ENABLE_NMS", False)
    return threshold, n_contiguous, enable_nms


async def run_wrapper_case(dut, gray_plane: np.ndarray, *, pass_through: bool = False) -> None:
    if gray_plane.ndim != 2:
        raise ValueError(
            f"Expected gray plane with shape (H, W), got shape={gray_plane.shape}",
        )

    width, height = _frame_geometry_from_dut(dut)
    if gray_plane.shape != (height, width):
        raise AssertionError(
            "Input plane shape must match DUT geometry: "
            f"input={gray_plane.shape}, dut={(height, width)}",
        )

    i_clk = getattr(dut, ACLK_SIGNAL)
    i_rst_n = getattr(dut, ARESETN_SIGNAL)
    i_pass_through = getattr(dut, PASS_THROUGH_SIGNAL)

    i_rst_n.value = int(RESET_ACTIVE_LEVEL)
    getattr(dut, f"{S_AXIS_PREFIX}_tvalid").value = 0
    getattr(dut, f"{S_AXIS_PREFIX}_tdata").value = 0
    getattr(dut, f"{S_AXIS_PREFIX}_tlast").value = 0
    getattr(dut, f"{S_AXIS_PREFIX}_tuser").value = 0
    i_pass_through.value = int(pass_through)
    getattr(dut, f"{M_AXIS_PREFIX}_tready").value = 0

    cocotb.start_soon(Clock(i_clk, 10, unit="ns").start())
    await apply_reset(
        dut=dut,
        i_clk=i_clk,
        i_rst_n=i_rst_n,
        stream_input_prefix=S_AXIS_PREFIX,
        reset_active_level=RESET_ACTIVE_LEVEL,
    )

    source = AxiGrayStreamSource(
        dut=dut,
        i_clk=i_clk,
        i_rst_n=i_rst_n,
        prefix=S_AXIS_PREFIX,
        reset_active_level=RESET_ACTIVE_LEVEL,
    )
    sink = AxiGrayStreamSink(
        dut=dut,
        i_clk=i_clk,
        i_rst_n=i_rst_n,
        prefix=M_AXIS_PREFIX,
        reset_active_level=RESET_ACTIVE_LEVEL,
    )
    getattr(dut, f"{M_AXIS_PREFIX}_tready").value = 1

    if pass_through:
        expected = gray_plane
        flush_pixels = 0
    else:
        threshold, n_contiguous, enable_nms = _fast_mode_from_dut(dut)
        expected = _fast_expected(
            gray_plane,
            threshold=threshold,
            n_contiguous=n_contiguous,
            enable_nms=enable_nms,
        )
        flush_pixels = _warmup_beats(width=width, wndw_size=KERNEL_SIZE)

    await source.send_image(
        _gray_plane_to_image(gray_plane),
        tail_padding_pixels=flush_pixels,
    )

    timeout_ns = max(500_000, width * height * 180)
    received = await sink.recv_plane(width=width, height=height, timeout_ns=timeout_ns)
    _assert_plane_equal(expected, received)


@cocotb.test(timeout_time=220, timeout_unit="ms")
async def test_axi_fast_window_module_gradient(dut) -> None:
    width, height = _frame_geometry_from_dut(dut)
    image = Image.gradient_gray(width=width, height=height)
    gray = image.pixels[:, :, 0]
    await run_wrapper_case(dut, gray)


@cocotb.test(timeout_time=220, timeout_unit="ms")
async def test_axi_fast_window_module_passthrough(dut) -> None:
    width, height = _frame_geometry_from_dut(dut)
    y, x = np.indices((height, width), dtype=np.int32)
    board = ((x // 2) + (y // 2)) & 1
    gray = (board * 255).astype(np.uint8)
    await run_wrapper_case(dut, gray, pass_through=True)
