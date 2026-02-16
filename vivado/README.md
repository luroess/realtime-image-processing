# Vivado/Vitis Save and Rebuild Guide

This project uses a script-first Vivado workflow (via `vivado/vivado-git`) so Git tracks source files, not generated build output.

## One-time optional setup (Vivado `wproj` helper)

If you want `wproj` available in Vivado Tcl Console:

1. Copy `vivado/vivado-git/Vivado_init.tcl` and `vivado/vivado-git/scripts/` to:
- Windows: `%APPDATA%/Xilinx/Vivado`
- Linux: `~/.Xilinx/Vivado`
2. Restart Vivado.
3. You can now run `wproj` in the Tcl Console.

If you skip this setup, use the direct Tcl commands shown below.

## What to keep in Git (source of truth)

Track these:

- `vivado/hw.tcl`: Vivado project recreation script (generated from current project).
- `vivado/README.md`: This workflow documentation.
- `vivado/Zybo-Z7-10-Pcam-5C-hw.xpr/hw/hw.xpr`: Vivado project descriptor.
- `vivado/Zybo-Z7-10-Pcam-5C-hw.xpr/hw/hw.srcs/**`: Source constraints/BD/HDL imports.
- `vivado/Zybo-Z7-10-Pcam-5C-hw.xpr/hw/hw.ipdefs/repo/local/**`: Local custom IP sources.
- `vivado/Zybo-Z7-10-Pcam-5C-hw.xpr/hw/hw.ipdefs/repo/vivado-library/ip/MIPI_CSI_2_RX/**`: Required CSI-2 IP source package.
- `vivado/Zybo-Z7-10-Pcam-5C-hw.xpr/hw/hw.ipdefs/repo/vivado-library/ip/MIPI_D_PHY_RX/**`: Required D-PHY IP source package.
- `vivado/Zybo-Z7-10-Pcam-5C-hw.xpr/hw/hw.ipdefs/repo/vivado-library/ip/rgb2dvi/**`: Required RGB-to-DVI IP source package.
- `rtl/**`: Local RTL source tree.
- `vivado/Zybo-Z7-10-Pcam-5C-sw.ide/pcam_hdmi/src/**`: Application source.
- `vivado/Zybo-Z7-10-Pcam-5C-sw.ide/pcam_hdmi/_ide/launch.json`: Run/debug launch settings.
- `vivado/Zybo-Z7-10-Pcam-5C-sw.ide/pcam_hdmi/vitis-comp.json`: App component metadata.

Do not track generated artifacts:

- `vivado/**/*.runs/**`, `vivado/**/*.gen/**`, `vivado/**/*.cache/**`, `vivado/**/*.sim/**`, `vivado/**/.Xil/**`
- `vivado/**/build/**`, `vivado/**/export/**`, `vivado/**/bsp/**`, `vivado/**/logs/**`
- `**/*.jou`, `**/*.log`, `**/compile_commands.json`, `**/.cache/**`

## Save the current project state

1. Open Vivado project:
`vivado/Zybo-Z7-10-Pcam-5C-hw.xpr/hw/hw.xpr`

2. Generate the project recreation script (`vivado/hw.tcl`).

Option A (if `wproj` is installed):
```tcl
wproj
file copy -force [current_project].tcl ../../hw.tcl
```

Option B (direct commands, no `wproj` required):
```tcl
source ../../vivado-git/scripts/write_project_tcl_git.tcl
namespace import ::custom_projutils::write_project_tcl_git
write_project_tcl_git -no_copy_sources -force ../../hw.tcl
```

3. Build bitstream in Vivado (`impl_1`) so this exists:
`vivado/Zybo-Z7-10-Pcam-5C-hw.xpr/hw/hw.runs/impl_1/system_wrapper.bit`

4. Ensure Vitis launch uses Vivado bitstream path. In:
`vivado/Zybo-Z7-10-Pcam-5C-sw.ide/pcam_hdmi/_ide/launch.json`
set:
`targetSetup.bitstreamFile = "..\\..\\Zybo-Z7-10-Pcam-5C-hw.xpr\\hw\\hw.runs\\impl_1\\system_wrapper.bit"`

1. From repo root, stage source files only:
```bash
git add \
  vivado/hw.tcl \
  vivado/README.md \
  vivado/Zybo-Z7-10-Pcam-5C-hw.xpr/hw/hw.xpr \
  vivado/Zybo-Z7-10-Pcam-5C-hw.xpr/hw/hw.srcs \
  vivado/Zybo-Z7-10-Pcam-5C-hw.xpr/hw/hw.ipdefs/repo/local \
  vivado/Zybo-Z7-10-Pcam-5C-hw.xpr/hw/hw.ipdefs/repo/vivado-library/ip/MIPI_CSI_2_RX \
  vivado/Zybo-Z7-10-Pcam-5C-hw.xpr/hw/hw.ipdefs/repo/vivado-library/ip/MIPI_D_PHY_RX \
  vivado/Zybo-Z7-10-Pcam-5C-hw.xpr/hw/hw.ipdefs/repo/vivado-library/ip/rgb2dvi \
  rtl \
  vivado/Zybo-Z7-10-Pcam-5C-sw.ide/pcam_hdmi/src \
  vivado/Zybo-Z7-10-Pcam-5C-sw.ide/pcam_hdmi/_ide/launch.json \
  vivado/Zybo-Z7-10-Pcam-5C-sw.ide/pcam_hdmi/vitis-comp.json
```

1. Commit:
```bash
git commit -m "Save Vivado/Vitis source project state"
```

## Rebuild from a clean clone

1. Clone repository and open Vivado.

2. Recreate hardware project from script:
- Vivado GUI: `Tools -> Run Tcl Script...` and select `vivado/hw.tcl`
- The project should be recreated under `vivado/Zybo-Z7-10-Pcam-5C-hw.xpr/hw/`

3. In Vivado, run synthesis/implementation and generate bitstream.

4. Export/update hardware handoff (`system_wrapper.xsa`) for Vitis platform.

5. Open Vitis workspace:
`vivado/Zybo-Z7-10-Pcam-5C-sw.ide`

6. Regenerate/rebuild platform:
- `hw_pcam` -> regenerate platform (updates BSP/export artifacts)

7. Confirm launch bitstream path in:
`vivado/Zybo-Z7-10-Pcam-5C-sw.ide/pcam_hdmi/_ide/launch.json`
It must point to:
`..\\..\\Zybo-Z7-10-Pcam-5C-hw.xpr\\hw\\hw.runs\\impl_1\\system_wrapper.bit`

8. Build application:
- `pcam_hdmi` -> Build

9. Run/debug `pcam_hdmi`.

## IP repository location

`realtime-image-processing/vivado/Zybo-Z7-10-Pcam-5C-hw.xpr/hw/hw.ipdefs/repo`
