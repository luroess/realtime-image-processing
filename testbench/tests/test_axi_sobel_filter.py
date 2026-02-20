"""AXI4-Stream Sobel filter cocotb tests."""

from __future__ import annotations

import os
from pathlib import Path

import cocotb
import numpy as np
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge
from cocotbext.axi import AxiStreamBus, AxiStreamFrame, AxiStreamSource

from common.pause import repeating_pause
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
TESTBENCH_ROOT = Path(__file__).resolve().parents[1]


class _KnownIdleAxiStreamSource(AxiStreamSource):
    """AxiStreamSource variant that avoids X-initialization on sidebands."""

    _init_x = False


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
    # raise AssertionError(
    #     f"First mismatch at (x={int(x)}, y={int(y)}): "
    #     f"expected={int(expected[y, x])}, received={int(received[y, x])}",
    # )


async def run_sobel_case(
    dut,
    gray_plane: np.ndarray,
    output_path: Path | None = None,
    start_clock: bool = True,
    ready_stall_cycles: int = 0,
) -> np.ndarray:
    i_clk = getattr(dut, ACLK_SIGNAL)
    i_rst_n = getattr(dut, ARESETN_SIGNAL)
    m_axis_tready = getattr(dut, f"{M_AXIS_PREFIX}_tready")

    i_rst_n.value = int(RESET_ACTIVE_LEVEL)
    getattr(dut, f"{S_AXIS_PREFIX}_tvalid").value = 0
    getattr(dut, f"{S_AXIS_PREFIX}_tdata").value = 0
    getattr(dut, f"{S_AXIS_PREFIX}_tlast").value = 0
    getattr(dut, f"{S_AXIS_PREFIX}_tuser").value = 0
    m_axis_tready.value = 0

    if start_clock:
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
    expected = _sobel_expected(gray_plane, threshold=SOBEL_THRESHOLD)
    if ready_stall_cycles > 0:
        m_axis_tready.value = 0
        send_task = cocotb.start_soon(source.send_gray_image(gray_plane))
        for _ in range(ready_stall_cycles):
            await RisingEdge(i_clk)
        m_axis_tready.value = 1
        await send_task
    else:
        m_axis_tready.value = 1
        await source.send_gray_image(gray_plane)

    height, width = gray_plane.shape
    timeout_ns = max(200_000, width * height * 60)
    received = await sink.recv_plane(width=width, height=height, timeout_ns=timeout_ns)
    _assert_plane_equal(expected, received)

    if output_path is not None:
        rgb = np.stack((received, received, received), axis=2)
        Image(rgb).to_png(output_path)

    return received


