"""Full RGB->gray->blurr->sobel->overlay pipeline integration tests."""

from __future__ import annotations

import os
from pathlib import Path

import cocotb
import numpy as np
from cocotb.clock import Clock
from cocotb.triggers import Timer
from common.pause import repeating_pause
from common.reset import apply_reset
from drivers.axis_video_source import AxiVideoStreamSource
from models.image_model import Image
from monitors.axis_video_sink import AxiVideoStreamSink

ACLK_SIGNAL = "i_aclk"
ARESETN_SIGNAL = "i_aresetn"
BTN_SIGNAL = "i_btn"
S_AXIS_PREFIX = "s_axis_video_rbg888"
M_AXIS_PREFIX = "m_axis_video_rbg888"
RESET_ACTIVE_LEVEL = False
PIXEL_ORDER = "rbg"
TESTBENCH_ROOT = Path(__file__).resolve().parents[1]
FRAME_WIDTH = 512
FRAME_HEIGHT = 512


def _ensure_clock_started(dut, i_clk) -> None:
    task = getattr(dut, "_axi_pipeline_clock_task", None)
    if task is not None:
        try:
            if not task.done():
                return
        except Exception:
            pass

    task = cocotb.start_soon(Clock(i_clk, 10, unit="ns").start())
    dut._axi_pipeline_clock_task = task


def _sim_artifact_dir() -> Path:
    results_file = os.getenv("COCOTB_RESULTS_FILE")
    if results_file:
        return Path(results_file).resolve().parent
    return TESTBENCH_ROOT / "sim_build" / "test_axi_pipeline"


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


