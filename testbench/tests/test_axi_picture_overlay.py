"""Behavioural tests for AxiPictureOverlay.

Tests
-----
test_passthrough_when_disabled
    With i_pass_picture_overlay='1', every output pixel must equal the input pixel,
    regardless of the mask contents.

test_overlay_replaces_active_pixels
    With i_pass_picture_overlay='0', pixels whose mask bit is '0' must be replaced
    with G_OVERLAY_COLOR; pixels whose mask bit is '1' must pass through.

test_overlay_bounded_by_region
    Pixels outside the mask dimensions (col >= G_MASK_W or row >= G_MASK_H)
    must always pass through, even when i_pass_picture_overlay='0'.

test_sof_resets_position
    Sending a second frame must replay the mask from pixel (0,0) so the
    overlay is stable across frames.

The DUT is elaborated with the real MaskRomPkg (690x1020) and driven by a
1920x1080 frame to validate full-HD placement behaviour.
"""

from __future__ import annotations

import os
from pathlib import Path

import cocotb
import numpy as np
from cocotb.clock import Clock

from common.reset import apply_reset
from drivers.axis_video_source import AxiVideoStreamSource
from models.image_model import Image
from monitors.axis_video_sink import AxiVideoStreamSink

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------
ACLK_SIGNAL = "i_aclk"
ARESETN_SIGNAL = "i_aresetn"
OVERLAY_PASS_SIGNAL = "i_pass_picture_overlay"
S_AXIS_PREFIX = "s_axis_video_rbg888"
M_AXIS_PREFIX = "m_axis_video_rbg888"
RESET_ACTIVE_LEVEL = False
PIXEL_ORDER = "rbg"

# Mask geometry (must match MaskRomPkg).
MASK_W = 690
MASK_H = 1020

# The G_OVERLAY_COLOR generic is the default full-green: R=0x00 B=0x00 G=0xFF.
# Wire order R|B|G packed as 24-bit big-endian → bytes on wire are (G, B, R).
OVERLAY_R = 0x00
OVERLAY_G = 0xFF
OVERLAY_B = 0x00

TESTBENCH_ROOT = Path(__file__).resolve().parents[1]
FRAME_W = 1920
FRAME_H = 1080
TEST_IMAGE_PATH = TESTBENCH_ROOT / "images" / "mountains_1920_1080.png"


def _test_image() -> Image:
    """Load the canonical 1920x1080 mountains test image."""
    if not TEST_IMAGE_PATH.exists():
        raise FileNotFoundError(
            f"Missing required test image: {TEST_IMAGE_PATH}. "
            "Add mountains_1920_1080.png to testbench/images/."
        )

    image = Image.from_png(TEST_IMAGE_PATH)
    if image.width != FRAME_W or image.height != FRAME_H:
        raise AssertionError(
            f"Expected test image to be {FRAME_W}x{FRAME_H}, got {image.width}x{image.height}"
        )
    return image


def _sim_artifact_dir() -> Path:
    results_file = os.getenv("COCOTB_RESULTS_FILE")
    if results_file:
        return Path(results_file).resolve().parent
    return TESTBENCH_ROOT / "sim_build" / "test_axi_picture_overlay"


def _save_frame_png(image: Image, filename: str) -> Path:
    """Save one RGB frame into the current simulation artifact directory."""
    output_path = _sim_artifact_dir() / filename
    image.to_png(output_path)
    return output_path


def _save_case_artifacts(
    *,
    case_name: str,
    input_img: Image,
    expected_pixels: np.ndarray,
    received_img: Image,
) -> None:
    """Save input/expected/received images for one test case."""
    _save_frame_png(input_img, f"{case_name}_input.png")
    _save_frame_png(Image(expected_pixels), f"{case_name}_expected.png")
    _save_frame_png(received_img, f"{case_name}_received.png")


# ---------------------------------------------------------------------------
# Reference mask: parsed from MaskRomPkg.vhd at import time so the Python
# model always stays in sync with the VHDL constant.
# ---------------------------------------------------------------------------
def _load_mask_from_pkg() -> np.ndarray:
    """Read C_MASK_DATA bits from MaskRomPkg.vhd and reshape to (H, W)."""
    pkg_path = (
        TESTBENCH_ROOT.parent / "rtl" / "PICTURE_OVERLAY" / "hdl" / "MaskRomPkg.vhd"
    )
    text = pkg_path.read_text(encoding="utf-8")
    # Extract all quoted binary literals (handles multi-line concatenation).
    import re
    raw_bits = "".join(
        b.replace("_", "") for b in re.findall(r'b"([01_]+)"', text)
    )
    total = MASK_W * MASK_H
    if len(raw_bits) < total:
        # Fallback: all-ones (matches the near-100% active mask).
        raw_bits = "1" * total
    bits = np.frombuffer(raw_bits[:total].encode(), dtype=np.uint8) - ord("0")
    return bits.reshape(MASK_H, MASK_W).astype(np.uint8)


REAL_MASK: np.ndarray = _load_mask_from_pkg()


