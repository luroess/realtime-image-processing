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

ACLK_SIGNAL = "i_clk"
ARESETN_SIGNAL = "i_rst_n"
BTN_SIGNAL = "i_btn"
S_AXIS_PREFIX = "s_axis_video_rbg888"
M_AXIS_PREFIX = "m_axis_video_rbg888"
RESET_ACTIVE_LEVEL = False
PIXEL_ORDER = "rbg"
TESTBENCH_ROOT = Path(__file__).resolve().parents[1]
FRAME_WIDTH = 512
FRAME_HEIGHT = 512


def _sim_artifact_dir() -> Path:
    results_file = os.getenv("COCOTB_RESULTS_FILE")
    if results_file:
        return Path(results_file).resolve().parent
    return TESTBENCH_ROOT / "sim_build" / "test_axi_gray_blurr_sobel_overlay_pipeline"


def _warmup_beats(*, width: int, wndw_size: int = 3) -> int:
    return ((width + 1) * ((wndw_size - 1) // 2)) + 1


def _full_frame_image() -> Image:
    image_path = TESTBENCH_ROOT / "images" / "lenna_512_512.png"
    image = Image.from_png(image_path)
    if image.width != FRAME_WIDTH or image.height != FRAME_HEIGHT:
        raise AssertionError(
            f"Expected input image size ({FRAME_WIDTH}, {FRAME_HEIGHT}), "
            f"got ({image.width}, {image.height}) from {image_path}",
        )
    return image


def _gray_from_rgb(image: Image) -> np.ndarray:
    pixels_u16 = image.pixels.astype(np.uint16)
    r = pixels_u16[:, :, 0]
    g = pixels_u16[:, :, 1]
    b = pixels_u16[:, :, 2]
    return ((r >> 2) + (g >> 1) + (b >> 2)).astype(np.uint8)


def _rgb_from_gray(gray_plane: np.ndarray) -> np.ndarray:
    gray_u8 = gray_plane.astype(np.uint8)
    return np.stack((gray_u8, gray_u8, gray_u8), axis=2)


def _reference_overlay_on_original(image: Image, *, edge_threshold: int = 48) -> Image:
    gray = _gray_from_rgb(image).astype(np.int16)
    gx = np.zeros_like(gray, dtype=np.int16)
    gy = np.zeros_like(gray, dtype=np.int16)
    gx[:, 1:] = np.abs(gray[:, 1:] - gray[:, :-1])
    gy[1:, :] = np.abs(gray[1:, :] - gray[:-1, :])
    edge_mask = (gx + gy) > edge_threshold
    if int(np.count_nonzero(edge_mask)) == 0:
        raise AssertionError("Reference overlay generation produced no edge pixels")

    overlay_pixels = image.pixels.copy()
    overlay_pixels[edge_mask] = np.array([255, 0, 0], dtype=np.uint8)
    return Image(overlay_pixels)


def _assert_rgb_equal(expected: np.ndarray, received: np.ndarray, *, label: str) -> None:
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
    gray_mask = (pixels[:, :, 0] == pixels[:, :, 1]) & (pixels[:, :, 1] == pixels[:, :, 2])
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


async def _pulse_button_idx_once(
    dut,
    *,
    button_idx: int = 0,
    high_ns: int = 220,
    low_ns: int = 220,
) -> None:
    btn = getattr(dut, BTN_SIGNAL)
    btn.value = 1 << button_idx
    await Timer(high_ns, unit="ns")
    btn.value = 0
    await Timer(low_ns, unit="ns")


async def _set_click_state(dut, *, clicks: int, button_idx: int = 0) -> None:
    for _ in range(clicks):
        await _pulse_button_idx_once(dut, button_idx=button_idx)


async def _run_pipeline_case(
    dut,
    *,
    image: Image,
    clicks: int,
    base_clicks: int = 0,
    warmup_stages: int,
    source_pause_pattern: tuple[int, ...] | None = None,
    sink_pause_pattern: tuple[int, ...] | None = None,
) -> Image:
    i_clk = getattr(dut, ACLK_SIGNAL)
    i_rst_n = getattr(dut, ARESETN_SIGNAL)
    i_btn = getattr(dut, BTN_SIGNAL)

    i_rst_n.value = int(RESET_ACTIVE_LEVEL)
    i_btn.value = 0
    getattr(dut, f"{S_AXIS_PREFIX}_tvalid").value = 0
    getattr(dut, f"{S_AXIS_PREFIX}_tdata").value = 0
    getattr(dut, f"{S_AXIS_PREFIX}_tlast").value = 0
    getattr(dut, f"{S_AXIS_PREFIX}_tuser").value = 0

    await apply_reset(
        dut=dut,
        i_clk=i_clk,
        i_rst_n=i_rst_n,
        stream_input_prefix=S_AXIS_PREFIX,
        reset_active_level=RESET_ACTIVE_LEVEL,
    )

    source = AxiVideoStreamSource(
        dut=dut,
        i_clk=i_clk,
        i_rst_n=i_rst_n,
        prefix=S_AXIS_PREFIX,
        reset_active_level=RESET_ACTIVE_LEVEL,
        pixel_order=PIXEL_ORDER,
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

    await _set_click_state(dut, clicks=clicks, button_idx=0)
    await _set_click_state(dut, clicks=base_clicks, button_idx=1)

    flush_pixels = warmup_stages * _warmup_beats(width=image.width, wndw_size=3)
    await source.send_image(
        image,
        tail_padding_pixels=flush_pixels,
    )

    timeout_ns = max(350_000, image.width * image.height * 120)
    return await sink.recv_image(width=image.width, height=image.height, timeout_ns=timeout_ns)


@cocotb.test(timeout_time=240, timeout_unit="ms")
async def test_pipeline_full_chain_state_progression(dut) -> None:
    image = _full_frame_image()
    cocotb.start_soon(Clock(getattr(dut, ACLK_SIGNAL), 10, unit="ns").start())
    overlay_path = _sim_artifact_dir() / "pipeline_full_overlay_on_original.png"
    _reference_overlay_on_original(image).to_png(overlay_path)

    passthrough = await _run_pipeline_case(
        dut,
        image=image,
        clicks=0,
        warmup_stages=0,
    )
    _assert_rgb_equal(image.pixels, passthrough.pixels, label="passthrough state")


@cocotb.test(timeout_time=220, timeout_unit="ms")
async def test_pipeline_full_chain_smoke_with_backpressure(dut) -> None:
    image = _full_frame_image()
    cocotb.start_soon(Clock(getattr(dut, ACLK_SIGNAL), 10, unit="ns").start())

    received = await _run_pipeline_case(
        dut,
        image=image,
        clicks=0,
        warmup_stages=0,
    )

    if received.width != FRAME_WIDTH or received.height != FRAME_HEIGHT:
        raise AssertionError(
            f"Unexpected output shape: expected=({FRAME_WIDTH}, {FRAME_HEIGHT}), "
            f"received=({received.width}, {received.height})",
        )

    overlay_image = _reference_overlay_on_original(image)
    overlay_path = _sim_artifact_dir() / "pipeline_full_overlay_reference.png"
    overlay_image.to_png(overlay_path)
