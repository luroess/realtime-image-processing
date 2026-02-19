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
S_AXIS_PREFIX = "s_axis_window"
M_AXIS_PREFIX = "m_axis_filter8"
RESET_ACTIVE_LEVEL = False
SOBEL_THRESHOLD = 200
SOBEL_MEAN_SHIFT = 4
SOBEL_MEAN_UPDATE_INTERVAL = 1
SOBEL_THRESHOLD_GAIN_NUM = 1
SOBEL_THRESHOLD_GAIN_DEN = 1
SOBEL_THRESHOLD_OFFSET = 0
PIXEL_WIDTH = 8
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


def _resolve_sobel_model_params(dut) -> dict[str, int]:
    pixel_width = _dut_generic_int(dut, "G_PIXEL_WIDTH", PIXEL_WIDTH)
    threshold_max_default = 8 * ((2 ** pixel_width) - 1)
    return {
        "threshold": _dut_generic_int(dut, "G_SOBEL_THRESHOLD", SOBEL_THRESHOLD),
        "mean_shift": _dut_generic_int(dut, "G_MEAN_SHIFT", SOBEL_MEAN_SHIFT),
        "mean_update_interval": _dut_generic_int(
            dut,
            "G_MEAN_UPDATE_INTERVAL",
            SOBEL_MEAN_UPDATE_INTERVAL,
        ),
        "gain_num": _dut_generic_int(dut, "G_THRESHOLD_GAIN_NUM", SOBEL_THRESHOLD_GAIN_NUM),
        "gain_den": _dut_generic_int(dut, "G_THRESHOLD_GAIN_DEN", SOBEL_THRESHOLD_GAIN_DEN),
        "offset": _dut_generic_int(dut, "G_THRESHOLD_OFFSET", SOBEL_THRESHOLD_OFFSET),
        "threshold_min": 0,
        "threshold_max": threshold_max_default,
    }


def _sobel_expected(
    gray_plane: np.ndarray,
    *,
    threshold: int,
    mean_shift: int,
    mean_update_interval: int,
    gain_num: int,
    gain_den: int,
    offset: int,
    threshold_min: int,
    threshold_max: int,
) -> np.ndarray:
    out, _, _ = _sobel_expected_with_mean(
        gray_plane,
        mean_start=threshold,
        mean_shift=mean_shift,
        update_counter_start=0,
        mean_update_interval=mean_update_interval,
        gain_num=gain_num,
        gain_den=gain_den,
        offset=offset,
        threshold_min=threshold_min,
        threshold_max=threshold_max,
    )
    return out


def _sobel_expected_with_mean(
    gray_plane: np.ndarray,
    *,
    mean_start: int,
    mean_shift: int,
    update_counter_start: int = 0,
    mean_update_interval: int,
    gain_num: int,
    gain_den: int,
    offset: int,
    threshold_min: int,
    threshold_max: int,
) -> tuple[np.ndarray, int, int]:
    height, width = gray_plane.shape
    padded = np.pad(gray_plane.astype(np.int16), ((1, 1), (1, 1)), mode="constant")
    out = np.zeros((height, width), dtype=np.uint8)
    mean = _clamp(int(mean_start), 0, int(threshold_max))
    alpha_div = 1 << int(mean_shift)
    update_interval = max(1, int(mean_update_interval))
    update_counter = int(update_counter_start) % update_interval

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
                (mean * int(gain_num)) // int(gain_den)
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

    return out, mean, update_counter


def _adaptive_threshold_from_mean(
    *,
    mean: int,
    gain_num: int,
    gain_den: int,
    offset: int,
    threshold_min: int,
    threshold_max: int,
) -> int:
    threshold = ((int(mean) * int(gain_num)) // int(gain_den)) + int(offset)
    return _clamp(threshold, int(threshold_min), int(threshold_max))


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


@cocotb.test(timeout_time=400, timeout_unit="ms")
async def test_axi_sobel_filter_lenna_adaptive_10_iterations(dut) -> None:
    input_path = TESTBENCH_ROOT / "images" / "lenna_512_512.png"
    output_dir = _sim_artifact_dir()
    output_dir.mkdir(parents=True, exist_ok=True)

    image = Image.from_png(input_path)
    gray = _gray_from_rgb(image)
    height, width = gray.shape

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

    model = _resolve_sobel_model_params(dut)
    mean_model = model["threshold"]
    update_counter_model = 0
    timeout_ns = max(250_000, width * height * 60)
    dut._log.info(
        "Adaptive Sobel model params: threshold_init=%d, mean_shift=%d, update_interval=%d, gain=%d/%d, offset=%d, clamp=[%d,%d]",
        model["threshold"],
        model["mean_shift"],
        model["mean_update_interval"],
        model["gain_num"],
        model["gain_den"],
        model["offset"],
        model["threshold_min"],
        model["threshold_max"],
    )

    for iteration in range(10):
        mean_start = mean_model
        threshold_start = _adaptive_threshold_from_mean(
            mean=mean_start,
            gain_num=model["gain_num"],
            gain_den=model["gain_den"],
            offset=model["offset"],
            threshold_min=model["threshold_min"],
            threshold_max=model["threshold_max"],
        )
        expected, mean_model, update_counter_model = _sobel_expected_with_mean(
            gray,
            mean_start=mean_start,
            mean_shift=model["mean_shift"],
            update_counter_start=update_counter_model,
            mean_update_interval=model["mean_update_interval"],
            gain_num=model["gain_num"],
            gain_den=model["gain_den"],
            offset=model["offset"],
            threshold_min=model["threshold_min"],
            threshold_max=model["threshold_max"],
        )
        threshold_end = _adaptive_threshold_from_mean(
            mean=mean_model,
            gain_num=model["gain_num"],
            gain_den=model["gain_den"],
            offset=model["offset"],
            threshold_min=model["threshold_min"],
            threshold_max=model["threshold_max"],
        )
        await source.send_gray_image(gray)
        received = await sink.recv_plane(
            width=width,
            height=height,
            timeout_ns=timeout_ns,
        )
        _assert_plane_equal(expected, received)

        rgb = np.stack((received, received, received), axis=2)
        output_path = output_dir / f"lenna_512_512_out_sobel_iter_{iteration:02d}.png"
        Image(rgb).to_png(output_path)
        dut._log.info(
            "Adaptive Sobel iteration %d/10 saved to %s (nonzero=%d, mean_start=%d, threshold_start=%d, mean_end=%d, threshold_end=%d, update_counter_end=%d)",
            iteration + 1,
            output_path,
            int(np.count_nonzero(received)),
            mean_start,
            threshold_start,
            mean_model,
            threshold_end,
            update_counter_model,
        )
