# PL Video Stream (AXI4-Stream Video) Guide

Primary source: `amd-docs/ug934_axi_videoIP.pdf` (UG934: AXI4-Stream Video IP and System Design Guide, November 16, 2022).

This file captures the project-relevant rules from UG934 and how to apply them in this design.

## AXI4-Stream video interface basics

Input side (slave) uses:
- `s_axis_video_tdata`
- `s_axis_video_tvalid`
- `s_axis_video_tready`
- `s_axis_video_tuser` (bit 0 is `SOF`)
- `s_axis_video_tlast` (`EOL`)

Output side (master) uses:
- `m_axis_video_tdata`
- `m_axis_video_tvalid`
- `m_axis_video_tready`
- `m_axis_video_tuser` (bit 0 is `SOF`)
- `m_axis_video_tlast` (`EOL`)

A transfer happens only when the handshake is accepted on a clock edge (`VALID` and `READY` asserted, with clock enable and reset conditions satisfied).

## SOF/EOL semantics (must keep exact)

- `SOF` must mark the first pixel of a frame/field.
- `EOL` must mark the last pixel of each line.
- Both are one accepted transfer wide.
- Downstream logic should use `SOF` to reinitialize frame-local state.

## What AXI4-Stream video carries

- Carries active pixels only.
- Does not carry blanking intervals, sync waveforms, audio, or ancillary packets.
- Do not encode periodic timing (`hsync`, `vsync`) into `TUSER`.
- Do not embed timing metadata or ancillary payloads into pixel data.

Timing and format control must come from dedicated control/timing paths (typically AXI4-Lite + VTC-style timing programming), not from ad-hoc fields in the stream.

## Data packing rules

- Pixels are packed from LSB to MSB in transfer order (earliest/left-most pixel in lower bits).
- Components are packed tightly.
- If payload width is not byte-aligned, pad unused MSBs with zeros.
- If line length is not divisible by pixels-per-beat, pack remaining valid pixels into LSB positions of the last beat and zero-pad unused upper pixel slots.
- Keep the interface layout static for an instantiated core; dynamic pixels-per-beat changes are generally not recommended.

## Reset and startup behavior

- Prefer resetting all connected video interfaces together.
- While in reset, interfaces deassert their `VALID` and `READY` outputs.
- After reset, cores should drop/ignore input samples until the next valid `SOF` boundary is seen.
- For software-sequenced reset across a pipeline, reset from output toward input and release in the same order.

## READY/VALID behavior for custom video IP

- Register READY/VALID paths and account for internal pipeline/FIFO occupancy.
- Keep `READY` asserted greedily unless buffers are full/almost full or internal flushing requires stalling.
- Add skid/extra buffering as needed to avoid pixel loss when downstream `READY` drops.
- Avoid processing bubbles: keep output `VALID` asserted while buffered valid data exists.
- Flush pipelines at line/frame boundaries so end-of-line pixels are not delayed into the next line/frame.

## SOF/EOL propagation in processing blocks

- Simple pipeline blocks without line buffers: delay `SOF`/`EOL` by pipeline latency.
- Complex blocks with line buffers/window generators: regenerate `SOF`/`EOL` from internal counters/state.
- On malformed timing (early/late EOL/SOF), handle deterministically (drop extra data or start next region early) and expose status/error where possible.

## How to use this in this repository

- Current BD stream direction is camera-side AXI stream into processing, then memory/output path:
  `MIPI_CSI_2_RX -> AXI_BayerToRGB -> AXI_GammaCorrection -> AXI VDMA (S2MM) -> AXI VDMA (MM2S) -> v_axi4s_vid_out -> rgb2dvi`.
- Any new grayscale/window/Sobel AXI core inserted in this chain must preserve handshake and framing (`TUSER[0]`/`TLAST`) exactly.
- For grayscale display over HDMI, output RGB with replicated luma (`R=Y, G=Y, B=Y`) when the downstream expects RGB pixel data.
