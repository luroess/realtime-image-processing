# AXI RGB to Grayscale Overview

`AXI_RgbToGrayscale` is now aligned with the real stream channel order used in this design and acts as the RGB-to-gray stage between gamma correction and frame-buffer writeback.

## Pipeline context

![AXI Bayer2RGB -> GammaCorrection -> RGBToGrayscale pipeline](../../docs/figures/axi_Bayer2RGB_Gamma_Corr2Gray.png)

Visible IPs in the image and related sources:

- [`AXI_BayerToRGB.vhd`](../../vivado/Zybo-Z7-10-Pcam-5C-hw.xpr/hw/hw.ipdefs/repo/local/ip/AXI_BayerToRGB/hdl/AXI_BayerToRGB.vhd)
- [`AXI_GammaCorrection.vhd`](../../vivado/Zybo-Z7-10-Pcam-5C-hw.xpr/hw/hw.ipdefs/repo/local/ip/AXI_GammaCorrection/hdl/AXI_GammaCorrection.vhd)
- [`axi_rgb_to_grayscale.vhd`](hdl/axi_rgb_to_grayscale.vhd)
- [`rgb_to_grayscale.vhd`](hdl/rgb_to_grayscale.vhd)
- [`system_xlconstant_0_0.xci`](../../vivado/Zybo-Z7-10-Pcam-5C-hw.xpr/hw/hw.srcs/sources_1/bd/system/ip/system_xlconstant_0_0/system_xlconstant_0_0.xci)

Block design references:

- [`system.bd`](../../vivado/Zybo-Z7-10-Pcam-5C-hw.xpr/hw/hw.srcs/sources_1/bd/system/system.bd)
- [`system.vhd`](../../vivado/Zybo-Z7-10-Pcam-5C-hw.xpr/hw/hw.gen/sources_1/bd/system/synth/system.vhd)

## Design theory

- This stage is intentionally stream-based and stateless per pixel. Unlike Sobel/3x3 filters, it does not require line buffers or full-frame storage.
- Full-frame buffering is only needed for random-access or frame-to-frame algorithms. In this design, those use the existing `VDMA + DDR` path.
- HDMI/display remains RGB-oriented, so grayscale is represented on the RGB stream as replicated luminance `{Y,Y,Y}`.
- Current implementation uses a DSP-free shift/add approximation: `Y = (R >> 2) + (G >> 1) + (B >> 2)`.
- Higher-fidelity fixed-point alternatives (for example Rec.601 `77/150/29`) are possible if image quality takes priority over minimal arithmetic.
- AXI4-Stream video framing is preserved end-to-end: `TUSER[0]` marks `SOF`, `TLAST` marks `EOL`, and payload carries active pixels only.
- Upstream pixel packing must be treated as authoritative for channel extraction. In this system, the effective wire order into this block is `R|B|G`, so decoder and testbench are aligned to that order.
- In the broader chain, placing grayscale after Bayer reconstruction and gamma correction ensures luminance is computed from corrected RGB data before memory writeback/display.

## Functionality

- Input stream format at this stage is `R|B|G` on `TDATA[23:0]` (MSB to LSB).
- Grayscale core (`E_RgbToGrayscale`) decodes this order and computes:
  - `Y = (R >> 2) + (G >> 1) + (B >> 2)`.
- It produces:
  - `o_gray8`: single-channel luminance,
  - `o_rbg888`: replicated grayscale `{Y,Y,Y}` in the same `R|B|G` byte order.
- Top wrapper (`AXI_RgbToGrayscale`) supports:
  - `i_pass_through='1'`: RGB path forwards input pixel data unchanged,
  - `i_pass_through='0'`: RGB path emits replicated grayscale.

## AXI4-Stream interfaces

Clock/reset:

- `i_aclk`
- `i_aresetn`
- `i_pass_through`

Input slave interface:

- `s_axis_video_tvalid`
- `s_axis_video_tready`
- `s_axis_video_tdata[23:0]`
- `s_axis_video_tuser` (`SOF`)
- `s_axis_video_tlast` (`EOL`)

Output master interfaces:

- RGB path:
  - `m_axis_rbg888_tvalid`
  - `m_axis_rbg888_tready`
  - `m_axis_rbg888_tdata[23:0]`
  - `m_axis_rbg888_tuser`
  - `m_axis_rbg888_tlast`
- Gray path:
  - `m_axis_gray8_tvalid`
  - `m_axis_gray8_tready`
  - `m_axis_gray8_tdata[7:0]`
  - `m_axis_gray8_tuser`
  - `m_axis_gray8_tlast`

Handshake behavior in wrapper:

- `s_axis_video_tready` is asserted only when both outputs are ready.
- Valid generation is cross-gated to keep RGB/gray fan-out synchronized under backpressure.
- `TUSER/TLAST` are forwarded beat-aligned with payload and cleared when output is invalid/reset.

## System integration in this project

Active video chain in the Vivado block design:

- `MIPI_CSI_2_RX_0` -> `AXI_BayerToRGB_0` -> `AXI_GammaCorrection_1` -> `AXI_RgbToGrayscale_0` -> `axi_vdma_0/S_AXIS_S2MM`.
- Display path then reads from DDR via `axi_vdma_0/M_AXIS_MM2S` -> `v_axi4s_vid_out_0` -> `rgb2dvi_0`.

Current generated BD wiring (`system.vhd`) for this module:

- `i_pass_through` is tied from `xlconstant_0_dout(0)` (static mode selection).
- `m_axis_gray8_tready` is tied to `'1'`.
- `m_axis_gray8_*` payload/control are left unconnected externally.
- RGB output (`m_axis_rgb888_*` at packaged IP boundary) is connected to VDMA S2MM stream input.

Note: the packaged BD interface name appears as `m_axis_rgb888`, while local RTL port naming uses `m_axis_rbg888_*`.

## Testbench overview

Primary cocotb target:

- [`testbench/targets.toml`](../../testbench/targets.toml) -> `[targets.axi_rgb_to_grayscale]`
- top: `axi_rgbtograyscale`
- module: [`testbench/tests/test_axi_rgb_to_grayscale.py`](../../testbench/tests/test_axi_rgb_to_grayscale.py)

Coverage provided:

- Functional grayscale conversion check against software model:
  - expected `Y = (R>>2) + (G>>1) + (B>>2)`,
  - verifies both RGB replicated output and gray8 output.
- Protocol checks under backpressure:
  - accepted beat count,
  - SOF/EOL correctness (`TUSER/TLAST`),
  - payload stability during `VALID=1` and `READY=0`.
- Pass-through mode regression (`i_pass_through=1`).
- Real image roundtrip (`lenna_512_512.png`) artifact generation.

Testbench stream pixel order is explicitly set to `rbg` to match DUT/BD wire order.
