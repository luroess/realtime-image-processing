"""AXI window-generator + Sobel filter cocotb tests."""

from __future__ import annotations

import os
from pathlib import Path

import cocotb
import numpy as np
from cocotb.clock import Clock
from common.reset import apply_reset
from drivers.axis_gray_source import AxiGrayStreamSource
from models.image_model import Image
from monitors.axis_gray_sink import AxiGrayStreamSink

ACLK_SIGNAL = "i_aclk"
ARESETN_SIGNAL = "i_aresetn"
PASS_THROUGH_SIGNAL = "i_pass_through"
S_AXIS_PREFIX = "s_axis_gray8"
M_AXIS_PREFIX = "m_axis_gray8"
RESET_ACTIVE_LEVEL = False
SOBEL_THRESHOLD = 200
TESTBENCH_ROOT = Path(__file__).resolve().parents[1]
FRAME_WIDTH = 512
FRAME_HEIGHT = 512


def _warmup_beats(*, width: int, wndw_size: int = 3) -> int:
    return ((width + 1) * ((wndw_size - 1) // 2)) + 1


def _sim_artifact_dir() -> Path:
    results_file = os.getenv("COCOTB_RESULTS_FILE")
    if results_file:
        return Path(results_file).resolve().parent
    return TESTBENCH_ROOT / "sim_build" / "test_axi_sobel_window_module"


def _gray_plane_to_image(gray_plane: np.ndarray) -> Image:
    gray_u8 = gray_plane.astype(np.uint8)
    rgb = np.stack((gray_u8, gray_u8, gray_u8), axis=2)
    return Image(rgb)


def _gray_from_rgb(image: Image) -> np.ndarray:
    pixels_u16 = image.pixels.astype(np.uint16)
    r = pixels_u16[:, :, 0]
    g = pixels_u16[:, :, 1]
    b = pixels_u16[:, :, 2]
    return ((r >> 2) + (g >> 1) + (b >> 2)).astype(np.uint8)


def _sobel_expected(
    gray_plane: np.ndarray,
    threshold: int = SOBEL_THRESHOLD,
) -> np.ndarray:
    height, width = gray_plane.shape
    padded = np.pad(gray_plane.astype(np.int16), ((1, 1), (1, 1)), mode="constant")
    out = np.zeros((height, width), dtype=np.uint8)

    for y in range(height):
        for x in range(width):
            p1 = int(padded[y + 0, x + 0])
            p2 = int(padded[y + 0, x + 1])
            p3 = int(padded[y + 0, x + 2])
            p4 = int(padded[y + 1, x + 0])
            p6 = int(padded[y + 1, x + 2])
            p7 = int(padded[y + 2, x + 0])
            p8 = int(padded[y + 2, x + 1])
            p9 = int(padded[y + 2, x + 2])

            gx = (p3 + 2 * p6 + p9) - (p1 + 2 * p4 + p7)
            gy = (p1 + 2 * p2 + p3) - (p7 + 2 * p8 + p9)
            out[y, x] = 255 if (abs(gx) + abs(gy)) >= threshold else 0

    return out


def _assert_plane_equal(expected: np.ndarray, received: np.ndarray) -> None:
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


async def run_wrapper_case(
    dut,
    gray_plane: np.ndarray,
    pass_through: bool = False,
    output_path: Path | None = None,
) -> None:
    i_clk = getattr(dut, ACLK_SIGNAL)
    i_rst_n = getattr(dut, ARESETN_SIGNAL)
    i_pass_through = getattr(dut, PASS_THROUGH_SIGNAL)
    m_axis_tready = getattr(dut, f"{M_AXIS_PREFIX}_tready")

    i_rst_n.value = int(RESET_ACTIVE_LEVEL)
    getattr(dut, f"{S_AXIS_PREFIX}_tvalid").value = 0
    getattr(dut, f"{S_AXIS_PREFIX}_tdata").value = 0
    getattr(dut, f"{S_AXIS_PREFIX}_tlast").value = 0
    getattr(dut, f"{S_AXIS_PREFIX}_tuser").value = 0
    i_pass_through.value = int(pass_through)
    m_axis_tready.value = 0

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
    m_axis_tready.value = 1

    expected = (
        gray_plane
        if pass_through
        else _sobel_expected(gray_plane, threshold=SOBEL_THRESHOLD)
    )
    flush_pixels = (
        0 if pass_through else _warmup_beats(width=gray_plane.shape[1], wndw_size=3)
    )

    await source.send_image(
        _gray_plane_to_image(gray_plane),
        tail_padding_pixels=flush_pixels,
    )

    height, width = gray_plane.shape
    timeout_ns = max(500_000, width * height * 70)
    received = await sink.recv_plane(width=width, height=height, timeout_ns=timeout_ns)
    _assert_plane_equal(expected, received)

    if output_path is not None:
        _gray_plane_to_image(received).to_png(output_path)


@cocotb.test(timeout_time=150, timeout_unit="ms")
async def test_axi_sobel_window_module_simple_image(dut) -> None:
    image = Image.gradient_gray(width=FRAME_WIDTH, height=FRAME_HEIGHT)
    gray = image.pixels[:, :, 0]
    await run_wrapper_case(dut, gray)


@cocotb.test(timeout_time=250, timeout_unit="ms")
async def test_axi_sobel_window_module_lenna_end_to_end(dut) -> None:
    input_path = TESTBENCH_ROOT / "images" / "lenna_512_512.png"
    output_path = _sim_artifact_dir() / "lenna_512_512_out_window_module_sobel.png"

    image = Image.from_png(input_path)
    gray = _gray_from_rgb(image)
    await run_wrapper_case(dut, gray, output_path=output_path)


@cocotb.test(timeout_time=150, timeout_unit="ms")
async def test_axi_sobel_window_module_passthrough_gray(dut) -> None:
    image = Image.gradient_gray(width=FRAME_WIDTH, height=FRAME_HEIGHT)
    gray = image.pixels[:, :, 0]
    await run_wrapper_case(dut, gray, pass_through=True)
