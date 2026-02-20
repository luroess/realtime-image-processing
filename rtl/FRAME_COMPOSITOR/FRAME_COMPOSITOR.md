# FRAME_COMPOSITOR (Sobel-Only Contract)

This note captures the active no-FAST behavior for `FRAME_COMPOSITOR` in this branch.

## Scope

`FRAME_COMPOSITOR` is used only for overlay-producing modes.

- In `ST_PASS_ALL`, pipeline output must bypass `FRAME_COMPOSITOR` and forward the RGB/grayscale base stream directly from `AXI_RgbToGrayscale`.
- In `ST_SOBEL` and `ST_BLUR_SOBEL`, `FRAME_COMPOSITOR` merges Sobel mask output with the selected base image mode.

## Control Contract (from ClickDetector)

### BTN1 processing FSM

| State | `o_pass_blurr_filter` | `o_pass_sobel` | Intended routing |
|---|---:|---:|---|
| `ST_PASS_ALL` | 1 | 1 | Bypass compositor, direct base path |
| `ST_SOBEL` | 1 | 0 | Compositor active, Sobel delay |
| `ST_BLUR_SOBEL` | 0 | 0 | Compositor active, Blur+Sobel delay |

### BTN2 base FSM

| Base state | `o_pass_grayscale` | `o_overlay_zeros` | Intended base behavior |
|---|---:|---:|---|
| `ST_RGB` | 1 | 0 | Delayed RGB base |
| `ST_GRAY` | 0 | 0 | Delayed gray-as-RGB base |
| `ST_ZEROS` | 0 | 1 | Binary-only overlay (no base merge) |

## Delay-Select Semantics

`i_base_delay_stage_sel` values in compositor path:

- `00`: bypass/no delay (used only outside overlay merge)
- `01`: Sobel delay
- `10`: Blur+Sobel delay
- `11`: reserved (warn, alias to Sobel delay)

## No-FAST Requirement

FAST-related controls and delay paths are intentionally removed.

- No FAST-specific generics in `FrameCompositor`, `ShiftRamChain`, or `AXI_FrameCompositor`.
- No FAST selector mode in compositor color/mask routing.
- Pipeline/test routing must not depend on FAST states.

## Validation Commands

```bash
cd testbench
uv run tb-sim --target test_debouncer
uv run tb-sim --target test_click_detector
uv run tb-sim --target test_debounced_click_detector
uv run tb-sim --target axi_gray_blurr_sobel_overlay_pipeline_downscaled
```
