#import "../shared/macros.typ": *
#import "@preview/algorithmic:1.0.7"
#import algorithmic: algorithm-figure, style-algorithm
#show: style-algorithm

= FAST Implementation and FAST-on-Zynq (Zybo Z7-10)

#component_owner("Implemented RTL path: `rtl/FAST_FILTER/hdl/*`")

This section documents the implemented FAST pipeline in this repository and summarizes how it maps to the Zybo Z7-10 streaming architecture. The active RTL modules are:

- `rtl/FAST_FILTER/hdl/fast_core.vhd`
- `rtl/FAST_FILTER/hdl/fast_nms3x3.vhd`
- `rtl/FAST_FILTER/hdl/axi_fast_filter.vhd`

The implementation uses a FAST-9 style contiguous arc test on a `7x7` window, computes a corner score, and applies `3x3` non-maximum suppression before emitting a binary corner mask on AXI.@rosten_drummond_fast2006 @rosten_porter_drummond_fast2010

== FAST Corner Detector Fundamentals

FAST (Features from Accelerated Segment Test) classifies a pixel center `p` as corner when a contiguous arc on the 16-point circle around `p` is consistently brighter or darker than the center by threshold `t`.@rosten_drummond_fast2006 @rosten_porter_drummond_fast2010

A center pixel is a FAST corner when a contiguous subset `S` on the 16-point circle satisfies the run-length condition:

$ |S| >= N $

and each pixel in that run passes either the bright or dark threshold test:

$ I_q >= I_p + t $

$ I_q <= I_p - t $

Where:

- `C_16` is the 16-point circle (radius 3) around the center pixel.
- `N` is typically 9, 10, or 12 (FAST-9 is common in realtime settings).
- `t` controls corner selectivity and noise sensitivity.

The implementation also uses the classic high-speed precheck (4 ring points) before full run evaluation.@rosten_drummond_fast2006

== Typst Pseudocode: `E_FastCore` (Candidate + Score)

Pseudocode in @alg-fast-core summarizes the combinational FSM behavior in `rtl/FAST_FILTER/hdl/fast_core.vhd`.

#algorithm-figure(
  [FAST core pseudocode aligned with `E_FastCore`],
  vstroke: .5pt + luma(220),
  {
    import algorithmic: *

    Procedure(
      "FastCore7x7",
      ("window7x7", "threshold", "N"),
      {
        Assign[`center`][`pixel(window7x7, 24)`]
        Assign[`T`][`clamp(threshold, 0, 255)`]
        Assign[`high_ref`][`center + T`]
        Assign[`low_ref`][`center - T`]
        Assign[`ring[0..15]`][`window7x7[C_RING_INDEX[i]]`]

        Assign[`bright_pre`][`count(ring[p] > high_ref for p in {0,8,4,12})`]
        Assign[`dark_pre`][`count(ring[p] < low_ref for p in {0,8,4,12})`]

        If(`bright_pre < 3 and dark_pre < 3`, {
          Return[`(is_candidate=0, score=0)`]
        })

        Assign[`best_score`][`0`]
        Assign[`is_candidate`][`0`]

        For(`start_idx in 0..15`, {
          Assign[`bright_run`][`true`]
          Assign[`dark_run`][`true`]
          Assign[`bright_score`][`0`]
          Assign[`dark_score`][`0`]

          For(`off_idx in 0..N-1`, {
            Assign[`idx`][`(start_idx + off_idx) mod 16`]
            Assign[`value`][`ring[idx]`]

            If(`value > high_ref`, {
              Assign[`bright_score`][`bright_score + (value - high_ref)`]
            })
            If(`value <= high_ref`, {
              Assign[`bright_run`][`false`]
            })

            If(`value < low_ref`, {
              Assign[`dark_score`][`dark_score + (low_ref - value)`]
            })
            If(`value >= low_ref`, {
              Assign[`dark_run`][`false`]
            })
          })

          If(`bright_run`, {
            Assign[`is_candidate`][`1`]
            Assign[`best_score`][`max(best_score, bright_score)`]
          })
          If(`dark_run`, {
            Assign[`is_candidate`][`1`]
            Assign[`best_score`][`max(best_score, dark_score)`]
          })
        })

        Assign[`best_score`][`min(best_score, 8191)`]
        Return[`(is_candidate, best_score)`]
      },
    )
  },
) <alg-fast-core>