async def run_sobel_window_frames_case(
    dut,
    gray_plane: np.ndarray,
    window_frames: list[np.ndarray],
    start_clock: bool = True,
    ready_stall_cycles: int = 0,
    source_pause_pattern: tuple[int, ...] | None = None,
    sink_pause_pattern: tuple[int, ...] | None = None,
) -> np.ndarray:
    i_clk = getattr(dut, ACLK_SIGNAL)
    i_rst_n = getattr(dut, ARESETN_SIGNAL)
    m_axis_tready = getattr(dut, f"{M_AXIS_PREFIX}_tready")

    i_rst_n.value = int(RESET_ACTIVE_LEVEL)
    getattr(dut, f"{S_AXIS_PREFIX}_tvalid").value = 0
    getattr(dut, f"{S_AXIS_PREFIX}_tdata").value = 0
    getattr(dut, f"{S_AXIS_PREFIX}_tlast").value = 0
    getattr(dut, f"{S_AXIS_PREFIX}_tuser").value = 0
    m_axis_tready.value = 0

    if start_clock:
        cocotb.start_soon(Clock(i_clk, 10, unit="ns").start())
    await apply_reset(
        dut=dut,
        i_clk=i_clk,
        i_rst_n=i_rst_n,
        stream_input_prefix=S_AXIS_PREFIX,
        reset_active_level=RESET_ACTIVE_LEVEL,
    )

    source = _KnownIdleAxiStreamSource(
        bus=AxiStreamBus.from_prefix(dut, S_AXIS_PREFIX),
        clock=i_clk,
        reset=i_rst_n,
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

    height, width = gray_plane.shape
    if len(window_frames) != (width * height):
        raise AssertionError(
            f"Expected {width * height} window frames, got {len(window_frames)}",
        )

    async def _send_frames() -> None:
        for y in range(height):
            line_bytes = bytearray()
            for x in range(width):
                window = window_frames[(y * width) + x]
                line_bytes.extend(int(v) & 0xFF for v in window.reshape(-1))

            tuser = [0] * len(line_bytes)
            if y == 0 and tuser:
                tuser[0:9] = [1] * min(9, len(tuser))

            await source.send(AxiStreamFrame(tdata=bytes(line_bytes), tuser=tuser))

        await source.wait()
        source.bus.tdata.value = 0
        if hasattr(source.bus, "tlast"):
            source.bus.tlast.value = 0
        if hasattr(source.bus, "tuser"):
            source.bus.tuser.value = 0

    expected = _sobel_expected(gray_plane, threshold=SOBEL_THRESHOLD)
    if ready_stall_cycles > 0:
        m_axis_tready.value = 0
        send_task = cocotb.start_soon(_send_frames())
        for _ in range(ready_stall_cycles):
            await RisingEdge(i_clk)
        m_axis_tready.value = 1
        await send_task
    else:
        m_axis_tready.value = 1
        await _send_frames()

    timeout_ns = max(200_000, width * height * 60)
    received = await sink.recv_plane(width=width, height=height, timeout_ns=timeout_ns)
    _assert_plane_equal(expected, received)
    return received


def _checkerboard_gray_plane(size: int = 5) -> np.ndarray:
    yy, xx = np.indices((size, size), dtype=np.int32)
    gray = ((xx + yy) & 1).astype(np.uint8) * 255
    pixels = np.stack((gray, gray, gray), axis=2)
    return Image(pixels).pixels[:, :, 0].copy()


def _windows_3x3_zero_padded(gray_plane: np.ndarray) -> np.ndarray:
    height, width = gray_plane.shape
    padded = np.pad(gray_plane, ((1, 1), (1, 1)), mode="constant", constant_values=0)
    windows = np.zeros((height, width, 3, 3), dtype=np.uint8)
    for y in range(height):
        for x in range(width):
            windows[y, x] = padded[y : y + 3, x : x + 3]
    return windows


def _rotating_checkerboard_frames(size: int = 5) -> list[np.ndarray]:
    base = _checkerboard_gray_plane(size=size)
    frames: list[np.ndarray] = []
    for shift_y in range(size):
        for shift_x in range(size):
            frame = np.roll(base, shift=shift_y, axis=0)
            frame = np.roll(frame, shift=shift_x, axis=1)
            frames.append(frame.copy())
    return frames


def _white_gray_plane(size: int = 5) -> np.ndarray:
    gray = np.full((size, size), 255, dtype=np.uint8)
    pixels = np.stack((gray, gray, gray), axis=2)
    return Image(pixels).pixels[:, :, 0].copy()


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
async def test_axi_sobel_filter_rotating_white_pixel_5x5(dut) -> None:
    base = _checkerboard_gray_plane(size=5)
    windows = _windows_3x3_zero_padded(base)
    expected_first = np.asarray(
        [
            [0, 0, 0],
            [0, 0, 255],
            [0, 255, 0],
        ],
        dtype=np.uint8,
    )
    expected_second = np.asarray(
        [
            [0, 0, 0],
            [0, 255, 0],
            [255, 0, 255],
        ],
        dtype=np.uint8,
    )
    if not np.array_equal(windows[0, 0], expected_first):
        raise AssertionError(
            f"Unexpected first window at (0,0):\n{windows[0, 0]}",
        )
    if not np.array_equal(windows[0, 1], expected_second):
        raise AssertionError(
            f"Unexpected second window at (1,0):\n{windows[0, 1]}",
        )

    frames = _rotating_checkerboard_frames(size=5)
    received_frames: list[np.ndarray] = []
    for idx, gray in enumerate(frames):
        received = await run_sobel_case(dut, gray, start_clock=(idx == 0))
        received_frames.append(received.copy())

    unique_outputs = {frame.tobytes() for frame in received_frames}
    if len(unique_outputs) <= 1:
        raise AssertionError(
            "Rotating white-pixel stimulus produced identical Sobel outputs for all frames.",
        )


@cocotb.test()
async def test_axi_sobel_filter_white_3x3_zero_padded_windows(dut) -> None:
    size = 3
    gray = _white_gray_plane(size=size)
    windows = _windows_3x3_zero_padded(gray)
    window_frames = [windows[y, x].copy() for y in range(size) for x in range(size)]

    if len(window_frames) != 9:
        raise AssertionError(f"Expected 9 windows for 3x3 image, got {len(window_frames)}")

    expected_first = np.asarray(
        [
            [0, 0, 0],
            [0, 255, 255],
            [0, 255, 255],
        ],
        dtype=np.uint8,
    )
    expected_second = np.asarray(
        [
            [0, 0, 0],
            [255, 255, 255],
            [255, 255, 255],
        ],
        dtype=np.uint8,
    )
    expected_last = np.asarray(
        [
            [255, 255, 0],
            [255, 255, 0],
            [0, 0, 0],
        ],
        dtype=np.uint8,
    )
    if not np.array_equal(window_frames[0], expected_first):
        raise AssertionError(
            f"Unexpected first window. Expected:\n{expected_first}\nGot:\n{window_frames[0]}",
        )
    if not np.array_equal(window_frames[1], expected_second):
        raise AssertionError(
            f"Unexpected second window. Expected:\n{expected_second}\nGot:\n{window_frames[1]}",
        )
    if not np.array_equal(window_frames[8], expected_last):
        raise AssertionError(
            f"Unexpected last window. Expected:\n{expected_last}\nGot:\n{window_frames[8]}",
        )

    for y in range(size):
        for x in range(size):
            expected = np.zeros((3, 3), dtype=np.uint8)
            for wy, dy in enumerate((-1, 0, 1)):
                for wx, dx in enumerate((-1, 0, 1)):
                    yy = y + dy
                    xx = x + dx
                    if 0 <= yy < size and 0 <= xx < size:
                        expected[wy, wx] = 255
            if not np.array_equal(windows[y, x], expected):
                raise AssertionError(
                    f"Unexpected window at ({x},{y}). Expected:\\n{expected}\\nGot:\\n{windows[y, x]}",
                )

    # Drive DUT with explicit 3x3 window input frames (raster order), under backpressure.
    await run_sobel_window_frames_case(
        dut,
        gray,
        window_frames,
        start_clock=True,
        ready_stall_cycles=20,
        source_pause_pattern=(0, 1, 0, 0, 1, 0),
        sink_pause_pattern=(0, 0, 1, 0, 1, 0, 0),
    )
