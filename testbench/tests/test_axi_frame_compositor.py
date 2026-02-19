"""AXI_FrameCompositor stress checks with frame sequences and handshake validation."""

from __future__ import annotations

from pathlib import Path

import cocotb
import numpy as np
from cocotb.clock import Clock
from cocotb.triggers import ReadOnly, RisingEdge, SimTimeoutError, Timer, with_timeout
from common.pause import repeating_pause
from drivers.axis_gray_source import AxiGrayStreamSource
from drivers.axis_video_source import AxiVideoStreamSource
from models.image_model import Image
from monitors.axis_video_sink import AxiVideoStreamSink

ACLK_SIGNAL = "i_aclk"
ARESETN_SIGNAL = "i_aresetn"
RESET_ACTIVE_LEVEL = False

S_RGB_PREFIX = "s_axis_video_rbg888"
S_GRAY_PREFIX = "s_axis_video_gray8"
M_RGB_PREFIX = "m_axis_video_rbg888"
PIXEL_ORDER = "rbg"
TESTBENCH_ROOT = Path(__file__).resolve().parents[1]

FRAME_W = 12
FRAME_H = 8
FRAME_COUNT = 3

C_OVERLAY_FAST = 0b01
C_OVERLAY_SOBEL = 0b10
C_DELAY_NONE = 0b00
C_DELAY_SOBEL = 0b01
C_DELAY_BLUR_SOBEL = 0b10
C_SOBEL_DELAY_CYCLES = 1027
C_BLUR_SOBEL_DELAY_CYCLES = 2054
C_SOBEL_DELAY_EFFECTIVE = 1028
C_BLUR_SOBEL_DELAY_EFFECTIVE = 2057


def _make_rgb_frame(frame_idx: int) -> Image:
    y, x = np.indices((FRAME_H, FRAME_W), dtype=np.uint16)
    r = (x * 7 + y * 3 + frame_idx * 41) % 256
    g = (x * 5 + y * 11 + frame_idx * 17) % 256
    b = (x * 13 + y * 2 + frame_idx * 29) % 256
    pixels = np.stack([r, g, b], axis=2).astype(np.uint8)
    return Image(pixels)


def _make_gray_mask_frame(frame_idx: int) -> Image:
    y, x = np.indices((FRAME_H, FRAME_W), dtype=np.uint16)
    mask = ((x + frame_idx * 3) % 9 == 0) | ((y + frame_idx * 2) % 7 == 0)
    gray = np.where(mask, 255, 0).astype(np.uint8)
    pixels = np.stack([gray, gray, gray], axis=2)
    return Image(pixels)


def _make_rgb_frame_size(frame_idx: int, *, width: int, height: int) -> Image:
    y, x = np.indices((height, width), dtype=np.uint16)
    r = (x * 19 + y * 7 + frame_idx * 13) % 256
    g = (x * 3 + y * 23 + frame_idx * 11) % 256
    b = (x * 29 + y * 5 + frame_idx * 17) % 256
    return Image(np.stack([r, g, b], axis=2).astype(np.uint8))


def _make_gray_mask_frame_size(frame_idx: int, *, width: int, height: int) -> Image:
    y, x = np.indices((height, width), dtype=np.uint16)
    mask = ((x + frame_idx) % 4 == 0) | ((y + 2 * frame_idx) % 3 == 0)
    gray = np.where(mask, 255, 0).astype(np.uint8)
    return Image(np.stack((gray, gray, gray), axis=2))


def _expected_output_for_controls(
    *,
    base: Image,
    mask: Image,
    overlay_mode: int,
    overlay_zeros: int,
) -> Image:
    edge = mask.pixels[:, :, 0] != 0
    if overlay_zeros == 1:
        bin_plane = np.where(edge, 255, 0).astype(np.uint8)
        return Image(np.stack((bin_plane, bin_plane, bin_plane), axis=2))

    out = base.pixels.copy()
    if overlay_mode == C_OVERLAY_SOBEL:
        out[edge] = np.array([255, 0, 0], dtype=np.uint8)
    elif overlay_mode == C_OVERLAY_FAST:
        # FAST color x"0000FF" in DUT maps to R|B|G packing => green in Image RGB tuples.
        out[edge] = np.array([0, 255, 0], dtype=np.uint8)
    return Image(out)


