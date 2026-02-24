"""Minimal 3x3 AXI integration test: RGB2GRAY -> delayed gray -> FrameCompositor."""

from __future__ import annotations

import cocotb
import numpy as np
from cocotb.clock import Clock
from cocotb.triggers import ReadOnly, RisingEdge, with_timeout
from common.reset import apply_reset
from drivers.axis_video_source import AxiVideoStreamSource
from models.image_model import Image
from monitors.axis_video_sink import AxiVideoStreamSink

ACLK_SIGNAL = "i_aclk"
ARESETN_SIGNAL = "i_aresetn"
RESET_ACTIVE_LEVEL = False
S_AXIS_PREFIX = "s_axis_video"
M_AXIS_PREFIX = "m_axis_video_rbg888"
PIXEL_ORDER = "rbg"
FRAME_W = 3
FRAME_H = 2


def _minimal_image_3x2_frame0() -> Image:
    pixels = np.asarray(
        [
            [[0, 0, 0], [4, 0, 0], [0, 8, 0]],
            [[0, 0, 16], [32, 32, 32], [1, 1, 1]],
        ],
        dtype=np.uint8,
    )
    return Image(pixels)


def _minimal_image_3x2_frame1() -> Image:
    pixels = np.asarray(
        [
            [[8, 0, 0], [0, 12, 0], [0, 0, 20]],
            [[40, 10, 0], [5, 5, 5], [0, 0, 0]],
        ],
        dtype=np.uint8,
    )
    return Image(pixels)


def _gray_plane(image: Image) -> np.ndarray:
    pixels_u16 = image.pixels.astype(np.uint16)
    r = pixels_u16[:, :, 0]
    g = pixels_u16[:, :, 1]
    b = pixels_u16[:, :, 2]
    return ((r >> 2) + (g >> 1) + (b >> 2)).astype(np.uint8)


def _expected_overlay(image: Image) -> Image:
    gray = _gray_plane(image)
    edge = gray != 0
    expected = image.pixels.copy()
    expected[edge] = np.asarray([255, 0, 0], dtype=np.uint8)
    return Image(expected)


def _assert_image_equal(expected: Image, observed: Image) -> None:
    if np.array_equal(expected.pixels, observed.pixels):
        return

    mismatch = np.argwhere(np.any(expected.pixels != observed.pixels, axis=2))[0]
    y = int(mismatch[0])
    x = int(mismatch[1])
    raise AssertionError(
        "Output mismatch at "
        f"(x={x}, y={y}), expected={expected.pixels[y, x].tolist()}, "
        f"observed={observed.pixels[y, x].tolist()}",
    )


async def _first_handshake_cycle(
    dut,
    *,
    valid_name: str,
    ready_name: str,
    timeout_cycles: int,
) -> int:
    i_clk = getattr(dut, ACLK_SIGNAL)
    valid = getattr(dut, valid_name)
    ready = getattr(dut, ready_name)

    for cycle in range(timeout_cycles):
        await RisingEdge(i_clk)
        await ReadOnly()
        if int(valid.value) == 1 and int(ready.value) == 1:
            return cycle

    raise AssertionError(
        f"Timed out waiting for first handshake on {valid_name}/{ready_name}.",
    )


async def _count_ready_low_before_first_handshake(
    dut,
    *,
    valid_name: str,
    ready_name: str,
    timeout_cycles: int,
) -> int:
    i_clk = getattr(dut, ACLK_SIGNAL)
    valid = getattr(dut, valid_name)
    ready = getattr(dut, ready_name)
    ready_low_cycles = 0

    for _ in range(timeout_cycles):
        await RisingEdge(i_clk)
        await ReadOnly()
        v = int(valid.value)
        r = int(ready.value)

        if v == 1 and r == 0:
            ready_low_cycles += 1
        if v == 1 and r == 1:
            return ready_low_cycles

    raise AssertionError(
        f"Timed out waiting for first handshake on {valid_name}/{ready_name}.",
    )


