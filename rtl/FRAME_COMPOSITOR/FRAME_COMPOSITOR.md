# FRAME_COMPOSITOR

`FrameCompositor` replaces deprecated `EDGE_OVERLAY`.
It merges a binary edge/corner mask onto an RGB base frame with mode-aware AXI routing.

## Current architecture

- `hdl/frame_compositor.vhd`:
  - combinational pixel merge (base RGB vs overlay color).
- `hdl/axi_frame_compositor.vhd`:
  - AXI4-Stream wrapper.
  - consumes delayed base RGB and processed `gray8` mask stream.
  - supports binary-only output via `i_overlay_zeros`.
- `hdl/shift_ram_chain.vhd`:
  - BRAM-shift delay chain using cascaded `c_shift_ram_0` taps.
  - fixed 26-bit payload packing `{SOF, EOL, RGB24}`.

## RTL walkthrough (functions/processes)

`hdl/frame_compositor.vhd`:

- function `f_expand_color`:
  - converts generic RGB888 constants to configured `G_COMPONENT_WIDTH`.
  - preserves project wire order `R|B|G`.
- process `P_COMB_OVERLAY`:
  - decodes `i_overlay_mode`.
  - asserts overlay only when corresponding edge flag is high.
  - falls back to base RGB for unsupported overlay mode values.

`hdl/shift_ram_chain.vhd`:

- function `f_ceil_div`:
  - computes number of `c_shift_ram_0` chunks needed for a target delay.
- function `f_last_chunk_delay`:
  - computes residual delay for final Sobel chunk.
- function `f_extra_last_chunk_delay`:
  - computes residual delay for final extra (blur extension) chunk.
- function `f_chunk_delay`:
  - returns delay for chunk index (full block vs residual block).
- generate chains:
  - `G_SOBEL_CHAIN`: Sobel delay chain.
  - `G_EXTRA_CHAIN`: optional blur-extension chain.

`hdl/axi_frame_compositor.vhd`:

- function `f_ceil_div`:
  - computes stage/chunk counts used for effective-delay constants.
- process `P_REG_BASE_VALID_DELAY`:
  - advances beat-domain validity markers alongside accepted RGB beats.
  - provides tap-valid indication for selected delay stage.
- process `P_ASSERT_ALIGN`:
  - simulation-only/verification guard that checks delayed RGB SOF/EOL
    against gray-reference SOF/EOL during accepted merge-mode beats.

## Control semantics

From `ClickDetector`:

- `o_pass_blurr_filter`, `o_pass_sobel`, `o_pass_fast`: processing FSM controls.
- `o_pass_grayscale`: base source selector.
  - `1`: RGB base from RGB2Gray pass-through.
  - `0`: gray replicated to RGB on base branch.
- `o_overlay_zeros`:
  - `1`: binary-only output (no base merge).
  - `0`: merge edge/corner mask onto delayed base RGB.

## Mode consequences for routing

Processing FSM consequences:

| State | pass_blurr | pass_sobel | pass_fast | Selected output path |
|---|---:|---:|---:|---|
| `ST_PASS_ALL` | 1 | 1 | 1 | direct `RGB2Gray.rgb888` (no buffering) |
| `ST_BLUR` | 0 | 1 | 1 | blurred chain output (`s_fast_*` pass-through) |
| `ST_SOBEL` | 1 | 0 | 1 | compositor output, sobel-class base delay |
| `ST_BLUR_SOBEL` | 0 | 0 | 1 | compositor output, blur+sobel base delay |
| `ST_FAST` | 1 | 1 | 0 | compositor output, fast-class (7x7) base delay |

Base FSM consequences (only relevant in compositor/overlay states):

| Base state | `o_pass_grayscale` | `o_overlay_zeros` | Effect |
|---|---:|---:|---|
| `ST_BRAM_RGB` | 1 | 0 | merge mask with delayed color RGB base |
| `ST_BRAM_GRAY` | 0 | 0 | merge mask with delayed gray-as-RGB base |
| `ST_ZEROS` | 0 | 1 | output binary-only frame (no base merge) |

## BRAM delay model

Delay values are resolved inside `AXI_FrameCompositor` from generics:

- `G_LINE_WIDTH`
- `G_SOBEL_KERNEL_SIZE`
- `G_FAST_KERNEL_SIZE`
- `G_BLURR_KERNEL_SIZE`
- optional overrides:
  - `G_SOBEL_DELAY_OVERRIDE`
  - `G_FAST_DELAY_OVERRIDE`
  - `G_BLUR_SOBEL_DELAY_OVERRIDE`

Default auto-derivation uses warm-up style stage delays:

`D_stage(K,W) = ((W + 1) * ((K - 1) / 2))`

and derives:

