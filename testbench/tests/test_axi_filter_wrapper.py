"""AXI window-generator + Sobel wrapper cocotb tests."""

from __future__ import annotations

import os
from dataclasses import dataclass
from pathlib import Path
from typing import Any

import cocotb
import numpy as np
from cocotb.clock import Clock
from cocotb.triggers import ReadOnly, RisingEdge, with_timeout
from common.pause import repeating_pause
from common.reset import apply_reset
from drivers.axis_gray_source import AxiGrayStreamSource
from models.image_model import Image
from monitors.axis_gray_sink import AxiGrayStreamSink

ACLK_SIGNAL = "i_aclk"
ARESETN_SIGNAL = "i_aresetn"
S_AXIS_PREFIX = "s_axis_gray8"
M_AXIS_PREFIX = "m_axis_filter8"
RESET_ACTIVE_LEVEL = False
SOBEL_THRESHOLD = 200
TESTBENCH_ROOT = Path(__file__).resolve().parents[1]
FRAME_WIDTH = 512
FRAME_HEIGHT = 512
SINK_PAUSE_PATTERN = (0, 0, 0, 0, 0, 0, 0, 1)
MIN_READY_LOW_RUN = 1
HANDSHAKE_SETTLE_CYCLES = 6
FAST_STRESS_SEED = 0xA11F_1101
HEAVY_STRESS_SEED = 0xA11F_2202


@dataclass(slots=True)
class HandshakeStats:
    saw_stall: bool = False
    max_ready_low_run: int = 0
    accepted_beats: int = 0


@dataclass(slots=True, frozen=True)
class FrameGeometry:
    width: int
    height: int


@dataclass(slots=True)
class WrapperRunConfig:
    gray_plane: np.ndarray
    output_path: Path | None = None
    with_backpressure: bool = False
    check_expected: bool = True
    sink_pause_pattern: tuple[int, ...] = SINK_PAUSE_PATTERN
    timeout_factor_no_backpressure: int = 70
    timeout_factor_backpressure: int = 160
    timeout_ns_floor: int = 500_000
    expect_stall: bool = True
    min_ready_low_run: int = MIN_READY_LOW_RUN