async def _collect_sof_ready_low_runs(
    dut,
    *,
    valid_name: str,
    ready_name: str,
    user_name: str,
    expected_sof_count: int,
    timeout_cycles: int,
) -> list[int]:
    i_clk = getattr(dut, ACLK_SIGNAL)
    valid = getattr(dut, valid_name)
    ready = getattr(dut, ready_name)
    user = getattr(dut, user_name)

    runs: list[int] = []
    current_run = 0

    for _ in range(timeout_cycles):
        await RisingEdge(i_clk)
        await ReadOnly()
        v = int(valid.value)
        r = int(ready.value)
        u = int(user.value)

        if v == 1 and r == 0 and u == 1:
            current_run += 1
            continue

        if v == 1 and r == 1 and u == 1:
            runs.append(current_run)
            current_run = 0
            if len(runs) == expected_sof_count:
                return runs
            continue

        if v == 0:
            current_run = 0

    raise AssertionError(
        f"Timed out waiting for {expected_sof_count} SOF handshakes on {valid_name}/{ready_name}/{user_name}. "
        f"Collected={runs}",
    )


async def _send_images(source: AxiVideoStreamSource, images: list[Image]) -> None:
    for image in images:
        await source.send_image(image)


async def _collect_handshake_events(
    dut,
    *,
    valid_name: str,
    ready_name: str,
    user_name: str,
    last_name: str,
    expected_count: int,
    timeout_cycles: int,
) -> list[tuple[int, int, int]]:
    i_clk = getattr(dut, ACLK_SIGNAL)
    valid = getattr(dut, valid_name)
    ready = getattr(dut, ready_name)
    user = getattr(dut, user_name)
    last = getattr(dut, last_name)
    events: list[tuple[int, int, int]] = []

    for cycle in range(timeout_cycles):
        await RisingEdge(i_clk)
        await ReadOnly()
        if int(valid.value) == 1 and int(ready.value) == 1:
            events.append((cycle, int(user.value), int(last.value)))
            if len(events) == expected_count:
                return events

    raise AssertionError(
        f"Timed out collecting {expected_count} handshakes on "
        f"{valid_name}/{ready_name}. Collected={len(events)}",
    )


