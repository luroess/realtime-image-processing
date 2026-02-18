"""AXI window-generator + FAST-9 + NMS wrapper cocotb tests."""

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
from drivers.axis_gray_source import AxiGrayStreamSource
from models.image_model import Image
from monitors.axis_gray_sink import AxiGrayStreamSink

# TODO(config-surface): Keep wrapper-level constants aligned with target generics so fast/heavy tiers exercise intended dimensions.
ACLK_SIGNAL = "i_aclk"
ARESETN_SIGNAL = "i_aresetn"
S_AXIS_PREFIX = "s_axis_gray8"
M_AXIS_PREFIX = "m_axis_filter8"
RESET_ACTIVE_LEVEL = False
TESTBENCH_ROOT = Path(__file__).resolve().parents[1]

FAST_THRESHOLD = 20
FAST_N = 9
FRAME_WIDTH = 512
FRAME_HEIGHT = 512
LENNA_MIN_CORNER_RATIO = 0.005
LENNA_MIN_INTERIOR_RATIO = 0.003
LENNA_MAX_BORDER_FRACTION = 0.70
VISUAL_BORDER = 8
SINK_PAUSE_PATTERN = (0, 0, 0, 0, 0, 0, 0, 1)
MIN_READY_LOW_RUN = 1
HANDSHAKE_SETTLE_CYCLES = 6
FAST_STRESS_SEED = 0xA1F9_1101
HEAVY_STRESS_SEED = 0xA1F9_2202

@dataclass(slots=True)
class HandshakeStats:
    # TODO(handshake-metrics): Extend with latency histograms if wrapper regressions need finer protocol diagnostics.
    saw_stall: bool = False
    max_ready_low_run: int = 0
    accepted_beats: int = 0


@dataclass(slots=True, frozen=True)
class FrameGeometry:
    # TODO(geometry-source): Keep this immutable shape record tied to DUT generic reads to prevent accidental resizing in tests.
    width: int
    height: int


@dataclass(slots=True)
class WrapperFastRunConfig:
    # FIXME(timeout-budget): Revisit timeout factors when adding pipeline stages so backpressure checks remain stable.
    gray_plane: np.ndarray
    output_path: Path | None = None
    with_backpressure: bool = False
    check_expected: bool = True
    sink_pause_pattern: tuple[int, ...] = SINK_PAUSE_PATTERN
    timeout_factor_no_backpressure: int = 90
    timeout_factor_backpressure: int = 190
    timeout_ns_floor: int = 500_000
    expect_stall: bool = True
    min_ready_low_run: int = MIN_READY_LOW_RUN


