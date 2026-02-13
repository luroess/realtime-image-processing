"""AXI4-Stream lowpass-filter cocotb tests."""

from __future__ import annotations

import os
from pathlib import Path

import cocotb
import numpy as np
from cocotb.clock import Clock
from cocotb.triggers import with_timeout
from common.reset import apply_reset
from drivers.axis_lowpass_filter_driver import AxisLowpassFilterDriver
from monitors.axis_lowpass_monitor import AxisLowpassMonitor
from PIL import Image as PILImage
from verification.lowpass_scoreboard import LowpassScoreboard

CLK_SIGNAL = "clk"
RST_N_SIGNAL = "rst_n"
S_AXIS_PREFIX = "s_axis_lowpass"
TESTBENCH_ROOT = Path(__file__).resolve().parents[1]

RESET_ACTIVE_LEVEL = False



def _sim_artifact_dir() -> Path:
    results_file = os.getenv("COCOTB_RESULTS_FILE")
    if results_file:
        return Path(results_file).resolve().parent
    return TESTBENCH_ROOT / "sim_build" / "test_lowpass_filter"


def _expected_lowpass(gray_pixels: np.ndarray) -> np.ndarray:
    height, width = gray_pixels.shape
    out_height = height - 2
    out_width = width - 2
    expected = np.zeros((out_height, out_width), dtype=np.uint8)

    for y in range(out_height):
        for x in range(out_width):
            window = gray_pixels[y : y + 3, x : x + 3]
            expected[y, x] = int(np.sum(window, dtype=np.uint16) // 9)

    return expected


@cocotb.test(timeout_time=40, timeout_unit="ms")
async def test_lowpass_filter_from_folder_image(dut) -> None:
    """Load image from folder, grayscale + windowize via driver, then verify output."""
    i_clk = getattr(dut, CLK_SIGNAL)
    i_rst_n = getattr(dut, RST_N_SIGNAL)

    cocotb.start_soon(Clock(i_clk, 10, unit="ns").start())

    await apply_reset(
        dut=dut,
        i_clk=i_clk,
        i_rst_n=i_rst_n,
        stream_input_prefix=S_AXIS_PREFIX,
        reset_active_level=RESET_ACTIVE_LEVEL,
    )

    driver = AxisLowpassFilterDriver(
        dut=dut,
        i_clk=i_clk,
        i_rst_n=i_rst_n,
        prefix=S_AXIS_PREFIX,
        reset_active_level=int(RESET_ACTIVE_LEVEL),
    )
    monitor = AxisLowpassMonitor(
        dut=dut,
        i_clk=i_clk,
        i_rst_n=i_rst_n,
        prefix="m_axis_lowpass",
        reset_active_level=int(RESET_ACTIVE_LEVEL),
    )

    artifact_dir = _sim_artifact_dir() / "assets"
    artifact_dir.mkdir(parents=True, exist_ok=True)
    input_path = TESTBENCH_ROOT / "images" / "lenna_512_512.png"

    gray_pixels = driver.load_grayscale_image(input_path)
    expected = _expected_lowpass(gray_pixels)

    out_height, out_width = expected.shape
    expected_output_beats = int(out_height * out_width)
    send_timeout_ns = max(2_000_000, expected_output_beats * 20)
    recv_timeout_ns = max(2_000_000, expected_output_beats * 20)

    recv_task = cocotb.start_soon(
        monitor.recv_image(
            width=int(expected.shape[1]),
            height=int(expected.shape[0]),
            timeout_ns=recv_timeout_ns,
            check_sidebands=True,
        ),
    )

    await with_timeout(
        driver.send_image_file(input_path),
        send_timeout_ns,
        "ns",
    )
    received = await with_timeout(recv_task, recv_timeout_ns, "ns")

    expected_path = artifact_dir / "lowpass_expected.png"
    received_path = artifact_dir / "lowpass_received.png"
    input_copy_path = artifact_dir / "lowpass_input.png"
    PILImage.open(input_path).save(input_copy_path)
    PILImage.fromarray(expected, mode="L").save(expected_path)
    PILImage.fromarray(received, mode="L").save(received_path)

    LowpassScoreboard.compare(expected=expected, received=received)
