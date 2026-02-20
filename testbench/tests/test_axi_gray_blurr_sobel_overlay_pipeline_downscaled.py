"""Downscaled real-image full pipeline overlay integration test."""

from __future__ import annotations

import os
from pathlib import Path

import cocotb
import numpy as np
from cocotb.clock import Clock
from cocotb.triggers import SimTimeoutError, Timer, with_timeout

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

FRAME_WIDTH = 64
FRAME_HEIGHT = 64
BTN1_PROCESSING = 0
BTN2_BASE_MODE = 1


def _sim_artifact_dir() -> Path:
    results_file = os.getenv("COCOTB_RESULTS_FILE")
    if results_file:
        return Path(results_file).resolve().parent
    return TESTBENCH_ROOT / "sim_build" / "test_axi_gray_blurr_sobel_overlay_pipeline_downscaled"


def _warmup_beats(*, width: int, wndw_size: int = 3) -> int:
    return ((width + 1) * ((wndw_size - 1) // 2)) + 1


def _downscaled_real_image() -> Image:
    image_path = TESTBENCH_ROOT / "images" / "lenna_512_512.png"
    full = Image.from_png(image_path)
    pixels = full.pixels[::8, ::8, :].copy()
    image = Image(pixels)
    if image.width != FRAME_WIDTH or image.height != FRAME_HEIGHT:
        raise AssertionError(
            f"Expected downscaled image size ({FRAME_WIDTH}, {FRAME_HEIGHT}), "
            f"got ({image.width}, {image.height})",
        )
    return image


def _assert_rgb_not_grayscale(image: Image, *, label: str) -> None:
    pixels = image.pixels
    non_gray = (pixels[:, :, 0] != pixels[:, :, 1]) | (pixels[:, :, 1] != pixels[:, :, 2])
    if np.any(non_gray):
        return
    raise AssertionError(f"{label}: expected color output but all pixels are grayscale")


async def _pulse_button_once(
    dut,
    *,
    button_idx: int,
    high_ns: int = 220,
    low_ns: int = 220,
) -> None:
    btn = getattr(dut, BTN_SIGNAL)
    btn.value = 1 << button_idx
    await Timer(high_ns, unit="ns")
    btn.value = 0
    await Timer(low_ns, unit="ns")


async def _set_processing_state(dut, *, clicks: int) -> None:
    for _ in range(clicks):
        await _pulse_button_once(dut, button_idx=BTN1_PROCESSING)


async def _set_base_state(dut, *, clicks: int) -> None:
    for _ in range(clicks):
        await _pulse_button_once(dut, button_idx=BTN2_BASE_MODE)


@cocotb.test(timeout_time=320, timeout_unit="ms")
async def test_pipeline_downscaled_real_image_overlay_saved(dut) -> None:
    image = _downscaled_real_image()
    i_aclk = getattr(dut, ACLK_SIGNAL)
    i_aresetn = getattr(dut, ARESETN_SIGNAL)
    i_btn = getattr(dut, BTN_SIGNAL)

    i_aresetn.value = int(RESET_ACTIVE_LEVEL)
    i_btn.value = 0
    getattr(dut, f"{S_AXIS_PREFIX}_tvalid").value = 0
    getattr(dut, f"{S_AXIS_PREFIX}_tdata").value = 0
    getattr(dut, f"{S_AXIS_PREFIX}_tlast").value = 0
    getattr(dut, f"{S_AXIS_PREFIX}_tuser").value = 0

    cocotb.start_soon(Clock(i_aclk, 10, unit="ns").start())
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
    source.set_pause_generator(repeating_pause((0, 0, 1, 0, 1, 0)))
    sink.set_pause_generator(repeating_pause((0, 1, 0, 0, 1)))

    # BTN1: ST_PASS_ALL -> ST_BLUR -> ST_SOBEL (overlay active)
    dut._log.info("Setting processing FSM to ST_SOBEL (2 BTN1 clicks)")
    await _set_processing_state(dut, clicks=2)
    # BTN2: ST_ZEROS -> ST_BRAM_RGB (overlay base = color RGB)
    dut._log.info("Setting base FSM to ST_BRAM_RGB (1 BTN2 click)")
    await _set_base_state(dut, clicks=1)

    flush_pixels = _warmup_beats(width=image.width, wndw_size=3)
    dut._log.info(
        "Sending downscaled frame %dx%d with tail_padding_pixels=%d",
        image.width,
        image.height,
        flush_pixels,
    )
    tx_source = cocotb.start_soon(
        source.send_image(
            image,
            tail_padding_pixels=flush_pixels,
        ),
    )

    timeout_ns = max(350_000, image.width * image.height * 120)
    dut._log.info("Receiving output frame with timeout_ns=%d", timeout_ns)
    observed = await with_timeout(
        sink.recv_image(width=image.width, height=image.height, timeout_ns=timeout_ns),
        80_000_000,
        "ns",
    )

    try:
        await with_timeout(tx_source, 5_000_000, "ns")
    except SimTimeoutError:
        dut._log.info("Source tail flush did not fully drain within 5ms sim-time; canceling send task.")
        tx_source.cancel()

    if int(np.count_nonzero(observed.pixels)) == 0:
        raise AssertionError("Downscaled pipeline overlay output is fully zero")
    _assert_rgb_not_grayscale(observed, label="downscaled overlay output")

    if np.array_equal(observed.pixels, image.pixels):
        raise AssertionError("Overlay output did not differ from input frame")

    artifact_dir = _sim_artifact_dir()
    dut._log.info("Saving artifacts to %s", artifact_dir)
    image.to_png(artifact_dir / "pipeline_downscaled_input.png")
    observed.to_png(artifact_dir / "pipeline_downscaled_overlay_rgb.png")