def _load_lenna_downscaled(step: int = 8) -> Image:
    image_path = TESTBENCH_ROOT / "images" / "lenna_512_512.png"
    full = Image.from_png(image_path)
    pixels = full.pixels[::step, ::step, :].copy()
    return Image(pixels)


def _make_real_image_sequence() -> tuple[list[Image], list[Image]]:
    base = _load_lenna_downscaled(step=8)
    frame0 = base
    frame1 = Image(np.roll(base.pixels, shift=5, axis=1))

    mask0_plane = np.where(frame0.pixels[:, :, 1] > 110, 255, 0).astype(np.uint8)
    mask1_plane = np.where(frame1.pixels[:, :, 2] > 140, 255, 0).astype(np.uint8)

    mask0 = Image(np.stack((mask0_plane, mask0_plane, mask0_plane), axis=2))
    mask1 = Image(np.stack((mask1_plane, mask1_plane, mask1_plane), axis=2))
    return [frame0, frame1], [mask0, mask1]


def _overlay_expected(base: Image, mask: Image) -> Image:
    out = base.pixels.copy()
    edge = mask.pixels[:, :, 0] != 0
    out[edge] = np.array([255, 0, 0], dtype=np.uint8)
    return Image(out)


def _assert_image_equal(expected: Image, observed: Image, *, label: str) -> None:
    if np.array_equal(expected.pixels, observed.pixels):
        return
    mismatch = np.argwhere(np.any(expected.pixels != observed.pixels, axis=2))[0]
    y = int(mismatch[0])
    x = int(mismatch[1])
    raise AssertionError(
        f"{label}: first mismatch at (x={x}, y={y}), "
        f"expected={expected.pixels[y, x].tolist()}, observed={observed.pixels[y, x].tolist()}",
    )


def _is_resolved(value) -> bool:
    try:
        return bool(value.is_resolvable)
    except AttributeError:
        text = str(value)
        return all(ch in "01" for ch in text)


async def _monitor_axis_video_handshake(
    dut,
    *,
    prefix: str,
    width: int,
    height: int,
    frames: int,
    check_stall_stability: bool,
    verbose: bool = False,
) -> dict[str, int]:
    tvalid = getattr(dut, f"{prefix}_tvalid")
    tready = getattr(dut, f"{prefix}_tready")
    tdata = getattr(dut, f"{prefix}_tdata")
    tuser = getattr(dut, f"{prefix}_tuser")
    tlast = getattr(dut, f"{prefix}_tlast")
    i_rst_n = getattr(dut, ARESETN_SIGNAL)
    i_clk = getattr(dut, ACLK_SIGNAL)

    total_beats = width * height * frames
    accepted = 0
    row = 0
    col = 0
    stall_cycles = 0
    prev_stall_payload: tuple[int, int, int] | None = None

    while accepted < total_beats:
        await RisingEdge(i_clk)
        await ReadOnly()

        if int(i_rst_n.value) == int(RESET_ACTIVE_LEVEL):
            accepted = 0
            row = 0
            col = 0
            stall_cycles = 0
            prev_stall_payload = None
            continue

        assert _is_resolved(tvalid.value), f"{prefix}: unresolved TVALID"
        assert _is_resolved(tready.value), f"{prefix}: unresolved TREADY"
        assert _is_resolved(tdata.value), f"{prefix}: unresolved TDATA"
        assert _is_resolved(tuser.value), f"{prefix}: unresolved TUSER"
        assert _is_resolved(tlast.value), f"{prefix}: unresolved TLAST"

        valid = int(tvalid.value)
        ready = int(tready.value)
        data = int(tdata.value)
        user = int(tuser.value)
        last = int(tlast.value)

        if valid == 1 and ready == 0:
            stall_cycles += 1
            if check_stall_stability:
                payload = (data, user, last)
                if prev_stall_payload is not None:
                    assert payload == prev_stall_payload, (
                        f"{prefix}: payload changed while stalled; "
                        f"prev={prev_stall_payload}, now={payload}"
                    )
                prev_stall_payload = payload
            if verbose and (stall_cycles == 1 or (stall_cycles % 256) == 0):
                dut._log.info(
                    "%s stalled: stalls=%d accepted=%d row=%d col=%d",
                    prefix,
                    stall_cycles,
                    accepted,
                    row,
                    col,
                )
            continue

        prev_stall_payload = None

        if valid == 1 and ready == 1:
            exp_user = 1 if (row == 0 and col == 0) else 0
            exp_last = 1 if (col == width - 1) else 0
            assert user == exp_user, (
                f"{prefix}: TUSER mismatch at beat {accepted}: observed={user}, expected={exp_user}"
            )
            assert last == exp_last, (
                f"{prefix}: TLAST mismatch at beat {accepted}: observed={last}, expected={exp_last}"
            )
            if verbose and (accepted < 8 or col == 0):
                dut._log.info(
                    "%s beat=%d row=%d col=%d user=%d last=%d data=0x%X",
                    prefix,
                    accepted,
                    row,
                    col,
                    user,
                    last,
                    data,
                )

            accepted += 1
            if col == width - 1:
                col = 0
                row += 1
                if row == height:
                    row = 0
            else:
                col += 1

    return {"accepted": accepted, "stall_cycles": stall_cycles}


