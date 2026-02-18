# Current Video IP Reference (Official Docs)

Current `system.bd` pipeline:
- `MIPI_D_PHY_RX_0` -> `MIPI_CSI_2_RX_0` -> `AXI_BayerToRGB_0` -> `AXI_GammaCorrection_1` -> `axi_vdma_0` -> `v_axi4s_vid_out_0` -> `rgb2dvi_0`
- `vtg` drives timing into `v_axi4s_vid_out_0`.

## AXI Video DMA (`axi_vdma_0`, PG020)

- Role: DMA bridge between DDR and AXI4-Stream video endpoints.
- This design uses both channels:
- `S2MM` capture path (stream to memory)
- `MM2S` playback path (memory to stream)
- Key checks:
- Channel clocks/resets are explicit and consistent.
- Frame size/stride programming matches active pixel packing.
- DDR bandwidth is sufficient for simultaneous read and write.
- Docs:
- https://docs.amd.com/r/en-US/pg020_axi_vdma
- https://docs.amd.com/r/en-US/pg020_axi_vdma/Features

## AXI4-Stream to Video Out (`v_axi4s_vid_out_0`, PG044)

- Role: converts AXI4-Stream Video to parallel video timing/data.
- Inputs:
- AXI4-Stream video (`s_axis_video_*`)
- Video timing (`vtg`)
- Key protocol checks:
- Transfer accepts on rising `ACLK` when `READY`, `VALID`, `ACLKEN`, and `ARESETn` are high.
- `TUSER` carries SOF; `TLAST` carries EOL.
- Active video only is transported on AXI4-Stream.
- Docs:
- https://docs.amd.com/r/en-US/pg044_v_axis_vid_out
- https://docs.amd.com/r/en-US/pg044_v_axis_vid_out/AXI4-Stream-Interface
- https://docs.amd.com/r/en-US/pg044_v_axis_vid_out/SOF-s_axis_video_tuser

## Video Timing Controller (`vtg`, PG016)

- Role: programmable timing generator/detector.
- This design uses it as timing source for display chain.
- Key checks:
- Timing parameters match target display mode.
- Timing clock/reset and AXI control clock/reset are coherent.
- Docs:
- https://docs.amd.com/r/en-US/pg016_v_tc
- https://docs.amd.com/r/en-US/pg016_v_tc/Video-Timing-Detection

## MIPI CSI-2 Receiver Subsystem (`MIPI_CSI_2_RX_0`, PG232)

- Role: converts camera CSI-2 serial traffic to AXI4-Stream video.
- Internal components include D-PHY interface logic, CSI-2 controller, and video formatting bridge.
- Key checks:
- Lane count, data type, and pixels-per-clock match downstream width and timing budget.
- VFB filtering/packing matches sensor output format.
- Docs:
- https://docs.amd.com/r/en-US/pg232-mipi-csi2-rx
- https://docs.amd.com/r/en-US/pg232-mipi-csi2-rx/Features

## MIPI D-PHY (`MIPI_D_PHY_RX_0`, PG202)

- Role: physical layer for MIPI camera serial signaling.
- Key checks:
- Lane constraints and board pin/bank rules are respected.
- Line rate is within device/speed-grade limits.
- D-PHY and CSI-2 reset/init sequencing is coherent.
- Docs:
- https://docs.amd.com/r/en-US/pg202-mipi-dphy
- https://docs.amd.com/r/en-US/pg202-mipi-dphy/Features

## Notes on non-AMD local IP in this BD

- `AXI_BayerToRGB_0` and `AXI_GammaCorrection_1` are local user IP.
- Use local HDL, XGUI metadata, and project constraints as the authority for behavior/parameters.
