#import "../shared/macros.typ": *

= System and Protocol Architecture

#component_owner("Team-wide integration")

The repository follows UG934-compatible AXI4-Stream video semantics with strict sideband interpretation.@amd_ug934

- `TUSER[0]` denotes Start of Frame (`SOF`).
- `TLAST` denotes End of Line (`EOL`).
- Only active pixels are transmitted on AXI4-Stream video.

$ "transfer"_k = "tvalid"_k and "tready"_k $ <eq-transfer-condition>

The stream contract in @eq-transfer-condition is the basis for all cocotb monitors and scoreboard synchronization.

#figure(
  image("../figures/AXI_Bayer2RGB_Gamma_Corr2Gray.png", width: 95%),
  caption: [Vivado context around Bayer-to-RGB, gamma correction, and custom grayscale insertion point.],
) <fig-vivado-context>

== Timing Domains and Framing Responsibility

The effective architectural split is:

- PS-controlled AXI4-Lite configuration for camera, DMA, timing, and custom IP setup.
- AXI4-Stream compute chain in PL for per-pixel transforms and local neighborhood operations.
- Frame buffering through VDMA/DDR between ingress and display timing domains.

Custom stream modules inside this repository must preserve framing semantics across reset, startup, and backpressure. In practical terms this means that payload, `SOF`, and `EOL` all remain beat-aligned whenever `TVALID=1`, including stalled cycles.

== Framing Recovery Strategy

For modules with internal history (line buffers, sliding windows), frame boundaries require explicit re-initialization logic. The project uses `SOF` as the event that re-establishes deterministic per-frame state and avoids cross-frame leakage.

#mono_block([
AXI4-Stream rule set enforced in this report:
1) accepted transfer iff TVALID && TREADY
2) SOF on first accepted beat of frame
3) EOL on last accepted beat of each line
4) payload/sidebands stable while stalled
])