async def _reset(dut) -> None:
    i_rst_n = getattr(dut, ARESETN_SIGNAL)
    i_clk = getattr(dut, ACLK_SIGNAL)

    i_rst_n.value = 0
    dut.i_overlay_zeros.value = 0
    dut.i_overlay_mode.value = 0
    dut.i_base_delay_stage_sel.value = C_DELAY_NONE
    dut.m_axis_video_rbg888_tready.value = 1

    getattr(dut, f"{S_RGB_PREFIX}_tvalid").value = 0
    getattr(dut, f"{S_RGB_PREFIX}_tdata").value = 0
    getattr(dut, f"{S_RGB_PREFIX}_tuser").value = 0
    getattr(dut, f"{S_RGB_PREFIX}_tlast").value = 0
    getattr(dut, f"{S_GRAY_PREFIX}_tvalid").value = 0
    getattr(dut, f"{S_GRAY_PREFIX}_tdata").value = 0
    getattr(dut, f"{S_GRAY_PREFIX}_tuser").value = 0
    getattr(dut, f"{S_GRAY_PREFIX}_tlast").value = 0

    await RisingEdge(i_clk)
    await RisingEdge(i_clk)
    i_rst_n.value = 1
    await RisingEdge(i_clk)


async def _send_rgb_sequence(source: AxiVideoStreamSource, frames: list[Image]) -> None:
    for frame in frames:
        await source.send_image(frame)


async def _send_gray_sequence_with_delay(
    dut,
    source: AxiGrayStreamSource,
    frames: list[Image],
) -> None:
    i_clk = getattr(dut, ACLK_SIGNAL)
    for idx, frame in enumerate(frames):
        for _ in range(12 + (idx * 5)):
            await RisingEdge(i_clk)
        await source.send_image(frame)


async def _send_gray_frame_with_initial_delay(
    dut,
    source: AxiGrayStreamSource,
    frame: Image,
    delay_cycles: int,
) -> None:
    i_clk = getattr(dut, ACLK_SIGNAL)
    for _ in range(delay_cycles):
        await RisingEdge(i_clk)
    await source.send_image(frame)