def _warmup_beats(*, width: int, wndw_size: int = 3) -> int:
    return ((width + 1) * ((wndw_size - 1) // 2)) + 1


def _sim_artifact_dir() -> Path:
    results_file = os.getenv("COCOTB_RESULTS_FILE")
    if results_file:
        return Path(results_file).resolve().parent
    return TESTBENCH_ROOT / "sim_build" / "test_axi_filter_wrapper"


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


def _sobel_expected(
    gray_plane: np.ndarray,
    threshold: int = SOBEL_THRESHOLD,
) -> np.ndarray:
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


def _read_positive_generic(dut: Any, name: str, default: int) -> int:
    handle = getattr(dut, name, None)
    if handle is None:
        return default

    raw_value = getattr(handle, "value", handle)
    try:
        value = int(raw_value)
    except (TypeError, ValueError):
        integer_value = getattr(raw_value, "integer", None)
        if integer_value is None:
            value = int(handle)
        else:
            value = int(integer_value)

    if value <= 0:
        raise AssertionError(f"Expected positive generic value for {name}, got {value}")
    return value


def _frame_geometry_from_dut(dut: Any) -> FrameGeometry:
    return FrameGeometry(
        width=_read_positive_generic(dut, "G_LINE_WIDTH", FRAME_WIDTH),
        height=_read_positive_generic(dut, "G_NUM_ROW", FRAME_HEIGHT),
    )


def _random_pause_pattern(
    rng: np.random.Generator,
    *,
    min_len: int,
    max_len: int,
) -> tuple[int, ...]:
    if min_len < 2:
        raise ValueError("Pause pattern min_len must be >= 2.")
    if max_len < min_len:
        raise ValueError("Pause pattern max_len must be >= min_len.")

    while True:
        length = int(rng.integers(min_len, max_len + 1))
        pattern = tuple(int(v) for v in rng.integers(0, 2, size=length))
        if any(pattern) and not all(pattern):
            return pattern


def _random_gray_plane(
    rng: np.random.Generator,
    *,
    width: int,
    height: int,
) -> np.ndarray:
    return rng.integers(0, 256, size=(height, width), dtype=np.uint8)


def _stress_iteration_count(geometry: FrameGeometry, *, heavy: bool) -> int:
    pixels = geometry.width * geometry.height
    if pixels >= (FRAME_WIDTH * FRAME_HEIGHT):
        return 1
    if pixels >= (256 * 256):
        return 2 if heavy else 1
    return 4 if heavy else 2


async def _monitor_output_handshake(
    *,
    i_clk: Any,
    i_rst_n: Any,
    m_axis_tvalid: Any,
    m_axis_tready: Any,
    m_axis_tdata: Any,
    m_axis_tlast: Any,
    m_axis_tuser: Any,
    width: int,
    height: int,
) -> HandshakeStats:
    stats = HandshakeStats()
    ready_low_run = 0
    prev_stall_payload: tuple[int, int, int] | None = None
    accepted_beats = 0
    expected_beats = width * height

    while accepted_beats < expected_beats:
        await RisingEdge(i_clk)
        await ReadOnly()

        if int(i_rst_n.value) == int(RESET_ACTIVE_LEVEL):
            ready_low_run = 0
            prev_stall_payload = None
            accepted_beats = 0
            continue

        valid = int(m_axis_tvalid.value)
        ready = int(m_axis_tready.value)

        if ready == 0:
            ready_low_run += 1
            stats.max_ready_low_run = max(stats.max_ready_low_run, ready_low_run)
        else:
            ready_low_run = 0

        if valid == 1 and ready == 1:
            observed_tuser = int(m_axis_tuser.value)
            observed_tlast = int(m_axis_tlast.value)
            expected_sof = 1 if accepted_beats == 0 else 0
            expected_tlast = 1 if ((accepted_beats + 1) % width) == 0 else 0
            assert observed_tuser == expected_sof, (
                "SOF/TUSER mismatch on accepted output beat "
                f"{accepted_beats}: observed={observed_tuser}, expected={expected_sof}"
            )
            assert observed_tlast == expected_tlast, (
                "EOL/TLAST mismatch on accepted output beat "
                f"{accepted_beats}: observed={observed_tlast}, expected={expected_tlast}"
            )
            accepted_beats += 1

        if valid == 1 and ready == 0:
            stats.saw_stall = True
            payload = (
                int(m_axis_tdata.value),
                int(m_axis_tlast.value),
                int(m_axis_tuser.value),
            )
            if prev_stall_payload is not None:
                assert payload == prev_stall_payload, (
                    "Output payload changed while stalled (VALID=1, READY=0). "
                    f"prev={prev_stall_payload}, now={payload}"
                )
            prev_stall_payload = payload
        else:
            prev_stall_payload = None

    stats.accepted_beats = accepted_beats
    return stats


async def run_wrapper_case(dut, cfg: WrapperRunConfig) -> None:
    if cfg.gray_plane.ndim != 2:
        raise ValueError(
            f"Expected gray plane with shape (H, W), got shape={cfg.gray_plane.shape}",
        )
    gray_plane = cfg.gray_plane.astype(np.uint8, copy=False)
    height, width = gray_plane.shape
    geometry = _frame_geometry_from_dut(dut)
    if width != geometry.width or height != geometry.height:
        raise AssertionError(
            "Input plane shape must match DUT geometry: "
            f"input={(height, width)}, dut={(geometry.height, geometry.width)}"
        )

    i_clk = getattr(dut, ACLK_SIGNAL)
    i_rst_n = getattr(dut, ARESETN_SIGNAL)
    m_axis_tvalid = getattr(dut, f"{M_AXIS_PREFIX}_tvalid")
    m_axis_tready = getattr(dut, f"{M_AXIS_PREFIX}_tready")
    m_axis_tdata = getattr(dut, f"{M_AXIS_PREFIX}_tdata")
    m_axis_tlast = getattr(dut, f"{M_AXIS_PREFIX}_tlast")
    m_axis_tuser = getattr(dut, f"{M_AXIS_PREFIX}_tuser")

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

    timeout_factor = (
        cfg.timeout_factor_backpressure
        if cfg.with_backpressure
        else cfg.timeout_factor_no_backpressure
    )
    timeout_ns = max(cfg.timeout_ns_floor, width * height * timeout_factor)
    handshake_task = None
    if cfg.with_backpressure:
        sink.set_pause_generator(repeating_pause(cfg.sink_pause_pattern))
        handshake_task = cocotb.start_soon(
            _monitor_output_handshake(
                i_clk=i_clk,
                i_rst_n=i_rst_n,
                m_axis_tvalid=m_axis_tvalid,
                m_axis_tready=m_axis_tready,
                m_axis_tdata=m_axis_tdata,
                m_axis_tlast=m_axis_tlast,
                m_axis_tuser=m_axis_tuser,
                width=width,
                height=height,
            ),
        )

    try:
        if cfg.with_backpressure:
            for _ in range(HANDSHAKE_SETTLE_CYCLES):
                await RisingEdge(i_clk)

        expected = _sobel_expected(gray_plane, threshold=SOBEL_THRESHOLD)
        flush_pixels = _warmup_beats(width=width)
        await source.send_image(
            _gray_plane_to_image(gray_plane),
            tail_padding_pixels=flush_pixels,
        )
        received = await sink.recv_plane(
            width=width,
            height=height,
            timeout_ns=timeout_ns,
        )
        if cfg.check_expected:
            _assert_plane_equal(expected, received)

        if handshake_task is not None:
            handshake_stats = await with_timeout(handshake_task, timeout_ns, "ns")
            if cfg.expect_stall:
                assert handshake_stats.saw_stall, (
                    "Expected at least one VALID=1, READY=0 stall cycle."
                )
            if cfg.min_ready_low_run > 0:
                assert handshake_stats.max_ready_low_run >= cfg.min_ready_low_run, (
                    "Backpressure READY-low run too short: "
                    f"observed={handshake_stats.max_ready_low_run}, "
                    f"required>={cfg.min_ready_low_run}"
                )
            assert handshake_stats.accepted_beats == (width * height), (
                "Output accepted-beat count mismatch. "
                f"observed={handshake_stats.accepted_beats}, expected={width * height}"
            )

        if cfg.output_path is not None:
            rgb = np.stack((received, received, received), axis=2)
            Image(rgb).to_png(cfg.output_path)
    finally:
        if handshake_task is not None and not handshake_task.done():
            handshake_task.cancel()
        sink.set_pause_generator(None)
        sink.set_pause(False)


@cocotb.test(timeout_time=150, timeout_unit="ms")
async def test_axi_windowed_filter_wrapper_simple_image(dut) -> None:
    geometry = _frame_geometry_from_dut(dut)
    image = Image.gradient_gray(width=geometry.width, height=geometry.height)
    gray = image.pixels[:, :, 0]
    await run_wrapper_case(dut, WrapperRunConfig(gray_plane=gray))


@cocotb.test(timeout_time=250, timeout_unit="ms")
async def test_axi_windowed_filter_wrapper_lenna_end_to_end(dut) -> None:
    geometry = _frame_geometry_from_dut(dut)
    if (geometry.width, geometry.height) != (FRAME_WIDTH, FRAME_HEIGHT):
        cocotb.log.info(
            "Skipping Lenna functional check for non-default geometry %dx%d",
            geometry.width,
            geometry.height,
        )
        return

    input_path = TESTBENCH_ROOT / "images" / "lenna_512_512.png"
    output_path = _sim_artifact_dir() / "lenna_512_512_out_wrapper_sobel.png"

    image = Image.from_png(input_path)
    gray = _gray_from_rgb(image)
    await run_wrapper_case(
        dut,
        WrapperRunConfig(
            gray_plane=gray,
            output_path=output_path,
        ),
    )


@cocotb.test(timeout_time=320, timeout_unit="ms")
async def test_axi_windowed_filter_wrapper_backpressure_handshake_only(dut) -> None:
    geometry = _frame_geometry_from_dut(dut)
    image = Image.gradient_gray(width=geometry.width, height=geometry.height)
    gray = image.pixels[:, :, 0]
    await run_wrapper_case(
        dut,
        WrapperRunConfig(
            gray_plane=gray,
            with_backpressure=True,
            check_expected=False,
        ),
    )


@cocotb.test(timeout_time=360, timeout_unit="ms")
async def test_axi_windowed_filter_wrapper_stress_fast(dut) -> None:
    geometry = _frame_geometry_from_dut(dut)
    if (geometry.width, geometry.height) == (FRAME_WIDTH, FRAME_HEIGHT):
        cocotb.log.info(
            "Skipping randomized stress on default geometry %dx%d; "
            "run target axi_filter_wrapper_stress for stress coverage.",
            geometry.width,
            geometry.height,
        )
        return

    rng = np.random.default_rng(FAST_STRESS_SEED)

    for _ in range(_stress_iteration_count(geometry, heavy=False)):
        gray_plane = _random_gray_plane(
            rng,
            width=geometry.width,
            height=geometry.height,
        )
        await run_wrapper_case(
            dut,
            WrapperRunConfig(
                gray_plane=gray_plane,
                with_backpressure=True,
                sink_pause_pattern=_random_pause_pattern(rng, min_len=4, max_len=10),
                timeout_factor_backpressure=190,
                min_ready_low_run=1,
            ),
        )


@cocotb.test(timeout_time=520, timeout_unit="ms")
async def test_axi_windowed_filter_wrapper_stress_heavy_randomized(dut) -> None:
    geometry = _frame_geometry_from_dut(dut)
    if (geometry.width, geometry.height) == (FRAME_WIDTH, FRAME_HEIGHT):
        cocotb.log.info(
            "Skipping heavy randomized stress on default geometry %dx%d; "
            "run target axi_filter_wrapper_stress for stress coverage.",
            geometry.width,
            geometry.height,
        )
        return

    rng = np.random.default_rng(HEAVY_STRESS_SEED)

    for _ in range(_stress_iteration_count(geometry, heavy=True)):
        gray_plane = _random_gray_plane(
            rng,
            width=geometry.width,
            height=geometry.height,
        )
        await run_wrapper_case(
            dut,
            WrapperRunConfig(
                gray_plane=gray_plane,
                with_backpressure=True,
                sink_pause_pattern=_random_pause_pattern(rng, min_len=8, max_len=18),
                timeout_factor_backpressure=240,
                min_ready_low_run=1,
            ),
        )
