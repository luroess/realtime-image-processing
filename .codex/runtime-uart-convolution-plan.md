# Runtime UART Control for 3x3 Convolution (PS AXI4-Lite -> PL Kernel Update)

## Summary
This plan follows your selected decisions:
1. **Authoritative baseline:** current Vitis XSA snapshot behavior.
2. **Snapshot gap handling:** reconstruct that snapshot first in source-controlled Vivado assets.
3. **Convolution control mode:** hybrid (preset kernels + writable 9-coefficient bank + atomic commit).
4. **Filter position:** after gamma, with convolution IP doing internal luminance conversion.

The implementation preserves existing menu behavior and keeps gamma/sensor controls intact, while adding a new UART path to configure convolution at runtime via `Xil_Out32`.

## Public Interfaces / API Changes
1. **New UART option in app:** `k` for convolution control in `vivado/Zybo-Z7-10-Pcam-5C-sw.ide/pcam_hdmi/src/main.cc`.
2. **New AXI4-Lite slave register map for convolution IP** (instance target: `AXI_Convolution_0`, base target: `0x43C50000`, range `64K`).
3. **New BSP macro usage:** `XPAR_<CONV_INSTANCE>_BASEADDR` from generated `xparameters.h` (resolved after platform regenerate).
4. **New IP in BD control path:** `ps7_0_axi_periph` expanded from `NUM_MI=6` to `NUM_MI=7` with new `M06_AXI` segment.

### Convolution Register Map (Decision Complete)
| Offset | Register | Access | Bit fields | Meaning |
|---|---|---|---|---|
| `0x00` | `CTRL` | RW | `[0] ENABLE`, `[1] BYPASS`, `[2] COEFF_MODE`, `[3] ABS_OUT`, `[4] COMMIT_W1P` | `COEFF_MODE=0` preset (`KERNEL_ID`), `1` custom coeff regs |
| `0x04` | `STATUS` | RO | `[0] COMMIT_PENDING`, `[1] ACTIVE_COEFF_MODE`, `[2] ACTIVE_BYPASS`, `[3] ACTIVE_ABS_OUT`, `[7:4] ACTIVE_KERNEL_ID`, `[31:16] APPLY_COUNT` | Runtime visibility/debug |
| `0x08` | `KERNEL_ID` | RW | `[2:0]` | `0..5` preset selector |
| `0x0C` | `SHIFT` | RW | `[4:0]` | Extra arithmetic right shift after fixed-point normalization |
| `0x20`..`0x40` | `COEFF0`..`COEFF8` | RW | signed `Q8.8` in bits `[15:0]` | 3x3 kernel shadow bank |
| `0x44` | `VERSION` | RO | implementation-defined | IP ID/version |

### Kernel Preset IDs
| ID | Name | Coefficients (Q8.8) | `ABS_OUT` | `SHIFT` |
|---|---|---|---|---|
| `0` | Identity | center=`256`, others `0` | `0` | `0` |
| `1` | Box Blur | all `28` (`~1/9`) | `0` | `0` |
| `2` | Sharpen | `[0,-256,0,-256,1280,-256,0,-256,0]` | `0` | `0` |
| `3` | Sobel X | `[-256,0,256,-512,0,512,-256,0,256]` | `1` | `0` |
| `4` | Sobel Y | `[-256,-512,-256,0,0,0,256,512,256]` | `1` | `0` |
| `5` | Laplacian | `[0,-256,0,-256,1024,-256,0,-256,0]` | `1` | `0` |

## Implementation Plan

### 1) Reconstruct XSA Snapshot Behavior in Source-Controlled Vivado Content
1. Promote grayscale IP package assets from `rtl/RGB_TO_GRAYSCALE` into local IP repo at `vivado/Zybo-Z7-10-Pcam-5C-hw.xpr/hw/hw.ipdefs/repo/local/ip/AXI_RgbToGrayscale` so the source tree can reproduce the snapshot that includes `AXI_RgbToGrayscale_0`.
2. In `vivado/Zybo-Z7-10-Pcam-5C-hw.xpr/hw/hw.srcs/sources_1/bd/system/system.bd`, restore the grayscale stage wiring equivalent to snapshot HWH: `AXI_GammaCorrection_1/m_axis_video -> AXI_RgbToGrayscale_0/s_axis_video -> axi_vdma_0/S_AXIS_S2MM`, with `xlconstant_0` driving `i_pass_through`.
3. Validate BD reproduction with `summarize_bd_interfaces.py` and confirm component/net presence before adding convolution.

