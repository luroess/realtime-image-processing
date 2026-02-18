# EDGE_OVERLAY v1

`AxiEdgeOverlay` merges two AXI4-Stream video inputs in lockstep:

- RGB input from [`AXI_RgbToGrayscale`](../RGB_TO_GRAYSCALE/hdl/axi_rgb_to_grayscale.vhd) via `s_axis_video_rbg888_*`
- edge input from the Sobel/filter path via `s_axis_rbg888_*`

It outputs one RGB AXI4-Stream (`m_axis_video_rbg888_*`) for VDMA writeback.

## Functional behavior

- Edge payload interpretation: `s_axis_rbg888_tdata` (binary) equals `1` means edge pixel.
- Composition mode: hard replace.
- If `i_overlay_enable='1'` and edge is detected, output `G_EDGE_COLOR`.
- Otherwise, pass input RGB pixel unchanged.

## RTL blocks

- [`edge_overlay.vhd`](hdl/edge_overlay.vhd):
  - combinational core (`EdgeOverlay`)
  - generic `G_EDGE_COLOR` (default red)
- [`axi_edge_overlay.vhd`](hdl/axi_edge_overlay.vhd):
  - AXI4-Stream wrapper (`AxiEdgeOverlay`)
  - dual-input lockstep handshake
  - SOF/EOL forwarding from RGB stream
  - simulation-only assertions for sideband alignment

## AXI4-Stream contract

For active reset low `i_aresetn='0'`, all `tvalid/tready` outputs deassert and output payload/sidebands are zeroed.

Normal operation:

- `m_axis_video_rbg888_tvalid = s_axis_video_rbg888_tvalid and s_axis_rbg888_tvalid`
- `s_axis_video_rbg888_tready = m_axis_video_rbg888_tready and s_axis_rbg888_tvalid`
- `s_axis_rbg888_tready  = m_axis_video_rbg888_tready and s_axis_video_rbg888_tvalid`

Framing:

- `TUSER[0]` is SOF, `TLAST` is EOL.
- RGB and edge inputs are required to be framing-aligned beat-by-beat.
- Wrapper assertions fail simulation if SOF/EOL mismatch while both streams are valid.

## Assumptions

- Both upstream producers provide active-pixel-only AXI4-Stream video.
- Pixel packing for RGB path follows project convention `R|B|G` on `TDATA[23:0]`.
- This block is standalone in RTL/testbench scope; Vivado IP packaging and BD rewiring are handled separately.
