"""AXI4-Stream Sobel filter cocotb tests (fixed-threshold model)."""

from __future__ import annotations

import os
from pathlib import Path
from typing import Any

import cocotb
import numpy as np
from cocotb.clock import Clock
from cocotb.triggers import FallingEdge, ReadOnly, RisingEdge

from common.pause import repeating_pause
from common.reset import apply_reset
from drivers.axis_window_gray_source import AxiWindowGraySource
from models.image_model import Image
from monitors.axis_gray_sink import AxiGrayStreamSink

ACLK_SIGNAL = "i_aclk"
ARESETN_SIGNAL = "i_aresetn"
S_AXIS_PREFIX = "s_axis_window"
M_AXIS_PREFIX = "m_axis_filter8"
RESET_ACTIVE_LEVEL = False
SOBEL_THRESHOLD = 200
PIXEL_WIDTH = 8
TESTBENCH_ROOT = Path(__file__).resolve().parents[1]


def _sim_artifact_dir() -> Path:
    results_file = os.getenv("COCOTB_RESULTS_FILE")
    if results_file:
        return Path(results_file).resolve().parent
    return TESTBENCH_ROOT / "sim_build" / "test_axi_sobel_filter"


def _gray_from_rgb(image: Image) -> np.ndarray:
    pixels_u16 = image.pixels.astype(np.uint16)
    r = pixels_u16[:, :, 0]
    g = pixels_u16[:, :, 1]
    b = pixels_u16[:, :, 2]
    return ((r >> 2) + (g >> 1) + (b >> 2)).astype(np.uint8)


def _dut_generic_int(dut: Any, generic_name: str, default: int) -> int:
    handle = getattr(dut, generic_name, None)
    if handle is None:
        return int(default)
    try:
        return int(handle.value)
    except Exception:
        return int(default)


def _resolve_threshold(dut: Any) -> int:
    threshold = _dut_generic_int(dut, "G_SOBEL_THRESHOLD", SOBEL_THRESHOLD)
    pixel_width = _dut_generic_int(dut, "G_PIXEL_WIDTH", PIXEL_WIDTH)
    threshold_max = 8 * ((2**pixel_width) - 1)
    return max(0, min(int(threshold), int(threshold_max)))


def _sobel_expected(gray_plane: np.ndarray, *, threshold: int) -> np.ndarray:
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
            mag = abs(gx) + abs(gy)

            out[y, x] = 255 if mag >= threshold else 0

    return out


def _assert_plane_equal(expected: np.ndarray, received: np.ndarray) -> None:
    if expected.shape != received.shape:
        raise AssertionError(
            f"Shape mismatch: expected={expected.shape}, received={received.shape}",
        )
    if np.array_equal(expected, received):
        return

    y, x = np.argwhere(expected != received)[0]
    raise AssertionError(
        f"First mismatch at (x={int(x)}, y={int(y)}): "
        f"expected={int(expected[y, x])}, received={int(received[y, x])}",
    )


async def _monitor_output_stall_stability(
    *,
    dut: Any,
    i_clk: Any,
    i_rst_n: Any,
    m_axis_tready: Any,
    stop: dict[str, bool],
    stats: dict[str, int | bool],
) -> None:
    m_axis_tvalid = getattr(dut, f"{M_AXIS_PREFIX}_tvalid")
    m_axis_tdata = getattr(dut, f"{M_AXIS_PREFIX}_tdata")
    m_axis_tuser = getattr(dut, f"{M_AXIS_PREFIX}_tuser")
    m_axis_tlast = getattr(dut, f"{M_AXIS_PREFIX}_tlast")

    ready_low_run = 0
    prev_stall_payload: tuple[int, int, int] | None = None

    while not stop["done"]:
        await FallingEdge(i_clk)
        await ReadOnly()

        if int(i_rst_n.value) == int(RESET_ACTIVE_LEVEL):
            ready_low_run = 0
            prev_stall_payload = None
            await RisingEdge(i_clk)
            continue

        valid = int(m_axis_tvalid.value)
        ready = int(m_axis_tready.value)

        if ready == 0:
            ready_low_run += 1
            stats["max_ready_low_run"] = max(
                int(stats["max_ready_low_run"]),
                ready_low_run,
            )
        else:
            ready_low_run = 0

        if valid == 1 and ready == 0:
            stats["saw_stall"] = True
            payload = (
                int(m_axis_tdata.value),
                int(m_axis_tuser.value),
                int(m_axis_tlast.value),
            )
            if prev_stall_payload is not None:
                assert payload == prev_stall_payload, (
                    "Output payload changed while stalled (VALID=1, READY=0). "
                    f"prev={prev_stall_payload}, now={payload}"
                )
            prev_stall_payload = payload
        else:
            prev_stall_payload = None

        await RisingEdge(i_clk)


