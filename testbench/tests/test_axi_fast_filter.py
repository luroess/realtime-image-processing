"""AXI4-Stream FAST-9 + NMS filter cocotb tests."""

from __future__ import annotations

import os
from dataclasses import dataclass
from pathlib import Path
from typing import Any

import cocotb
import numpy as np
from cocotb.clock import Clock
from cocotb.triggers import ReadOnly, RisingEdge, with_timeout
from common.fast_reference import (
    _assert_matches_opencv_interior,
    _assert_plane_equal,
    _center_crop,
    _fast_expected,
    _gray_from_rgb,
    _random_pause_pattern,
    _read_positive_generic,
)
from common.pause import repeating_pause
from common.reset import apply_reset
from drivers.axis_window_gray_source import AxiWindowGraySource
from models.image_model import Image
from monitors.axis_gray_sink import AxiGrayStreamSink

# TODO(config-surface): Keep these module-level knobs mirrored with target generics so stress tiers exercise the intended FAST operating point.
ACLK_SIGNAL = "i_aclk"
ARESETN_SIGNAL = "i_aresetn"
S_AXIS_PREFIX = "s_axis_window"
M_AXIS_PREFIX = "m_axis_filter8"
RESET_ACTIVE_LEVEL = False
TESTBENCH_ROOT = Path(__file__).resolve().parents[1]

FAST_THRESHOLD = 20
FAST_N = 9
WINDOW_SIZE = 7
NMS_WINDOW_SIZE = 3
FRAME_WIDTH = 128
FRAME_HEIGHT = 128
LENNA_MIN_CORNER_RATIO = 0.005
LENNA_MIN_INTERIOR_RATIO = 0.003
LENNA_MAX_BORDER_FRACTION = 0.70
VISUAL_BORDER = 8

SINK_PAUSE_PATTERN = (1, 1, 1, 0, 0, 0)
SOURCE_PAUSE_PATTERN = (0, 1, 0, 0)
MIN_READY_LOW_RUN = 3
HANDSHAKE_SETTLE_CYCLES = 6
FAST_STRESS_SEED = 0xF45A_1101
HEAVY_STRESS_SEED = 0xF45A_2202
HEAVY_STRESS_CASE_COUNT = 8

@dataclass(slots=True)
class HandshakeStats:
    # TODO(handshake-metrics): Extend this record with cycle counters if throughput regressions need finer attribution than stall/run length.
    saw_stall: bool = False
    max_ready_low_run: int = 0
    accepted_beats: int = 0


@dataclass(slots=True)
class FastRunConfig:
    # FIXME(timeout-budget): Re-tune timeout defaults when frame size or DUT latency changes to avoid flaky timeout-driven failures.
    gray_plane: np.ndarray
    output_path: Path | None = None
    source_pause_pattern: tuple[int, ...] | None = SOURCE_PAUSE_PATTERN
    sink_pause_pattern: tuple[int, ...] | None = SINK_PAUSE_PATTERN
    timeout_ns_per_pixel: int = 180
    timeout_ns_floor: int = 200_000
    expect_stall: bool = True
    min_ready_low_run: int = MIN_READY_LOW_RUN


@dataclass(slots=True, frozen=True)
class FrameGeometry:
    # TODO(geometry-source): Keep geometry values sourced from DUT generics so test vectors remain valid after resolution changes.
    width: int
    height: int


def _sim_artifact_dir() -> Path:
    # TODO(artifact-layout): Keep artifact path deterministic per test module so CI can collect reference images predictably.
    results_file = os.getenv("COCOTB_RESULTS_FILE")
    if results_file:
        return Path(results_file).resolve().parent
    return TESTBENCH_ROOT / "sim_build" / "test_axi_fast_filter"


def _frame_geometry_from_dut(dut: Any) -> FrameGeometry:
    # TODO(geometry-validation): Add explicit bounds checks here when supporting larger stress profiles to fail fast on invalid generics.
    return FrameGeometry(
        width=_read_positive_generic(dut, "G_LINE_WIDTH", FRAME_WIDTH),
        height=_read_positive_generic(dut, "G_NUM_ROW", FRAME_HEIGHT),
    )