== Typst Pseudocode: `AXI_FastFilter` (Core + NMS + AXI)

Pseudocode in @alg-axi-fast-filter captures the stream-level composition in `rtl/FAST_FILTER/hdl/axi_fast_filter.vhd`.

#algorithm-figure(
  [AXI FAST filter pipeline pseudocode aligned with `AXI_FastFilter`],
  vstroke: .5pt + luma(220),
  {
    import algorithmic: *

    Procedure(
      "AxiFastFilter",
      ("s_axis_window", "m_axis_filter8"),
      {
        Comment[Per accepted 7x7 input window]
        Line[`(is_candidate, score13) <- FastCore7x7(window, G_FAST_THRESHOLD, G_FAST_N)`]
        Assign[`score_pixel`][`score13 if is_candidate else 0`]

        Comment[Build 3x3 neighborhoods in score domain]
        Line[`score_window3x3 <- WindowGenerator3x3(score_pixel)`]

        Comment[Non-maximum suppression]
        Assign[`corner`][`FastNms3x3(score_window3x3)`]

        Comment[Emit binary corner mask]
        Assign[`out_pixel`][`0xFF if corner else 0x00`]

        Comment[AXI sidebands forwarded with reset-safe gating]
        Line[`TVALID/TREADY/TUSER/TLAST follow score-window output timing`]
      },
    )
  },
) <alg-axi-fast-filter>

== Streaming Hardware Mapping

The current design chain for FAST is:

- Gray window input (`7x7`) from `window_generator`
- FAST candidate/score extraction (`E_FastCore`)
- Score-window generation (`3x3`) for NMS
- NMS corner decision (`E_FastNms3x3`)
- AXI output mask (`0xFF` corner, `0x00` non-corner)

This keeps FAST fully streaming and compatible with the existing AXI framing discipline.

== FAST on Zybo Z7-10 (Zynq-7010) Integration Strategy

The Zybo Z7-10 project already uses PS7 + AXI4-Stream video infrastructure and VDMA buffering. FAST is integrated as an AXI4-Stream block and selected through wrapper-level filter configuration.

#academic_table(
  columns: (1.5fr, 2.2fr),
  align: (left, left),
  table.header([Module role], [FAST-on-Zybo implementation status]),
  [Input format], [Gray stream windows are consumed as `7x7` flattened AXI payloads.],
  [Decision core], [`E_FastCore` implements precheck + contiguous-run FAST test and score saturation.],
  [Post-processing], [`E_FastNms3x3` suppresses non-maxima in local `3x3` score neighborhoods.],
  [System interface], [`AXI_FastFilter` forwards AXI handshakes and framing with reset-safe gating.],
  [Verification], [Targets `axi_fast_filter` and `axi_filter_wrapper_fast` are present in `testbench/targets.toml`.],
)

== Throughput and Latency Expectations

For a single-pixel-per-cycle (`PPC=1`) pipeline, ideal frame-rate bound is:

$ F = f / (W * H) $

where `f` is the processing clock frequency in pixels per second.

At `f_clk = 100 MHz`:

- `512x512`: about `381 FPS` theoretical upper bound.
- `1280x720`: about `108 FPS` theoretical upper bound.

Practical results are lower due to buffering, downstream backpressure, and NMS latency.

== Risk and Validation Plan for FAST Path

- Threshold sensitivity: fixed threshold may underperform across lighting changes; mitigation is runtime-configurable `G_FAST_THRESHOLD` and sweep tests.
- Border behavior: radius-3 circle implies larger invalid margins than Sobel; mitigation is explicit border policy mirrored in cocotb golden model.
- Timing closure risk: 16-point comparison + contiguous run logic can stretch critical paths; mitigation is staged combinational partitioning and scoreboard-backed regressions.
- Integration risk: preserving AXI `SOF/EOL` across 7x7 warm-up and score-domain NMS must be continuously validated under backpressure.

The implemented FAST path now complements the Sobel path in the same wrapper architecture and enables direct algorithm-level comparison on identical streaming infrastructure.
