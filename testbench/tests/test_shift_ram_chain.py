"""Compact ShiftRamChain checks focused on delay taps and control behavior."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import (
    NextTimeStep,
    ReadOnly,
    RisingEdge,
    SimTimeoutError,
    with_timeout,
)

C_SEL_NONE = 0b00
C_SEL_SOBEL = 0b01
C_SEL_BLUR_SOBEL = 0b10
C_SEL_RESERVED = 0b11

C_BLOCK_DELAY = 1024
C_SOBEL_DELAY_CFG = 3
C_BLUR_SOBEL_DELAY_CFG = 5
C_WORD_MASK = (1 << 26) - 1


def _ceil_div(i_numerator: int, i_denominator: int) -> int:
    return (i_numerator + i_denominator - 1) // i_denominator


def _effective_sobel_delay(i_sobel_delay: int) -> int:
    sobel_chunks = _ceil_div(i_sobel_delay, C_BLOCK_DELAY)
    return i_sobel_delay + (sobel_chunks - 1)


def _effective_blur_sobel_delay(i_sobel_delay: int, i_blur_sobel_delay: int) -> int:
    sobel_chunks = _ceil_div(i_sobel_delay, C_BLOCK_DELAY)
    extra_delay = i_blur_sobel_delay - i_sobel_delay
    extra_chunks = _ceil_div(extra_delay, C_BLOCK_DELAY) if extra_delay > 0 else 0
    total_chunks = sobel_chunks + extra_chunks
    return i_blur_sobel_delay + (total_chunks - 1)


C_SOBEL_DELAY_EFFECTIVE = _effective_sobel_delay(C_SOBEL_DELAY_CFG)
C_BLUR_SOBEL_DELAY_EFFECTIVE = _effective_blur_sobel_delay(
    C_SOBEL_DELAY_CFG,
    C_BLUR_SOBEL_DELAY_CFG,
)


@dataclass(frozen=True)
class StimulusStep:
    ce: int
    sclr: int
    sel: int
    din: int
    label: str


class DelayTapModel:
    """Beat-domain delay model for one selected output tap."""

    def __init__(self, i_delay: int) -> None:
        self._delay = i_delay
        self._fifo = [0] * i_delay
        self._out = 0

    @property
    def out(self) -> int:
        return self._out

    def step(self, *, ce: bool, sclr: bool, din: int) -> int:
        if sclr:
            self._fifo = [0] * self._delay
            self._out = 0
            return self._out

        if ce:
            v_din = din & C_WORD_MASK
            if self._delay == 0:
                self._out = v_din
            else:
                self._fifo.append(v_din)
                self._out = self._fifo.pop(0)
        return self._out


def _word(i_seed: int) -> int:
    sof = (i_seed & 0x1) << 25
    eol = ((i_seed >> 1) & 0x1) << 24
    rgb = ((i_seed * 0x1F03) + 0x55AA) & 0x00FF_FFFF
    return (sof | eol | rgb) & C_WORD_MASK


def _selected_expected(*, sel: int, din: int, sobel_out: int, blur_out: int) -> int:
    if sel == C_SEL_NONE:
        return din & C_WORD_MASK
    if sel == C_SEL_SOBEL or sel == C_SEL_RESERVED:
        return sobel_out
    if sel == C_SEL_BLUR_SOBEL:
        return blur_out
    return din & C_WORD_MASK


async def _step_and_sample(dut: Any, step: StimulusStep) -> int:
    dut.i_ce.value = step.ce
    dut.i_sclr.value = step.sclr
    dut.i_base_delay_stage_sel.value = step.sel
    dut.i_din.value = step.din & C_WORD_MASK

    await RisingEdge(dut.i_clk)
    await ReadOnly()
    await NextTimeStep()
    return int(dut.o_dout.value) & C_WORD_MASK


async def _run_sequence_with_model(dut: Any, steps: list[StimulusStep]) -> dict[str, int]:
    sobel_model = DelayTapModel(C_SOBEL_DELAY_EFFECTIVE)
    blur_model = DelayTapModel(C_BLUR_SOBEL_DELAY_EFFECTIVE)
    observed_by_label: dict[str, int] = {}

    for idx, step in enumerate(steps):
        sobel_out = sobel_model.step(ce=bool(step.ce), sclr=bool(step.sclr), din=step.din)
        blur_out = blur_model.step(ce=bool(step.ce), sclr=bool(step.sclr), din=step.din)
        expected = _selected_expected(
            sel=step.sel,
            din=step.din,
            sobel_out=sobel_out,
            blur_out=blur_out,
        )
        observed = await _step_and_sample(dut, step)
        observed_by_label[step.label] = observed

        assert observed == expected, (
            f"[{idx:02d}] {step.label}: observed=0x{observed:07X}, "
            f"expected=0x{expected:07X}, ce={step.ce}, sclr={step.sclr}, "
            f"sel={step.sel:02b}, din=0x{(step.din & C_WORD_MASK):07X}"
        )

    return observed_by_label


def _expected_stream_outputs(i_inputs: list[int], i_delay: int) -> list[int]:
    return [
        (i_inputs[idx - i_delay] & C_WORD_MASK) if idx >= i_delay else 0
        for idx in range(len(i_inputs))
    ]


async def _initialize_and_run_minimal_functional_scenario(dut: Any) -> None:
    steps: list[StimulusStep] = [
        StimulusStep(ce=0, sclr=1, sel=C_SEL_NONE, din=0, label="reset_0"),
        StimulusStep(ce=0, sclr=1, sel=C_SEL_NONE, din=0, label="reset_1"),
        StimulusStep(ce=0, sclr=0, sel=C_SEL_NONE, din=_word(1), label="bypass_ce0"),
        StimulusStep(ce=1, sclr=0, sel=C_SEL_NONE, din=_word(2), label="bypass_ce1"),
        StimulusStep(ce=0, sclr=1, sel=C_SEL_SOBEL, din=0, label="clear_delayed_0"),
        StimulusStep(ce=0, sclr=0, sel=C_SEL_SOBEL, din=0, label="clear_delayed_1"),
    ]

    sobel_fill_inputs = [_word(10 + i) for i in range(7)]
    for i, word in enumerate(sobel_fill_inputs):
        steps.append(
            StimulusStep(
                ce=1,
                sclr=0,
                sel=C_SEL_SOBEL,
                din=word,
                label=f"sobel_fill_{i}",
            ),
        )

    steps.extend(
        [
            StimulusStep(ce=0, sclr=0, sel=C_SEL_SOBEL, din=_word(40), label="sobel_ce_stall_0"),
            StimulusStep(ce=0, sclr=0, sel=C_SEL_SOBEL, din=_word(41), label="sobel_ce_stall_1"),
            StimulusStep(ce=1, sclr=0, sel=C_SEL_SOBEL, din=_word(17), label="sobel_resume_0"),
            StimulusStep(ce=1, sclr=0, sel=C_SEL_SOBEL, din=_word(18), label="sobel_resume_1"),
        ],
    )

    for i in range(3):
        steps.append(
            StimulusStep(
                ce=1,
                sclr=0,
                sel=C_SEL_BLUR_SOBEL,
                din=_word(30 + i),
                label=f"blur_stream_{i}",
            ),
        )

    steps.extend(
        [
            StimulusStep(ce=0, sclr=0, sel=C_SEL_RESERVED, din=_word(90), label="reserved_alias"),
            StimulusStep(ce=0, sclr=0, sel=C_SEL_SOBEL, din=_word(90), label="reserved_reference"),
            StimulusStep(ce=0, sclr=1, sel=C_SEL_BLUR_SOBEL, din=0, label="flush_0"),
            StimulusStep(ce=0, sclr=0, sel=C_SEL_BLUR_SOBEL, din=0, label="flush_1"),
        ],
    )

    blur_refill_inputs = [_word(60 + i) for i in range(C_BLUR_SOBEL_DELAY_EFFECTIVE + 2)]
    for i, word in enumerate(blur_refill_inputs):
        steps.append(
            StimulusStep(
                ce=1,
                sclr=0,
                sel=C_SEL_BLUR_SOBEL,
                din=word,
                label=f"blur_refill_{i}",
            ),
        )

    observed = await _run_sequence_with_model(dut, steps)

    assert observed["bypass_ce0"] == (_word(1) & C_WORD_MASK)
    assert observed["bypass_ce1"] == (_word(2) & C_WORD_MASK)
    assert observed["reserved_alias"] == observed["reserved_reference"]
    assert observed["flush_0"] == 0

    sobel_fill_observed = [observed[f"sobel_fill_{i}"] for i in range(len(sobel_fill_inputs))]
    sobel_fill_expected = _expected_stream_outputs(sobel_fill_inputs, C_SOBEL_DELAY_EFFECTIVE)
    assert sobel_fill_observed == sobel_fill_expected

    assert observed["sobel_ce_stall_0"] == observed["sobel_fill_6"]
    assert observed["sobel_ce_stall_1"] == observed["sobel_fill_6"]
    assert observed["sobel_resume_0"] == (sobel_fill_inputs[4] & C_WORD_MASK)
    assert observed["sobel_resume_1"] == (sobel_fill_inputs[5] & C_WORD_MASK)

    blur_refill_observed = [observed[f"blur_refill_{i}"] for i in range(len(blur_refill_inputs))]
    blur_refill_expected = _expected_stream_outputs(
        blur_refill_inputs,
        C_BLUR_SOBEL_DELAY_EFFECTIVE,
    )
    assert blur_refill_observed == blur_refill_expected


async def _reset_chain_for_delay_measure(dut: Any, sel: int) -> None:
    for idx in range(2):
        await _step_and_sample(
            dut,
            StimulusStep(ce=0, sclr=1, sel=sel, din=0, label=f"measure_reset_{idx}"),
        )
    await _step_and_sample(
        dut,
        StimulusStep(ce=0, sclr=0, sel=sel, din=0, label="measure_post_reset"),
    )


async def _measure_accepted_beats_to_marker(dut: Any, *, sel: int, marker_seed: int) -> int:
    await _reset_chain_for_delay_measure(dut, sel)

    marker = _word(marker_seed)
    await _step_and_sample(
        dut,
        StimulusStep(ce=1, sclr=0, sel=sel, din=marker, label="marker_insert"),
    )

    accepted_beats = 0
    while accepted_beats < 32:
        observed = await _step_and_sample(
            dut,
            StimulusStep(
                ce=1,
                sclr=0,
                sel=sel,
                din=_word(marker_seed + 100 + accepted_beats),
                label=f"marker_wait_{accepted_beats}",
            ),
        )
        accepted_beats += 1
        if observed == marker:
            return accepted_beats

    raise AssertionError(f"Marker 0x{marker:07X} did not reappear within 32 accepted beats.")


@cocotb.test(timeout_time=250, timeout_unit="us")
async def test_shift_ram_chain_minimal_cycle_functional_behaviour(dut: Any) -> None:
    cocotb.start_soon(Clock(dut.i_clk, 10, unit="ns").start())
    try:
        await with_timeout(_initialize_and_run_minimal_functional_scenario(dut), 150, "us")
    except SimTimeoutError as exc:
        raise AssertionError("Timed out while running compact functional ShiftRamChain scenario.") from exc


@cocotb.test(timeout_time=250, timeout_unit="us")
async def test_shift_ram_chain_delay_lengths_match_effective_taps(dut: Any) -> None:
    cocotb.start_soon(Clock(dut.i_clk, 10, unit="ns").start())
    try:
        measured_sobel = await with_timeout(
            _measure_accepted_beats_to_marker(dut, sel=C_SEL_SOBEL, marker_seed=150),
            100,
            "us",
        )
        measured_blur_sobel = await with_timeout(
            _measure_accepted_beats_to_marker(dut, sel=C_SEL_BLUR_SOBEL, marker_seed=190),
            100,
            "us",
        )
    except SimTimeoutError as exc:
        raise AssertionError("Timed out while measuring ShiftRamChain effective delays.") from exc

    assert measured_sobel == C_SOBEL_DELAY_EFFECTIVE, (
        f"Sobel delay mismatch: measured={measured_sobel}, "
        f"expected={C_SOBEL_DELAY_EFFECTIVE}"
    )
    assert measured_blur_sobel == C_BLUR_SOBEL_DELAY_EFFECTIVE, (
        f"Blur+Sobel delay mismatch: measured={measured_blur_sobel}, "
        f"expected={C_BLUR_SOBEL_DELAY_EFFECTIVE}"
    )
