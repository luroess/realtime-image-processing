# FRAME_COMPOSITOR

`FrameCompositor` is the active merger/compositor implementation.

## Modes

Base image (`i_base_mode`):
- `00`: original RGB
- `01`: grayscale
- `10`: zeros

Overlay (`i_overlay_mode`):
- `00`: none
- `01`: FAST
- `10`: Sobel

## RTL

- `hdl/frame_compositor.vhd`: combinational merge logic (`FrameCompositor`)
- `hdl/axi_frame_compositor.vhd`: AXI4-Stream wrapper (`AXI_FrameCompositor`) with staged input channels
- `ip/`: reserved location for the Vivado Edit-IP project (`edit_AXI_FrameCompositor*.xpr`)

## Notes

- AXI wrapper consumes RGB/gray/sobel/fast inputs in lockstep.
- `EDGE_OVERLAY` is deprecated and kept for legacy compatibility only.