def _warmup_beats(*, width: int, wndw_size: int = 3) -> int:
    return ((width + 1) * ((wndw_size - 1) // 2)) + 1


def _full_frame_image(dut) -> Image:
    width, height = _frame_shape_from_dut(dut)
    image_path = TESTBENCH_ROOT / "images" / "lenna_512_512.png"
    image = Image.from_png(image_path)
    if image.width < width or image.height < height:
        raise AssertionError(
            f"Input image too small for configured frame ({width}, {height}), "
            f"got ({image.width}, {image.height}) from {image_path}",
        )
    if image.width == width and image.height == height:
        return image
    return Image(image.pixels[:height, :width, :])


def _gray_from_rgb(image: Image) -> np.ndarray:
    pixels_u16 = image.pixels.astype(np.uint16)
    r = pixels_u16[:, :, 0]
    g = pixels_u16[:, :, 1]
    b = pixels_u16[:, :, 2]
    return ((r >> 2) + (g >> 1) + (b >> 2)).astype(np.uint8)


def _rgb_from_gray(gray_plane: np.ndarray) -> np.ndarray:
    gray_u8 = gray_plane.astype(np.uint8)
    return np.stack((gray_u8, gray_u8, gray_u8), axis=2)


def _assert_rgb_equal(
    expected: np.ndarray,
    received: np.ndarray,
    *,
    label: str,
) -> None:
    if expected.shape != received.shape:
        raise AssertionError(
            f"{label}: shape mismatch expected={expected.shape}, received={received.shape}",
        )
    if np.array_equal(expected, received):
        return

    y, x = np.argwhere(np.any(expected != received, axis=2))[0]
    raise AssertionError(
        f"{label}: first mismatch at (x={int(x)}, y={int(y)}), "
        f"expected={expected[y, x].tolist()}, received={received[y, x].tolist()}",
    )


def _assert_rgb_is_grayscale(image: Image, *, label: str) -> None:
    pixels = image.pixels
    gray_mask = (pixels[:, :, 0] == pixels[:, :, 1]) & (
        pixels[:, :, 1] == pixels[:, :, 2]
    )
    if np.all(gray_mask):
        return

    y, x = np.argwhere(~gray_mask)[0]
    raise AssertionError(
        f"{label}: pixel is not grayscale at (x={int(x)}, y={int(y)}), value={pixels[y, x].tolist()}",
    )


async def _pulse_button_once(dut, *, high_ns: int = 220, low_ns: int = 220) -> None:
    btn = getattr(dut, BTN_SIGNAL)
    btn.value = 1
    await Timer(high_ns, unit="ns")
    btn.value = 0
    await Timer(low_ns, unit="ns")


async def _set_click_state(dut, *, clicks: int) -> None:
    for _ in range(clicks):
        await _pulse_button_once(dut)


async def _run_pipeline_case(
    dut,
    *,
    image: Image,
    clicks: int,
    warmup_stages: int,
    source_pause_pattern: tuple[int, ...] | None = None,
    sink_pause_pattern: tuple[int, ...] | None = None,
) -> Image:
    i_aclk = getattr(dut, ACLK_SIGNAL)
    i_aresetn = getattr(dut, ARESETN_SIGNAL)
    i_btn = getattr(dut, BTN_SIGNAL)

    i_aresetn.value = int(RESET_ACTIVE_LEVEL)
    i_btn.value = 0
    getattr(dut, f"{S_AXIS_PREFIX}_tvalid").value = 0
    getattr(dut, f"{S_AXIS_PREFIX}_tdata").value = 0
    getattr(dut, f"{S_AXIS_PREFIX}_tlast").value = 0
    getattr(dut, f"{S_AXIS_PREFIX}_tuser").value = 0

    _ensure_clock_started(dut, i_aclk)
    await apply_reset(
        dut=dut,
        i_clk=i_aclk,
        i_rst_n=i_aresetn,
        stream_input_prefix=S_AXIS_PREFIX,
        reset_active_level=RESET_ACTIVE_LEVEL,
    )

    source = AxiVideoStreamSource(
        dut=dut,
        i_clk=i_aclk,
        i_rst_n=i_aresetn,
        prefix=S_AXIS_PREFIX,
        reset_active_level=RESET_ACTIVE_LEVEL,
        pixel_order=PIXEL_ORDER,
    )
    sink = AxiVideoStreamSink(
        dut=dut,
        i_clk=i_aclk,
        i_rst_n=i_aresetn,
        prefix=M_AXIS_PREFIX,
        reset_active_level=RESET_ACTIVE_LEVEL,
        pixel_order=PIXEL_ORDER,
    )

    if source_pause_pattern is not None:
        source.set_pause_generator(repeating_pause(source_pause_pattern))
    if sink_pause_pattern is not None:
        sink.set_pause_generator(repeating_pause(sink_pause_pattern))

    await _set_click_state(dut, clicks=clicks)

    flush_pixels = warmup_stages * _warmup_beats(width=image.width, wndw_size=3)
    dut._log.info(
        "Pipeline case start: clicks=%d warmup_stages=%d flush_pixels=%d size=%dx%d",
        clicks,
        warmup_stages,
        flush_pixels,
        image.width,
        image.height,
    )
    dut._log.info("Pipeline case: send_image begin")
    await source.send_image(
        image,
        tail_padding_pixels=flush_pixels,
    )
    dut._log.info("Pipeline case: send_image complete")

    timeout_ns = max(200_000, image.width * 200)
    dut._log.info("Pipeline case: recv_image begin (timeout_ns=%d)", timeout_ns)
    received = await sink.recv_image(
        width=image.width,
        height=image.height,
        timeout_ns=timeout_ns,
    )
    dut._log.info("Pipeline case: recv_image complete")
    return received


@cocotb.test(timeout_time=240, timeout_unit="ms")
async def test_pipeline_full_chain_state_progression(dut) -> None:
    image = _full_frame_image(dut)

    dut._log.info("Pipeline state progression: starting passthrough case")
    passthrough = await _run_pipeline_case(
        dut,
        image=image,
        clicks=0,
        warmup_stages=0,
    )
    dut._log.info("Pipeline state progression: passthrough case completed")
    gray_expected = _rgb_from_gray(_gray_from_rgb(image))
    _assert_rgb_equal(gray_expected, passthrough.pixels, label="passthrough state")

    dut._log.info("Pipeline state progression: starting grayscale case")
    grayscale = await _run_pipeline_case(
        dut,
        image=image,
        clicks=1,
        warmup_stages=0,
    )
    dut._log.info("Pipeline state progression: grayscale case completed")
    gray_expected = _rgb_from_gray(_gray_from_rgb(image))
    _assert_rgb_equal(gray_expected, grayscale.pixels, label="grayscale state")

    dut._log.info("Pipeline state progression: starting blurr case")
    blurr = await _run_pipeline_case(
        dut,
        image=image,
        clicks=2,
        warmup_stages=1,
    )
    dut._log.info("Pipeline state progression: blurr case completed")
    _assert_rgb_is_grayscale(blurr, label="blurr state")
    if np.array_equal(blurr.pixels, grayscale.pixels):
        raise AssertionError(
            "blurr state did not differ from grayscale state on edge-rich image",
        )

    dut._log.info("Pipeline state progression: starting sobel case")
    sobel = await _run_pipeline_case(
        dut,
        image=image,
        clicks=3,
        warmup_stages=2,
    )
    dut._log.info("Pipeline state progression: sobel case completed")
    _assert_rgb_is_grayscale(sobel, label="sobel state")
    if int(np.count_nonzero(sobel.pixels)) == 0:
        raise AssertionError("sobel state produced no non-zero edge pixels")

    output_path = _sim_artifact_dir() / "pipeline_full_chain_state3_sobel.png"
    sobel.to_png(output_path)


@cocotb.test(timeout_time=220, timeout_unit="ms")
async def test_pipeline_full_chain_smoke_with_backpressure(dut) -> None:
    image = _full_frame_image(dut)
    width, height = _frame_shape_from_dut(dut)

    received = await _run_pipeline_case(
        dut,
        image=image,
        clicks=3,
        warmup_stages=2,
        source_pause_pattern=(0, 0, 1, 0, 1, 0),
        sink_pause_pattern=(0, 1, 0, 0, 1),
    )

    if received.width != width or received.height != height:
        raise AssertionError(
            f"Unexpected output shape: expected=({width}, {height}), "
            f"received=({received.width}, {received.height})",
        )

    if int(np.count_nonzero(received.pixels)) == 0:
        raise AssertionError("Smoke test output is fully zeroed under backpressure")