### 2) Add New AXI4-Stream + AXI4-Lite Convolution IP
1. Add canonical RTL under `rtl/CONVOLUTION_3X3/hdl` with two entities: AXI wrapper + core datapath.
2. Datapath behavior: decode incoming `R|B|G`, compute luminance `Y=(R>>2)+(G>>1)+(B>>2)`, build 3x3 window (zero padding), perform signed MAC with active coefficients (`Q8.8`), optional absolute value, normalize by `>> (8 + SHIFT)`, saturate to `[0..255]`, replicate to RGB output in `R|B|G`.
3. Keep AXI4-Stream framing compliant: `TUSER[0]=SOF`, `TLAST=EOL`, active pixels only, no timing metadata in payload.
4. Implement atomic kernel updates: AXI-Lite writes update shadow registers; `COMMIT` sets pending; pending set applies only on next accepted SOF beat, copying shadow to active atomically.
5. Package IP in local repo as `AXI_Convolution` with AXI4-Stream slave/master plus AXI4-Lite slave interface.

### 3) Integrate Convolution into Vivado BD and Address Map
1. Insert `AXI_Convolution_0` between gamma and grayscale in `system.bd`.
2. Connect stream clocks/resets consistently with current design domains.
3. Connect `AXI_Convolution_0/s_axil` to `ps7_0_axi_periph` by expanding `NUM_MI` to `7` and using `M06_AXI`.
4. Assign control segment `0x43C50000/64K` in PS Data address space.
5. Validate BD, regenerate output products, run synthesis/implementation, generate bitstream.

### 4) Export Handoff and Rebuild Vitis Platform/App
1. Export updated hardware handoff (`system_wrapper.xsa`) from Vivado and update platform import in `vivado/Zybo-Z7-10-Pcam-5C-sw.ide/hw_pcam/hw/system_wrapper.xsa`.
2. Regenerate platform/domain so `xparameters.h` contains convolution base-address macro.
3. Keep launch programming path aligned to implementation bitstream in `vivado/Zybo-Z7-10-Pcam-5C-sw.ide/pcam_hdmi/_ide/launch.json`.
4. Rebuild `pcam_hdmi` app.

### 5) Add UART Menu + AXI Writes in Vitis App
1. Extend main menu in `vivado/Zybo-Z7-10-Pcam-5C-sw.ide/pcam_hdmi/src/main.cc` with `k. Configure 3x3 Convolution Kernel`.
2. Add `#define CONV_BASE_ADDR XPAR_<resolved_macro>` and register offset constants.
3. Add `k` submenu with options: identity, box blur, sharpen, Sobel X, Sobel Y, Laplacian, custom coefficients, bypass toggle, status print.
4. Implement all register writes with `Xil_Out32(CONV_BASE_ADDR + offset, value)` and reads with `Xil_In32`.
5. Preserve existing behavior by boot default `BYPASS=1`; selecting a kernel clears bypass and commits.
6. Preserve setting persistence by maintaining software shadow of current selection and reapplying after pipeline re-init paths.

### 6) Documentation Updates
1. Add a concise README section documenting the new UART option and kernel presets.
2. Update `docs/pcam5c_block_design.md` AXI4-Lite address map with convolution IP entry and register summary.
3. Add a short register-map table and example UART sequence (command + expected console print).

## Test Cases and Scenarios

### RTL / Simulation
1. Preset correctness test: each preset output against software golden model on representative frames.
2. Atomic commit test: issue writes and `COMMIT` mid-frame; verify old kernel for current frame, new kernel from next SOF only.
3. Bypass test: bypass output must bit-match input stream payload/framing.
4. Protocol test: random backpressure with no `TUSER/TLAST` corruption and no dropped beats.

### Software Integration
1. Build and boot app; ensure existing `g` (gamma), `a` (resolution), sensor register controls still work.
2. Select each `k` preset and verify visible HDMI changes.
3. Confirm printed status reflects active kernel and control bits.
4. Change resolution after kernel selection and verify kernel configuration persists.

### End-to-End Acceptance
1. UART at `115200 8N1`: kernel selection changes HDMI output observably.
2. Register writes target convolution base address from generated `xparameters.h`.
3. No crashes/hangs; gamma and camera controls remain functional.

## Assumptions and Defaults
1. Source-controlled reconstruction of snapshot is performed first because current XSA behavior includes grayscale stage not present in committed `system.bd`.
2. Convolution uses one IP instance (`AXI_Convolution_0`) with hybrid control mode.
3. Coefficients are signed `Q8.8`, presets defined as above, and output is saturated grayscale replicated to RGB.
4. Default power-on mode is `ENABLE=1`, `BYPASS=1` to keep legacy demo output unchanged until user selects a kernel.
5. Address allocation default is `0x43C50000/64K`; if occupied at integration time, next free `0x43Cxxxx` segment is chosen and propagated via regenerated BSP macro.