def _warmup_beats(*, width: int, wndw_size: int) -> int:
    # FIXME(warmup-coupling): Update this formula whenever wrapper internals add/remove windowed stages.
    return ((width + 1) * ((wndw_size - 1) // 2)) + 1


def _sim_artifact_dir() -> Path:
    # TODO(artifact-layout): Keep outputs grouped by module for deterministic artifact collection in CI.
    results_file = os.getenv("COCOTB_RESULTS_FILE")
    if results_file:
        return Path(results_file).resolve().parent
    return TESTBENCH_ROOT / "sim_build" / "test_axi_filter_wrapper_fast"


def _gray_plane_to_image(gray_plane: np.ndarray) -> Image:
    # TODO(image-adapter): Preserve this conversion helper so source driver remains decoupled from numpy storage details.
    gray_u8 = gray_plane.astype(np.uint8)
    rgb = np.stack((gray_u8, gray_u8, gray_u8), axis=2)
    return Image(rgb)


def _frame_geometry_from_dut(dut: Any) -> FrameGeometry:
    # TODO(geometry-validation): Add optional max-bound checks when adding larger stress presets.
    return FrameGeometry(
        width=_read_positive_generic(dut, "G_LINE_WIDTH", FRAME_WIDTH),
        height=_read_positive_generic(dut, "G_NUM_ROW", FRAME_HEIGHT),
    )


def _random_gray_plane(
    rng: np.random.Generator,
    *,
    width: int,
    height: int,
) -> np.ndarray:
    # TODO(random-seeding): Keep seeded random generation deterministic to allow reproducible stress failures.
    return rng.integers(0, 256, size=(height, width), dtype=np.uint8)


def _assert_visual_acceptance(
    *,
    hw_mask: np.ndarray,
    border: int = VISUAL_BORDER,
    min_corner_ratio: float = LENNA_MIN_CORNER_RATIO,
    min_interior_ratio: float = LENNA_MIN_INTERIOR_RATIO,
    max_border_fraction: float = LENNA_MAX_BORDER_FRACTION,
) -> None:
    # TODO(visual-gates): Keep these thresholds in sync with representative datasets so low-information crops fail deterministically.
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
    # FIXME(protocol-watchdog): Keep stall payload stability checks strict so READY deassertions cannot hide protocol bugs.
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


async def run_wrapper_fast_case(dut, cfg: WrapperFastRunConfig) -> np.ndarray:
    # TODO(case-runner): Keep wrapper execution and checks centralized here for reuse by fast and heavy tier tests.
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

    received: np.ndarray | None = None

    try:
        if cfg.with_backpressure:
            for _ in range(HANDSHAKE_SETTLE_CYCLES):
                await RisingEdge(i_clk)

        if cfg.check_expected:
            expected = _fast_expected(gray_plane)

        flush_pixels = _warmup_beats(width=width, wndw_size=7) + _warmup_beats(
            width=width,
            wndw_size=3,
        )
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

    if received is None:
        raise AssertionError("No output plane captured from wrapper FAST DUT.")
    return received


@cocotb.test(timeout_time=180, timeout_unit="ms")
async def test_axi_filter_wrapper_fast_simple_image(dut) -> None:
    # TODO(test-baseline): Preserve a deterministic smoke case for quick wrapper health checks.
    geometry = _frame_geometry_from_dut(dut)
    image = Image.gradient_gray(width=geometry.width, height=geometry.height)
    gray = image.pixels[:, :, 0]
    await run_wrapper_fast_case(dut, WrapperFastRunConfig(gray_plane=gray))


@cocotb.test(timeout_time=320, timeout_unit="ms")
async def test_axi_filter_wrapper_fast_lenna_end_to_end(dut) -> None:
    # TODO(test-fixture): Keep natural-image validation to capture texture-driven FAST behavior.
    geometry = _frame_geometry_from_dut(dut)
    input_path = TESTBENCH_ROOT / "images" / "lenna_512_512.png"
    output_path = _sim_artifact_dir() / "lenna_out_wrapper_fast.png"

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
    received = await run_wrapper_fast_case(
        dut,
        WrapperFastRunConfig(
            gray_plane=gray_fit,
            output_path=output_path,
        ),
    )
    _assert_visual_acceptance(hw_mask=received)
    _assert_matches_opencv_interior(gray_plane=gray_fit, hw_mask=received)


@cocotb.test(timeout_time=360, timeout_unit="ms")
async def test_axi_filter_wrapper_fast_mountains_center_crop_end_to_end(dut) -> None:
    # FIXME(dataset-assumption): Keep fixture size checks explicit so coverage loss via skip remains visible.
    geometry = _frame_geometry_from_dut(dut)
    input_path = TESTBENCH_ROOT / "images" / "mountains_1920_1080.png"
    output_path = _sim_artifact_dir() / "mountains_1920_1080_center_out_wrapper_fast.png"

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
    received = await run_wrapper_fast_case(
        dut,
        WrapperFastRunConfig(
            gray_plane=gray_crop,
            output_path=output_path,
        ),
    )
    _assert_matches_opencv_interior(gray_plane=gray_crop, hw_mask=received)


@cocotb.test(timeout_time=320, timeout_unit="ms")
async def test_axi_filter_wrapper_fast_backpressure_handshake_only(dut) -> None:
    # TODO(test-handshake): Maintain this protocol-focused case to isolate transport issues from functional mismatches.
    geometry = _frame_geometry_from_dut(dut)
    image = Image.gradient_gray(width=geometry.width, height=geometry.height)
    gray = image.pixels[:, :, 0]
    await run_wrapper_fast_case(
        dut,
        WrapperFastRunConfig(
            gray_plane=gray,
            with_backpressure=True,
            check_expected=False,
        ),
    )


@cocotb.test(timeout_time=360, timeout_unit="ms")
async def test_axi_filter_wrapper_fast_stress_fast(dut) -> None:
    # TODO(stress-fast): Keep fast-tier randomized coverage lightweight while still exercising pause-driven stalls.
    geometry = _frame_geometry_from_dut(dut)
    rng = np.random.default_rng(FAST_STRESS_SEED)

    for _ in range(2):
        gray_plane = _random_gray_plane(
            rng,
            width=geometry.width,
            height=geometry.height,
        )
        await run_wrapper_fast_case(
            dut,
            WrapperFastRunConfig(
                gray_plane=gray_plane,
                with_backpressure=True,
                sink_pause_pattern=_random_pause_pattern(rng, min_len=4, max_len=10),
                timeout_factor_backpressure=220,
                min_ready_low_run=1,
            ),
        )


@cocotb.test(timeout_time=520, timeout_unit="ms")
async def test_axi_filter_wrapper_fast_stress_heavy_randomized(dut) -> None:
    # FIXME(stress-heavy-budget): Re-tune heavy loop count and timeout if wrapper latency/queue depth changes.
    geometry = _frame_geometry_from_dut(dut)
    rng = np.random.default_rng(HEAVY_STRESS_SEED)

    for _ in range(4):
        gray_plane = _random_gray_plane(
            rng,
            width=geometry.width,
            height=geometry.height,
        )
        await run_wrapper_fast_case(
            dut,
            WrapperFastRunConfig(
                gray_plane=gray_plane,
                with_backpressure=True,
                sink_pause_pattern=_random_pause_pattern(rng, min_len=8, max_len=18),
                timeout_factor_backpressure=260,
                min_ready_low_run=1,
            ),
        )