@cocotb.test(timeout_time=260, timeout_unit="ms")
async def test_axi_frame_compositor_multiframe_sync_with_gray_delay_and_backpressure(
    dut,
) -> None:
    i_clk = getattr(dut, ACLK_SIGNAL)
    cocotb.start_soon(Clock(i_clk, 10, unit="ns").start())
    await _reset(dut)

    dut.i_overlay_mode.value = C_OVERLAY_SOBEL
    dut.i_overlay_zeros.value = 0
    dut.i_base_delay_stage_sel.value = C_DELAY_NONE

    rgb_source = AxiVideoStreamSource(
        dut=dut,
        i_clk=i_clk,
        i_rst_n=getattr(dut, ARESETN_SIGNAL),
        prefix=S_RGB_PREFIX,
        reset_active_level=RESET_ACTIVE_LEVEL,
        pixel_order=PIXEL_ORDER,
    )
    gray_source = AxiGrayStreamSource(
        dut=dut,
        i_clk=i_clk,
        i_rst_n=getattr(dut, ARESETN_SIGNAL),
        prefix=S_GRAY_PREFIX,
        reset_active_level=RESET_ACTIVE_LEVEL,
    )
    sink = AxiVideoStreamSink(
        dut=dut,
        i_clk=i_clk,
        i_rst_n=getattr(dut, ARESETN_SIGNAL),
        prefix=M_RGB_PREFIX,
        reset_active_level=RESET_ACTIVE_LEVEL,
        pixel_order=PIXEL_ORDER,
    )

    rgb_source.set_pause_generator(repeating_pause((0, 0, 1, 0, 0, 1, 0)))
    gray_source.set_pause_generator(repeating_pause((0, 1, 0, 0, 0, 1)))
    sink.set_pause_generator(repeating_pause((0, 1, 0, 0, 1, 0, 0)))

    rgb_frames = [_make_rgb_frame(i) for i in range(FRAME_COUNT)]
    gray_frames = [_make_gray_mask_frame(i) for i in range(FRAME_COUNT)]
    expected_frames = [
        _overlay_expected(rgb, gray) for rgb, gray in zip(rgb_frames, gray_frames)
    ]

    mon_rgb_in = cocotb.start_soon(
        _monitor_axis_video_handshake(
            dut,
            prefix=S_RGB_PREFIX,
            width=FRAME_W,
            height=FRAME_H,
            frames=FRAME_COUNT,
            check_stall_stability=True,
            verbose=False,
        ),
    )
    mon_gray_in = cocotb.start_soon(
        _monitor_axis_video_handshake(
            dut,
            prefix=S_GRAY_PREFIX,
            width=FRAME_W,
            height=FRAME_H,
            frames=FRAME_COUNT,
            check_stall_stability=True,
            verbose=False,
        ),
    )
    mon_out = cocotb.start_soon(
        _monitor_axis_video_handshake(
            dut,
            prefix=M_RGB_PREFIX,
            width=FRAME_W,
            height=FRAME_H,
            frames=FRAME_COUNT,
            check_stall_stability=True,
            verbose=False,
        ),
    )

    tx_rgb = cocotb.start_soon(_send_rgb_sequence(rgb_source, rgb_frames))
    tx_gray = cocotb.start_soon(
        _send_gray_sequence_with_delay(dut, gray_source, gray_frames),
    )

    observed_frames: list[Image] = []
    for _ in range(FRAME_COUNT):
        frame = await sink.recv_image(
            width=FRAME_W,
            height=FRAME_H,
            timeout_ns=1_500_000,
        )
        observed_frames.append(frame)

    await with_timeout(tx_rgb, 30_000_000, "ns")
    await with_timeout(tx_gray, 30_000_000, "ns")

    rgb_in_stats = await with_timeout(mon_rgb_in, 30_000_000, "ns")
    gray_in_stats = await with_timeout(mon_gray_in, 30_000_000, "ns")
    out_stats = await with_timeout(mon_out, 30_000_000, "ns")

    for idx, (expected, observed) in enumerate(zip(expected_frames, observed_frames)):
        _assert_image_equal(expected, observed, label=f"frame {idx}")

    assert rgb_in_stats["accepted"] == FRAME_W * FRAME_H * FRAME_COUNT
    assert gray_in_stats["accepted"] == FRAME_W * FRAME_H * FRAME_COUNT
    assert out_stats["accepted"] == FRAME_W * FRAME_H * FRAME_COUNT
    assert rgb_in_stats["stall_cycles"] > 0
    assert gray_in_stats["stall_cycles"] > 0
    assert out_stats["stall_cycles"] > 0


