"""AXI4-Video RGB-to-grayscale cocotb tests."""

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
from drivers.axis_video_source import AxiVideoStreamSource
from models.image_model import Image
from monitors.axis_video_sink import AxiVideoStreamSink
from verification.scoreboard import Scoreboard

ACLK_SIGNAL = "i_aclk"
ARESETN_SIGNAL = "i_aresetn"
S_AXIS_PREFIX = "s_axis_video"
M_AXIS_PREFIX = "m_axis_video"
RESET_ACTIVE_LEVEL = False
TESTBENCH_ROOT = Path(__file__).resolve().parents[1]


def _sim_artifact_dir() -> Path:
    """Return an artifact directory inside the current simulation build tree."""
    results_file = os.getenv("COCOTB_RESULTS_FILE")
    if results_file:
        return Path(results_file).resolve().parent
    return TESTBENCH_ROOT / "sim_build" / "test_axi_rgb_to_grayscale"


def _expected_gray_rgb(image: Image) -> Image:
    """Compute expected grayscale output with Y replicated into RGB channels."""
    pixels_u16 = image.pixels.astype(np.uint16)
    r = pixels_u16[:, :, 0]
    g = pixels_u16[:, :, 1]
    b = pixels_u16[:, :, 2]
    y = (r >> 2) + (g >> 1) + (b >> 2)
    gray_u8 = y.astype(np.uint8)
    gray_rgb = np.stack((gray_u8, gray_u8, gray_u8), axis=2)
    return Image(gray_rgb)


@dataclass(slots=True)
class GrayscaleCaseConfig:
    """Configuration knobs for a single grayscale scenario."""

    with_backpressure: bool = False
    pause_pattern: tuple[int, ...] = (0, 1, 0, 0, 1)
    check_handshake: bool = False
    pass_through: bool = False
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


class AxiRgbToGrayscaleTestbench:
    """Encapsulates setup, traffic, protocol checking, and cleanup."""

    def __init__(self, dut, cfg: GrayscaleCaseConfig) -> None:
        self.dut = dut
        self.cfg = cfg

        self.i_clk = getattr(dut, ACLK_SIGNAL)
        self.i_rst_n = getattr(dut, ARESETN_SIGNAL)
        self.i_pass_through = getattr(dut, "i_pass_through", None)

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
        self.handshake_stats = HandshakeStats()

        self._clock_started = False
        self._pause_task = None
        self._handshake_task = None

    async def initialize(self) -> None:
        """Bring DUT to a known reset state and build stream endpoints."""
        self.i_rst_n.value = int(RESET_ACTIVE_LEVEL)
        self.s_axis_tvalid.value = 0
        self.s_axis_tdata.value = 0
        self.s_axis_tlast.value = 0
        self.s_axis_tuser.value = 0
        self.m_axis_tready.value = 0
        if self.i_pass_through is not None:
            self.i_pass_through.value = int(self.cfg.pass_through)

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

        self.source = AxiVideoStreamSource(
            dut=self.dut,
            i_clk=self.i_clk,
            i_rst_n=self.i_rst_n,
            prefix=S_AXIS_PREFIX,
            reset_active_level=RESET_ACTIVE_LEVEL,
        )
        self.sink = AxiVideoStreamSink(
            dut=self.dut,
            i_clk=self.i_clk,
            i_rst_n=self.i_rst_n,
            prefix=M_AXIS_PREFIX,
            reset_active_level=RESET_ACTIVE_LEVEL,
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
        output_path: Path | None = None,
    ) -> None:
        """Execute one send/receive/check cycle for a single frame."""
        await self.initialize()
        assert self.source is not None
        assert self.sink is not None

        expected = image if self.cfg.pass_through else _expected_gray_rgb(image)

        self._start_optional_tasks(width=image.width, height=image.height)
        try:
            if self.cfg.check_handshake:
                for _ in range(self.cfg.handshake_settle_cycles):
                    await RisingEdge(self.i_clk)

            await self.source.send_image(image)

            min_timeout_ns = (
                image.width * image.height * self.cfg.recv_timeout_per_pixel_ns
            )
            received_image = await self.sink.recv_image(
                width=image.width,
                height=image.height,
                timeout_ns=max(self.cfg.recv_timeout_floor_ns, min_timeout_ns),
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

            self._assert_resolved(self.m_axis_tvalid, "m_axis_video_tvalid")
            self._assert_resolved(self.m_axis_tready, "m_axis_video_tready")
            self._assert_resolved(self.m_axis_tdata, "m_axis_video_tdata")
            self._assert_resolved(self.m_axis_tlast, "m_axis_video_tlast")
            self._assert_resolved(self.m_axis_tuser, "m_axis_video_tuser")

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


async def run_frame_test(
    dut,
    image: Image,
    output_path: Path | None = None,
    with_backpressure: bool = False,
    pause_pattern: tuple[int, ...] = (0, 1, 0, 0, 1),
    check_handshake: bool = False,
    pass_through: bool = False,
    min_ready_low_run: int = 0,
) -> None:
    cfg = GrayscaleCaseConfig(
        with_backpressure=with_backpressure,
        pause_pattern=pause_pattern,
        check_handshake=check_handshake,
        pass_through=pass_through,
        min_ready_low_run=min_ready_low_run,
    )
    tb = AxiRgbToGrayscaleTestbench(dut=dut, cfg=cfg)
    await tb.run_frame(image=image, output_path=output_path)


@cocotb.test()
async def test_axi_rgb_to_grayscale_with_backpressure_three_cycle_breaks(dut) -> None:
    """Primary regression case with enforced READY-low windows under traffic."""
    await run_frame_test(
        dut=dut,
        image=Image.gradient(width=8, height=6),
        with_backpressure=True,
        pause_pattern=(1, 1, 1, 0, 0, 0),
        check_handshake=True,
        min_ready_low_run=3,
    )


@cocotb.test(timeout_time=40, timeout_unit="ms")
async def test_axi_rgb_to_grayscale_image_file_roundtrip(dut) -> None:
    """Roundtrip a real image through DUT and save the grayscale output artifact."""
    input_path = TESTBENCH_ROOT / "images" / "lenna_512_512.png"
    output_path = _sim_artifact_dir() / "lenna_512_512_out_gray_rgb.png"

    image = Image.from_png(input_path)
    await run_frame_test(dut=dut, image=image, output_path=output_path)


@cocotb.test()
async def test_axi_rgb_to_grayscale_passthrough_mode(dut) -> None:
    """When i_pass_through=1, output must match input pixels exactly."""
    image = Image.gradient(width=8, height=6)
    await run_frame_test(
        dut=dut,
        image=image,
        pass_through=True,
    )
