"""AXI4-Stream Sobel filter cocotb tests."""

from __future__ import annotations

import os
from pathlib import Path

import cocotb
import numpy as np
from cocotb.clock import Clock

from common.reset import apply_reset
from drivers.axis_window_gray_source import AxiWindowGraySource
from models.image_model import Image
from monitors.axis_gray_sink import AxiGrayStreamSink

ACLK_SIGNAL = "i_aclk"
ARESETN_SIGNAL = "i_aresetn"
S_AXIS_PREFIX = "s_axis_video"
M_AXIS_PREFIX = "m_axis_window"
RESET_ACTIVE_LEVEL = False
SOBEL_THRESHOLD = 200
TESTBENCH_ROOT = Path(__file__).resolve().parents[1]


def _sim_artifact_dir() -> Path:
    results_file = os.getenv("COCOTB_RESULTS_FILE")
    if results_file:
        return Path(results_file).resolve().parent
    return TESTBENCH_ROOT / "sim_build" / "test_axi_sobel_filter"


def _gray_from_rgb(image: Image) -> np.ndarray:
    pixels_u16 = image.pixels.astype(np.uint16)
    r = pixels_u16[:, :, 0]
    g = pixels_u16[:, :, 1]
    b = pixels_u16[:, :, 2]
    return ((r >> 2) + (g >> 1) + (b >> 2)).astype(np.uint8)


def _sobel_expected(gray_plane: np.ndarray, threshold: int = SOBEL_THRESHOLD) -> np.ndarray:
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


async def run_sobel_case(
    dut,
    gray_plane: np.ndarray,
    output_path: Path | None = None,
) -> None:
    i_clk = getattr(dut, ACLK_SIGNAL)
    i_rst_n = getattr(dut, ARESETN_SIGNAL)
    m_axis_tready = getattr(dut, f"{M_AXIS_PREFIX}_tready")

    i_rst_n.value = int(RESET_ACTIVE_LEVEL)
    getattr(dut, f"{S_AXIS_PREFIX}_tvalid").value = 0
    getattr(dut, f"{S_AXIS_PREFIX}_tdata").value = 0
    getattr(dut, f"{S_AXIS_PREFIX}_tlast").value = 0
    getattr(dut, f"{S_AXIS_PREFIX}_tuser").value = 0
    m_axis_tready.value = 0

    cocotb.start_soon(Clock(i_clk, 10, unit="ns").start())
    await apply_reset(
        dut=dut,
        i_clk=i_clk,
        i_rst_n=i_rst_n,
        stream_input_prefix=S_AXIS_PREFIX,
        reset_active_level=RESET_ACTIVE_LEVEL,
    )

    source = AxiWindowGraySource(
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

    expected = _sobel_expected(gray_plane, threshold=SOBEL_THRESHOLD)
    await source.send_gray_image(gray_plane)

    height, width = gray_plane.shape
    timeout_ns = max(200_000, width * height * 60)
    received = await sink.recv_plane(width=width, height=height, timeout_ns=timeout_ns)
    _assert_plane_equal(expected, received)

    if output_path is not None:
        rgb = np.stack((received, received, received), axis=2)
        Image(rgb).to_png(output_path)


@cocotb.test()
async def test_axi_sobel_filter_gradient_gray_windows(dut) -> None:
    image = Image.gradient_gray(width=5, height=5)
    gray = image.pixels[:, :, 0]
    await run_sobel_case(dut, gray)


@cocotb.test(timeout_time=120, timeout_unit="ms")
async def test_axi_sobel_filter_lenna_end_to_end(dut) -> None:
    input_path = TESTBENCH_ROOT / "images" / "lenna_512_512.png"
    output_path = _sim_artifact_dir() / "lenna_512_512_out_sobel.png"

    image = Image.from_png(input_path)
    gray = _gray_from_rgb(image)
    await run_sobel_case(dut, gray, output_path=output_path)
