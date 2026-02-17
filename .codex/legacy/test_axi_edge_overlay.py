"""AXI4-Video edge-overlay cocotb tests."""

from __future__ import annotations

import os
from dataclasses import dataclass
from pathlib import Path

import cocotb
import numpy as np
from cocotb.clock import Clock
from cocotb.triggers import ReadOnly, RisingEdge, with_timeout
from common.pause import drive_sink_pause
from common.reset import apply_reset
from drivers.axis_gray_source import AxiGray8StreamSource
from drivers.axis_video_source import AxiVideoStreamSource
from models.image_model import Image
from monitors.axis_video_sink import AxiVideoStreamSink
from verification.scoreboard import Scoreboard

ACLK_SIGNAL = "i_aclk"
ARESETN_SIGNAL = "i_aresetn"
OVERLAY_ENABLE_SIGNAL = "i_overlay_enable"
RGB_S_AXIS_PREFIX = "s_axis_video_rbg888"
EDGE_S_AXIS_PREFIX = "s_axis_video_edges"
M_AXIS_PREFIX = "m_axis_video_rbg888"
RESET_ACTIVE_LEVEL = False
TESTBENCH_ROOT = Path(__file__).resolve().parents[1]
PIXEL_ORDER = "rbg"
EDGE_COLOR_RGB = np.asarray((255, 0, 0), dtype=np.uint8)


def _sim_artifact_dir() -> Path:
    """Return an artifact directory inside the current simulation build tree."""
    results_file = os.getenv("COCOTB_RESULTS_FILE")
    if results_file:
        return Path(results_file).resolve().parent
    return TESTBENCH_ROOT / "sim_build" / "test_axi_edge_overlay"


def _checkerboard_edge_plane(width: int, height: int) -> np.ndarray:
    y, x = np.indices((height, width), dtype=np.uint16)
    return np.where(((x + y) % 2) == 0, 255, 0).astype(np.uint8)


def _nonzero_semantics_plane(width: int, height: int) -> np.ndarray:
    pattern = np.asarray((0, 1, 7, 255), dtype=np.uint8)
    flat = np.tile(pattern, int(np.ceil((width * height) / len(pattern))))[: width * height]
    return flat.reshape((height, width))