@cocotb.test(timeout_time=260, timeout_unit="ms")
async def test_axi_frame_compositor_downscaled_real_image_sequence(dut) -> None:
    i_clk = getattr(dut, ACLK_SIGNAL)
    cocotb.start_soon(Clock(i_clk, 10, unit="ns").start())
    await _reset(dut)

    dut.i_overlay_mode.value = C_OVERLAY_SOBEL
    dut.i_overlay_zeros.value = 0
    dut.i_base_delay_stage_sel.value = C_DELAY_NONE

    rgb_source = AxiVideoStreamSource(
        dut=dut,
        i_clk=i_clk,
        i_rst_n=getattr(dut, ARESETN_SIGNAL),
        prefix=S_RGB_PREFIX,
        reset_active_level=RESET_ACTIVE_LEVEL,
        pixel_order=PIXEL_ORDER,
    )
    gray_source = AxiGrayStreamSource(
        dut=dut,
        i_clk=i_clk,
        i_rst_n=getattr(dut, ARESETN_SIGNAL),
        prefix=S_GRAY_PREFIX,
        reset_active_level=RESET_ACTIVE_LEVEL,
    )
    sink = AxiVideoStreamSink(
        dut=dut,
        i_clk=i_clk,
        i_rst_n=getattr(dut, ARESETN_SIGNAL),
        prefix=M_RGB_PREFIX,
        reset_active_level=RESET_ACTIVE_LEVEL,
        pixel_order=PIXEL_ORDER,
    )

    rgb_source.set_pause_generator(repeating_pause((0, 1, 0, 0, 0, 1)))
    gray_source.set_pause_generator(repeating_pause((0, 0, 1, 0, 1, 0)))
    sink.set_pause_generator(repeating_pause((0, 0, 1, 0)))

    rgb_frames, gray_frames = _make_real_image_sequence()
    expected_frames = [
        _overlay_expected(rgb, gray) for rgb, gray in zip(rgb_frames, gray_frames)
    ]
    frame_w = rgb_frames[0].width
    frame_h = rgb_frames[0].height

    mon_out = cocotb.start_soon(
        _monitor_axis_video_handshake(
            dut,
            prefix=M_RGB_PREFIX,
            width=frame_w,
            height=frame_h,
            frames=len(rgb_frames),
            check_stall_stability=True,
            verbose=False,
        ),
    )

    tx_rgb = cocotb.start_soon(_send_rgb_sequence(rgb_source, rgb_frames))
    tx_gray = cocotb.start_soon(
        _send_gray_sequence_with_delay(dut, gray_source, gray_frames),
    )

    observed_frames: list[Image] = []
    for _ in range(len(rgb_frames)):
        observed = await sink.recv_image(
            width=frame_w,
            height=frame_h,
            timeout_ns=1_500_000,
        )
        observed_frames.append(observed)

    await with_timeout(tx_rgb, 30_000_000, "ns")
    await with_timeout(tx_gray, 30_000_000, "ns")
    out_stats = await with_timeout(mon_out, 30_000_000, "ns")

    for idx, (expected, observed) in enumerate(zip(expected_frames, observed_frames)):
        _assert_image_equal(expected, observed, label=f"downscaled real frame {idx}")

    assert out_stats["accepted"] == frame_w * frame_h * len(rgb_frames)
    assert out_stats["stall_cycles"] > 0