@cocotb.test(timeout_time=80, timeout_unit="ms")
async def test_axi_rgb2gray_frame_compositor_minimal_3x2_two_frames_with_gray_warmup(
    dut,
) -> None:
    i_clk = getattr(dut, ACLK_SIGNAL)
    i_rst_n = getattr(dut, ARESETN_SIGNAL)
    cocotb.start_soon(Clock(i_clk, 10, unit="ns").start())

    dut.i_pass_through.value = 1
    dut.i_overlay_zeros.value = 0
    await apply_reset(
        dut=dut,
        i_clk=i_clk,
        i_rst_n=i_rst_n,
        cycles=4,
        stream_input_prefix=S_AXIS_PREFIX,
        reset_active_level=RESET_ACTIVE_LEVEL,
    )
    dut.i_pass_through.value = 1
    dut.i_overlay_zeros.value = 0

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

    images = [
        _minimal_image_3x2_frame0(),
        _minimal_image_3x2_frame1(),
    ]
    expected_images = [_expected_overlay(image) for image in images]

    gray_pre_hs = cocotb.start_soon(
        _first_handshake_cycle(
            dut,
            valid_name="o_dbg_gray_pre_tvalid",
            ready_name="o_dbg_gray_pre_tready",
            timeout_cycles=200,
        ),
    )
    gray_pre_ready_low = cocotb.start_soon(
        _count_ready_low_before_first_handshake(
            dut,
            valid_name="o_dbg_gray_pre_tvalid",
            ready_name="o_dbg_gray_pre_tready",
            timeout_cycles=220,
        ),
    )
    gray_pre_sof_runs = cocotb.start_soon(
        _collect_sof_ready_low_runs(
            dut,
            valid_name="o_dbg_gray_pre_tvalid",
            ready_name="o_dbg_gray_pre_tready",
            user_name="s_split_gray_tuser",
            expected_sof_count=2,
            timeout_cycles=600,
        ),
    )
    gray_post_hs = cocotb.start_soon(
        _first_handshake_cycle(
            dut,
            valid_name="o_dbg_gray_post_tvalid",
            ready_name="o_dbg_gray_post_tready",
            timeout_cycles=260,
        ),
    )
    post_events = cocotb.start_soon(
        _collect_handshake_events(
            dut,
            valid_name="o_dbg_gray_post_tvalid",
            ready_name="o_dbg_gray_post_tready",
            user_name="s_comp_tuser",
            last_name="s_comp_tlast",
            expected_count=FRAME_W * FRAME_H * 2,
            timeout_cycles=1200,
        ),
    )

    tx_images = cocotb.start_soon(_send_images(source, images))
    observed_0 = await sink.recv_image(
        width=FRAME_W,
        height=FRAME_H,
        timeout_ns=500_000,
    )
    observed_1 = await sink.recv_image(
        width=FRAME_W,
        height=FRAME_H,
        timeout_ns=500_000,
    )

    pre_cycle = int(await with_timeout(gray_pre_hs, 800_000, "ns"))
    pre_ready_low_cycles = int(await with_timeout(gray_pre_ready_low, 800_000, "ns"))
    pre_sof_runs = await with_timeout(gray_pre_sof_runs, 1_200_000, "ns")
    post_cycle = int(await with_timeout(gray_post_hs, 800_000, "ns"))
    post_handshakes = await with_timeout(post_events, 1_200_000, "ns")
    await with_timeout(tx_images, 1_200_000, "ns")
    warmup_cycles = post_cycle - pre_cycle

    dut._log.info(
        "Gray path behavior: pre_ready_low=%d cycles, pre_sof_runs=%s, pre=%d, post=%d, delta=%d cycles",
        pre_ready_low_cycles,
        pre_sof_runs,
        pre_cycle,
        post_cycle,
        warmup_cycles,
    )
    assert pre_ready_low_cycles == 0, (
        "Expected gray pre-ready to keep accepting data during warm-up. "
        f"Observed={pre_ready_low_cycles}."
    )
    assert pre_sof_runs == [0, 0], (
        "Expected no pre-branch SOF stall before handshake for both frames. "
        f"Observed={pre_sof_runs}."
    )
    assert 3 <= warmup_cycles <= 6, (
        "Expected post-branch SOF warm-up delay after first pre-handshake. "
        f"Observed delta={warmup_cycles} cycles."
    )

    # 1-cycle cadence within each frame once warm-up is complete.
    frame_size = FRAME_W * FRAME_H
    assert len(post_handshakes) == frame_size * 2
    for idx in range(0, frame_size - 1):
        assert post_handshakes[idx + 1][0] - post_handshakes[idx][0] == 1, (
            f"Frame0 pixel cadence is not 1 cycle at index {idx}: "
            f"{post_handshakes[idx]} -> {post_handshakes[idx + 1]}"
        )
    for idx in range(frame_size, (2 * frame_size) - 1):
        assert post_handshakes[idx + 1][0] - post_handshakes[idx][0] == 1, (
            f"Frame1 pixel cadence is not 1 cycle at index {idx - frame_size}: "
            f"{post_handshakes[idx]} -> {post_handshakes[idx + 1]}"
        )
    frame_gap = post_handshakes[frame_size][0] - post_handshakes[frame_size - 1][0]
    assert 3 <= frame_gap <= 6, (
        "Expected warm-up gap between frame0 tail and frame1 SOF on post branch. "
        f"Observed frame_gap={frame_gap} cycles."
    )
    assert post_handshakes[0][1] == 1 and post_handshakes[frame_size][1] == 1, (
        "Expected SOF marker on first beat of each frame at post branch."
    )

    _assert_image_equal(expected_images[0], observed_0)
    _assert_image_equal(expected_images[1], observed_1)