def _deterministic_artifact_plane(width: int, height: int) -> np.ndarray:
    y, x = np.indices((height, width), dtype=np.uint16)
    return np.where((((x // 16) + (y // 16)) % 2) == 0, 255, 0).astype(np.uint8)


def _dual_synthetic_3x4_case() -> tuple[tuple[Image, np.ndarray], tuple[Image, np.ndarray]]:
    image1 = Image(
        pixels=np.array(
            [
                [[10, 20, 30], [40, 50, 60], [70, 80, 90]],
                [[15, 25, 35], [45, 55, 65], [75, 85, 95]],
                [[20, 30, 40], [50, 60, 70], [80, 90, 100]],
                [[25, 35, 45], [55, 65, 75], [85, 95, 105]],
            ],
            dtype=np.uint8,
        )
    )
    edge1 = np.array(
        [
            [255, 0, 1],
            [0, 7, 0],
            [1, 0, 255],
            [0, 0, 1],
        ],
        dtype=np.uint8,
    )

    image2 = Image(
        pixels=np.array(
            [
                [[5, 10, 15], [20, 25, 30], [35, 40, 45]],
                [[50, 55, 60], [65, 70, 75], [80, 85, 90]],
                [[95, 100, 105], [110, 115, 120], [125, 130, 135]],
                [[140, 145, 150], [155, 160, 165], [170, 175, 180]],
            ],
            dtype=np.uint8,
        )
    )
    edge2 = np.array(
        [
            [0, 0, 0],
            [255, 0, 255],
            [0, 0, 1],
            [1, 0, 0],
        ],
        dtype=np.uint8,
    )

    return (image1, edge1), (image2, edge2)


def _expected_overlay(
    image: Image,
    edge_plane: np.ndarray,
    *,
    overlay_enable: bool,
    edge_color: np.ndarray = EDGE_COLOR_RGB,
) -> Image:
    if edge_plane.shape != (image.height, image.width):
        raise ValueError(
            "edge_plane must match image geometry: "
            f"expected={(image.height, image.width)}, got={edge_plane.shape}",
        )

    expected = np.asarray(image.pixels, dtype=np.uint8).copy()
    if overlay_enable:
        edge_mask = edge_plane.astype(np.uint8, copy=False) != 0
        expected[edge_mask] = edge_color
    return Image(expected)


@dataclass(slots=True)
class EdgeOverlayCaseConfig:
    """Configuration knobs for a single edge-overlay scenario."""

    overlay_enable: bool = True
    with_backpressure: bool = False
    pause_pattern: tuple[int, ...] = (0, 1, 0, 0, 1)
    check_handshake: bool = False
    min_ready_low_run: int = 0
    handshake_settle_cycles: int = 6
    recv_timeout_floor_ns: int = 200_000
    recv_timeout_per_pixel_ns: int = 40
    handshake_timeout_ns: int = 20_000


@dataclass(slots=True)
class HandshakeStats:
    """Runtime statistics collected by the output protocol checker."""

    saw_stall: bool = False
    max_ready_low_run: int = 0
    accepted_beats: int = 0


class AxiEdgeOverlayTestbench:
    """Encapsulates setup, traffic, protocol checking, and cleanup."""

    def __init__(self, dut, cfg: EdgeOverlayCaseConfig) -> None:
        self.dut = dut
        self.cfg = cfg

        self.i_clk = getattr(dut, ACLK_SIGNAL)
        self.i_rst_n = getattr(dut, ARESETN_SIGNAL)
        self.i_overlay_enable = getattr(dut, OVERLAY_ENABLE_SIGNAL)

        self.s_rgb_tvalid = getattr(dut, f"{RGB_S_AXIS_PREFIX}_tvalid")
        self.s_rgb_tdata = getattr(dut, f"{RGB_S_AXIS_PREFIX}_tdata")
        self.s_rgb_tlast = getattr(dut, f"{RGB_S_AXIS_PREFIX}_tlast")
        self.s_rgb_tuser = getattr(dut, f"{RGB_S_AXIS_PREFIX}_tuser")

        self.s_edge_tvalid = getattr(dut, f"{EDGE_S_AXIS_PREFIX}_tvalid")
        self.s_edge_tdata = getattr(dut, f"{EDGE_S_AXIS_PREFIX}_tdata")
        self.s_edge_tlast = getattr(dut, f"{EDGE_S_AXIS_PREFIX}_tlast")
        self.s_edge_tuser = getattr(dut, f"{EDGE_S_AXIS_PREFIX}_tuser")

        self.m_axis_tvalid = getattr(dut, f"{M_AXIS_PREFIX}_tvalid")
        self.m_axis_tready = getattr(dut, f"{M_AXIS_PREFIX}_tready")
        self.m_axis_tdata = getattr(dut, f"{M_AXIS_PREFIX}_tdata")
        self.m_axis_tlast = getattr(dut, f"{M_AXIS_PREFIX}_tlast")
        self.m_axis_tuser = getattr(dut, f"{M_AXIS_PREFIX}_tuser")

        self.rgb_source: AxiVideoStreamSource | None = None
        self.edge_source: AxiGray8StreamSource | None = None
        self.sink: AxiVideoStreamSink | None = None

        self.scoreboard = Scoreboard()
        self.handshake_stats = HandshakeStats()

        self._clock_started = False
        self._pause_task = None
        self._handshake_task = None

    async def initialize(self) -> None:
        """Bring DUT to a known reset state and build stream endpoints."""
        self.i_rst_n.value = int(RESET_ACTIVE_LEVEL)
        self.i_overlay_enable.value = int(self.cfg.overlay_enable)

        self.s_rgb_tvalid.value = 0
        self.s_rgb_tdata.value = 0
        self.s_rgb_tlast.value = 0
        self.s_rgb_tuser.value = 0

        self.s_edge_tvalid.value = 0
        self.s_edge_tdata.value = 0
        self.s_edge_tlast.value = 0
        self.s_edge_tuser.value = 0

        self.m_axis_tready.value = 0

        if not self._clock_started:
            cocotb.start_soon(Clock(self.i_clk, 10, unit="ns").start())
            self._clock_started = True

        await apply_reset(
            dut=self.dut,
            i_clk=self.i_clk,
            i_rst_n=self.i_rst_n,
            stream_input_prefix=RGB_S_AXIS_PREFIX,
            reset_active_level=RESET_ACTIVE_LEVEL,
        )

        self.s_edge_tvalid.value = 0
        self.s_edge_tdata.value = 0
        self.s_edge_tlast.value = 0
        self.s_edge_tuser.value = 0
        self.i_overlay_enable.value = int(self.cfg.overlay_enable)

        self.rgb_source = AxiVideoStreamSource(
            dut=self.dut,
            i_clk=self.i_clk,
            i_rst_n=self.i_rst_n,
            prefix=RGB_S_AXIS_PREFIX,
            reset_active_level=RESET_ACTIVE_LEVEL,
            pixel_order=PIXEL_ORDER,
        )
        self.edge_source = AxiGray8StreamSource(
            dut=self.dut,
            i_clk=self.i_clk,
            i_rst_n=self.i_rst_n,
            prefix=EDGE_S_AXIS_PREFIX,
            reset_active_level=RESET_ACTIVE_LEVEL,
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
        if self.cfg.check_handshake:
            self._handshake_task = cocotb.start_soon(
                self._monitor_output_handshake(width=width, height=height),
            )

        if self.cfg.with_backpressure:
            assert self.sink is not None
            self._pause_task = cocotb.start_soon(
                drive_sink_pause(
                    sink=self.sink,
                    i_clk=self.i_clk,
                    pattern=self.cfg.pause_pattern,
                ),
            )

    async def _finish_optional_tasks(self, *, width: int, height: int) -> None:
        if not self.cfg.check_handshake or self._handshake_task is None:
            return

        await with_timeout(self._handshake_task, self.cfg.handshake_timeout_ns, "ns")

        if self.cfg.min_ready_low_run > 0:
            assert (
                self.handshake_stats.max_ready_low_run >= self.cfg.min_ready_low_run
            ), (
                "Backpressure READY-low run too short: "
                f"observed={self.handshake_stats.max_ready_low_run}, "
                f"required>={self.cfg.min_ready_low_run}"
            )

        if self.cfg.with_backpressure or self.cfg.min_ready_low_run > 0:
            assert self.handshake_stats.saw_stall, (
                "Expected at least one VALID=1, READY=0 stall cycle."
            )

        expected_beats = width * height
        assert self.handshake_stats.accepted_beats == expected_beats, (
            "Output accepted-beat count mismatch. "
            f"observed={self.handshake_stats.accepted_beats}, expected={expected_beats}"
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
        edge_plane: np.ndarray,
        output_path: Path | None = None,
    ) -> None:
        """Execute one send/receive/check cycle for a single frame."""
        await self.initialize()
        assert self.rgb_source is not None
        assert self.edge_source is not None
        assert self.sink is not None

        expected = _expected_overlay(
            image=image,
            edge_plane=edge_plane,
            overlay_enable=self.cfg.overlay_enable,
        )

        if self.cfg.check_handshake:
            self.handshake_stats = HandshakeStats()
        self._start_optional_tasks(width=image.width, height=image.height)

        try:
            if self.cfg.check_handshake:
                for _ in range(self.cfg.handshake_settle_cycles):
                    await RisingEdge(self.i_clk)

            send_timeout_ns = max(
                self.cfg.recv_timeout_floor_ns,
                image.width * image.height * self.cfg.recv_timeout_per_pixel_ns * 4,
            )
            recv_timeout_ns = max(
                self.cfg.recv_timeout_floor_ns,
                image.width * image.height * self.cfg.recv_timeout_per_pixel_ns,
            )

            rgb_send_task = cocotb.start_soon(self.rgb_source.send_image(image))
            edge_send_task = cocotb.start_soon(self.edge_source.send_plane(edge_plane))

            await with_timeout(rgb_send_task, send_timeout_ns, "ns")
            await with_timeout(edge_send_task, send_timeout_ns, "ns")

            received_image = await self.sink.recv_image(
                width=image.width,
                height=image.height,
                timeout_ns=recv_timeout_ns,
            )

            if output_path is not None:
                received_image.to_png(output_path)

            self.scoreboard.compare(expected=expected, received=received_image)
            await self._finish_optional_tasks(width=image.width, height=image.height)
        finally:
            self._stop_optional_tasks()

    async def _monitor_output_handshake(self, *, width: int, height: int) -> None:
        """Bus-level protocol checker for accepted beats and stall stability."""
        ready_low_run = 0
        prev_stall_payload: tuple[int, int, int] | None = None
        accepted_beats = 0
        expected_beats = width * height

        while accepted_beats < expected_beats:
            await RisingEdge(self.i_clk)
            await ReadOnly()

            self._assert_resolved(self.m_axis_tvalid, M_AXIS_PREFIX + "_tvalid")
            self._assert_resolved(self.m_axis_tready, M_AXIS_PREFIX + "_tready")
            self._assert_resolved(self.m_axis_tdata, M_AXIS_PREFIX + "_tdata")
            self._assert_resolved(self.m_axis_tlast, M_AXIS_PREFIX + "_tlast")
            self._assert_resolved(self.m_axis_tuser, M_AXIS_PREFIX + "_tuser")

            if int(self.i_rst_n.value) == int(RESET_ACTIVE_LEVEL):
                ready_low_run = 0
                prev_stall_payload = None
                accepted_beats = 0
                continue

            valid = int(self.m_axis_tvalid.value)
            ready = int(self.m_axis_tready.value)

            if ready == 0:
                ready_low_run += 1
                self.handshake_stats.max_ready_low_run = max(
                    self.handshake_stats.max_ready_low_run,
                    ready_low_run,
                )
            else:
                ready_low_run = 0

            if valid == 1 and ready == 1:
                tuser = int(self.m_axis_tuser.value)
                tlast = int(self.m_axis_tlast.value)

                expected_sof = 1 if accepted_beats == 0 else 0
                assert tuser == expected_sof, (
                    "SOF/TUSER mismatch on accepted output beat "
                    f"{accepted_beats}: observed={tuser}, expected={expected_sof}"
                )

                expected_tlast = 1 if ((accepted_beats + 1) % width) == 0 else 0
                assert tlast == expected_tlast, (
                    "EOL/TLAST mismatch on accepted output beat "
                    f"{accepted_beats}: observed={tlast}, expected={expected_tlast}"
                )

                accepted_beats += 1

            if valid == 1 and ready == 0:
                self.handshake_stats.saw_stall = True
                payload = (
                    int(self.m_axis_tdata.value),
                    int(self.m_axis_tlast.value),
                    int(self.m_axis_tuser.value),
                )
                if prev_stall_payload is not None:
                    assert payload == prev_stall_payload, (
                        "Output payload changed while stalled (VALID=1, READY=0). "
                        f"prev={prev_stall_payload}, now={payload}"
                    )
                prev_stall_payload = payload
            else:
                prev_stall_payload = None

        self.handshake_stats.accepted_beats = accepted_beats

    @staticmethod
    def _assert_resolved(signal, signal_name: str) -> None:
        try:
            int(signal.value)
        except Exception as exc:  # pragma: no cover
            raise AssertionError(
                f"{signal_name} is not fully resolved at sample point: {signal.value!s}",
            ) from exc


async def run_single_frame_test(
    dut,
    *,
    image: Image,
    edge_plane: np.ndarray,
    output_path: Path | None = None,
    overlay_enable: bool = True,
    with_backpressure: bool = False,
    pause_pattern: tuple[int, ...] = (0, 1, 0, 0, 1),
    check_handshake: bool = False,
    min_ready_low_run: int = 0,
) -> None:
    cfg = EdgeOverlayCaseConfig(
        overlay_enable=overlay_enable,
        with_backpressure=with_backpressure,
        pause_pattern=pause_pattern,
        check_handshake=check_handshake,
        min_ready_low_run=min_ready_low_run,
    )
    tb = AxiEdgeOverlayTestbench(dut=dut, cfg=cfg)
    await tb.run_frame(
        image=image,
        edge_plane=edge_plane,
        output_path=output_path,
    )


@cocotb.test()
async def test_axi_edge_overlay_disabled_passthrough(dut) -> None:
    image = Image.gradient(width=16, height=12)
    edge_plane = _checkerboard_edge_plane(width=image.width, height=image.height)
    await run_single_frame_test(
        dut=dut,
        image=image,
        edge_plane=edge_plane,
        overlay_enable=False,
        check_handshake=True,
    )


@cocotb.test()
async def test_axi_edge_overlay_hard_replace_checkerboard(dut) -> None:
    image = Image.gradient(width=16, height=12)
    edge_plane = _checkerboard_edge_plane(width=image.width, height=image.height)
    await run_single_frame_test(
        dut=dut,
        image=image,
        edge_plane=edge_plane,
        overlay_enable=True,
        check_handshake=True,
    )


@cocotb.test()
async def test_axi_edge_overlay_nonzero_edge_semantics(dut) -> None:
    image = Image.gradient(width=11, height=9)
    edge_plane = _nonzero_semantics_plane(width=image.width, height=image.height)
    await run_single_frame_test(
        dut=dut,
        image=image,
        edge_plane=edge_plane,
        overlay_enable=True,
        check_handshake=True,
    )


@cocotb.test()
async def test_axi_edge_overlay_backpressure_protocol(dut) -> None:
    image = Image.gradient(width=3, height=4)
    edge_plane = _checkerboard_edge_plane(width=image.width, height=image.height)
    await run_single_frame_test(
        dut=dut,
        image=image,
        edge_plane=edge_plane,
        overlay_enable=True,
        with_backpressure=True,
        pause_pattern=(0, 1, 0, 0, 1),
        check_handshake=True,
        min_ready_low_run=1,
    )


@cocotb.test()
async def test_axi_edge_overlay_synthetic_dual_3x4_frames(dut) -> None:
    (image_a, edge_a), (image_b, edge_b) = _dual_synthetic_3x4_case()

    await run_single_frame_test(
        dut=dut,
        image=image_a,
        edge_plane=edge_a,
        overlay_enable=True,
        check_handshake=True,
    )

    await run_single_frame_test(
        dut=dut,
        image=image_b,
        edge_plane=edge_b,
        overlay_enable=False,
        check_handshake=True,
    )


@cocotb.test()
async def test_axi_edge_overlay_image_roundtrip_artifact(dut) -> None:
    input_path = TESTBENCH_ROOT / "images" / "lenna_512_512.png"
    output_path = _sim_artifact_dir() / "lenna_512_512_edge_overlay_out_rgb.png"
    image = Image.from_png(input_path)
    edge_plane = _deterministic_artifact_plane(width=image.width, height=image.height)

    await run_single_frame_test(
        dut=dut,
        image=image,
        edge_plane=edge_plane,
        output_path=output_path,
        overlay_enable=True,
        check_handshake=False,
    )