@cocotb.test(timeout_time=420, timeout_unit="ms")
async def test_axi_frame_compositor_small_mode_matrix_with_backpressure_and_gray_delays(
    dut,
) -> None:
    i_clk = getattr(dut, ACLK_SIGNAL)
    cocotb.start_soon(Clock(i_clk, 10, unit="ns").start())

    width = 8
    height = 6
    case_idx = 0

    for overlay_mode in (0b00, 0b01, 0b10, 0b11):
        for overlay_zeros in (0, 1):
            await _reset(dut)

            dut.i_overlay_mode.value = overlay_mode
            dut.i_overlay_zeros.value = overlay_zeros
            dut.i_base_delay_stage_sel.value = C_DELAY_NONE
            need_rgb = (overlay_zeros == 0) and (overlay_mode != 0b00)

            rgb_source = AxiVideoStreamSource(
                dut=dut,
                i_clk=i_clk,
                i_rst_n=getattr(dut, ARESETN_SIGNAL),
                prefix=S_RGB_PREFIX,
                reset_active_level=RESET_ACTIVE_LEVEL,
                pixel_order=PIXEL_ORDER,
            )
            gray_source = AxiGrayStreamSource(
                dut=dut,
                i_clk=i_clk,
                i_rst_n=getattr(dut, ARESETN_SIGNAL),
                prefix=S_GRAY_PREFIX,
                reset_active_level=RESET_ACTIVE_LEVEL,
            )
            sink = AxiVideoStreamSink(
                dut=dut,
                i_clk=i_clk,
                i_rst_n=getattr(dut, ARESETN_SIGNAL),
                prefix=M_RGB_PREFIX,
                reset_active_level=RESET_ACTIVE_LEVEL,
                pixel_order=PIXEL_ORDER,
            )

            if need_rgb:
                gray_source.set_pause_generator(repeating_pause((0, 0, 1, 0, 1, 0, 0)))
                sink.set_pause_generator(repeating_pause((0, 1, 0, 0, 1)))

            rgb_frame = _make_rgb_frame_size(case_idx + 1, width=width, height=height)
            gray_mask = _make_gray_mask_frame_size(
                case_idx + 2,
                width=width,
                height=height,
            )
            expected = _expected_output_for_controls(
                base=rgb_frame,
                mask=gray_mask,
                overlay_mode=overlay_mode,
                overlay_zeros=overlay_zeros,
            )

            gray_start_delay = (case_idx % 4) * 3 if need_rgb else 0

            dut._log.info(
                "small matrix case=%d mode=0b%s zeros=%d gray_start_delay=%d need_rgb=%d",
                case_idx,
                format(overlay_mode, "02b"),
                overlay_zeros,
                gray_start_delay,
                int(need_rgb),
            )

            mon_rgb = cocotb.start_soon(
                _monitor_axis_video_handshake(
                    dut,
                    prefix=S_RGB_PREFIX,
                    width=width,
                    height=height,
                    frames=1,
                    check_stall_stability=True,
                    verbose=(case_idx == 0),
                ),
            )
            mon_gray = cocotb.start_soon(
                _monitor_axis_video_handshake(
                    dut,
                    prefix=S_GRAY_PREFIX,
                    width=width,
                    height=height,
                    frames=1,
                    check_stall_stability=True,
                    verbose=(case_idx == 0),
                ),
            )
            mon_out = cocotb.start_soon(
                _monitor_axis_video_handshake(
                    dut,
                    prefix=M_RGB_PREFIX,
                    width=width,
                    height=height,
                    frames=1,
                    check_stall_stability=True,
                    verbose=(case_idx == 0),
                ),
            )

            tx_rgb = cocotb.start_soon(rgb_source.send_image(rgb_frame))
            tx_gray = cocotb.start_soon(
                _send_gray_frame_with_initial_delay(
                    dut,
                    gray_source,
                    gray_mask,
                    gray_start_delay,
                ),
            )

            observed = await sink.recv_image(
                width=width,
                height=height,
                timeout_ns=2_000_000,
            )

            await with_timeout(tx_rgb, 40_000_000, "ns")
            await with_timeout(tx_gray, 40_000_000, "ns")
            rgb_stats = await with_timeout(mon_rgb, 40_000_000, "ns")
            gray_stats = await with_timeout(mon_gray, 40_000_000, "ns")
            out_stats = await with_timeout(mon_out, 40_000_000, "ns")

            _assert_image_equal(
                expected,
                observed,
                label=f"small matrix case {case_idx}",
            )
            assert rgb_stats["accepted"] == width * height
            assert gray_stats["accepted"] == width * height
            assert out_stats["accepted"] == width * height
            if need_rgb:
                assert gray_stats["stall_cycles"] > 0
                assert rgb_stats["stall_cycles"] > 0
                assert out_stats["stall_cycles"] > 0

            dut._log.info(
                "small matrix case=%d passed rgb_stalls=%d gray_stalls=%d out_stalls=%d",
                case_idx,
                rgb_stats["stall_cycles"],
                gray_stats["stall_cycles"],
                out_stats["stall_cycles"],
            )

            case_idx += 1

    assert case_idx == 8