- `D_sobel = D_stage(3, W)`
- `D_fast = D_stage(G_FAST_KERNEL_SIZE, W)`
- `D_blur_sobel = D_stage(G_BLURR_KERNEL_SIZE, W) + D_stage(3, W)`

For `W=512`, `G_FAST_KERNEL_SIZE=7`, `G_BLURR_KERNEL_SIZE=3`:

- `D_sobel = 513`
- `D_fast = 1539`
- `D_blur_sobel = 1026`

Note: isolated compositor tests intentionally set override generics
`G_SOBEL_DELAY_OVERRIDE=1027`, `G_BLUR_SOBEL_DELAY_OVERRIDE=2054` to match the simulation
`c_shift_ram_0` latency model used in `test_shift_ram_chain.py` and
`test_axi_frame_compositor.py`.

Also note that the wrapper tracks effective tap-valid latency using:

- `C_SOBEL_DELAY_EFFECTIVE = C_SOBEL_DELAY + (C_SOBEL_CHUNKS - 1)`
- `C_FAST_DELAY_EFFECTIVE = C_FAST_DELAY + (C_FAST_CHUNKS - 1)`
- `C_BLUR_SOBEL_DELAY_EFFECTIVE = C_BLUR_SOBEL_DELAY + (C_TOTAL_CHUNKS - 1)`

to account for per-stage registered output behavior in cascaded `c_shift_ram_0`.

## `c_shift_ram_0` tap mapping

Current generated IP in-tree (`rtl/FRAME_COMPOSITOR/ip/edit_FrameCompositor.gen/...`) is:

- width: 26 (`D[25:0]`, `Q[25:0]`)
- address/tap port: `A[3:0]`
- depth: 16 (`A=15` means 16-beat delay)

Current `ShiftRamChain` implementation is written for 1024-beat chunks (`A[9:0]`).
That means the currently generated `c_shift_ram_0` wrapper is configuration-mismatched for existing defaults.
To use vendor IP without changing delay-model assumptions in tests/docs, regenerate the IP with `Depth=1024` (`A[9:0]`).

How FIFO/shift length is determined:

1. Delay lengths are resolved in `AXI_FrameCompositor` from line width/kernel generics (or explicit override generics):
   - `G_LINE_WIDTH`
   - `G_SOBEL_KERNEL_SIZE`
   - `G_FAST_KERNEL_SIZE`
   - `G_BLURR_KERNEL_SIZE`
   - `G_SOBEL_DELAY_OVERRIDE`
   - `G_FAST_DELAY_OVERRIDE`
   - `G_BLUR_SOBEL_DELAY_OVERRIDE`
2. `ShiftRamChain` splits each target delay into 1024-pixel chunks plus one residual chunk.
3. Chunk count and each chunk `A` value are compile-time constants (generated by `for generate`).

Examples:

1. `1027 = 1024 + 3`
   - chunk0: `A=1023`
   - chunk1: `A=2`
2. `2054 = 1024 + 1024 + 6`
   - chunk0: `A=1023`
   - chunk1: `A=1023`
   - chunk2: `A=5`

`ShiftRamChain` stage select:

- `00`: bypass (0 delay)
- `01`: sobel-class delay (`C_SOBEL_DELAY`)
- `10`: blur+sobel delay (`C_BLUR_SOBEL_DELAY`)
- `11`: fast-class delay (`C_FAST_DELAY`)

Common standalone/simulation values are `1027`, `1540`, and `2054` for
effective Sobel/FAST/blur+Sobel alignment with cascaded `c_shift_ram_0` stages.

## Cocotb vendor-IP flow

- GHDL cannot consume the encrypted AMD `ipstatic` VHDL (`\`protect` blocks).
- Vendor-IP cocotb targets therefore use simulator `questa` and compile in ordered libraries:
  - `xbip_utils_v3_0_14`
  - `c_reg_fd_v12_0_10`
  - `c_shift_ram_v12_0_19`
  - `top` (generated `c_shift_ram_0.vhd` + project RTL)
- Added targets:
  - `axi_frame_compositor_vivado_ip_questa`
  - `axi_gray_blurr_sobel_overlay_pipeline_vivado_ip_questa`
- These targets are configured in `testbench/targets.toml` via `build_stages`.
- Vivado regeneration sketch (from `rtl/FRAME_COMPOSITOR/ip/edit_FrameCompositor.xpr`):
  - `set_property -dict [list CONFIG.Depth {1024}] [get_ips c_shift_ram_0]`
  - `generate_target {simulation} [get_ips c_shift_ram_0]`
  - `export_ip_user_files -of_objects [get_ips c_shift_ram_0] -force -quiet`

## AXI integration requirements

