"""AXI4-Video RGB-to-grayscale cocotb tests."""

from __future__ import annotations

import os
from dataclasses import dataclass, field
from pathlib import Path

import cocotb
import numpy as np
from typing import List
from cocotb.clock import Clock
from cocotb.triggers import FallingEdge, ReadOnly, RisingEdge, with_timeout
from common.pause import drive_sink_pause
from common.reset import apply_reset
from drivers.axis_gray_source import AxiGrayStreamSource
from models.image_model import Image
from monitors.axis_window_sink import AxiWindowStreamSink
from verification.scoreboard import Scoreboard

ACLK_SIGNAL = "i_aclk"
ARESETN_SIGNAL = "i_aresetn"
S_AXIS_PREFIX = "s_axis_video"
M_AXIS_PREFIX = "m_axis_window"
RESET_ACTIVE_LEVEL = False
TESTBENCH_ROOT = Path(__file__).resolve().parents[1]


def _windows_from_image(image: Image, wndw_size: int) -> List[np.ndarray]:
    """
    For each pixel in the image, extract a wndw_size * wndw_size RGB window
    centered on that pixel. Out-of-bounds areas are filled with zeros.

    Args:
        image: Image dataclass containing .pixels (H, W, 3) uint8 array
        wndw_size: Size of the square window (must be odd)

    Returns:
        List of windows, each a (wndw_size, wndw_size, 3) uint8 array.
        Windows are ordered in row-major order (y-major).
    """

    if wndw_size % 2 == 0:
        raise ValueError(f"Expected odd window size, got {wndw_size}")

    h, w, c = image.height, image.width, image.channels
    pad = wndw_size // 2

    # Zero-pad the image (constant 0 padding)
    padded = np.pad(
        image.pixels,
        pad_width=((pad, pad), (pad, pad), (0, 0)),
        mode="constant",
        constant_values=0,
    )

    windows = np.zeros(
        (h * w, wndw_size, wndw_size, c),
        dtype=np.uint8,
    )

    index = 0
    for y in range(h):
        for x in range(w):
            y0 = y
            x0 = x
            windows[index] = padded[
                y0 : y0 + wndw_size,
                x0 : x0 + wndw_size
            ]
            index += 1

    return windows


def _sim_artifact_dir() -> Path:
    """Return an artifact directory inside the current simulation build tree."""
    results_file = os.getenv("COCOTB_RESULTS_FILE")
    if results_file:
        return Path(results_file).resolve().parent
    return TESTBENCH_ROOT / "sim_build" / "test_axi_rgb_to_grayscale"


@dataclass(slots=True)
class WindowCaseConfig:
    """Configuration knobs for a single scenario."""

    with_backpressure: bool = False
    pause_pattern: tuple[int, ...] = (0, 1, 0, 0, 1)
    check_handshake: bool = False
    pass_through: bool = False
    min_ready_low_run: int = 0
    handshake_settle_cycles: int = 6
    recv_timeout_floor_ns: int = 200_000
    recv_timeout_per_pixel_ns: int = 40
    handshake_timeout_ns: int = 20_000
    check_tlast_eol: bool = False
    check_tuser_sof: bool = False
    extra_transfer_guard_cycles: int = 80
    check_window_data: bool = True
    output_height: int | None = None


@dataclass(slots=True)
class HandshakeStats:
    """Runtime statistics collected by the output protocol checker."""

    saw_stall: bool = False
    max_ready_low_run: int = 0
    accepted_beats: int = 0
    captured_windows: list[np.ndarray] = field(default_factory=list)


