"""Synthetic small-frame full-pipeline AXI/FSM/synchronization checks."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any

import cocotb
import numpy as np
from cocotb.clock import Clock
from cocotb.triggers import ReadOnly, RisingEdge, SimTimeoutError, Timer, with_timeout
from common.pause import repeating_pause
from common.reset import apply_reset
from drivers.axis_video_source import AxiVideoStreamSource
from models.image_model import Image
from monitors.axis_video_sink import AxiVideoStreamSink

ACLK_SIGNAL = "i_aclk"
ARESETN_SIGNAL = "i_aresetn"
BTN_SIGNAL = "i_btn"
S_AXIS_PREFIX = "s_axis_video_rbg888"
M_AXIS_PREFIX = "m_axis_video_rbg888"
RESET_ACTIVE_LEVEL = False
PIXEL_ORDER = "rbg"

FRAME_WIDTH = 8
FRAME_HEIGHT = 8

BTN1_PROCESSING = 0
BTN2_BASE_MODE = 1

C_OVERLAY_FAST = 0b01
C_OVERLAY_SOBEL = 0b10
C_SOBEL_COLOR = 0xFF0000
C_FAST_COLOR = 0x0000FF
C_BINARY_ON_COLOR = 0xFFFFFF
C_BINARY_OFF_COLOR = 0x000000

PausePattern = tuple[int, ...]

C_BACKPRESSURE_PROFILES: tuple[tuple[PausePattern | None, PausePattern | None], ...] = (
    (None, None),
    ((0, 0, 1, 0, 1, 0, 0, 1), None),
    (None, (0, 1, 1, 0, 0, 1, 0, 1)),
    ((0, 1, 0, 1, 1, 0, 0), (1, 0, 1, 0, 0, 1, 1, 0)),
)


@dataclass(frozen=True)
class StateCase:
    name: str
    btn1_clicks: int
    btn2_clicks: int
    btn_both_clicks: int
    warmup_stages: int
    exp_pass_grayscale: int
    exp_pass_blur: int
    exp_pass_sobel: int
    exp_pass_fast: int
    exp_overlay_zeros: int
    check_merge_sync: bool
    check_binary_sync: bool
    expect_grayscale_output: bool
    source_pause_pattern: PausePattern | None
    sink_pause_pattern: PausePattern | None


@dataclass(frozen=True)
class MonitorStats:
    accepted_beats: int
    stall_cycles: int
    mask_hits: int
    mask_misses: int


class _NoSofAxiVideoStreamSource(AxiVideoStreamSource):
    """Video source variant that never asserts SOF on TUSER."""

    def _build_line_tuser(self, line_bytes_len: int, *, line_index: int) -> list[int]:
        del line_index
        return [0] * line_bytes_len


def _is_resolved(value: Any) -> bool:
    try:
        return bool(value.is_resolvable)
    except AttributeError:
        text = str(value)
        return all(ch in "01" for ch in text)


def _gray_from_rgb(image: Image) -> np.ndarray:
    pixels_u16 = image.pixels.astype(np.uint16)
    r = pixels_u16[:, :, 0]
    g = pixels_u16[:, :, 1]
    b = pixels_u16[:, :, 2]
    return ((r >> 2) + (g >> 1) + (b >> 2)).astype(np.uint8)


def _rgb_from_gray(gray_plane: np.ndarray) -> np.ndarray:
    gray_u8 = gray_plane.astype(np.uint8)
    return np.stack((gray_u8, gray_u8, gray_u8), axis=2)


def _make_synthetic_frame(frame_idx: int) -> Image:
    """Generate deterministic edge-rich synthetic input with flat regions."""
    y, x = np.indices((FRAME_HEIGHT, FRAME_WIDTH), dtype=np.uint16)
    left = x < (FRAME_WIDTH // 2)
    top = y < (FRAME_HEIGHT // 2)

    r = np.where(left, 20 + y * 9 + frame_idx * 7, 230 - y * 11 - frame_idx * 5) % 256
    g = np.where(top, 30 + x * 13 + frame_idx * 3, 210 - x * 15 - frame_idx * 9) % 256
    b = ((x * 27) + (y * 19) + (frame_idx * 41)) % 256

    pixels = np.stack((r, g, b), axis=2).astype(np.uint8)
    return Image(pixels)


def _warmup_beats(*, width: int, wndw_size: int = 3) -> int:
    return ((width + 1) * ((wndw_size - 1) // 2)) + 1


def _resolve_axiframecompositor_instance(dut: Any) -> Any:
    for name in ("u_axiframecompositor", "U_AxiFrameCompositor"):
        if hasattr(dut, name):
            return getattr(dut, name)
    raise AssertionError(
        "Could not resolve AXI_FrameCompositor instance handle from pipeline DUT.",
    )


async def _pulse_button_once(
    dut: Any,
    *,
    button_idx: int,
    high_ns: int = 220,
    low_ns: int = 220,
) -> None:
    await _pulse_button_mask(
        dut,
        btn_mask=(1 << button_idx),
        high_ns=high_ns,
        low_ns=low_ns,
    )


async def _pulse_button_mask(
    dut: Any,
    *,
    btn_mask: int,
    high_ns: int = 220,
    low_ns: int = 220,
) -> None:
    btn = getattr(dut, BTN_SIGNAL)
    btn.value = int(btn_mask) & 0xF
    await Timer(high_ns, unit="ns")
    btn.value = 0
    await Timer(low_ns, unit="ns")


async def _set_clicks(
    dut: Any,
    *,
    btn1_clicks: int,
    btn2_clicks: int,
    btn_both_clicks: int,
) -> None:
    for _ in range(btn1_clicks):
        await _pulse_button_once(dut, button_idx=BTN1_PROCESSING)
    for _ in range(btn_both_clicks):
        await _pulse_button_mask(
            dut,
            btn_mask=(1 << BTN1_PROCESSING) | (1 << BTN2_BASE_MODE),
        )
    for _ in range(btn2_clicks):
        await _pulse_button_once(dut, button_idx=BTN2_BASE_MODE)


async def _assert_controls(
    dut: Any,
    case: StateCase,
    *,
    settle_cycles: int = 64,
) -> None:
    for _ in range(settle_cycles):
        await RisingEdge(getattr(dut, ACLK_SIGNAL))
        await ReadOnly()

        current = (
            int(dut.o_pass_grayscale.value),
            int(dut.o_pass_blurr_filter.value),
            int(dut.o_pass_sobel.value),
            int(dut.o_pass_fast.value),
            int(dut.s_overlay_zeros.value),
        )
        expected = (
            case.exp_pass_grayscale,
            case.exp_pass_blur,
            case.exp_pass_sobel,
            case.exp_pass_fast,
            case.exp_overlay_zeros,
        )
        if current == expected:
            return

    raise AssertionError(
        f"{case.name}: control outputs did not settle to expected tuple "
        f"(pass_gray,pass_blur,pass_sobel,pass_fast,overlay_zeros)={expected}, "
        f"observed={current}",
    )


def _assert_rgb_equal(
    expected: np.ndarray,
    received: np.ndarray,
    *,
    label: str,
) -> None:
    if expected.shape != received.shape:
        raise AssertionError(
            f"{label}: shape mismatch expected={expected.shape}, received={received.shape}",
        )
    if np.array_equal(expected, received):
        return
    y, x = np.argwhere(np.any(expected != received, axis=2))[0]
    raise AssertionError(
        f"{label}: first mismatch at (x={int(x)}, y={int(y)}), "
        f"expected={expected[y, x].tolist()}, received={received[y, x].tolist()}",
    )


def _assert_rgb_is_grayscale(image: Image, *, label: str) -> None:
    pixels = image.pixels
    gray_mask = (pixels[:, :, 0] == pixels[:, :, 1]) & (
        pixels[:, :, 1] == pixels[:, :, 2]
    )
    if np.all(gray_mask):
        return
    y, x = np.argwhere(~gray_mask)[0]
    raise AssertionError(
        f"{label}: non-grayscale pixel at (x={int(x)}, y={int(y)}), value={pixels[y, x].tolist()}",
    )


def _control_tuple(case: StateCase) -> tuple[int, int, int, int, int]:
    return (
        case.exp_pass_grayscale,
        case.exp_pass_blur,
        case.exp_pass_sobel,
        case.exp_pass_fast,
        case.exp_overlay_zeros,
    )


def _bp_profile(index: int) -> tuple[PausePattern | None, PausePattern | None]:
    return C_BACKPRESSURE_PROFILES[index % len(C_BACKPRESSURE_PROFILES)]


async def _monitor_output_axi_and_sync(
    dut: Any,
    *,
    width: int,
    height: int,
    check_merge_sync: bool,
    check_binary_sync: bool,
    trace: bool = False,
) -> MonitorStats:
    i_clk = getattr(dut, ACLK_SIGNAL)
    i_rst_n = getattr(dut, ARESETN_SIGNAL)
    cycle = 0

    out_tvalid = getattr(dut, f"{M_AXIS_PREFIX}_tvalid")
    out_tready = getattr(dut, f"{M_AXIS_PREFIX}_tready")
    out_tdata = getattr(dut, f"{M_AXIS_PREFIX}_tdata")
    out_tuser = getattr(dut, f"{M_AXIS_PREFIX}_tuser")
    out_tlast = getattr(dut, f"{M_AXIS_PREFIX}_tlast")

    u_fc = _resolve_axiframecompositor_instance(dut)
    fc_base_delayed_rgb = u_fc.s_base_delayed_rgb
    fc_base_delayed_sof = u_fc.s_base_delayed_sof
    fc_base_delayed_eol = u_fc.s_base_delayed_eol

    accepted = 0
    input_accepted = 0
    row = 0
    col = 0
    stalls = 0
    mask_hits = 0
    mask_misses = 0
    prev_stall_payload: tuple[int, int, int] | None = None

    total_beats = width * height
    while accepted < total_beats:
        cycle += 1
        await RisingEdge(i_clk)
        await ReadOnly()

        if int(i_rst_n.value) == int(RESET_ACTIVE_LEVEL):
            accepted = 0
            row = 0
            col = 0
            stalls = 0
            mask_hits = 0
            mask_misses = 0
            prev_stall_payload = None
            continue

        for sig, label in (
            (out_tvalid, "m_axis_tvalid"),
            (out_tready, "m_axis_tready"),
            (out_tdata, "m_axis_tdata"),
            (out_tuser, "m_axis_tuser"),
            (out_tlast, "m_axis_tlast"),
        ):
            assert _is_resolved(sig.value), f"Unresolved signal during monitor: {label}"

        valid = int(out_tvalid.value)
        ready = int(out_tready.value)
        data = int(out_tdata.value)
        user = int(out_tuser.value)
        last = int(out_tlast.value)

        in_valid = int(getattr(dut, f"{S_AXIS_PREFIX}_tvalid").value)
        in_ready = int(getattr(dut, f"{S_AXIS_PREFIX}_tready").value)
        in_user = int(getattr(dut, f"{S_AXIS_PREFIX}_tuser").value)
        in_last = int(getattr(dut, f"{S_AXIS_PREFIX}_tlast").value)
        if in_valid and in_ready:
            input_accepted += 1

        # if trace and (
        #     cycle <= 50
        #     or int(dut.s_fc_gray_tvalid.value) == 1
        #     or valid == 1
        #     or stalls
        #     or cycle % 50 == 0
        # ):
        #     print(
        #         f"CYCLE={cycle} in_v={in_valid} in_r={in_ready} gray_v={int(dut.s_fc_gray_tvalid.value)} "
        #         f"gray_r={int(dut.s_fc_gray_tready.value)} out_v={valid} out_r={ready} "
        #         f"inp_u={in_user} inp_l={in_last} out_u={user} out_l={last} "
        #         f"base_v={int(u_fc.s_base_delayed_valid.value)}",
        #     )

        if valid == 1 and ready == 0:
            stalls += 1
            payload = (data, user, last)
            if prev_stall_payload is not None:
                assert payload == prev_stall_payload, (
                    f"Output payload changed while stalled: prev={prev_stall_payload}, now={payload}"
                )
            prev_stall_payload = payload
            continue

        prev_stall_payload = None

        if valid == 1 and ready == 1:
            # if trace:
            #     print(
            #         f"TRACE beat={accepted} "
            #         f"in_beat={input_accepted} "
            #         f"user={user} last={last} "
            #         f"gray_user={int(dut.s_fc_gray_tuser.value)} "
            #         f"gray_last={int(dut.s_fc_gray_tlast.value)} "
            #         f"base_sof={int(fc_base_delayed_sof.value)} "
            #         f"base_eol={int(fc_base_delayed_eol.value)} "
            #         f"in_valid={in_valid} in_user={in_user} in_last={in_last} ",
            #     )
            exp_user = 1 if (row == 0 and col == 0) else 0
            exp_last = 1 if (col == width - 1) else 0
            assert user == exp_user, (
                f"TUSER mismatch at accepted beat {accepted}: observed={user}, expected={exp_user}"
            )
            assert last == exp_last, (
                f"TLAST mismatch at accepted beat {accepted}: observed={last}, expected={exp_last}"
            )

            if check_merge_sync:
                overlay_mode = int(dut.s_fc_overlay_mode.value)
                overlay_zeros = int(dut.s_overlay_zeros.value)
                fc_gray = int(dut.s_fc_gray_tdata.value)
                base_rgb = int(fc_base_delayed_rgb.value)

                assert int(dut.s_mode_overlay.value) == 1, (
                    "Expected overlay path active while checking compositor merge synchronization."
                )
                assert overlay_zeros == 0, (
                    "Expected base-merge mode (overlay_zeros=0) while checking synchronization."
                )
                assert int(fc_base_delayed_sof.value) == int(
                    dut.s_fc_gray_tuser.value,
                ), (
                    f"FRAME_COMPOSITOR delayed base SOF does not match gray SOF at beat {accepted} "
                    f"(x={col}, y={row})."
                )
                assert int(fc_base_delayed_eol.value) == int(
                    dut.s_fc_gray_tlast.value,
                ), (
                    f"FRAME_COMPOSITOR delayed base EOL does not match gray EOL at beat {accepted} "
                    f"(x={col}, y={row})."
                )

                if fc_gray != 0:
                    if overlay_mode == C_OVERLAY_SOBEL:
                        expected_data = C_SOBEL_COLOR
                    elif overlay_mode == C_OVERLAY_FAST:
                        expected_data = C_FAST_COLOR
                    else:
                        raise AssertionError(
                            f"Unexpected overlay mode during merge synchronization check: {overlay_mode}",
                        )
                    mask_hits += 1
                else:
                    expected_data = base_rgb
                    mask_misses += 1

                assert data == expected_data, (
                    f"Compositor synchronization mismatch at beat {accepted}: "
                    f"gray=0x{fc_gray:02X}, mode=0b{overlay_mode:02b}, "
                    f"base_delayed=0x{base_rgb:06X}, observed=0x{data:06X}, expected=0x{expected_data:06X}"
                )
            elif check_binary_sync:
                overlay_mode = int(dut.s_fc_overlay_mode.value)
                overlay_zeros = int(dut.s_overlay_zeros.value)
                fc_gray = int(dut.s_fc_gray_tdata.value)
                gray_user = int(dut.s_fc_gray_tuser.value)
                gray_last = int(dut.s_fc_gray_tlast.value)

                assert int(dut.s_mode_overlay.value) == 1, (
                    "Expected overlay path active while checking binary-overlay synchronization."
                )
                assert overlay_zeros == 1, (
                    "Expected binary-only overlay mode (overlay_zeros=1) while checking synchronization."
                )
                assert overlay_mode in (C_OVERLAY_SOBEL, C_OVERLAY_FAST), (
                    f"Unexpected overlay mode in binary synchronization check: 0b{overlay_mode:02b}"
                )
                assert user == gray_user, (
                    f"Binary sync mismatch on TUSER at beat {accepted}: out={user}, gray={gray_user}"
                )
                assert last == gray_last, (
                    f"Binary sync mismatch on TLAST at beat {accepted}: out={last}, gray={gray_last}"
                )

                expected_data = (
                    C_BINARY_ON_COLOR if fc_gray != 0 else C_BINARY_OFF_COLOR
                )
                if fc_gray != 0:
                    mask_hits += 1
                else:
                    mask_misses += 1

                assert data == expected_data, (
                    f"Binary overlay mismatch at beat {accepted}: gray=0x{fc_gray:02X}, "
                    f"observed=0x{data:06X}, expected=0x{expected_data:06X}"
                )

            accepted += 1
            if col == width - 1:
                col = 0
                row += 1
            else:
                col += 1

    return MonitorStats(
        accepted_beats=accepted,
        stall_cycles=stalls,
        mask_hits=mask_hits,
        mask_misses=mask_misses,
    )


async def _run_case(
    dut: Any,
    *,
    case: StateCase,
    frame_idx: int,
) -> tuple[Image, Image, MonitorStats]:
    i_clk = getattr(dut, ACLK_SIGNAL)
    i_aresetn = getattr(dut, ARESETN_SIGNAL)
    i_btn = getattr(dut, BTN_SIGNAL)

    i_aresetn.value = int(RESET_ACTIVE_LEVEL)
    i_btn.value = 0
    getattr(dut, f"{S_AXIS_PREFIX}_tvalid").value = 0
    getattr(dut, f"{S_AXIS_PREFIX}_tdata").value = 0
    getattr(dut, f"{S_AXIS_PREFIX}_tlast").value = 0
    getattr(dut, f"{S_AXIS_PREFIX}_tuser").value = 0

    await apply_reset(
        dut=dut,
        i_clk=i_clk,
        i_rst_n=i_aresetn,
        stream_input_prefix=S_AXIS_PREFIX,
        reset_active_level=RESET_ACTIVE_LEVEL,
    )

    source = AxiVideoStreamSource(
        dut=dut,
        i_clk=i_clk,
        i_rst_n=i_aresetn,
        prefix=S_AXIS_PREFIX,
        reset_active_level=RESET_ACTIVE_LEVEL,
        pixel_order=PIXEL_ORDER,
    )
    sink = AxiVideoStreamSink(
        dut=dut,
        i_clk=i_clk,
        i_rst_n=i_aresetn,
        prefix=M_AXIS_PREFIX,
        reset_active_level=RESET_ACTIVE_LEVEL,
        pixel_order=PIXEL_ORDER,
    )
    if case.source_pause_pattern is not None:
        source.set_pause_generator(repeating_pause(case.source_pause_pattern))
    if case.sink_pause_pattern is not None:
        sink.set_pause_generator(repeating_pause(case.sink_pause_pattern))

    await _set_clicks(
        dut,
        btn1_clicks=case.btn1_clicks,
        btn_both_clicks=case.btn_both_clicks,
        btn2_clicks=case.btn2_clicks,
    )
    await _assert_controls(dut, case)

    image = _make_synthetic_frame(frame_idx)
    flush_pixels = case.warmup_stages * _warmup_beats(width=image.width, wndw_size=3)

    mon_task = cocotb.start_soon(
        _monitor_output_axi_and_sync(
            dut,
            width=image.width,
            height=image.height,
            check_merge_sync=case.check_merge_sync,
            check_binary_sync=case.check_binary_sync,
            trace=case.name in ("blur_btn2_ignored", "sobel_bram_rgb"),
        ),
    )

    tx_task = cocotb.start_soon(
        source.send_image(
            image,
            tail_padding_pixels=flush_pixels,
        ),
    )

    timeout_ns = max(2_000_000, image.width * image.height * 2000)
    try:
        observed = await sink.recv_image(
            width=image.width,
            height=image.height,
            timeout_ns=timeout_ns,
        )
    except AssertionError as exc:
        raise AssertionError(
            f"{case.name}: output frame reception failed (width={image.width}, height={image.height}, "
            f"timeout_ns={timeout_ns}).",
        ) from exc

    try:
        await with_timeout(tx_task, 6_000_000, "ns")
    except SimTimeoutError:
        tx_task.cancel()
        raise AssertionError(f"{case.name}: source transmit did not drain in time.")

    stats = await with_timeout(mon_task, 6_000_000, "ns")
    return image, observed, stats


@cocotb.test(timeout_time=1200, timeout_unit="ms")
async def test_pipeline_synthetic_axi_fsm_and_compositor_sync(dut: Any) -> None:
    i_clk = getattr(dut, ACLK_SIGNAL)
    cocotb.start_soon(Clock(i_clk, 10, unit="ns").start())

    bp_none = _bp_profile(0)
    bp_src = _bp_profile(1)
    bp_sink = _bp_profile(2)
    bp_both = _bp_profile(3)

    cases = (
        StateCase(
            name="pass_all_initial",
            btn1_clicks=0,
            btn2_clicks=0,
            btn_both_clicks=0,
            warmup_stages=0,
            exp_pass_grayscale=0,
            exp_pass_blur=1,
            exp_pass_sobel=1,
            exp_pass_fast=1,
            exp_overlay_zeros=1,
            check_merge_sync=False,
            check_binary_sync=False,
            expect_grayscale_output=True,
            source_pause_pattern=bp_none[0],
            sink_pause_pattern=bp_none[1],
        ),
        StateCase(
            name="pass_all_btn2_rgb",
            btn1_clicks=0,
            btn2_clicks=1,
            btn_both_clicks=0,
            warmup_stages=0,
            exp_pass_grayscale=1,
            exp_pass_blur=1,
            exp_pass_sobel=1,
            exp_pass_fast=1,
            exp_overlay_zeros=0,
            check_merge_sync=False,
            check_binary_sync=False,
            expect_grayscale_output=False,
            source_pause_pattern=bp_sink[0],
            sink_pause_pattern=bp_sink[1],
        ),
        StateCase(
            name="pass_all_btn2_gray",
            btn1_clicks=0,
            btn2_clicks=2,
            btn_both_clicks=0,
            warmup_stages=0,
            exp_pass_grayscale=0,
            exp_pass_blur=1,
            exp_pass_sobel=1,
            exp_pass_fast=1,
            exp_overlay_zeros=0,
            check_merge_sync=False,
            check_binary_sync=False,
            expect_grayscale_output=True,
            source_pause_pattern=bp_src[0],
            sink_pause_pattern=bp_src[1],
        ),
        StateCase(
            name="blur",
            btn1_clicks=1,
            btn2_clicks=0,
            btn_both_clicks=0,
            warmup_stages=1,
            exp_pass_grayscale=0,
            exp_pass_blur=0,
            exp_pass_sobel=1,
            exp_pass_fast=1,
            exp_overlay_zeros=1,
            check_merge_sync=False,
            check_binary_sync=False,
            expect_grayscale_output=True,
            source_pause_pattern=bp_src[0],
            sink_pause_pattern=bp_src[1],
        ),
        StateCase(
            name="blur_btn2_ignored",
            btn1_clicks=1,
            btn2_clicks=1,
            btn_both_clicks=0,
            warmup_stages=1,
            exp_pass_grayscale=0,
            exp_pass_blur=0,
            exp_pass_sobel=1,
            exp_pass_fast=1,
            exp_overlay_zeros=1,
            check_merge_sync=False,
            check_binary_sync=False,
            expect_grayscale_output=True,
            source_pause_pattern=bp_both[0],
            sink_pause_pattern=bp_both[1],
        ),
        StateCase(
            name="sobel_zeros",
            btn1_clicks=2,
            btn2_clicks=0,
            btn_both_clicks=0,
            warmup_stages=1,
            exp_pass_grayscale=0,
            exp_pass_blur=1,
            exp_pass_sobel=0,
            exp_pass_fast=1,
            exp_overlay_zeros=1,
            check_merge_sync=False,
            check_binary_sync=True,
            expect_grayscale_output=True,
            source_pause_pattern=bp_sink[0],
            sink_pause_pattern=bp_sink[1],
        ),
        StateCase(
            name="sobel_bram_rgb",
            btn1_clicks=2,
            btn2_clicks=1,
            btn_both_clicks=0,
            warmup_stages=1,
            exp_pass_grayscale=1,
            exp_pass_blur=1,
            exp_pass_sobel=0,
            exp_pass_fast=1,
            exp_overlay_zeros=0,
            check_merge_sync=True,
            check_binary_sync=False,
            expect_grayscale_output=False,
            source_pause_pattern=bp_both[0],
            sink_pause_pattern=bp_both[1],
        ),
        StateCase(
            name="sobel_bram_gray",
            btn1_clicks=2,
            btn2_clicks=2,
            btn_both_clicks=0,
            warmup_stages=1,
            exp_pass_grayscale=0,
            exp_pass_blur=1,
            exp_pass_sobel=0,
            exp_pass_fast=1,
            exp_overlay_zeros=0,
            check_merge_sync=True,
            check_binary_sync=False,
            expect_grayscale_output=False,
            source_pause_pattern=bp_none[0],
            sink_pause_pattern=bp_none[1],
        ),
        StateCase(
            name="blur_sobel_zeros",
            btn1_clicks=3,
            btn2_clicks=0,
            btn_both_clicks=0,
            warmup_stages=2,
            exp_pass_grayscale=0,
            exp_pass_blur=0,
            exp_pass_sobel=0,
            exp_pass_fast=1,
            exp_overlay_zeros=1,
            check_merge_sync=False,
            check_binary_sync=True,
            expect_grayscale_output=True,
            source_pause_pattern=bp_src[0],
            sink_pause_pattern=bp_src[1],
        ),
        StateCase(
            name="blur_sobel_bram_gray",
            btn1_clicks=3,
            btn2_clicks=2,
            btn_both_clicks=0,
            warmup_stages=2,
            exp_pass_grayscale=0,
            exp_pass_blur=0,
            exp_pass_sobel=0,
            exp_pass_fast=1,
            exp_overlay_zeros=0,
            check_merge_sync=True,
            check_binary_sync=False,
            expect_grayscale_output=False,
            source_pause_pattern=bp_sink[0],
            sink_pause_pattern=bp_sink[1],
        ),
        StateCase(
            name="blur_sobel_bram_rgb_dual_click",
            btn1_clicks=2,
            btn2_clicks=0,
            btn_both_clicks=1,
            warmup_stages=2,
            exp_pass_grayscale=1,
            exp_pass_blur=0,
            exp_pass_sobel=0,
            exp_pass_fast=1,
            exp_overlay_zeros=0,
            check_merge_sync=True,
            check_binary_sync=False,
            expect_grayscale_output=False,
            source_pause_pattern=bp_both[0],
            sink_pause_pattern=bp_both[1],
        ),
        StateCase(
            name="fast_zeros",
            btn1_clicks=4,
            btn2_clicks=0,
            btn_both_clicks=0,
            warmup_stages=3,
            exp_pass_grayscale=0,
            exp_pass_blur=1,
            exp_pass_sobel=1,
            exp_pass_fast=0,
            exp_overlay_zeros=1,
            check_merge_sync=False,
            check_binary_sync=True,
            expect_grayscale_output=True,
            source_pause_pattern=bp_none[0],
            sink_pause_pattern=bp_none[1],
        ),
        StateCase(
            name="fast_bram_rgb",
            btn1_clicks=4,
            btn2_clicks=1,
            btn_both_clicks=0,
            warmup_stages=3,
            exp_pass_grayscale=1,
            exp_pass_blur=1,
            exp_pass_sobel=1,
            exp_pass_fast=0,
            exp_overlay_zeros=0,
            check_merge_sync=True,
            check_binary_sync=False,
            expect_grayscale_output=False,
            source_pause_pattern=bp_src[0],
            sink_pause_pattern=bp_src[1],
        ),
        StateCase(
            name="fast_bram_gray",
            btn1_clicks=4,
            btn2_clicks=2,
            btn_both_clicks=0,
            warmup_stages=3,
            exp_pass_grayscale=0,
            exp_pass_blur=1,
            exp_pass_sobel=1,
            exp_pass_fast=0,
            exp_overlay_zeros=0,
            check_merge_sync=True,
            check_binary_sync=False,
            expect_grayscale_output=False,
            source_pause_pattern=bp_both[0],
            sink_pause_pattern=bp_both[1],
        ),
    )

    expected_control_space = {
        (0, 1, 1, 1, 1),  # PASS_ALL + ZEROS
        (1, 1, 1, 1, 0),  # PASS_ALL + BRAM_RGB
        (0, 1, 1, 1, 0),  # PASS_ALL + BRAM_GRAY
        (0, 0, 1, 1, 1),  # BLUR (+ BTN2 ignored variant)
        (0, 1, 0, 1, 1),  # SOBEL + ZEROS
        (1, 1, 0, 1, 0),  # SOBEL + BRAM_RGB
        (0, 1, 0, 1, 0),  # SOBEL + BRAM_GRAY
        (0, 0, 0, 1, 1),  # BLUR_SOBEL + ZEROS
        (1, 0, 0, 1, 0),  # BLUR_SOBEL + BRAM_RGB
        (0, 0, 0, 1, 0),  # BLUR_SOBEL + BRAM_GRAY
        (0, 1, 1, 0, 1),  # FAST + ZEROS
        (1, 1, 1, 0, 0),  # FAST + BRAM_RGB
        (0, 1, 1, 0, 0),  # FAST + BRAM_GRAY
    }
    observed_control_space = {_control_tuple(case) for case in cases}
    assert observed_control_space == expected_control_space, (
        "Case matrix does not cover all reachable click-detector control combinations: "
        f"observed={sorted(observed_control_space)}, expected={sorted(expected_control_space)}"
    )

    expected_bp_space = {(False, False), (True, False), (False, True), (True, True)}
    observed_bp_space = {
        (case.source_pause_pattern is not None, case.sink_pause_pattern is not None)
        for case in cases
    }
    assert observed_bp_space == expected_bp_space, (
        "Case matrix does not cover all source/sink backpressure combinations: "
        f"observed={sorted(observed_bp_space)}, expected={sorted(expected_bp_space)}"
    )

    saw_sink_backpressure_stall = False

    for idx, case in enumerate(cases):
        assert not (case.check_merge_sync and case.check_binary_sync), (
            f"{case.name}: invalid case configuration, merge and binary synchronization checks are mutually exclusive."
        )

        image, observed, stats = await _run_case(
            dut,
            case=case,
            frame_idx=idx + 1,
        )

        assert stats.accepted_beats == FRAME_WIDTH * FRAME_HEIGHT, (
            f"{case.name}: unexpected accepted output beats {stats.accepted_beats}"
        )
        if case.sink_pause_pattern is not None:
            saw_sink_backpressure_stall = saw_sink_backpressure_stall or (
                stats.stall_cycles > 0
            )

        if case.expect_grayscale_output:
            _assert_rgb_is_grayscale(observed, label=case.name)

        if case.check_merge_sync or case.check_binary_sync:
            assert stats.mask_hits > 0, (
                f"{case.name}: expected at least one mask-hit pixel."
            )
            assert stats.mask_misses > 0, (
                f"{case.name}: expected at least one mask-miss pixel."
            )

    assert saw_sink_backpressure_stall, (
        "Expected at least one sink-backpressure case to introduce output stall cycles."
    )


async def _assert_no_sof_accept_until_task_done(
    dut: Any,
    *,
    task: cocotb.task.Task[Any],
    timeout_cycles: int = 200_000,
) -> None:
    i_clk = getattr(dut, ACLK_SIGNAL)
    in_tvalid = getattr(dut, f"{S_AXIS_PREFIX}_tvalid")
    in_tready = getattr(dut, f"{S_AXIS_PREFIX}_tready")
    in_tuser = getattr(dut, f"{S_AXIS_PREFIX}_tuser")
    cycles = 0

    while not task.done():
        cycles += 1
        if cycles > timeout_cycles:
            raise AssertionError(
                "Timed out while waiting for monitored task to complete.",
            )

        await RisingEdge(i_clk)
        await ReadOnly()
        assert not (
            int(in_tvalid.value) == 1
            and int(in_tready.value) == 1
            and int(in_tuser.value) == 1
        ), "Unexpected input SOF handshake detected while source drives TUSER=0."

    await RisingEdge(i_clk)
    await ReadOnly()
    assert not (
        int(in_tvalid.value) == 1
        and int(in_tready.value) == 1
        and int(in_tuser.value) == 1
    ), "Unexpected input SOF handshake detected after source transfer completion."


@cocotb.test(timeout_time=1200, timeout_unit="ms")
async def test_pipeline_controls_stay_default_without_input_sof(dut: Any) -> None:
    i_clk = getattr(dut, ACLK_SIGNAL)
    i_aresetn = getattr(dut, ARESETN_SIGNAL)
    i_btn = getattr(dut, BTN_SIGNAL)
    cocotb.start_soon(Clock(i_clk, 10, unit="ns").start())

    i_aresetn.value = int(RESET_ACTIVE_LEVEL)
    i_btn.value = 0
    getattr(dut, f"{S_AXIS_PREFIX}_tvalid").value = 0
    getattr(dut, f"{S_AXIS_PREFIX}_tdata").value = 0
    getattr(dut, f"{S_AXIS_PREFIX}_tlast").value = 0
    getattr(dut, f"{S_AXIS_PREFIX}_tuser").value = 0

    await apply_reset(
        dut=dut,
        i_clk=i_clk,
        i_rst_n=i_aresetn,
        stream_input_prefix=S_AXIS_PREFIX,
        reset_active_level=RESET_ACTIVE_LEVEL,
    )

    source = _NoSofAxiVideoStreamSource(
        dut=dut,
        i_clk=i_clk,
        i_rst_n=i_aresetn,
        prefix=S_AXIS_PREFIX,
        reset_active_level=RESET_ACTIVE_LEVEL,
        pixel_order=PIXEL_ORDER,
    )
    controls_before = (
        int(dut.s_pass_grayscale.value),
        int(dut.s_pass_blurr_filter.value),
        int(dut.s_pass_sobel.value),
        int(dut.s_pass_fast.value),
        int(dut.s_overlay_zeros.value),
    )
    assert controls_before == (0, 1, 1, 1, 1), (
        f"Unexpected initial controls after reset: {controls_before}"
    )

    await _set_clicks(
        dut,
        btn1_clicks=2,
        btn2_clicks=0,
        btn_both_clicks=0,
    )
    await _assert_controls(
        dut,
        StateCase(
            name="raw_controls_advance_without_latch",
            btn1_clicks=0,
            btn2_clicks=0,
            btn_both_clicks=0,
            warmup_stages=0,
            exp_pass_grayscale=0,
            exp_pass_blur=1,
            exp_pass_sobel=0,
            exp_pass_fast=1,
            exp_overlay_zeros=1,
            check_merge_sync=False,
            check_binary_sync=False,
            expect_grayscale_output=False,
            source_pause_pattern=None,
            sink_pause_pattern=None,
        ),
        settle_cycles=256,
    )

    controls_after_clicks = (
        int(dut.s_pass_grayscale.value),
        int(dut.s_pass_blurr_filter.value),
        int(dut.s_pass_sobel.value),
        int(dut.s_pass_fast.value),
        int(dut.s_overlay_zeros.value),
    )
    assert controls_after_clicks == (0, 1, 0, 1, 1), (
        f"Controls did not update immediately after button clicks: {controls_after_clicks}"
    )

    frame_1 = _make_synthetic_frame(203)
    frame_2 = _make_synthetic_frame(204)

    tx_frame_1 = cocotb.start_soon(source.send_image(frame_1))
    mon_frame_1 = cocotb.start_soon(
        _assert_no_sof_accept_until_task_done(
            dut,
            task=tx_frame_1,
        ),
    )
    await with_timeout(tx_frame_1, 30_000_000, "ns")
    await with_timeout(mon_frame_1, 30_000_000, "ns")

    tx_frame_2 = cocotb.start_soon(source.send_image(frame_2))
    mon_frame_2 = cocotb.start_soon(
        _assert_no_sof_accept_until_task_done(
            dut,
            task=tx_frame_2,
        ),
    )
    await with_timeout(tx_frame_2, 30_000_000, "ns")
    await with_timeout(mon_frame_2, 30_000_000, "ns")
