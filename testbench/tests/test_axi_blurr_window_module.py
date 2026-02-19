"""AXI window-generator + blurr filter cocotb tests."""

from __future__ import annotations

import os
from pathlib import Path

import cocotb
import numpy as np
from cocotb.clock import Clock

from common.pause import repeating_pause
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
TESTBENCH_ROOT = Path(__file__).resolve().parents[1]
FRAME_WIDTH = 512
FRAME_HEIGHT = 512

# Default 3x3 Gaussian used by AXI_BlurrFilter.
GAUSS3X3 = np.array(
    [
        [1, 2, 1],
        [2, 4, 2],
        [1, 2, 1],
    ],
    dtype=np.int16,
)


def _warmup_beats(*, width: int, wndw_size: int = 3) -> int:
    return ((width + 1) * ((wndw_size - 1) // 2)) + 1


def _sim_artifact_dir() -> Path:
    results_file = os.getenv("COCOTB_RESULTS_FILE")
    if results_file:
        return Path(results_file).resolve().parent
    return TESTBENCH_ROOT / "sim_build" / "test_axi_blurr_window_module"


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


def _dut_generic_int(dut, generic_name: str, default: int) -> int:
    handle = getattr(dut, generic_name, None)
    if handle is None:
        return int(default)
    try:
        return int(handle.value)
    except Exception:
        return int(default)


def _frame_shape_from_dut(dut) -> tuple[int, int]:
    width = _dut_generic_int(dut, "G_LINE_WIDTH", FRAME_WIDTH)
    height = _dut_generic_int(dut, "G_NUM_ROW", FRAME_HEIGHT)
    return int(width), int(height)


def _apply_kernel_expected(
    gray_plane: np.ndarray,
    *,
    kernel: np.ndarray,
    normalize_divisor: int,
    bias: int = 0,
) -> np.ndarray:
    height, width = gray_plane.shape
    k_size = int(kernel.shape[0])
    pad = k_size // 2
    padded = np.pad(gray_plane.astype(np.int16), ((pad, pad), (pad, pad)), mode="constant")
    out = np.zeros((height, width), dtype=np.uint8)

    for y in range(height):
        for x in range(width):
            wndw = padded[y : y + k_size, x : x + k_size]
            acc = int(np.sum(wndw * kernel)) + int(bias)

            if normalize_divisor > 1:
                if acc >= 0:
                    acc = (acc + (normalize_divisor // 2)) // normalize_divisor
                else:
                    acc = (acc - (normalize_divisor // 2)) // normalize_divisor

            if acc < 0:
                acc = 0
            elif acc > 255:
                acc = 255

            out[y, x] = acc

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
    source_pause_pattern: tuple[int, ...] | None = None,
    sink_pause_pattern: tuple[int, ...] | None = None,
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

    if source_pause_pattern is not None:
        source.set_pause_generator(repeating_pause(source_pause_pattern))
    if sink_pause_pattern is not None:
        sink.set_pause_generator(repeating_pause(sink_pause_pattern))

    m_axis_tready.value = 1

    expected = (
        gray_plane
        if pass_through
        else _apply_kernel_expected(
            gray_plane,
            kernel=GAUSS3X3,
            normalize_divisor=16,
            bias=0,
        )
    )

    flush_pixels = 0 if pass_through else _warmup_beats(width=gray_plane.shape[1], wndw_size=3)

    await source.send_image(
        _gray_plane_to_image(gray_plane),
        tail_padding_pixels=flush_pixels,
    )

    height, width = gray_plane.shape
    timeout_ns = max(10_000_000, width * height * 250)
    received = await sink.recv_plane(width=width, height=height, timeout_ns=timeout_ns)
    _assert_plane_equal(expected, received)

    if output_path is not None:
        rgb = np.stack((received, received, received), axis=2)
        Image(rgb).to_png(output_path)


@cocotb.test(timeout_time=150, timeout_unit="ms")
async def test_axi_blurr_window_module_simple_image(dut) -> None:
    width, height = _frame_shape_from_dut(dut)
    image = Image.gradient_gray(width=width, height=height)
    gray = image.pixels[:, :, 0]
    await run_wrapper_case(dut, gray)


@cocotb.test(timeout_time=250, timeout_unit="ms")
async def test_axi_blurr_window_module_lenna_end_to_end(dut) -> None:
    input_path = TESTBENCH_ROOT / "images" / "lenna_512_512.png"
    output_path = _sim_artifact_dir() / "lenna_512_512_out_window_module_blurr.png"

    image = Image.from_png(input_path)
    width, height = _frame_shape_from_dut(dut)
    if image.width < width or image.height < height:
        raise AssertionError(
            f"Input image too small for configured frame ({width}, {height}), "
            f"got ({image.width}, {image.height})",
        )
    if image.width != width or image.height != height:
        image = Image(image.pixels[:height, :width, :])
    gray = _gray_from_rgb(image)
    await run_wrapper_case(dut, gray, output_path=output_path)


@cocotb.test(timeout_time=150, timeout_unit="ms")
async def test_axi_blurr_window_module_passthrough_gray(dut) -> None:
    width, height = _frame_shape_from_dut(dut)
    image = Image.gradient_gray(width=width, height=height)
    gray = image.pixels[:, :, 0]
    await run_wrapper_case(dut, gray, pass_through=True)


@cocotb.test(timeout_time=700, timeout_unit="ms")
async def test_axi_blurr_window_module_backpressure_filter_mode(dut) -> None:
    width, height = _frame_shape_from_dut(dut)
    image = Image.gradient_gray(width=width, height=height)
    gray = image.pixels[:, :, 0]
    await run_wrapper_case(
        dut,
        gray,
        pass_through=False,
        source_pause_pattern=(0, 1, 0, 0, 1, 0, 1, 0, 0, 1),
        sink_pause_pattern=(0, 0, 1, 0, 1, 0, 0),
    )


@cocotb.test(timeout_time=700, timeout_unit="ms")
async def test_axi_blurr_window_module_backpressure_passthrough_mode(dut) -> None:
    width, height = _frame_shape_from_dut(dut)
    image = Image.gradient_gray(width=width, height=height)
    gray = image.pixels[:, :, 0]
    await run_wrapper_case(
        dut,
        gray,
        pass_through=True,
        source_pause_pattern=(0, 1, 0, 0, 1, 0, 1, 0, 0, 1),
        sink_pause_pattern=(0, 0, 1, 0, 1, 0, 0),
    )


@cocotb.test(timeout_time=900, timeout_unit="ms")
async def test_axi_blurr_window_module_backpressure_mode_switch_passthrough_to_filter(dut) -> None:
    i_clk = getattr(dut, ACLK_SIGNAL)
    i_rst_n = getattr(dut, ARESETN_SIGNAL)
    i_pass_through = getattr(dut, PASS_THROUGH_SIGNAL)
    m_axis_tready = getattr(dut, f"{M_AXIS_PREFIX}_tready")

    i_rst_n.value = int(RESET_ACTIVE_LEVEL)
    getattr(dut, f"{S_AXIS_PREFIX}_tvalid").value = 0
    getattr(dut, f"{S_AXIS_PREFIX}_tdata").value = 0
    getattr(dut, f"{S_AXIS_PREFIX}_tlast").value = 0
    getattr(dut, f"{S_AXIS_PREFIX}_tuser").value = 0
    i_pass_through.value = 1
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
    source.set_pause_generator(repeating_pause((0, 1, 0, 0, 1, 0, 1, 0, 0, 1)))
    sink.set_pause_generator(repeating_pause((0, 0, 1, 0, 1, 0, 0)))
    m_axis_tready.value = 1

    width, height = _frame_shape_from_dut(dut)
    frame0 = Image.gradient_gray(width=width, height=height).pixels[:, :, 0]
    frame1 = np.roll(frame0, shift=13, axis=1)

    # Frame 0: pass-through branch under pressure.
    i_pass_through.value = 1
    await source.send_image(_gray_plane_to_image(frame0), tail_padding_pixels=0)
    timeout_ns = max(12_000_000, width * height * 300)
    received0 = await sink.recv_plane(width=width, height=height, timeout_ns=timeout_ns)
    _assert_plane_equal(frame0, received0)

    # Frame 1: switch branch without reset; filter branch must still work.
    i_pass_through.value = 0
    expected1 = _apply_kernel_expected(
        frame1,
        kernel=GAUSS3X3,
        normalize_divisor=16,
        bias=0,
    )
    flush_pixels = _warmup_beats(width=width, wndw_size=3)
    await source.send_image(_gray_plane_to_image(frame1), tail_padding_pixels=flush_pixels)
    received1 = await sink.recv_plane(width=width, height=height, timeout_ns=timeout_ns)
    _assert_plane_equal(expected1, received1)
