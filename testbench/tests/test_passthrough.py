"""AXI4-Video passthrough cocotb tests."""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ReadOnly, RisingEdge, with_timeout
from common.pause import drive_sink_pause
from common.reset import apply_reset
from drivers.axis_video_source import AxiVideoStreamSource
from models.image_model import Image
from monitors.axis_video_sink import AxiVideoStreamSink
from verification.scoreboard import Scoreboard

CLK_SIGNAL = "clk"
RST_SIGNAL = "rst"
S_AXIS_PREFIX = "s_axis_video"
M_AXIS_PREFIX = "m_axis_video"
RESET_ACTIVE_LEVEL = True
TESTBENCH_ROOT = Path(__file__).resolve().parents[1]


@dataclass(slots=True)
class PassthroughCaseConfig:
    """Configuration knobs for a single passthrough scenario."""

    with_backpressure: bool = False
    """Enable sink-side READY throttling to create backpressure windows."""

    pause_pattern: tuple[int, ...] = (0, 1, 0, 0, 1)
    """Per-cycle pause pattern for sink backpressure (`1` pauses, `0` accepts)."""

    check_handshake: bool = False
    """Run the protocol checker for SOF/EOL alignment and stall-stability rules."""

    min_ready_low_run: int = 0
    """Minimum required consecutive READY-low cycles when backpressure is enabled."""

    handshake_settle_cycles: int = 6
    """Pre-frame warm-up cycles to establish deterministic pause/READY phasing."""

    recv_timeout_floor_ns: int = 200_000
    """Absolute minimum receive timeout to avoid short-test false timeouts."""

    recv_timeout_per_pixel_ns: int = 40
    """Additional receive timeout budget per pixel to scale with frame size."""

    handshake_timeout_ns: int = 20_000
    """Timeout for completing protocol-checker observations after frame transfer."""


@dataclass(slots=True)
class HandshakeStats:
    """Runtime statistics collected by the output protocol checker."""

    saw_stall: bool = False
    """True once a `VALID=1, READY=0` cycle is observed on the output stream."""

    max_ready_low_run: int = 0
    """Longest consecutive READY-low run seen during the monitored frame."""

    accepted_beats: int = 0
    """Count of beats transferred with `VALID && READY` during checking."""


class PassthroughTestbench:
    """Encapsulates setup, traffic, protocol checking, and cleanup."""

    def __init__(self, dut, cfg: PassthroughCaseConfig) -> None:
        self.dut = dut
        self.cfg = cfg

        self.clk = getattr(dut, CLK_SIGNAL)
        self.rst = getattr(dut, RST_SIGNAL)

        # Cache stream ports once so monitor code remains compact.
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
        if not self._clock_started:
            cocotb.start_soon(Clock(self.clk, 10, unit="ns").start())
            self._clock_started = True

        # Keep input side quiescent while reset is active so no accidental transfers occur.
        self.rst.value = int(RESET_ACTIVE_LEVEL)
        self.s_axis_tvalid.value = 0
        self.s_axis_tdata.value = 0
        self.s_axis_tlast.value = 0
        self.s_axis_tuser.value = 0

        await apply_reset(
            dut=self.dut,
            clk=self.clk,
            rst=self.rst,
            stream_input_prefix=S_AXIS_PREFIX,
            reset_active_level=RESET_ACTIVE_LEVEL,
        )

        self.source = AxiVideoStreamSource(
            dut=self.dut,
            clk=self.clk,
            rst=self.rst,
            prefix=S_AXIS_PREFIX,
            reset_active_level=RESET_ACTIVE_LEVEL,
        )
        self.sink = AxiVideoStreamSink(
            dut=self.dut,
            clk=self.clk,
            rst=self.rst,
            prefix=M_AXIS_PREFIX,
            reset_active_level=RESET_ACTIVE_LEVEL,
        )

    def _start_optional_tasks(self, *, width: int, height: int) -> None:
        """Start optional monitor/backpressure coroutines based on test config."""
        if self.cfg.check_handshake:
            self._handshake_task = cocotb.start_soon(
                self._monitor_output_handshake(width=width, height=height),
            )

        if self.cfg.with_backpressure:
            assert self.sink is not None
            self._pause_task = cocotb.start_soon(
                drive_sink_pause(
                    sink=self.sink,
                    clk=self.clk,
                    pattern=self.cfg.pause_pattern,
                ),
            )

    async def _finish_optional_tasks(self, *, width: int, height: int) -> None:
        """Wait for monitor completion and evaluate protocol expectations."""
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
        """Always release background tasks and leave sink unpaused."""
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

        self._start_optional_tasks(width=image.width, height=image.height)
        try:
            if self.cfg.check_handshake:
                # Give pause driving a few cycles to establish deterministic READY patterns.
                for _ in range(self.cfg.handshake_settle_cycles):
                    await RisingEdge(self.clk)

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

            self.scoreboard.compare(expected=image, received=received_image)
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
            # Sample in read-only phase so assertions see stable values for this edge.
            await RisingEdge(self.clk)
            await ReadOnly()

            # Enforce fully resolved outputs at all times (no X/Z/U windows on observed outputs).
            self._assert_resolved(self.m_axis_tvalid, "m_axis_video_tvalid")
            self._assert_resolved(self.m_axis_tready, "m_axis_video_tready")
            self._assert_resolved(self.m_axis_tdata, "m_axis_video_tdata")
            self._assert_resolved(self.m_axis_tlast, "m_axis_video_tlast")
            self._assert_resolved(self.m_axis_tuser, "m_axis_video_tuser")

            if int(self.rst.value) == int(RESET_ACTIVE_LEVEL):
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
                # AXI rule: payload/sidebands must remain stable while stalled.
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
        """Fail fast if a sampled signal contains non-resolved logic states."""
        try:
            int(signal.value)
        except Exception as exc:  # pragma: no cover - simulator-value type dependent
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
    min_ready_low_run: int = 0,
) -> None:
    """Compatibility wrapper so existing call sites stay unchanged."""
    cfg = PassthroughCaseConfig(
        with_backpressure=with_backpressure,
        pause_pattern=pause_pattern,
        check_handshake=check_handshake,
        min_ready_low_run=min_ready_low_run,
    )
    tb = PassthroughTestbench(dut=dut, cfg=cfg)
    await tb.run_frame(image=image, output_path=output_path)


@cocotb.test()
async def test_passthrough_with_backpressure_three_cycle_breaks(dut) -> None:
    """Primary regression case: enforced 3-cycle READY-low windows under traffic."""
    await run_frame_test(
        dut=dut,
        image=Image.gradient(width=4, height=3),
        with_backpressure=True,
        pause_pattern=(1, 1, 1, 0, 0, 0),
        check_handshake=True,
        min_ready_low_run=3,
    )


@cocotb.test(timeout_time=30, timeout_unit="ms")
async def test_passthrough_image_file_roundtrip(dut) -> None:
    """Roundtrip a real PNG frame and verify pixel-perfect passthrough."""
    input_path = TESTBENCH_ROOT / "images" / "lenna_512_512.png"
    output_path = TESTBENCH_ROOT / "sim_build" / "lenna_512_512_out_rgb.png"
    output_path.parent.mkdir(parents=True, exist_ok=True)

    image = Image.from_png(input_path)
    await run_frame_test(dut=dut, image=image, output_path=output_path)
