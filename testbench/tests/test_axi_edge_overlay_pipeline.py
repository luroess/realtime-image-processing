"""AXI4-Stream end-to-end integration tests for RGB->Gray->Sobel->Overlay pipeline."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any

import cocotb
import numpy as np
from cocotb.clock import Clock
from cocotb.triggers import ReadOnly, RisingEdge, with_timeout
from common.pause import drive_sink_pause
from common.reset import apply_reset
from drivers.axis_video_source import AxiVideoStreamSource
from models.image_model import Image
from monitors.axis_video_sink import AxiVideoStreamSink
from verification.scoreboard import Scoreboard

ACLK_SIGNAL = "i_aclk"
ARESETN_SIGNAL = "i_aresetn"
S_AXIS_PREFIX = "s_axis_video"
M_AXIS_PREFIX = "m_axis_video_rbg888"
RESET_ACTIVE_LEVEL = False
PIXEL_ORDER = "rbg"
EDGE_COLOR_RGB = (255, 0, 0)


@dataclass(slots=True)
class PipelineCaseConfig:
    overlay_enable: bool = True
    pass_through: bool = False
    with_backpressure: bool = False
    pause_pattern: tuple[int, ...] = (0, 0, 1, 0, 0, 1, 0)
    check_handshake: bool = False
    min_ready_low_run: int = 0
    handshake_settle_cycles: int = 8
    timeout_floor_ns: int = 500_000
    timeout_per_pixel_ns: int = 140


@dataclass(slots=True)
class HandshakeStats:
    saw_stall: bool = False
    max_ready_low_run: int = 0
    accepted_beats: int = 0


@dataclass(slots=True, frozen=True)
class FrameGeometry:
    width: int
    height: int


def _warmup_beats(*, width: int, kernel_size: int = 3) -> int:
    return ((width + 1) * ((kernel_size - 1) // 2)) + 1


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


def _read_nonnegative_generic(dut: Any, name: str, default: int) -> int:
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

    if value < 0:
        raise AssertionError(f"Expected non-negative generic value for {name}, got {value}")
    return value


def _frame_geometry_from_dut(dut: Any) -> FrameGeometry:
    return FrameGeometry(
        width=_read_positive_generic(dut, "G_LINE_WIDTH", 64),
        height=_read_positive_generic(dut, "G_NUM_ROW", 48),
    )


def _checkerboard_image(width: int, height: int, tile: int = 8) -> Image:
    if tile <= 0:
        raise ValueError("tile must be > 0")

    yy, xx = np.indices((height, width), dtype=np.int32)
    board = ((xx // tile) + (yy // tile)) & 1

    r = np.where(board == 0, 30, 220)
    g = np.where(board == 0, 200, 40)
    b = np.where(board == 0, 60, 180)

    pixels = np.stack((r, g, b), axis=2).astype(np.uint8)
    return Image(pixels)


def _gray_plane(image: Image) -> np.ndarray:
    pixels_u16 = image.pixels.astype(np.uint16)
    r = pixels_u16[:, :, 0]
    g = pixels_u16[:, :, 1]
    b = pixels_u16[:, :, 2]
    return ((r >> 2) + (g >> 1) + (b >> 2)).astype(np.uint8)


def _sobel_binary(gray_plane: np.ndarray, *, threshold: int) -> np.ndarray:
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


def _expected_overlay(
    image: Image,
    *,
    overlay_enable: bool,
    pass_through: bool,
    threshold: int,
) -> Image:
    if pass_through:
        base_rgb = image.pixels.copy()
    else:
        gray = _gray_plane(image)
        base_rgb = np.stack((gray, gray, gray), axis=2)

    if not overlay_enable:
        return Image(base_rgb.astype(np.uint8))

    edges = _sobel_binary(_gray_plane(image), threshold=threshold)
    out = base_rgb.astype(np.uint8, copy=True)
    out[edges != 0] = np.array(EDGE_COLOR_RGB, dtype=np.uint8)
    return Image(out)


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
    accepted_beats = 0
    expected_beats = width * height
    prev_stall_payload: tuple[int, int, int] | None = None

    while accepted_beats < expected_beats:
        await RisingEdge(i_clk)
        await ReadOnly()

        if int(i_rst_n.value) == int(RESET_ACTIVE_LEVEL):
            ready_low_run = 0
            accepted_beats = 0
            prev_stall_payload = None
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
            expected_tuser = 1 if accepted_beats == 0 else 0
            expected_tlast = 1 if ((accepted_beats + 1) % width) == 0 else 0

            assert observed_tuser == expected_tuser, (
                "SOF/TUSER mismatch on accepted output beat "
                f"{accepted_beats}: observed={observed_tuser}, expected={expected_tuser}"
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


class AxiEdgeOverlayPipelineTestbench:
    def __init__(self, dut, cfg: PipelineCaseConfig) -> None:
        self.dut = dut
        self.cfg = cfg

        self.i_clk = getattr(dut, ACLK_SIGNAL)
        self.i_rst_n = getattr(dut, ARESETN_SIGNAL)
        self.i_overlay_enable = getattr(dut, "i_overlay_enable")
        self.i_pass_through = getattr(dut, "i_pass_through")

        self.s_axis_tvalid = getattr(dut, f"{S_AXIS_PREFIX}_tvalid")
        self.s_axis_tdata = getattr(dut, f"{S_AXIS_PREFIX}_tdata")
        self.s_axis_tlast = getattr(dut, f"{S_AXIS_PREFIX}_tlast")
        self.s_axis_tuser = getattr(dut, f"{S_AXIS_PREFIX}_tuser")

        self.m_axis_tvalid = getattr(dut, f"{M_AXIS_PREFIX}_tvalid")
        self.m_axis_tready = getattr(dut, f"{M_AXIS_PREFIX}_tready")
        self.m_axis_tdata = getattr(dut, f"{M_AXIS_PREFIX}_tdata")
        self.m_axis_tlast = getattr(dut, f"{M_AXIS_PREFIX}_tlast")
        self.m_axis_tuser = getattr(dut, f"{M_AXIS_PREFIX}_tuser")

        self.source: AxiVideoStreamSource | None = None
        self.sink: AxiVideoStreamSink | None = None
        self.scoreboard = Scoreboard()

        self._clock_started = False
        self._pause_task = None
        self._handshake_task = None

    async def initialize(self) -> None:
        self.i_rst_n.value = int(RESET_ACTIVE_LEVEL)
        self.i_overlay_enable.value = int(self.cfg.overlay_enable)
        self.i_pass_through.value = int(self.cfg.pass_through)
        self.s_axis_tvalid.value = 0
        self.s_axis_tdata.value = 0
        self.s_axis_tlast.value = 0
        self.s_axis_tuser.value = 0
        self.m_axis_tready.value = 0

        if not self._clock_started:
            cocotb.start_soon(Clock(self.i_clk, 10, unit="ns").start())
            self._clock_started = True

        await apply_reset(
            dut=self.dut,
            i_clk=self.i_clk,
            i_rst_n=self.i_rst_n,
            stream_input_prefix=S_AXIS_PREFIX,
            reset_active_level=RESET_ACTIVE_LEVEL,
        )

        self.i_overlay_enable.value = int(self.cfg.overlay_enable)
        self.i_pass_through.value = int(self.cfg.pass_through)

        self.source = AxiVideoStreamSource(
            dut=self.dut,
            i_clk=self.i_clk,
            i_rst_n=self.i_rst_n,
            prefix=S_AXIS_PREFIX,
            reset_active_level=RESET_ACTIVE_LEVEL,
            pixel_order=PIXEL_ORDER,
        )
        self.sink = AxiVideoStreamSink(
            dut=self.dut,
            i_clk=self.i_clk,
            i_rst_n=self.i_rst_n,
            prefix=M_AXIS_PREFIX,
            reset_active_level=RESET_ACTIVE_LEVEL,
            pixel_order=PIXEL_ORDER,
        )

    def _start_optional_tasks(self, *, width: int, height: int) -> None:
        if self.cfg.with_backpressure:
            assert self.sink is not None
            self._pause_task = cocotb.start_soon(
                drive_sink_pause(
                    sink=self.sink,
                    i_clk=self.i_clk,
                    pattern=self.cfg.pause_pattern,
                ),
            )

        if self.cfg.check_handshake:
            self._handshake_task = cocotb.start_soon(
                _monitor_output_handshake(
                    i_clk=self.i_clk,
                    i_rst_n=self.i_rst_n,
                    m_axis_tvalid=self.m_axis_tvalid,
                    m_axis_tready=self.m_axis_tready,
                    m_axis_tdata=self.m_axis_tdata,
                    m_axis_tlast=self.m_axis_tlast,
                    m_axis_tuser=self.m_axis_tuser,
                    width=width,
                    height=height,
                ),
            )

    async def _finish_optional_tasks(self, *, width: int, height: int) -> None:
        if not self.cfg.check_handshake or self._handshake_task is None:
            return

        timeout_ns = max(
            self.cfg.timeout_floor_ns,
            width * height * self.cfg.timeout_per_pixel_ns,
        )
        stats: HandshakeStats = await with_timeout(self._handshake_task, timeout_ns, "ns")

        if self.cfg.min_ready_low_run > 0:
            assert stats.max_ready_low_run >= self.cfg.min_ready_low_run, (
                "Backpressure READY-low run too short: "
                f"observed={stats.max_ready_low_run}, required>={self.cfg.min_ready_low_run}"
            )

        if self.cfg.with_backpressure:
            assert stats.saw_stall, "Expected at least one VALID=1, READY=0 stall cycle."

        expected_beats = width * height
        assert stats.accepted_beats == expected_beats, (
            "Accepted-beat count mismatch. "
            f"observed={stats.accepted_beats}, expected={expected_beats}"
        )

    def _stop_optional_tasks(self) -> None:
        if self._pause_task is not None:
            self._pause_task.cancel()
            self._pause_task = None

        if self._handshake_task is not None:
            self._handshake_task.cancel()
            self._handshake_task = None

        if self.sink is not None:
            self.sink.set_pause(False)

    async def run_frame(
        self,
        *,
        image: Image,
        threshold: int,
        tail_padding_pixels: int = 0,
    ) -> None:
        await self.initialize()
        assert self.source is not None
        assert self.sink is not None

        expected = _expected_overlay(
            image,
            overlay_enable=self.cfg.overlay_enable,
            pass_through=self.cfg.pass_through,
            threshold=threshold,
        )

        self._start_optional_tasks(width=image.width, height=image.height)
        try:
            if self.cfg.check_handshake:
                for _ in range(self.cfg.handshake_settle_cycles):
                    await RisingEdge(self.i_clk)

            await self.source.send_image(
                image,
                tail_padding_pixels=tail_padding_pixels,
            )

            timeout_ns = max(
                self.cfg.timeout_floor_ns,
                image.width * image.height * self.cfg.timeout_per_pixel_ns,
            )
            received = await self.sink.recv_image(
                width=image.width,
                height=image.height,
                timeout_ns=timeout_ns,
            )
            self.scoreboard.compare(expected=expected, received=received)
            await self._finish_optional_tasks(width=image.width, height=image.height)
        finally:
            self._stop_optional_tasks()


@cocotb.test()
async def test_axi_edge_overlay_pipeline_gradient_overlay(dut) -> None:
    """Check end-to-end grayscale->Sobel->overlay behavior without backpressure."""
    geometry = _frame_geometry_from_dut(dut)
    kernel_size = _read_positive_generic(dut, "G_KERNEL_SIZE", 3)
    threshold = _read_nonnegative_generic(dut, "G_SOBEL_THRESHOLD", 200)
    warmup_pixels = _warmup_beats(width=geometry.width, kernel_size=kernel_size)

    tb = AxiEdgeOverlayPipelineTestbench(
        dut,
        PipelineCaseConfig(
            overlay_enable=True,
            pass_through=False,
        ),
    )
    await tb.run_frame(
        image=Image.gradient(width=geometry.width, height=geometry.height),
        threshold=threshold,
        tail_padding_pixels=warmup_pixels,
    )


@cocotb.test()
async def test_axi_edge_overlay_pipeline_overlay_disabled_passthrough(dut) -> None:
    """When overlay is disabled and passthrough is enabled, output must equal input."""
    geometry = _frame_geometry_from_dut(dut)
    kernel_size = _read_positive_generic(dut, "G_KERNEL_SIZE", 3)
    threshold = _read_nonnegative_generic(dut, "G_SOBEL_THRESHOLD", 200)
    warmup_pixels = _warmup_beats(width=geometry.width, kernel_size=kernel_size)

    tb = AxiEdgeOverlayPipelineTestbench(
        dut,
        PipelineCaseConfig(
            overlay_enable=False,
            pass_through=True,
        ),
    )
    await tb.run_frame(
        image=_checkerboard_image(width=geometry.width, height=geometry.height, tile=4),
        threshold=threshold,
        tail_padding_pixels=warmup_pixels,
    )


@cocotb.test()
async def test_axi_edge_overlay_pipeline_backpressure_protocol(dut) -> None:
    """Check output protocol and data integrity under sink backpressure."""
    geometry = _frame_geometry_from_dut(dut)
    kernel_size = _read_positive_generic(dut, "G_KERNEL_SIZE", 3)
    threshold = _read_nonnegative_generic(dut, "G_SOBEL_THRESHOLD", 200)
    warmup_pixels = _warmup_beats(width=geometry.width, kernel_size=kernel_size)

    tb = AxiEdgeOverlayPipelineTestbench(
        dut,
        PipelineCaseConfig(
            overlay_enable=True,
            pass_through=False,
            with_backpressure=True,
            pause_pattern=(1, 1, 0, 0, 0, 1, 0, 0),
            check_handshake=True,
            min_ready_low_run=2,
        ),
    )
    await tb.run_frame(
        image=_checkerboard_image(width=geometry.width, height=geometry.height, tile=2),
        threshold=threshold,
        tail_padding_pixels=warmup_pixels,
    )
