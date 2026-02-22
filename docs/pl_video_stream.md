# PL AXI4-Stream Video Summary (UG934-aligned)

This repository uses AXI4-Stream video semantics for active pixels only. The summary below is the team-local checklist for RTL, testbench, and report work.

## Mandatory protocol points

- `TUSER[0]` marks `SOF` (start of frame).
- `TLAST` marks `EOL` (end of line).
- A transfer occurs only on `TVALID && TREADY`.
- While stalled (`TVALID=1` and `TREADY=0`), payload and sidebands must stay stable.
- Only active video pixels are transported; blanking/sync periods are not encoded in payload.

## Project-specific stream conventions

- RGB24 wire order in this repository: `TDATA[23:0] = R|B|G`.
- Python scoreboards compare decoded tuples as `(R, G, B)`.
- Control changes that alter visible output mode should be latched at frame boundaries (SOF) to avoid intra-frame mode tearing.

## Validation checklist for interface edits

- Verify SOF/EOL alignment across module boundaries.
- Verify no `TVALID <-> TREADY` combinational loops are introduced.
- Verify no beat loss/duplication at reset release and under downstream backpressure.
- Verify frame-boundary mode latching in both RTL assertions and cocotb tests.

## Primary references

- AMD UG934: AXI4-Stream Video IP and System Design Guide
  - https://docs.amd.com/r/en-US/ug934_axi_videoIP
- AMD PG232: MIPI CSI-2 Receiver Subsystem
  - https://docs.amd.com/r/en-US/pg232-mipi-csi2-rx