class AxiRgbToWindowTestbench:
    """Encapsulates setup, traffic, protocol checking, and cleanup."""

    def __init__(self, dut, cfg: WindowCaseConfig) -> None:
        self.dut = dut
        self.cfg = cfg

        self.i_clk = getattr(dut, ACLK_SIGNAL)
        self.i_rst_n = getattr(dut, ARESETN_SIGNAL)
        self.i_pass_through = None

        self.s_axis_tvalid = getattr(dut, f"{S_AXIS_PREFIX}_tvalid")
        self.s_axis_tdata = getattr(dut, f"{S_AXIS_PREFIX}_tdata")
        self.s_axis_tlast = getattr(dut, f"{S_AXIS_PREFIX}_tlast")
        self.s_axis_tuser = getattr(dut, f"{S_AXIS_PREFIX}_tuser")
        self.m_axis_tvalid = getattr(dut, f"{M_AXIS_PREFIX}_tvalid")
        self.m_axis_tready = getattr(dut, f"{M_AXIS_PREFIX}_tready")
        self.m_axis_tdata = getattr(dut, f"{M_AXIS_PREFIX}_tdata")
        self.m_axis_tlast = getattr(dut, f"{M_AXIS_PREFIX}_tlast")
        self.m_axis_tuser = getattr(dut, f"{M_AXIS_PREFIX}_tuser")

        self.source: AxiGrayStreamSource | None = None
        self.sink: AxiWindowStreamSink | None = None
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

        self.source = AxiGrayStreamSource(
            dut=self.dut,
            i_clk=self.i_clk,
            i_rst_n=self.i_rst_n,
            prefix=S_AXIS_PREFIX,
            reset_active_level=RESET_ACTIVE_LEVEL,
        )
        self.sink = AxiWindowStreamSink(
            dut=self.dut,
            i_clk=self.i_clk,
            i_rst_n=self.i_rst_n,
            prefix=M_AXIS_PREFIX,
            reset_active_level=RESET_ACTIVE_LEVEL,
        )

    @staticmethod
    def _warmup_beats(*, width: int, wndw_size: int) -> int:
        return ((width + 1) * ((wndw_size - 1) // 2)) + 1

    def _expected_output_beats(self, *, width: int, height: int, wndw_size: int) -> int:
        total_input = width * height
        if self.cfg.output_height is not None:
            return width * self.cfg.output_height
        warmup = self._warmup_beats(width=width, wndw_size=wndw_size)
        return max(0, total_input - warmup)

    @staticmethod
    def _output_start_index(*, wndw_size: int) -> int:
        return 0

    @staticmethod
    def _decode_single_window(*, raw: int, wndw_size: int, pxl_width: int) -> np.ndarray:
        wndw_pixels = wndw_size * wndw_size
        wndw = np.zeros((wndw_size, wndw_size, 3), dtype=np.uint8)
        mask = (1 << pxl_width) - 1

        for i in range(wndw_pixels):
            p_val = (raw >> (i * pxl_width)) & mask
            if pxl_width == 24:
                b = p_val & 0xFF
                g = (p_val >> 8) & 0xFF
                r = (p_val >> 16) & 0xFF
            elif pxl_width == 8:
                y_gray = p_val & 0xFF
                r = y_gray
                g = y_gray
                b = y_gray
            else:
                raise AssertionError(
                    f"Unsupported pxl_width={pxl_width}; expected 8 or 24",
                )

            y = i // wndw_size
            x = i % wndw_size
            wndw[y, x] = (r, g, b)

        return wndw

    async def _recv_windows_on_handshake(
        self,
        *,
        expected_beats: int,
        wndw_size: int,
        pxl_width: int,
        max_idle_cycles: int = 200,
    ) -> list[np.ndarray]:
        if expected_beats == 0:
            return []

        windows: list[np.ndarray] = []
        idle_cycles = 0
        while len(windows) < expected_beats:
            await FallingEdge(self.i_clk)
            await ReadOnly()

            valid = int(self.m_axis_tvalid.value)
            ready = int(self.m_axis_tready.value)
            if valid == 1 and ready == 1:
                raw = int(self.m_axis_tdata.value)
                windows.append(
                    self._decode_single_window(raw=raw, wndw_size=wndw_size, pxl_width=pxl_width),
                )
                idle_cycles = 0
            else:
                idle_cycles += 1
                if idle_cycles >= max_idle_cycles:
                    break
            await RisingEdge(self.i_clk)

        return windows

    def _start_optional_tasks(self, *, width: int, expected_beats: int) -> None:
        self.handshake_stats = HandshakeStats()
        if self.cfg.check_handshake:
            self._handshake_task = cocotb.start_soon(
                self._monitor_output_handshake(
                    width=width,
                    expected_beats=expected_beats,
                    wndw_size=3,
                    pxl_width=8,
                ),
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

    async def _finish_optional_tasks(self, *, expected_beats: int) -> None:
        if not self.cfg.check_handshake or self._handshake_task is None:
            return

        await with_timeout(self._handshake_task, self.cfg.handshake_timeout_ns, "ns")

        if self.cfg.with_backpressure or self.cfg.min_ready_low_run > 0:
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
        await self._run_frame_once(
            image=image,
            output_path=output_path,
            apply_startup_delay=True,
        )

    async def _run_frame_once(
        self,
        *,
        image: Image,
        output_path: Path | None = None,
        apply_startup_delay: bool = True,
    ) -> None:
        """Execute one send/receive/check cycle assuming initialized endpoints."""
        assert self.source is not None
        assert self.sink is not None

        if apply_startup_delay:
            expected_beats = self._expected_output_beats(
                width=image.width,
                height=image.height,
                wndw_size=3,
            )
            start_index = self._output_start_index(wndw_size=3)
        else:
            output_height = self.cfg.output_height if self.cfg.output_height is not None else image.height
            expected_beats = image.width * output_height
            if self.cfg.output_height is None:
                start_index = (image.width * image.height) - self._warmup_beats(
                    width=image.width,
                    wndw_size=3,
                )
            else:
                start_index = 0

        expected_windows = _windows_from_image(image=image, wndw_size=3)
        if not apply_startup_delay and self.cfg.output_height is None:
            expected_windows = np.concatenate(
                (expected_windows[start_index:], expected_windows[:start_index]),
                axis=0,
            )
        else:
            expected_windows = expected_windows[start_index : start_index + expected_beats]

        self._start_optional_tasks(width=image.width, expected_beats=expected_beats)
        try:
            recv_task = None
            if not self.cfg.check_handshake:
                recv_task = cocotb.start_soon(
                    self._recv_windows_on_handshake(
                        expected_beats=expected_beats,
                        wndw_size=3,
                        pxl_width=8,
                    ),
                )
            if self.cfg.check_handshake:
                for _ in range(self.cfg.handshake_settle_cycles):
                    await RisingEdge(self.i_clk)

            await self.source.send_image(image)

            if self.cfg.check_handshake:
                await self._finish_optional_tasks(expected_beats=expected_beats)
                received_windows = list(self.handshake_stats.captured_windows)
            else:
                assert recv_task is not None
                min_timeout_ns = (
                    image.width * image.height * self.cfg.recv_timeout_per_pixel_ns
                )
                received_windows = await with_timeout(
                    recv_task,
                    max(self.cfg.recv_timeout_floor_ns, min_timeout_ns),
                    "ns",
                )

            if self.cfg.check_window_data:
                try:
                    self.scoreboard.compare_windows(expected=expected_windows, received=received_windows)
                except AssertionError:
                    for i, (exp, got) in enumerate(zip(expected_windows, received_windows)):
                        if not np.array_equal(exp, got):
                            print(f"First mismatch at window index {i}")
                            print("Expected:", exp)
                            print("Received:", got)
                            break
                    raise
        finally:
            self._stop_optional_tasks()

    async def run_multi_frame(
        self,
        *,
        image: Image,
        output_path: Path | None = None,
        frame_count: int = 2,
    ) -> None:
        """Execute send/receive/check cycle for multiple frames."""
        await self.initialize()
        for i in range(frame_count):
            await self._run_frame_once(
                image=image,
                output_path=output_path,
                apply_startup_delay=(i == 0),
            )

    async def _monitor_output_handshake(
        self,
        *,
        width: int,
        expected_beats: int,
        wndw_size: int,
        pxl_width: int,
    ) -> None:
        """Bus-level protocol checker for accepted beats and stall stability."""
        ready_low_run = 0
        prev_stall_payload: tuple[int, int, int] | None = None
        accepted_beats = 0

        while accepted_beats < expected_beats:
            await FallingEdge(self.i_clk)
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
                raw = int(self.m_axis_tdata.value)
                tuser = int(self.m_axis_tuser.value)
                tlast = int(self.m_axis_tlast.value)

                if self.cfg.check_tuser_sof:
                    expected_sof = 1 if accepted_beats == 0 else 0
                    assert tuser == expected_sof, (
                        "SOF/TUSER mismatch on accepted output beat "
                        f"{accepted_beats}: observed={tuser}, expected={expected_sof}"
                    )

                if self.cfg.check_tlast_eol:
                    expected_tlast = 1 if ((accepted_beats + 1) % width) == 0 else 0
                    assert tlast == expected_tlast, (
                        "EOL/TLAST mismatch on accepted output beat "
                        f"{accepted_beats}: observed={tlast}, expected={expected_tlast}"
                    )

                self.handshake_stats.captured_windows.append(
                    self._decode_single_window(raw=raw, wndw_size=wndw_size, pxl_width=pxl_width),
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

            await RisingEdge(self.i_clk)

        # Guard period: once expected beats are received, no further transfers should appear.
        extra_transfers = 0
        for _ in range(self.cfg.extra_transfer_guard_cycles):
            await FallingEdge(self.i_clk)
            await ReadOnly()
            if int(self.m_axis_tvalid.value) == 1 and int(self.m_axis_tready.value) == 1:
                extra_transfers += 1
            await RisingEdge(self.i_clk)

        assert extra_transfers == 0, (
            "Observed output transfers after expected stream end: "
            f"extra_transfers={extra_transfers}"
        )

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
    image: Image,
    output_path: Path | None = None,
    with_backpressure: bool = False,
    pause_pattern: tuple[int, ...] = (0, 1, 0, 0, 1),
    check_handshake: bool = False,
    pass_through: bool = False,
    min_ready_low_run: int = 0,
    check_window_data: bool = True,
    output_height: int | None = None,
) -> None:
    cfg = WindowCaseConfig(
        with_backpressure=with_backpressure,
        pause_pattern=pause_pattern,
        check_handshake=check_handshake,
        pass_through=pass_through,
        min_ready_low_run=min_ready_low_run,
        check_window_data=check_window_data,
        output_height=output_height,
    )
    tb = AxiRgbToWindowTestbench(dut=dut, cfg=cfg)
    await tb.run_frame(image=image, output_path=output_path)


async def run_multi_frame_test(
    dut,
    image: Image,
    output_path: Path | None = None,
    with_backpressure: bool = False,
    pause_pattern: tuple[int, ...] = (0, 1, 0, 0, 1),
    check_handshake: bool = False,
    pass_through: bool = False,
    min_ready_low_run: int = 0,
    check_window_data: bool = True,
    frame_count: int = 2
) -> None:
    cfg = WindowCaseConfig(
        with_backpressure=with_backpressure,
        pause_pattern=pause_pattern,
        check_handshake=check_handshake,
        pass_through=pass_through,
        min_ready_low_run=min_ready_low_run,
        check_window_data=check_window_data,
    )
    tb = AxiRgbToWindowTestbench(dut=dut, cfg=cfg)
    await tb.run_multi_frame(image=image, output_path=output_path, frame_count=frame_count)


@cocotb.test()
async def test_axi_rgb_to_window_without_pressure(dut) -> None:
    """Simple algorithm test for window generation without pressure."""
    image = Image.gradient_gray(width=5, height=5)
    await run_single_frame_test(
        dut=dut,
        image=image,
        with_backpressure=False,
        pause_pattern=(0, 0, 0),
        check_handshake=True,
        min_ready_low_run=0,
    )

@cocotb.test()
async def test_axi_rgb_to_window_with_pressure(dut) -> None:
    """Test for window generation with pressure."""
    await run_single_frame_test(
        dut=dut,
        image=Image.gradient_gray(width=5, height=5),
        with_backpressure=True,
        pause_pattern=(0, 0, 1, 0, 1, 1),
        check_handshake=True,
        min_ready_low_run=1,
    )

@cocotb.test()
async def test_axi_rgb_to_window_multi_frame_without_pressure(dut) -> None:
    """Simple algorithm test for window generation without pressure for two consecutive frames."""
    await run_multi_frame_test(
        dut=dut,
        image=Image.gradient_gray(width=5, height=5),
        with_backpressure=False,
        pause_pattern=(0, 0, 0),
        check_handshake=True,
        min_ready_low_run=0,
        check_window_data=False,
        frame_count=2
    )