def _checkerboard_gray(*, width: int, height: int, tile: int = 2) -> np.ndarray:
    # TODO(pattern-coverage): Keep checkerboard generator available for deterministic aliasing/backpressure regressions.
    y, x = np.indices((height, width), dtype=np.int32)
    board = ((x // tile) + (y // tile)) & 1
    return (board * 255).astype(np.uint8)


def _impulse_gray(*, width: int, height: int) -> np.ndarray:
    # TODO(impulse-probe): Preserve this sparse stimulus for verifying corner localization and NMS suppression edges.
    plane = np.zeros((height, width), dtype=np.uint8)
    plane[height // 2, width // 2] = 255
    return plane


def _warmup_beats(*, width: int, wndw_size: int) -> int:
    # FIXME(warmup-coupling): Update warm-up math with any internal window-stage changes so tail padding remains sufficient.
    return ((width + 1) * ((wndw_size - 1) // 2)) + 1


def _assert_visual_acceptance(
    *,
    hw_mask: np.ndarray,
    border: int = VISUAL_BORDER,
    min_corner_ratio: float = LENNA_MIN_CORNER_RATIO,
    min_interior_ratio: float = LENNA_MIN_INTERIOR_RATIO,
    max_border_fraction: float = LENNA_MAX_BORDER_FRACTION,
) -> None:
    # TODO(visual-gates): Keep these acceptance thresholds aligned with real-scene datasets so sparse artifacts fail fast.
    total_pixels = int(hw_mask.size)
    if total_pixels == 0:
        raise AssertionError("Empty FAST mask received for visual acceptance check.")

    corner_count = int(np.count_nonzero(hw_mask))
    corner_ratio = corner_count / total_pixels
    if corner_ratio < min_corner_ratio:
        raise AssertionError(
            "Corner density below visual acceptance threshold: "
            f"ratio={corner_ratio:.6f}, min={min_corner_ratio:.6f}, corners={corner_count}",
        )

    if hw_mask.shape[0] <= (2 * border) or hw_mask.shape[1] <= (2 * border):
        return

    border_mask = np.zeros(hw_mask.shape, dtype=bool)
    border_mask[:border, :] = True
    border_mask[-border:, :] = True
    border_mask[:, :border] = True
    border_mask[:, -border:] = True

    border_corners = int(np.count_nonzero(hw_mask[border_mask]))
    interior_corners = int(np.count_nonzero(hw_mask[~border_mask]))
    interior_ratio = interior_corners / total_pixels
    border_fraction = 0.0 if corner_count == 0 else (border_corners / corner_count)

    cocotb.log.info(
        "Visual acceptance metrics: corners=%d ratio=%.6f interior=%d interior_ratio=%.6f border=%d border_fraction=%.6f",
        corner_count,
        corner_ratio,
        interior_corners,
        interior_ratio,
        border_corners,
        border_fraction,
    )

    if interior_ratio < min_interior_ratio:
        raise AssertionError(
            "Interior corner density below visual acceptance threshold: "
            f"interior_ratio={interior_ratio:.6f}, min={min_interior_ratio:.6f}, "
            f"interior_corners={interior_corners}",
        )
    if border_fraction > max_border_fraction:
        raise AssertionError(
            "Border-dominated corner distribution above visual acceptance threshold: "
            f"border_fraction={border_fraction:.6f}, max={max_border_fraction:.6f}, "
            f"border_corners={border_corners}, corners={corner_count}",
        )


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
    # FIXME(protocol-watchdog): Keep payload-stability and SOF/EOL checks strict during stalls to catch AXI contract violations early.
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


async def run_fast_case(dut, cfg: FastRunConfig) -> np.ndarray:
    # TODO(case-runner): Centralize source/sink setup here so future mode-select experiments can reuse one execution path.
    if cfg.gray_plane.ndim != 2:
        raise ValueError(
            f"Expected gray plane with shape (H, W), got shape={cfg.gray_plane.shape}",
        )
    gray_plane = cfg.gray_plane.astype(np.uint8, copy=False)
    geometry = _frame_geometry_from_dut(dut)
    if gray_plane.shape != (geometry.height, geometry.width):
        raise AssertionError(
            "Input plane shape must match DUT geometry: "
            f"input={gray_plane.shape}, dut={(geometry.height, geometry.width)}",
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

    source = AxiWindowGraySource(
        dut=dut,
        i_clk=i_clk,
        i_rst_n=i_rst_n,
        prefix=S_AXIS_PREFIX,
        reset_active_level=RESET_ACTIVE_LEVEL,
        wndw_size=WINDOW_SIZE,
    )
    sink = AxiGrayStreamSink(
        dut=dut,
        i_clk=i_clk,
        i_rst_n=i_rst_n,
        prefix=M_AXIS_PREFIX,
        reset_active_level=RESET_ACTIVE_LEVEL,
    )

    height, width = gray_plane.shape
    timeout_ns = max(
        cfg.timeout_ns_floor,
        width * height * cfg.timeout_ns_per_pixel,
    )

    if cfg.source_pause_pattern is not None:
        source.set_pause_generator(repeating_pause(cfg.source_pause_pattern))
    if cfg.sink_pause_pattern is not None:
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

    received: np.ndarray | None = None

    try:
        for _ in range(HANDSHAKE_SETTLE_CYCLES):
            await RisingEdge(i_clk)

        expected = _fast_expected(gray_plane)

        # AXI_FastFilter contains an internal 3x3 score-window stage for NMS.
        flush_windows = _warmup_beats(width=width, wndw_size=NMS_WINDOW_SIZE)
        await source.send_gray_image(
            gray_plane,
            tail_padding_windows=flush_windows,
        )

        received = await sink.recv_plane(
            width=width,
            height=height,
            timeout_ns=timeout_ns,
        )
        _assert_plane_equal(expected, received)

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
        if not handshake_task.done():
            handshake_task.cancel()
        source.set_pause_generator(None)
        source.set_pause(False)
        sink.set_pause_generator(None)
        sink.set_pause(False)

    if received is None:
        raise AssertionError("No output plane captured from FAST DUT.")
    return received


@cocotb.test()
async def test_axi_fast_filter_gradient_gray_windows(dut) -> None:
    # TODO(test-baseline): Keep this deterministic baseline as the first triage signal for functional regressions.
    geometry = _frame_geometry_from_dut(dut)
    image = Image.gradient_gray(width=geometry.width, height=geometry.height)
    gray = image.pixels[:, :, 0]
    await run_fast_case(
        dut,
        FastRunConfig(
            gray_plane=gray,
            source_pause_pattern=None,
            sink_pause_pattern=None,
            expect_stall=False,
            min_ready_low_run=0,
        ),
    )


@cocotb.test(timeout_time=160, timeout_unit="ms")
async def test_axi_fast_filter_checkerboard_backpressure_handshake(dut) -> None:
    # FIXME(backpressure-depth): Revisit expected READY-low run threshold after handshake pipeline or pause pattern updates.
    geometry = _frame_geometry_from_dut(dut)
    gray = _checkerboard_gray(width=geometry.width, height=geometry.height, tile=2)
    await run_fast_case(
        dut,
        FastRunConfig(
            gray_plane=gray,
            source_pause_pattern=None,
            sink_pause_pattern=SINK_PAUSE_PATTERN,
            expect_stall=True,
            min_ready_low_run=MIN_READY_LOW_RUN,
        ),
    )


@cocotb.test(timeout_time=180, timeout_unit="ms")
async def test_axi_fast_filter_impulse_mixed_throttle(dut) -> None:
    # TODO(test-throttle): Keep mixed source/sink throttling coverage for stress on simultaneous valid/ready gating.
    geometry = _frame_geometry_from_dut(dut)
    gray = _impulse_gray(width=geometry.width, height=geometry.height)
    await run_fast_case(
        dut,
        FastRunConfig(
            gray_plane=gray,
            source_pause_pattern=SOURCE_PAUSE_PATTERN,
            sink_pause_pattern=SINK_PAUSE_PATTERN,
            expect_stall=True,
            min_ready_low_run=MIN_READY_LOW_RUN,
            timeout_ns_per_pixel=220,
        ),
    )


@cocotb.test(timeout_time=320, timeout_unit="ms")
async def test_axi_fast_filter_lenna_end_to_end(dut) -> None:
    # TODO(test-fixture): Retain real-image coverage to expose corner-density behavior not visible in synthetic patterns.
    geometry = _frame_geometry_from_dut(dut)
    input_path = TESTBENCH_ROOT / "images" / "lenna_512_512.png"
    output_path = _sim_artifact_dir() / "lenna_512_512_out_fast.png"

    image = Image.from_png(input_path)
    gray = _gray_from_rgb(image)
    if gray.shape[0] < geometry.height or gray.shape[1] < geometry.width:
        cocotb.log.info(
            "Skipping Lenna check because DUT geometry exceeds image dimensions: %dx%d",
            geometry.width,
            geometry.height,
        )
        return

    gray_fit = _center_crop(
        gray,
        width=geometry.width,
        height=geometry.height,
    )
    received = await run_fast_case(
        dut,
        FastRunConfig(
            gray_plane=gray_fit,
            output_path=output_path,
            source_pause_pattern=SOURCE_PAUSE_PATTERN,
            sink_pause_pattern=SINK_PAUSE_PATTERN,
            timeout_ns_per_pixel=210,
        ),
    )
    _assert_visual_acceptance(hw_mask=received)
    _assert_matches_opencv_interior(gray_plane=gray_fit, hw_mask=received)


@cocotb.test(timeout_time=360, timeout_unit="ms")
async def test_axi_fast_filter_mountains_center_crop_end_to_end(dut) -> None:
    # FIXME(dataset-assumption): Ensure external image dimensions remain >= DUT geometry or this coverage silently degrades via skip path.
    geometry = _frame_geometry_from_dut(dut)
    input_path = TESTBENCH_ROOT / "images" / "mountains_1920_1080.png"
    output_path = _sim_artifact_dir() / "mountains_1920_1080_center_out_fast.png"

    image = Image.from_png(input_path)
    gray = _gray_from_rgb(image)
    if gray.shape[0] < geometry.height or gray.shape[1] < geometry.width:
        cocotb.log.info(
            "Skipping mountains center-crop check because DUT geometry exceeds image dimensions: %dx%d",
            geometry.width,
            geometry.height,
        )
        return

    gray_crop = _center_crop(
        gray,
        width=geometry.width,
        height=geometry.height,
    )
    received = await run_fast_case(
        dut,
        FastRunConfig(
            gray_plane=gray_crop,
            output_path=output_path,
            source_pause_pattern=SOURCE_PAUSE_PATTERN,
            sink_pause_pattern=SINK_PAUSE_PATTERN,
            timeout_ns_per_pixel=220,
        ),
    )
    _assert_matches_opencv_interior(gray_plane=gray_crop, hw_mask=received)


@cocotb.test(timeout_time=260, timeout_unit="ms")
async def test_axi_fast_filter_stress_fast(dut) -> None:
    # TODO(stress-fast): Keep this quick randomized sweep lightweight enough for pre-merge CI while still touching stall paths.
    geometry = _frame_geometry_from_dut(dut)
    rng = np.random.default_rng(FAST_STRESS_SEED)
    patterns = (
        lambda w, h: Image.gradient_gray(width=w, height=h).pixels[:, :, 0],
        lambda w, h: _checkerboard_gray(width=w, height=h, tile=2),
        lambda w, h: _impulse_gray(width=w, height=h),
        lambda w, h: rng.integers(0, 256, size=(h, w), dtype=np.uint8),
    )

    for idx in range(4):
        gray_plane = patterns[idx % len(patterns)](geometry.width, geometry.height)
        await run_fast_case(
            dut,
            FastRunConfig(
                gray_plane=gray_plane,
                source_pause_pattern=_random_pause_pattern(rng, min_len=3, max_len=7),
                sink_pause_pattern=_random_pause_pattern(rng, min_len=4, max_len=9),
                timeout_ns_per_pixel=240,
                expect_stall=False,
                min_ready_low_run=1,
            ),
        )


@cocotb.test(timeout_time=380, timeout_unit="ms")
async def test_axi_fast_filter_stress_heavy_randomized(dut) -> None:
    # FIXME(stress-heavy-budget): Re-balance case count and timeout when pipeline depth changes to prevent false negatives in heavy tier.
    geometry = _frame_geometry_from_dut(dut)
    rng = np.random.default_rng(HEAVY_STRESS_SEED)
    for _ in range(HEAVY_STRESS_CASE_COUNT):
        gray_plane = rng.integers(
            0,
            256,
            size=(geometry.height, geometry.width),
            dtype=np.uint8,
        )
        await run_fast_case(
            dut,
            FastRunConfig(
                gray_plane=gray_plane,
                source_pause_pattern=_random_pause_pattern(rng, min_len=5, max_len=12),
                sink_pause_pattern=_random_pause_pattern(rng, min_len=6, max_len=14),
                timeout_ns_per_pixel=280,
                expect_stall=False,
                min_ready_low_run=1,
            ),
        )
