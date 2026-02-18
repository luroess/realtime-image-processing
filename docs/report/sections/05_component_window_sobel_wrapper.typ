#import "../shared/macros.typ": *

= Component Deep Dive: Window Generator, Sobel, and Wrapper

#component_owner("Lukas Roess, Justin Loeber")

This stage converts a scalar pixel stream into local neighborhoods and computes gradient-based edges through Sobel kernels before optional thresholding/selection in wrapper logic.

== Window Generator Function

For `K = 3`, each output beat represents a local matrix around the current center pixel:

$ W(x, y) = mat(
  p(x-1, y-1), p(x, y-1), p(x+1, y-1);
  p(x-1, y), p(x, y), p(x+1, y);
  p(x-1, y+1), p(x, y+1), p(x+1, y+1)
) $

Window validity is emitted only after warm-up and border-policy conditions are met. Current tests include no-pressure and backpressure scenarios plus stress patterns.

== Sobel Core Equations

$ G_x = ((p_02 + 2 p_12 + p_22) - (p_00 + 2 p_10 + p_20)) $

$ G_y = ((p_20 + 2 p_21 + p_22) - (p_00 + 2 p_01 + p_02)) $

$ M = abs(G_x) + abs(G_y) $

The wrapper applies threshold selection and stream-level control while preserving AXI framing.

== Pipeline Micro-Flow (Doc-scanner style adaptation)

#mono_block([
for each accepted input pixel:
  update line buffers and horizontal taps
  if warm-up complete:
    emit 3x3 window
    compute Sobel gradients (Gx, Gy)
    derive edge magnitude M
    compare against threshold
    drive wrapper output beat
])

== Empirical Evidence

#figure(
  grid(
    columns: (1fr, 1fr),
    gutter: 8pt,
    image("../figures/artifacts/lenna_512_512_out_sobel.png", width: 100%),
    image("../figures/artifacts/lenna_512_512_out_wrapper_sobel.png", width: 100%),
  ),
  caption: [Left: Sobel core output artifact. Right: wrapper-level Sobel output artifact.],
) <fig-sobel-wrapper-output>

== Current Engineering Risks in this Block

- Window-generator frame boundary behavior must stay strictly aligned with emitted `SOF/EOL`.
- Warm-up latency and delayed sidebands require careful reset/restart discipline.
- Wrapper generic combinations should be validated beyond the default 3x3/8-bit operating point.