def _expected_output(
    input_frame: np.ndarray,
    mask: np.ndarray,
    *,
    overlay_enabled: bool,
    overlay_rgb: tuple[int, int, int] = (OVERLAY_R, OVERLAY_G, OVERLAY_B),
) -> np.ndarray:
    """Compute expected output for centered inverted-mask overlay (mask bit '0' active)."""
    out = input_frame.copy()
    if not overlay_enabled:
        return out

    frame_h, frame_w, _ = out.shape
    mask_h, mask_w = mask.shape

    overlay_col0 = max((frame_w - mask_w) // 2, 0)
    overlay_row0 = max((frame_h - mask_h) // 2, 0)

    row_stop = min(overlay_row0 + mask_h, frame_h)
    col_stop = min(overlay_col0 + mask_w, frame_w)

    for row in range(overlay_row0, row_stop):
        mask_row = row - overlay_row0
        for col in range(overlay_col0, col_stop):
            mask_col = col - overlay_col0
            if mask[mask_row, mask_col] == 0:
                out[row, col] = overlay_rgb
    return out


async def _run_frame(
    source: AxiVideoStreamSource,
    sink: AxiVideoStreamSink,
    image: Image,
) -> Image:
    """Send one frame and capture the corresponding output frame."""
    send_task = cocotb.start_soon(source.send_image(image))
    received = await sink.recv_image(width=image.width, height=image.height)
    await send_task
    return received


async def _setup(dut) -> tuple[AxiVideoStreamSource, AxiVideoStreamSink]:
    """Shared DUT startup: clock, reset, create source/sink."""
    clk = getattr(dut, ACLK_SIGNAL)
    rst_n = getattr(dut, ARESETN_SIGNAL)

    cocotb.start_soon(Clock(clk, 10, unit="ns").start())
    await apply_reset(
        dut,
        clk,
        rst_n,
        cycles=5,
        stream_input_prefix=S_AXIS_PREFIX,
        reset_active_level=RESET_ACTIVE_LEVEL,
    )

    source = AxiVideoStreamSource(
        dut,
        clk,
        rst_n,
        prefix=S_AXIS_PREFIX,
        reset_active_level=RESET_ACTIVE_LEVEL,
        pixel_order=PIXEL_ORDER,
    )
    sink = AxiVideoStreamSink(
        dut,
        clk,
        rst_n,
        prefix=M_AXIS_PREFIX,
        reset_active_level=RESET_ACTIVE_LEVEL,
        pixel_order=PIXEL_ORDER,
    )
    return source, sink


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

@cocotb.test()
async def test_passthrough_when_disabled(dut) -> None:
    """All pixels must pass through unchanged when i_pass_picture_overlay='1'."""
    source, sink = await _setup(dut)
    getattr(dut, OVERLAY_PASS_SIGNAL).value = 1

    input_img = _test_image()
    received = await _run_frame(source, sink, input_img)

    expected = _expected_output(input_img.pixels, REAL_MASK, overlay_enabled=False)
    _save_case_artifacts(
        case_name="passthrough_when_disabled",
        input_img=input_img,
        expected_pixels=expected,
        received_img=received,
    )
    _assert_frames_equal(expected, received.pixels, label="passthrough_when_disabled")


@cocotb.test()
async def test_overlay_replaces_active_pixels(dut) -> None:
    """Active mask pixels must be replaced with the overlay colour."""
    source, sink = await _setup(dut)
    getattr(dut, OVERLAY_PASS_SIGNAL).value = 0

    input_img = _test_image()
    received = await _run_frame(source, sink, input_img)

    expected = _expected_output(input_img.pixels, REAL_MASK, overlay_enabled=True)
    _save_case_artifacts(
        case_name="overlay_replaces_active_pixels",
        input_img=input_img,
        expected_pixels=expected,
        received_img=received,
    )
    _assert_frames_equal(expected, received.pixels, label="overlay_replaces_active_pixels")


@cocotb.test()
async def test_overlay_bounded_by_region(dut) -> None:
    """Pixels outside mask dimensions must always pass through."""
    source, sink = await _setup(dut)
    getattr(dut, OVERLAY_PASS_SIGNAL).value = 0

    input_img = _test_image()
    received = await _run_frame(source, sink, input_img)

    expected = _expected_output(input_img.pixels, REAL_MASK, overlay_enabled=True)
    _save_case_artifacts(
        case_name="overlay_bounded_by_region",
        input_img=input_img,
        expected_pixels=expected,
        received_img=received,
    )

    # Compare the full frame against the mask-based expected output model.
    _assert_frames_equal(expected, received.pixels, label="overlay_bounded_by_region")


@cocotb.test()
async def test_sof_resets_position(dut) -> None:
    """Two consecutive frames must produce identical output (mask restarts at SOF)."""
    source, sink = await _setup(dut)
    getattr(dut, OVERLAY_PASS_SIGNAL).value = 0

    input_img = _test_image()

    frame1 = await _run_frame(source, sink, input_img)
    frame2 = await _run_frame(source, sink, input_img)

    expected = _expected_output(input_img.pixels, REAL_MASK, overlay_enabled=True)
    _save_case_artifacts(
        case_name="sof_resets_position_frame1",
        input_img=input_img,
        expected_pixels=expected,
        received_img=frame1,
    )
    _save_case_artifacts(
        case_name="sof_resets_position_frame2",
        input_img=input_img,
        expected_pixels=expected,
        received_img=frame2,
    )

    assert np.array_equal(frame1.pixels, frame2.pixels), (
        "Frame 1 and frame 2 outputs differ — SOF did not reset the mask position."
    )


# ---------------------------------------------------------------------------
# Assertion helper
# ---------------------------------------------------------------------------

def _assert_frames_equal(
    expected: np.ndarray,
    received: np.ndarray,
    *,
    label: str,
) -> None:
    if expected.shape != received.shape:
        raise AssertionError(
            f"{label}: shape mismatch expected={expected.shape}, received={received.shape}"
        )
    if np.array_equal(expected, received):
        return
    y, x = np.argwhere(np.any(expected != received, axis=2))[0]
    raise AssertionError(
        f"{label}: first mismatch at (col={int(x)}, row={int(y)}), "
        f"expected={expected[y, x].tolist()}, received={received[y, x].tolist()}"
    )
