# ClickDetector FSM Summary

Source: `rtl/CLICK_DETECTOR/hdl/click_detection.vhd`

## BTN1 Processing FSM (`i_btn_debounced`)

Transition condition in all states: rising edge (`i_btn_debounced='1' and s_btn1_prev='0'`).

| State | `o_pass_blurr_filter` | `o_pass_sobel` | Behavior | Next state on BTN1 edge |
| --- | --- | --- | --- | --- |
| `ST_PASS_ALL` | `1` | `1` | Processing blocks bypassed | `ST_SOBEL` |
| `ST_SOBEL` | `1` | `0` | Sobel active, blur bypassed | `ST_BLUR_SOBEL` |
| `ST_BLUR_SOBEL` | `0` | `0` | Blur + Sobel active | `ST_PASS_ALL` |

Integration note:
- In `ST_PASS_ALL`, the RGB stream from the `AXI_RgbToGrayscale` pass-through branch should be forwarded directly and must **not** be buffered in `FRAME_COMPOSITOR`.

## BTN2 Base-Image FSM (`i_btn2_debounced`)

Transition condition in all states: rising edge (`i_btn2_debounced='1' and s_btn2_prev='0'`).

| State | `o_pass_grayscale` | `o_overlay_zeros` | Behavior | Next state on BTN2 edge |
| --- | --- | --- | --- | --- |
| `ST_RGB` | `1` | `0` | Use RGB base stream | `ST_GRAY` |
| `ST_GRAY` | `0` | `0` | Use grayscale-replicated base stream | `ST_ZEROS` |
| `ST_ZEROS` | `0` | `1` | Hide base stream (overlay/effects only) | `ST_RGB` |

## Reset Behavior

- `i_rst_n='0'` sets:
  - processing FSM to `ST_PASS_ALL`
  - base FSM to `ST_ZEROS`
  - edge-detect registers `s_btn1_prev='0'`, `s_btn2_prev='0'`

## Unit Tests

```
uv run tb-sim --target test_debouncer
uv run tb-sim --target test_click_detector
uv run tb-sim --target test_debounced_click
```