@cocotb.test(timeout_time=80, timeout_unit="ms")
async def test_axi_frame_compositor_delay_stage_sweep_with_backpressure(dut) -> None:
    i_clk = getattr(dut, ACLK_SIGNAL)
    cocotb.start_soon(Clock(i_clk, 10, unit="ns").start())

    cases = (
        ("sobel_delay", C_DELAY_SOBEL, C_SOBEL_DELAY_EFFECTIVE),
        ("blur_sobel_delay", C_DELAY_BLUR_SOBEL, C_BLUR_SOBEL_DELAY_EFFECTIVE),
        ("illegal_delay_sel_bypass", 0b11, 0),
    )

    for case_idx, (label, stage_sel, delay_cycles) in enumerate(cases):
        await _reset(dut)

        dut.i_overlay_mode.value = C_OVERLAY_SOBEL
        dut.i_overlay_zeros.value = 0
        dut.i_base_delay_stage_sel.value = stage_sel

        rgb_source = AxiVideoStreamSource(
            dut=dut,
            i_clk=i_clk,
            i_rst_n=getattr(dut, ARESETN_SIGNAL),
            prefix=S_RGB_PREFIX,
            reset_active_level=RESET_ACTIVE_LEVEL,
            pixel_order=PIXEL_ORDER,
        )
        gray_source = AxiGrayStreamSource(
            dut=dut,
            i_clk=i_clk,
            i_rst_n=getattr(dut, ARESETN_SIGNAL),
            prefix=S_GRAY_PREFIX,
            reset_active_level=RESET_ACTIVE_LEVEL,
        )
        sink = AxiVideoStreamSink(
            dut=dut,
            i_clk=i_clk,
            i_rst_n=getattr(dut, ARESETN_SIGNAL),
            prefix=M_RGB_PREFIX,
            reset_active_level=RESET_ACTIVE_LEVEL,
            pixel_order=PIXEL_ORDER,
        )

        gray_source.set_pause_generator(repeating_pause((0, 0, 1, 0, 1, 0, 0)))
        sink.set_pause_generator(repeating_pause((0, 1, 0, 0, 1)))

        frame_w = 10
        frame_h = 7
        base = _make_rgb_frame_size(10 + case_idx, width=frame_w, height=frame_h)
        mask = _make_gray_mask_frame_size(20 + case_idx, width=frame_w, height=frame_h)
        expected = _overlay_expected(base, mask)
        gray_start_delay = delay_cycles

        dut._log.info(
            "AXI_FrameCompositor stress case=%s stage_sel=%d delay_cycles=%d gray_start_delay=%d frame=%dx%d",
            label,
            stage_sel,
            delay_cycles,
            gray_start_delay,
            frame_w,
            frame_h,
        )

        mon_out = cocotb.start_soon(
            _monitor_axis_video_handshake(
                dut,
                prefix=M_RGB_PREFIX,
                width=frame_w,
                height=frame_h,
                frames=1,
                check_stall_stability=True,
                verbose=True,
            ),
        )

        tx_rgb = cocotb.start_soon(
            rgb_source.send_image(base, tail_padding_pixels=delay_cycles + 16),
        )
        tx_gray = cocotb.start_soon(
            _send_gray_frame_with_initial_delay(
                dut,
                gray_source,
                mask,
                gray_start_delay,
            ),
        )

        observed = await sink.recv_image(
            width=frame_w,
            height=frame_h,
            timeout_ns=1_500_000,
        )

        try:
            await with_timeout(tx_rgb, 2_000_000, "ns")
        except SimTimeoutError:
            tx_rgb.cancel()
        await with_timeout(tx_gray, 8_000_000, "ns")
        out_stats = await with_timeout(mon_out, 8_000_000, "ns")

        _assert_image_equal(expected, observed, label=f"{label} observed")
        assert out_stats["accepted"] == frame_w * frame_h

        dut._log.info(
            "AXI_FrameCompositor stress case=%s passed accepted=%d stalls=%d",
            label,
            out_stats["accepted"],
            out_stats["stall_cycles"],
        )


@cocotb.test(timeout_time=220, timeout_unit="ms")
async def test_axi_frame_compositor_binary_mode_not_blocked_by_rgb(dut) -> None:
    i_clk = getattr(dut, ACLK_SIGNAL)
    cocotb.start_soon(Clock(i_clk, 10, unit="ns").start())
    await _reset(dut)

    dut.i_overlay_mode.value = C_OVERLAY_SOBEL
    dut.i_overlay_zeros.value = 1
    dut.i_base_delay_stage_sel.value = C_DELAY_NONE

    gray_source = AxiGrayStreamSource(
        dut=dut,
        i_clk=i_clk,
        i_rst_n=getattr(dut, ARESETN_SIGNAL),
        prefix=S_GRAY_PREFIX,
        reset_active_level=RESET_ACTIVE_LEVEL,
    )
    sink = AxiVideoStreamSink(
        dut=dut,
        i_clk=i_clk,
        i_rst_n=getattr(dut, ARESETN_SIGNAL),
        prefix=M_RGB_PREFIX,
        reset_active_level=RESET_ACTIVE_LEVEL,
        pixel_order=PIXEL_ORDER,
    )

    # Keep sink mostly ready with occasional stalls.
    sink.set_pause_generator(repeating_pause((0, 0, 1, 0)))

    gray_frame = _make_gray_mask_frame(0)
    tx_gray = cocotb.start_soon(gray_source.send_image(gray_frame))
    observed = await sink.recv_image(
        width=FRAME_W,
        height=FRAME_H,
        timeout_ns=1_200_000,
    )
    await with_timeout(tx_gray, 20_000_000, "ns")

    expected = Image(
        np.where(gray_frame.pixels[:, :, 0:1] != 0, 255, 0)
        .repeat(3, axis=2)
        .astype(np.uint8),
    )
    _assert_image_equal(expected, observed, label="binary-only frame")

    # RGB interface should not block binary-only output mode.
    await Timer(100, unit="ns")
    assert int(dut.s_axis_video_gray8_tready.value) == 1