1. Frame-latch control at `SOF`:
   - processing/base control signals are sampled once per frame and held for that frame.
2. Non-overlay modes:
   - do not route frame output through compositor.
   - `ST_PASS_ALL`: output direct RGB2Gray `rgb888`.
   - `ST_BLUR`: output blurred chain.
3. Overlay modes:
   - use compositor output.
   - base stream is delayed in BRAM shift chain.
   - gray stream is mask/timing reference.
4. Binary-only mode (`o_overlay_zeros='1'`):
   - output binary RGB mask directly, independent of base merge.

## Inspected figures

### Processing + base-state sketch

`docs/figures/fsm.png`:

![FRAME_COMPOSITOR processing/base FSM reference](../../docs/figures/fsm.png)

Observed alignment with implementation intent:

- processing FSM initial state shown as `ST_PASS_ALL`
- base-image FSM (`ST_BRAM_RGB` / `ST_BRAM_GRAY` / `ST_ZEROS`) only matters in overlay states
- `ST_ZEROS` corresponds to binary-only output behavior (`i_overlay_zeros='1'`)

### Vivado hierarchy snapshot

`docs/figures/image.png`:

![AXI_FrameCompositor hierarchy with ShiftRamChain chunking](../../docs/figures/image.png)

Observed structure:

- `U_ShiftRamChain` contains Sobel, FAST, and blur-extension chunk chains
- generated hierarchy currently shows chunk fanout per configured delay tap
- `U_FrameCompositor` is fed from aligned stream outputs of that chain

## Related tests and test-cases (FRAME_COMPOSITOR)

Latest review run date: `2026-02-19`.

| Target | Test cases | Latest status | Repro command |
|---|---|---|---|
| `frame_compositor_core` | `test_frame_compositor_all_input_combinations` | `PASS` (1/1) | `cd testbench && uv run tb-sim --target frame_compositor_core` |
| `shift_ram_chain` | `test_shift_ram_chain_delay_select_none`<br>`test_shift_ram_chain_sobel_delay_1027`<br>`test_shift_ram_chain_blur_sobel_delay_2054` | `PASS` (3/3) | `cd testbench && uv run tb-sim --target shift_ram_chain` |
| `axi_frame_compositor` | `test_axi_frame_compositor_multiframe_sync_with_gray_delay_and_backpressure`<br>`test_axi_frame_compositor_downscaled_real_image_sequence`<br>`test_axi_frame_compositor_small_mode_matrix_with_backpressure_and_gray_delays`<br>`test_axi_frame_compositor_delay_stage_sweep_with_backpressure`<br>`test_axi_frame_compositor_binary_mode_not_blocked_by_rgb` | `PASS` (5/5) | `cd testbench && uv run tb-sim --target axi_frame_compositor` |
| `axi_gray_blurr_sobel_overlay_pipeline` | `test_pipeline_full_chain_state_progression`<br>`test_pipeline_full_chain_smoke_with_backpressure` | `FAIL` (wall-time timeout) | `cd testbench && timeout 240s uv run tb-sim --target axi_gray_blurr_sobel_overlay_pipeline` |
| `axi_gray_blurr_sobel_overlay_pipeline_downscaled` | `test_pipeline_downscaled_real_image_overlay_saved` | `PASS` (1/1) | `cd testbench && uv run tb-sim --target axi_gray_blurr_sobel_overlay_pipeline_downscaled` |
| `axi_gray_blurr_sobel_overlay_pipeline_synth_fsm_axi` | `test_pipeline_synthetic_axi_fsm_and_compositor_sync` | `PASS` (1/1) | `cd testbench && uv run tb-sim --target axi_gray_blurr_sobel_overlay_pipeline_synth_fsm_axi` |
| `test_click_detector` | `test_click_state_machine` | `PASS` (1/1) | `cd testbench && uv run tb-sim --target test_click_detector` |
| `test_debounced_click_detector` | `test_debounced_click_detection` | `PASS` (1/1) | `cd testbench && uv run tb-sim --target test_debounced_click_detector` |

## Implementation-vs-doc inconsistencies found

The following mismatches were present before this update and are now corrected in this document:

1. Delay formula/value mismatch:
   - doc previously stated `D_stage(...)+1` and listed `D_sobel=514`, `D_blur_sobel=1028` for `W=512`.
   - implementation currently uses `D_stage = ((W+1)*((K-1)/2))` (`rtl/PIPELINE/hdl/axi_rgb_gray_blurr_sobel_overlay_pipeline.vhd`), yielding `513` and `1026`.
2. Outdated downscaled test status:
   - doc previously listed `axi_gray_blurr_sobel_overlay_pipeline_downscaled` as failing.
   - current test run passes.
