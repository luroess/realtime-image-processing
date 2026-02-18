## Questions

- Should we save the entire image to BRAM before processing?
  - No for Sobel/3x3 streaming filters. Use line buffers (`K-1` lines) + shift registers and process at 1 px/clk after warm-up.
  - Save full frames only if an algorithm needs random frame access or frame-to-frame ops; then use VDMA + DDR (already present in `design_1`).
  - On Zynq-7010, full-frame BRAM storage is generally too expensive (e.g. 720p x 8-bit gray is already close to ~0.9 MB).
- Can we output the processed image as gray scale to the HDMI output? In what format?
  - Yes.
  - In this project, HDMI path is AXI4-Stream video into `v_axi4s_vid_out`/`rgb2dvi`, effectively RGB output. So send grayscale as replicated RGB:
    - `R = Y`, `G = Y`, `B = Y`
    - 24-bit pixel bus: `{Y, Y, Y}` (keep `tuser`/`tlast` framing intact).
- How to implement RGB to grayscale conversions?
  - without multipliers? (e.g. using shifts and adds)
    - Fast/simple: `Y = (R >> 2) + (G >> 1) + (B >> 2)` (0.25/0.5/0.25), matches your external reference style.
    - Better Rec.601 shift-add approximation:
      - `Y = (77*R + 150*G + 29*B + 128) >> 8`
      - Implement constants with shifts/adds (no DSP multipliers).
  - with multipliers? (e.g. using fixed-point coefficients)
    - Use fixed-point Rec.601:
      - `Y = (77*R + 150*G + 29*B + 128) >> 8` (8 fractional bits), or
      - `Y = (306*R + 601*G + 117*B + 512) >> 10` (10 fractional bits).
    - Pipeline the multiply-add stages (DSP48-friendly) to keep 1 px/clk throughput.
- How to convert from 8-bit grayscale to RGB?
  - Replicate luminance to all channels:
    - `R = Y`, `G = Y`, `B = Y`
    - bus packing: `{Y, Y, Y}` for 24-bit RGB.
  - Optional false-color/overlay mode can replace one channel (e.g. green edges) while keeping non-edge pixels as `{Y,Y,Y}`.

- Does the vitis project in "vivado/Zybo-Z7-10-Pcam-5C-sw.ide" actually use the vivado synthesis from the external hw vivado project or does it have its own copy of the vitis project?


## AXI4-Stream Video


![AXI BayerToRGB](axi_bayer_to_rgb.png)

Input to the BayerToRGB block is `s_axis_video_tdata[39:0]` (40 bits wide) containing 4 pixels of 10-bit Bayer data (RAW10 format). Output is `m_axis_video_tdata[31:0]` (32 bits wide) containing 1 pixel of 8-bit RGB data (with 8 bits of zero padding).

- TREADY: slave ready to accept data
- TVALID: master indicating that it has valid samples that can be passed to the slave

- Input SOF at pixel (0,0): the first valid 3×3 window appears at pixel (1,1) — two lines later.