@cocotb.test(timeout_time=120, timeout_unit="ms")
async def test_axi_frame_compositor_binary_mode_active_rgb_backpressure_lockstep(dut) -> None:
    i_clk = getattr(dut, ACLK_SIGNAL)
    cocotb.start_soon(Clock(i_clk, 10, unit="ns").start())
    await _reset(dut)

    width = 8
    height = 6

    dut.i_overlay_mode.value = C_OVERLAY_SOBEL
    dut.i_overlay_zeros.value = 1
    dut.i_base_delay_stage_sel.value = C_DELAY_NONE

    rgb_source = AxiVideoStreamSource(
        dut=dut,
        i_clk=i_clk,
        i_rst_n=getattr(dut, ARESETN_SIGNAL),
        prefix=S_RGB_PREFIX,
        reset_active_level=RESET_ACTIVE_LEVEL,
        pixel_order=PIXEL_ORDER,
    )
    gray_source = AxiGrayStreamSource(
        dut=dut,
        i_clk=i_clk,
        i_rst_n=getattr(dut, ARESETN_SIGNAL),
        prefix=S_GRAY_PREFIX,
        reset_active_level=RESET_ACTIVE_LEVEL,
    )
    sink = AxiVideoStreamSink(
        dut=dut,
        i_clk=i_clk,
        i_rst_n=getattr(dut, ARESETN_SIGNAL),
        prefix=M_RGB_PREFIX,
        reset_active_level=RESET_ACTIVE_LEVEL,
        pixel_order=PIXEL_ORDER,
    )

    # Keep RGB/gray sources continuously valid so lockstep acceptance in binary
    # mode is exercised against sink backpressure only.
    sink.set_pause_generator(repeating_pause((0, 1, 0, 0, 1, 0, 1)))

    rgb_frame = _make_rgb_frame_size(31, width=width, height=height)
    gray_frame = _make_gray_mask_frame_size(32, width=width, height=height)
    expected = Image(
        np.where(gray_frame.pixels[:, :, 0:1] != 0, 255, 0).repeat(3, axis=2).astype(np.uint8),
    )

    mon_rgb = cocotb.start_soon(
        _monitor_axis_video_handshake(
            dut,
            prefix=S_RGB_PREFIX,
            width=width,
            height=height,
            frames=1,
            check_stall_stability=True,
        ),
    )
    mon_gray = cocotb.start_soon(
        _monitor_axis_video_handshake(
            dut,
            prefix=S_GRAY_PREFIX,
            width=width,
            height=height,
            frames=1,
            check_stall_stability=True,
        ),
    )
    mon_out = cocotb.start_soon(
        _monitor_axis_video_handshake(
            dut,
            prefix=M_RGB_PREFIX,
            width=width,
            height=height,
            frames=1,
            check_stall_stability=True,
        ),
    )

    tx_rgb = cocotb.start_soon(rgb_source.send_image(rgb_frame))
    tx_gray = cocotb.start_soon(gray_source.send_image(gray_frame))

    observed = await sink.recv_image(
        width=width,
        height=height,
        timeout_ns=2_000_000,
    )

    await with_timeout(tx_rgb, 30_000_000, "ns")
    await with_timeout(tx_gray, 30_000_000, "ns")
    rgb_stats = await with_timeout(mon_rgb, 30_000_000, "ns")
    gray_stats = await with_timeout(mon_gray, 30_000_000, "ns")
    out_stats = await with_timeout(mon_out, 30_000_000, "ns")

    _assert_image_equal(expected, observed, label="binary active-rgb case")
    assert rgb_stats["accepted"] == width * height
    assert gray_stats["accepted"] == width * height
    assert out_stats["accepted"] == width * height
    assert rgb_stats["stall_cycles"] > 0
    assert gray_stats["stall_cycles"] > 0
    assert out_stats["stall_cycles"] > 0
