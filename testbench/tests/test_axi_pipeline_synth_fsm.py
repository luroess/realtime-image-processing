"""Synthetic FSM/compositor checks for the current no-FAST pipeline."""

from __future__ import annotations

from typing import Any

import cocotb
import numpy as np
from cocotb.clock import Clock
from cocotb.triggers import ReadOnly, RisingEdge, Timer, with_timeout
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

FRAME_WIDTH = 8
FRAME_HEIGHT = 8

BTN1_PROCESSING = 0
BTN2_BASE_MODE = 1


def _make_synthetic_frame(frame_idx: int) -> Image:
    """Generate deterministic edge-rich input with smooth and hard edges."""
    y, x = np.indices((FRAME_HEIGHT, FRAME_WIDTH), dtype=np.uint16)
    left = x < (FRAME_WIDTH // 2)
    top = y < (FRAME_HEIGHT // 2)

    r = np.where(left, 20 + y * 9 + frame_idx * 7, 230 - y * 11 - frame_idx * 5) % 256
    g = np.where(top, 30 + x * 13 + frame_idx * 3, 210 - x * 15 - frame_idx * 9) % 256
    b = ((x * 27) + (y * 19) + (frame_idx * 41)) % 256

    pixels = np.stack((r, g, b), axis=2).astype(np.uint8)
    return Image(pixels)


def _gray_from_rgb(image: Image) -> np.ndarray:
    pixels_u16 = image.pixels.astype(np.uint16)
    r = pixels_u16[:, :, 0]
    g = pixels_u16[:, :, 1]
    b = pixels_u16[:, :, 2]
    return ((r >> 2) + (g >> 1) + (b >> 2)).astype(np.uint8)


def _rgb_from_gray(gray_plane: np.ndarray) -> np.ndarray:
    gray_u8 = gray_plane.astype(np.uint8)
    return np.stack((gray_u8, gray_u8, gray_u8), axis=2)


def _warmup_beats(*, width: int, wndw_size: int = 3) -> int:
    return ((width + 1) * ((wndw_size - 1) // 2)) + 1


def _assert_rgb_equal(
    expected: np.ndarray, received: np.ndarray, *, label: str
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


def _assert_rgb_all_zero(image: Image, *, label: str) -> None:
    if int(np.count_nonzero(image.pixels)) == 0:
        return
    y, x = np.argwhere(np.any(image.pixels != 0, axis=2))[0]
    raise AssertionError(
        f"{label}: expected all-zero output, first non-zero at (x={int(x)}, y={int(y)}), value={image.pixels[y, x].tolist()}",
    )


def _assert_binary_rgb_mask(image: Image, *, label: str) -> None:
    pixels = image.pixels
    grayscale_mask = (pixels[:, :, 0] == pixels[:, :, 1]) & (
        pixels[:, :, 1] == pixels[:, :, 2]
    )
    if not np.all(grayscale_mask):
        y, x = np.argwhere(~grayscale_mask)[0]
        raise AssertionError(
            f"{label}: binary mask output is not grayscale at (x={int(x)}, y={int(y)}), value={pixels[y, x].tolist()}",
        )

    values = set(np.unique(pixels[:, :, 0]).tolist())
    if not values.issubset({0, 255}):
        raise AssertionError(
            f"{label}: expected only binary values {{0,255}}, observed={sorted(values)}"
        )
    if 255 not in values:
        raise AssertionError(f"{label}: expected at least one foreground (255) pixel")


async def _pulse_button_once(
    dut: Any,
    *,
    button_idx: int,
    high_ns: int = 220,
    low_ns: int = 220,
) -> None:
    btn = getattr(dut, BTN_SIGNAL)
    btn.value = int(1 << button_idx)
    await Timer(high_ns, unit="ns")
    btn.value = 0
    await Timer(low_ns, unit="ns")


async def _click_btn1(dut: Any, count: int) -> None:
    for _ in range(count):
        await _pulse_button_once(dut, button_idx=BTN1_PROCESSING)


async def _click_btn2(dut: Any, count: int) -> None:
    for _ in range(count):
        await _pulse_button_once(dut, button_idx=BTN2_BASE_MODE)


async def _assert_controls(
    dut: Any,
    *,
    exp_pass_gray: int,
    exp_pass_blur: int,
    exp_pass_sobel: int,
    exp_overlay_zeros: int,
    settle_cycles: int = 256,
) -> None:
    expected = (exp_pass_gray, exp_pass_blur, exp_pass_sobel, exp_overlay_zeros)
    current = (0, 0, 0, 0)

    for _ in range(settle_cycles):
        await RisingEdge(getattr(dut, ACLK_SIGNAL))
        await ReadOnly()
        current = (
            int(dut.o_pass_grayscale.value),
            int(dut.o_pass_blurr_filter.value),
            int(dut.o_pass_sobel.value),
            int(dut.s_overlay_zeros.value),
        )
        if current == expected:
            return

    raise AssertionError(
        f"Controls did not settle: expected={expected}, observed={current}"
    )


async def _assert_latched_controls(
    dut: Any,
    *,
    exp_pass_gray: int,
    exp_pass_blur: int,
    exp_pass_sobel: int,
    exp_overlay_zeros: int,
    settle_cycles: int = 256,
) -> None:
    expected = (exp_pass_gray, exp_pass_blur, exp_pass_sobel, exp_overlay_zeros)
    current = (0, 0, 0, 0)

    for _ in range(settle_cycles):
        await RisingEdge(getattr(dut, ACLK_SIGNAL))
        await ReadOnly()
        current = (
            int(dut.s_pass_grayscale_l.value),
            int(dut.s_pass_blurr_filter_l.value),
            int(dut.s_pass_sobel_l.value),
            int(dut.s_overlay_zeros_l.value),
        )
        if current == expected:
            return

    raise AssertionError(
        f"Latched controls did not settle: expected={expected}, observed={current}",
    )


async def _send_and_recv_frame(
    source: AxiVideoStreamSource,
    sink: AxiVideoStreamSink,
    image: Image,
    *,
    warmup_stages: int,
) -> Image:
    flush_pixels = warmup_stages * _warmup_beats(width=image.width, wndw_size=3)
    tx_task = cocotb.start_soon(
        source.send_image(
            image,
            tail_padding_pixels=flush_pixels,
        ),
    )
    observed = await sink.recv_image(
        width=image.width,
        height=image.height,
        timeout_ns=max(2_000_000, image.width * image.height * 2000),
    )
    await with_timeout(tx_task, 6_000_000, "ns")
    return observed


async def _assert_no_sof_accept_until_task_done(
    dut: Any,
    *,
    task: cocotb.task.Task[Any],
    timeout_cycles: int = 200_000,
) -> None:
    i_clk = getattr(dut, ACLK_SIGNAL)
    in_tvalid = getattr(dut, f"{S_AXIS_PREFIX}_tvalid")
    in_tready = getattr(dut, f"{S_AXIS_PREFIX}_tready")
    in_tuser = getattr(dut, f"{S_AXIS_PREFIX}_tuser")

    cycles = 0
    while not task.done():
        cycles += 1
        if cycles > timeout_cycles:
            raise AssertionError(
                "Timed out while waiting for monitored task to complete."
            )

        await RisingEdge(i_clk)
        await ReadOnly()
        assert not (
            int(in_tvalid.value) == 1
            and int(in_tready.value) == 1
            and int(in_tuser.value) == 1
        ), "Unexpected input SOF handshake detected while source drives TUSER=0."


class _NoSofAxiVideoStreamSource(AxiVideoStreamSource):
    """Video source variant that never asserts SOF on TUSER."""

    def _build_line_tuser(self, line_bytes_len: int, *, line_index: int) -> list[int]:
        del line_index
        return [0] * line_bytes_len


@cocotb.test(timeout_time=1200, timeout_unit="ms")
async def test_pipeline_synthetic_fsm_compositor_modes(dut: Any) -> None:
    i_clk = getattr(dut, ACLK_SIGNAL)
    i_rst_n = getattr(dut, ARESETN_SIGNAL)
    i_btn = getattr(dut, BTN_SIGNAL)

    cocotb.start_soon(Clock(i_clk, 10, unit="ns").start())

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

    # 1) Reset default: PASS_ALL + ZEROS => black frame.
    await _assert_controls(
        dut,
        exp_pass_gray=0,
        exp_pass_blur=1,
        exp_pass_sobel=1,
        exp_overlay_zeros=1,
    )
    frame0 = _make_synthetic_frame(1)
    out0 = await _send_and_recv_frame(source, sink, frame0, warmup_stages=0)
    _assert_rgb_all_zero(out0, label="pass_all_zeros")

    # 2) PASS_ALL + RGB base mode.
    await _click_btn2(dut, 1)
    await _assert_controls(
        dut,
        exp_pass_gray=1,
        exp_pass_blur=1,
        exp_pass_sobel=1,
        exp_overlay_zeros=0,
    )
    # Prime one frame so control latch is stable for checked frame.
    await _send_and_recv_frame(source, sink, _make_synthetic_frame(2), warmup_stages=0)
    await _assert_latched_controls(
        dut,
        exp_pass_gray=1,
        exp_pass_blur=1,
        exp_pass_sobel=1,
        exp_overlay_zeros=0,
    )
    frame1 = _make_synthetic_frame(3)
    out1 = await _send_and_recv_frame(source, sink, frame1, warmup_stages=0)
    _assert_rgb_equal(frame1.pixels, out1.pixels, label="pass_all_rgb")

    # 3) PASS_ALL + GRAY base mode.
    await _click_btn2(dut, 1)
    await _assert_controls(
        dut,
        exp_pass_gray=0,
        exp_pass_blur=1,
        exp_pass_sobel=1,
        exp_overlay_zeros=0,
    )
    await _send_and_recv_frame(source, sink, _make_synthetic_frame(4), warmup_stages=0)
    await _assert_latched_controls(
        dut,
        exp_pass_gray=0,
        exp_pass_blur=1,
        exp_pass_sobel=1,
        exp_overlay_zeros=0,
    )
    frame2 = _make_synthetic_frame(5)
    out2 = await _send_and_recv_frame(source, sink, frame2, warmup_stages=0)
    expected_gray = _gray_from_rgb(frame2)
    _assert_rgb_equal(_rgb_from_gray(expected_gray), out2.pixels, label="pass_all_gray")


@cocotb.test(timeout_time=1200, timeout_unit="ms")
async def test_pipeline_controls_stay_default_without_input_sof(dut: Any) -> None:
    i_clk = getattr(dut, ACLK_SIGNAL)
    i_rst_n = getattr(dut, ARESETN_SIGNAL)
    i_btn = getattr(dut, BTN_SIGNAL)

    cocotb.start_soon(Clock(i_clk, 10, unit="ns").start())

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

    source = _NoSofAxiVideoStreamSource(
        dut=dut,
        i_clk=i_clk,
        i_rst_n=i_rst_n,
        prefix=S_AXIS_PREFIX,
        reset_active_level=RESET_ACTIVE_LEVEL,
        pixel_order=PIXEL_ORDER,
    )

    raw_before = (
        int(dut.s_pass_grayscale.value),
        int(dut.s_pass_blurr_filter.value),
        int(dut.s_pass_sobel.value),
        int(dut.s_overlay_zeros.value),
    )
    latched_before = (
        int(dut.s_pass_grayscale_l.value),
        int(dut.s_pass_blurr_filter_l.value),
        int(dut.s_pass_sobel_l.value),
        int(dut.s_overlay_zeros_l.value),
    )
    assert raw_before == (0, 1, 1, 1), (
        f"Unexpected raw controls after reset: {raw_before}"
    )
    assert latched_before == (0, 1, 1, 1), (
        f"Unexpected latched controls after reset: {latched_before}"
    )

    await _click_btn1(dut, 1)
    await _click_btn2(dut, 1)

    raw_after = (
        int(dut.s_pass_grayscale.value),
        int(dut.s_pass_blurr_filter.value),
        int(dut.s_pass_sobel.value),
        int(dut.s_overlay_zeros.value),
    )
    latched_after = (
        int(dut.s_pass_grayscale_l.value),
        int(dut.s_pass_blurr_filter_l.value),
        int(dut.s_pass_sobel_l.value),
        int(dut.s_overlay_zeros_l.value),
    )
    assert raw_after == (1, 1, 0, 0), (
        f"Unexpected raw controls after clicks: {raw_after}"
    )
    assert latched_after == (0, 1, 1, 1), (
        "Latched controls changed without input SOF acceptance.",
    )

    tx_task = cocotb.start_soon(source.send_image(_make_synthetic_frame(20)))
    mon_task = cocotb.start_soon(
        _assert_no_sof_accept_until_task_done(dut, task=tx_task)
    )
    await with_timeout(tx_task, 30_000_000, "ns")
    await with_timeout(mon_task, 30_000_000, "ns")

    latched_final = (
        int(dut.s_pass_grayscale_l.value),
        int(dut.s_pass_blurr_filter_l.value),
        int(dut.s_pass_sobel_l.value),
        int(dut.s_overlay_zeros_l.value),
    )
    assert latched_final == (0, 1, 1, 1), (
        "Latched controls changed even though no SOF was accepted.",
    )