async def run_sobel_case(
    dut: Any,
    gray_plane: np.ndarray,
    *,
    output_path: Path | None = None,
    with_backpressure: bool = False,
) -> None:
    i_clk = getattr(dut, ACLK_SIGNAL)
    i_rst_n = getattr(dut, ARESETN_SIGNAL)
    m_axis_tready = getattr(dut, f"{M_AXIS_PREFIX}_tready")

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

    source = AxiWindowGraySource(
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
    m_axis_tready.value = 1

    monitor_task = None
    monitor_stop = {"done": False}
    monitor_stats: dict[str, int | bool] = {"saw_stall": False, "max_ready_low_run": 0}

    if with_backpressure:
        sink.set_pause_generator(repeating_pause((0, 1, 0, 0, 1, 0, 1)))
        monitor_task = cocotb.start_soon(
            _monitor_output_stall_stability(
                dut=dut,
                i_clk=i_clk,
                i_rst_n=i_rst_n,
                m_axis_tready=m_axis_tready,
                stop=monitor_stop,
                stats=monitor_stats,
            ),
        )

    try:
        expected = _sobel_expected(gray_plane, threshold=_resolve_threshold(dut))
        await source.send_gray_image(gray_plane)

        height, width = gray_plane.shape
        timeout_ns = max(200_000, width * height * 60)
        received = await sink.recv_plane(width=width, height=height, timeout_ns=timeout_ns)
        _assert_plane_equal(expected, received)

        if output_path is not None:
            rgb = np.stack((received, received, received), axis=2)
            Image(rgb).to_png(output_path)
    finally:
        if monitor_task is not None:
            monitor_stop["done"] = True
            await RisingEdge(i_clk)
            monitor_task.cancel()

    if with_backpressure:
        assert bool(monitor_stats["saw_stall"]), (
            "Expected at least one VALID=1, READY=0 stall cycle."
        )
        assert int(monitor_stats["max_ready_low_run"]) >= 1, (
            "Backpressure READY-low run too short: "
            f"observed={int(monitor_stats['max_ready_low_run'])}"
        )


@cocotb.test()
async def test_axi_sobel_filter_gradient_gray_windows(dut: Any) -> None:
    image = Image.gradient_gray(width=5, height=5)
    gray = image.pixels[:, :, 0]
    await run_sobel_case(dut, gray)


@cocotb.test(timeout_time=120, timeout_unit="ms")
async def test_axi_sobel_filter_lenna_end_to_end(dut: Any) -> None:
    input_path = TESTBENCH_ROOT / "images" / "lenna_512_512.png"
    output_path = _sim_artifact_dir() / "lenna_512_512_out_sobel.png"

    image = Image.from_png(input_path)
    gray = _gray_from_rgb(image)
    await run_sobel_case(dut, gray, output_path=output_path)


@cocotb.test(timeout_time=120, timeout_unit="ms")
async def test_axi_sobel_filter_gradient_with_backpressure(dut: Any) -> None:
    image = Image.gradient_gray(width=64, height=64)
    gray = image.pixels[:, :, 0]
    await run_sobel_case(dut, gray, with_backpressure=True)