3. Missing synthetic FSM/AXI/sync test coverage entry:
   - doc previously omitted `axi_gray_blurr_sobel_overlay_pipeline_synth_fsm_axi`.
4. Outdated claim about forced delay-stage bypass:
   - doc previously suggested pipeline still hard-forced `s_fc_delay_stage_sel` to `NONE`.
   - implementation now derives delay-stage from processing mode.
5. Outdated claim about `AXI_RgbToGrayscale` ready/valid coupling:
   - doc previously stated cross-coupled dual-output handshake remained.
   - implementation now uses registered per-beat dual-output handoff.

## Current issues and resolution instructions

Open items as of `2026-02-19`:

1. `HIGH`: Full compositor integration target does not complete in bounded wall time.
   - Evidence:
     - `timeout 240s uv run tb-sim --target axi_gray_blurr_sobel_overlay_pipeline` => timeout.
     - `COCOTB_TEST_FILTER='test_pipeline_full_chain_state_progression' timeout 240s uv run tb-sim --target axi_gray_blurr_sobel_overlay_pipeline` => timeout.
     - `COCOTB_TEST_FILTER='test_pipeline_full_chain_smoke_with_backpressure' timeout 240s uv run tb-sim --target axi_gray_blurr_sobel_overlay_pipeline` => timeout.
   - Resolution instructions:
     - Profile 512x512 run-time progress at source/sink/scoreboard boundaries.
     - Keep synthetic/downscaled compositor regressions as functional gates while large-frame runtime is optimized.

2. `HIGH`: `AXI_FrameCompositor` bypass mode can ignore downstream backpressure on RGB base input.
   - Evidence:
     - `rtl/FRAME_COMPOSITOR/hdl/axi_frame_compositor.vhd:181` to `rtl/FRAME_COMPOSITOR/hdl/axi_frame_compositor.vhd:184`.
   - Resolution instructions:
     - In `s_need_rgb='0'` mode, avoid unconditional `s_axis_rbg888_tready='1'`.
     - Either stop consuming RGB (`tready='0'`) when base is unused, or explicitly throttle with downstream acceptance and document drop behavior.
     - Add/keep a dedicated backpressure test that stalls `m_axis_video_rbg888_tready` while checking no uncontrolled RGB consumption.

3. `MEDIUM`: delayed-valid shift register can retain stale valid bits across pauses.
   - Evidence:
     - `rtl/FRAME_COMPOSITOR/hdl/axi_frame_compositor.vhd:145` to `rtl/FRAME_COMPOSITOR/hdl/axi_frame_compositor.vhd:163`.
   - Resolution instructions:
     - Shift the valid pipe every cycle and inject `0` when no accept occurs, or replace with explicit occupancy/count tracking tied to accepted beats.
     - Validate with prolonged pause patterns in `test_axi_frame_compositor_delay_stage_sweep_with_backpressure`.

4. `MEDIUM`: illegal delay selector values silently fall back to Sobel path.
   - Evidence:
     - `rtl/FRAME_COMPOSITOR/hdl/axi_frame_compositor.vhd:160` to `rtl/FRAME_COMPOSITOR/hdl/axi_frame_compositor.vhd:165`
     - `rtl/FRAME_COMPOSITOR/hdl/shift_ram_chain.vhd:138` to `rtl/FRAME_COMPOSITOR/hdl/shift_ram_chain.vhd:143`.
   - Resolution instructions:
     - Add simulation assertions for illegal selector values.
     - Prefer safe fallback to `C_SEL_NONE`/`C_DELAY_SEL_NONE` in synthesis path if assertion is not tripped.

5. `MEDIUM`: FAST and Sobel overlays currently share the same binary mask source.
   - Evidence:
     - `rtl/FRAME_COMPOSITOR/hdl/axi_frame_compositor.vhd:126` to `rtl/FRAME_COMPOSITOR/hdl/axi_frame_compositor.vhd:127`
     - `rtl/FRAME_COMPOSITOR/hdl/axi_frame_compositor.vhd:189` to `rtl/FRAME_COMPOSITOR/hdl/axi_frame_compositor.vhd:191`.
   - Resolution instructions:
     - Extend compositor wrapper interfaces for independent FAST/Sobel mask streams or explicit selected-mask muxing.
     - Add test vectors where FAST and Sobel masks differ to prove independent behavior.

6. `MEDIUM`: documented frame-latched control requirement is not fully implemented in compositor wrapper.
   - Evidence:
     - `rtl/FRAME_COMPOSITOR/hdl/axi_frame_compositor.vhd:133` contains TODO note to frame-latch `i_overlay_mode` / `i_overlay_zeros`.
   - Resolution instructions:
     - Latch control values on frame start (`SOF`) and hold until next frame to avoid mid-frame control tearing.
