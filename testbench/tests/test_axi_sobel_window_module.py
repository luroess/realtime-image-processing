"""AXI window-generator + Sobel filter cocotb tests."""

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
from monitors.axis_video_sink import AxiVideoStreamSink

ACLK_SIGNAL = "i_aclk"
ARESETN_SIGNAL = "i_aresetn"
PASS_THROUGH_SIGNAL = "i_pass_through"
S_AXIS_PREFIX = "s_axis_gray8"
M_AXIS_PREFIX = "m_axis_rbg888"
PIXEL_ORDER = "rbg"
RESET_ACTIVE_LEVEL = False
SOBEL_THRESHOLD = 200
SOBEL_MEAN_SHIFT = 4
SOBEL_MEAN_UPDATE_INTERVAL = 1
SOBEL_THRESHOLD_GAIN_NUM = 1
SOBEL_THRESHOLD_GAIN_DEN = 1
SOBEL_THRESHOLD_OFFSET = 0
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


def _clamp(value: int, lo: int, hi: int) -> int:
    if value < lo:
        return lo
    if value > hi:
        return hi
    return value


def _trunc_div_towards_zero(numerator: int, denominator: int) -> int:
    if numerator >= 0:
        return numerator // denominator
    return -((-numerator) // denominator)


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


def _resolve_sobel_model_params(dut) -> dict[str, int]:
    pixel_width = _dut_generic_int(dut, "G_PIXEL_WIDTH", 8)
    threshold_max_default = 8 * ((2 ** pixel_width) - 1)
    return {
        "threshold": _dut_generic_int(dut, "G_SOBEL_THRESHOLD", SOBEL_THRESHOLD),
        "mean_shift": _dut_generic_int(dut, "G_SOBEL_MEAN_SHIFT", SOBEL_MEAN_SHIFT),
        "mean_update_interval": _dut_generic_int(
            dut,
            "G_SOBEL_MEAN_UPDATE_INTERVAL",
            SOBEL_MEAN_UPDATE_INTERVAL,
        ),
        "gain_num": _dut_generic_int(dut, "G_SOBEL_THRESHOLD_GAIN_NUM", SOBEL_THRESHOLD_GAIN_NUM),
        "gain_den": _dut_generic_int(dut, "G_SOBEL_THRESHOLD_GAIN_DEN", SOBEL_THRESHOLD_GAIN_DEN),
        "offset": _dut_generic_int(dut, "G_SOBEL_THRESHOLD_OFFSET", SOBEL_THRESHOLD_OFFSET),
        "threshold_min": 0,
        "threshold_max": threshold_max_default,
    }


def _sobel_expected(
    gray_plane: np.ndarray,
    *,
    threshold: int = SOBEL_THRESHOLD,
    mean_shift: int = SOBEL_MEAN_SHIFT,
    mean_update_interval: int = SOBEL_MEAN_UPDATE_INTERVAL,
    gain_num: int = SOBEL_THRESHOLD_GAIN_NUM,
    gain_den: int = SOBEL_THRESHOLD_GAIN_DEN,
    offset: int = SOBEL_THRESHOLD_OFFSET,
    threshold_min: int = 0,
    threshold_max: int = (8 * ((2 ** 8) - 1)),
) -> np.ndarray:
    height, width = gray_plane.shape
    padded = np.pad(gray_plane.astype(np.int16), ((1, 1), (1, 1)), mode="constant")
    out = np.zeros((height, width), dtype=np.uint8)
    mean = _clamp(int(threshold), 0, int(threshold_max))
    alpha_div = 1 << int(mean_shift)
    update_interval = max(1, int(mean_update_interval))
    update_counter = 0
    gain_den_safe = max(1, int(gain_den))

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
            mag = abs(gx) + abs(gy)

            adaptive_threshold = (
                (mean * int(gain_num)) // gain_den_safe
            ) + int(offset)
            adaptive_threshold = _clamp(
                adaptive_threshold,
                int(threshold_min),
                int(threshold_max),
            )

            out[y, x] = 255 if mag >= adaptive_threshold else 0

            if update_counter == (update_interval - 1):
                delta = mag - mean
                step = (
                    _trunc_div_towards_zero(delta, alpha_div)
                    if alpha_div > 1
                    else delta
                )
                mean = _clamp(mean + step, 0, int(threshold_max))
                update_counter = 0
            else:
                update_counter += 1

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


def _assert_rgb_equal(expected: np.ndarray, received: np.ndarray) -> None:
    if expected.shape != received.shape:
        raise AssertionError(
            f"Shape mismatch: expected={expected.shape}, received={received.shape}",
        )
    if np.array_equal(expected, received):
        return

    y, x = np.argwhere(np.any(expected != received, axis=2))[0]
    raise AssertionError(
        f"First mismatch at (x={int(x)}, y={int(y)}): "
        f"expected={expected[y, x].tolist()}, received={received[y, x].tolist()}",
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
    sink = AxiVideoStreamSink(
        dut=dut,
        i_clk=i_clk,
        i_rst_n=i_rst_n,
        prefix=M_AXIS_PREFIX,
        reset_active_level=RESET_ACTIVE_LEVEL,
        pixel_order=PIXEL_ORDER,
    )

    if source_pause_pattern is not None:
        source.set_pause_generator(repeating_pause(source_pause_pattern))
    if sink_pause_pattern is not None:
        sink.set_pause_generator(repeating_pause(sink_pause_pattern))

    m_axis_tready.value = 1

    if pass_through:
        expected = gray_plane
    else:
        model = _resolve_sobel_model_params(dut)
        expected = _sobel_expected(
            gray_plane,
            threshold=model["threshold"],
            mean_shift=model["mean_shift"],
            mean_update_interval=model["mean_update_interval"],
            gain_num=model["gain_num"],
            gain_den=model["gain_den"],
            offset=model["offset"],
            threshold_min=model["threshold_min"],
            threshold_max=model["threshold_max"],
        )
    expected_rgb = np.stack((expected, expected, expected), axis=2)
    flush_pixels = 0 if pass_through else _warmup_beats(width=gray_plane.shape[1], wndw_size=3)

    await source.send_image(
        _gray_plane_to_image(gray_plane),
        tail_padding_pixels=flush_pixels,
    )

    height, width = gray_plane.shape
    timeout_ns = max(10_000_000, width * height * 250)
    received = await sink.recv_image(width=width, height=height, timeout_ns=timeout_ns)
    _assert_rgb_equal(expected_rgb, received.pixels)

    if output_path is not None:
        Image(received.pixels).to_png(output_path)


@cocotb.test(timeout_time=150, timeout_unit="ms")
async def test_axi_sobel_window_module_simple_image(dut) -> None:
    width, height = _frame_shape_from_dut(dut)
    image = Image.gradient_gray(width=width, height=height)
    gray = image.pixels[:, :, 0]
    await run_wrapper_case(dut, gray)


@cocotb.test(timeout_time=250, timeout_unit="ms")
async def test_axi_sobel_window_module_lenna_end_to_end(dut) -> None:
    input_path = TESTBENCH_ROOT / "images" / "lenna_512_512.png"
    output_path = _sim_artifact_dir() / "lenna_512_512_out_window_module_sobel.png"

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
async def test_axi_sobel_window_module_passthrough_gray(dut) -> None:
    width, height = _frame_shape_from_dut(dut)
    image = Image.gradient_gray(width=width, height=height)
    gray = image.pixels[:, :, 0]
    await run_wrapper_case(dut, gray, pass_through=True)


@cocotb.test(timeout_time=700, timeout_unit="ms")
async def test_axi_sobel_window_module_backpressure_filter_mode(dut) -> None:
    width, height = _frame_shape_from_dut(dut)
    image = Image.gradient_gray(width=width, height=height)
    gray = image.pixels[:, :, 0]
    await run_wrapper_case(
        dut,
        gray,
        pass_through=False,
        source_pause_pattern=(0, 1, 0, 0, 1, 0, 1, 0),
        sink_pause_pattern=(0, 0, 1, 0, 1, 0, 0),
    )


@cocotb.test(timeout_time=700, timeout_unit="ms")
async def test_axi_sobel_window_module_backpressure_passthrough_mode(dut) -> None:
    width, height = _frame_shape_from_dut(dut)
    image = Image.gradient_gray(width=width, height=height)
    gray = image.pixels[:, :, 0]
    await run_wrapper_case(
        dut,
        gray,
        pass_through=True,
        source_pause_pattern=(0, 1, 0, 0, 1, 0, 1, 0),
        sink_pause_pattern=(0, 0, 1, 0, 1, 0, 0),
    )


@cocotb.test(timeout_time=900, timeout_unit="ms")
async def test_axi_sobel_window_module_backpressure_mode_switch_passthrough_to_filter(dut) -> None:
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
    sink = AxiVideoStreamSink(
        dut=dut,
        i_clk=i_clk,
        i_rst_n=i_rst_n,
        prefix=M_AXIS_PREFIX,
        reset_active_level=RESET_ACTIVE_LEVEL,
        pixel_order=PIXEL_ORDER,
    )
    source.set_pause_generator(repeating_pause((0, 1, 0, 0, 1, 0, 1, 0)))
    sink.set_pause_generator(repeating_pause((0, 0, 1, 0, 1, 0, 0)))
    m_axis_tready.value = 1

    width, height = _frame_shape_from_dut(dut)
    frame0 = Image.gradient_gray(width=width, height=height).pixels[:, :, 0]
    frame1 = np.roll(frame0, shift=11, axis=1)
    timeout_ns = max(12_000_000, width * height * 300)

    # Frame 0: pass-through under pressure.
    i_pass_through.value = 1
    await source.send_image(_gray_plane_to_image(frame0), tail_padding_pixels=0)
    received0 = await sink.recv_image(width=width, height=height, timeout_ns=timeout_ns)
    expected0_rgb = np.stack((frame0, frame0, frame0), axis=2)
    _assert_rgb_equal(expected0_rgb, received0.pixels)

    # Frame 1: switch mode without reset and verify Sobel output.
    i_pass_through.value = 0
    model = _resolve_sobel_model_params(dut)
    expected1 = _sobel_expected(
        frame1,
        threshold=model["threshold"],
        mean_shift=model["mean_shift"],
        mean_update_interval=model["mean_update_interval"],
        gain_num=model["gain_num"],
        gain_den=model["gain_den"],
        offset=model["offset"],
        threshold_min=model["threshold_min"],
        threshold_max=model["threshold_max"],
    )
    expected1_rgb = np.stack((expected1, expected1, expected1), axis=2)
    flush_pixels = _warmup_beats(width=width, wndw_size=3)
    await source.send_image(_gray_plane_to_image(frame1), tail_padding_pixels=flush_pixels)
    received1 = await sink.recv_image(width=width, height=height, timeout_ns=timeout_ns)
    _assert_rgb_equal(expected1_rgb, received1.pixels)


@cocotb.test(timeout_time=900, timeout_unit="ms")
async def test_axi_sobel_window_module_backpressure_mode_switch_filter_to_passthrough(dut) -> None:
    i_clk = getattr(dut, ACLK_SIGNAL)
    i_rst_n = getattr(dut, ARESETN_SIGNAL)
    i_pass_through = getattr(dut, PASS_THROUGH_SIGNAL)
    m_axis_tready = getattr(dut, f"{M_AXIS_PREFIX}_tready")

    i_rst_n.value = int(RESET_ACTIVE_LEVEL)
    getattr(dut, f"{S_AXIS_PREFIX}_tvalid").value = 0
    getattr(dut, f"{S_AXIS_PREFIX}_tdata").value = 0
    getattr(dut, f"{S_AXIS_PREFIX}_tlast").value = 0
    getattr(dut, f"{S_AXIS_PREFIX}_tuser").value = 0
    i_pass_through.value = 0
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
    sink = AxiVideoStreamSink(
        dut=dut,
        i_clk=i_clk,
        i_rst_n=i_rst_n,
        prefix=M_AXIS_PREFIX,
        reset_active_level=RESET_ACTIVE_LEVEL,
        pixel_order=PIXEL_ORDER,
    )
    source.set_pause_generator(repeating_pause((0, 1, 0, 0, 1, 0, 1, 0)))
    sink.set_pause_generator(repeating_pause((0, 0, 1, 0, 1, 0, 0)))
    m_axis_tready.value = 1

    width, height = _frame_shape_from_dut(dut)
    frame0 = Image.gradient_gray(width=width, height=height).pixels[:, :, 0]
    frame1 = np.roll(frame0, shift=7, axis=0)
    timeout_ns = max(12_000_000, width * height * 300)

    # Frame 0: filter branch under pressure.
    i_pass_through.value = 0
    model = _resolve_sobel_model_params(dut)
    expected0 = _sobel_expected(
        frame0,
        threshold=model["threshold"],
        mean_shift=model["mean_shift"],
        mean_update_interval=model["mean_update_interval"],
        gain_num=model["gain_num"],
        gain_den=model["gain_den"],
        offset=model["offset"],
        threshold_min=model["threshold_min"],
        threshold_max=model["threshold_max"],
    )
    expected0_rgb = np.stack((expected0, expected0, expected0), axis=2)
    flush_pixels = _warmup_beats(width=width, wndw_size=3)
    await source.send_image(_gray_plane_to_image(frame0), tail_padding_pixels=flush_pixels)
    received0 = await sink.recv_image(width=width, height=height, timeout_ns=timeout_ns)
    _assert_rgb_equal(expected0_rgb, received0.pixels)

    # Frame 1: switch branch without reset; passthrough branch must stay lockstep.
    i_pass_through.value = 1
    await source.send_image(_gray_plane_to_image(frame1), tail_padding_pixels=0)
    received1 = await sink.recv_image(width=width, height=height, timeout_ns=timeout_ns)
    expected1_rgb = np.stack((frame1, frame1, frame1), axis=2)
    _assert_rgb_equal(expected1_rgb, received1.pixels)
