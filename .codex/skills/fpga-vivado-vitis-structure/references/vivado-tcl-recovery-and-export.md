# Vivado Tcl Recovery and Export (`wproj` / `vivado-git`)

## Use this note when

- `write_bd_tcl` fails with `BD 5-599` (IP not upgraded).
- IP Status shows `Locked by user` BD cells (for example `/xlconcat_0`, `/xlconstant_0`).
- You need a stable project export flow to `vivado/hw.tcl`.

## Recovery sequence (Vivado Tcl Console)

```tcl
open_project C:/Users/jandu/repos/clean/realtime-image-processing/vivado/Zybo-Z7-10-Pcam-5C-hw.xpr/hw/hw.xpr
open_bd_design [get_files */system.bd]

set_property LOCK_UPGRADE false [get_bd_cells /xlconcat_0]
set_property LOCK_UPGRADE false [get_bd_cells /xlconstant_0]

validate_bd_design
save_bd_design
upgrade_ip [get_ips]
report_ip_status
generate_target all [get_files */system.bd]
```

Notes:

- In Vivado 2025.1, use `report_ip_status` (plain). `-of_objects` is not supported.
- `generate_target all ...` may print "already up-to-date"; this is normal.

## Export flow to `vivado/hw.tcl`

Option A (`wproj` helper loaded):

```tcl
wproj
file copy -force [current_project].tcl ../../hw.tcl
```

Option B (direct `vivado-git` script):

```tcl
source ../../vivado-git/scripts/write_project_tcl_git.tcl
namespace import ::custom_projutils::write_project_tcl_git
write_project_tcl_git -no_copy_sources -force ../../hw.tcl
```

## Relevant scripts and what they do

- `vivado/vivado-git/Vivado_init.tcl`: Vivado startup hook that registers helper commands such as `wproj`.
- `vivado/vivado-git/scripts/write_project_tcl_git.tcl`: Core script that writes a reproducible project Tcl with source-oriented behavior.
- `vivado/hw.tcl`: Saved hardware recreation script that should be tracked in Git.

## If lock state persists unexpectedly

- Clear Windows read-only attributes under the hardware project tree, restart Vivado, and rerun recovery:

```bat
attrib -R /S /D C:\Users\jandu\repos\clean\realtime-image-processing\vivado\Zybo-Z7-10-Pcam-5C-hw.xpr\hw\*
```
