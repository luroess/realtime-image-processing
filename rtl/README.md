# Structure of the HDL code

- All top-level modules that are supposed to be packaged as a Vivado IP core need to be placed in their own sub-dir. These directories must include all `.vhd` sources ...

- When packaging a new IP core save them to the IP repo inside the local Vivado Project `/clean/realtime-image-processing/vivado/Zybo-Z7-10-Pcam-5C-hw.xpr/hw/hw.ipdefs/repo`.
- After adding it to the IP repo, run

```tcl
update_ip_catalog -rebuild -scan_changes
```

This requires the block design to be closed:
```
close_bd_design system
```

## Important Sources

- [`system.bd` (block design source)](../../vivado/Zybo-Z7-10-Pcam-5C-hw.xpr/hw/hw.srcs/sources_1/bd/system/system.bd)
- [`system.vhd` (synthesized BD top)](../../vivado/Zybo-Z7-10-Pcam-5C-hw.xpr/hw/hw.gen/sources_1/bd/system/synth/system.vhd)
- [`AXI_BayerToRGB.vhd`](../../vivado/Zybo-Z7-10-Pcam-5C-hw.xpr/hw/hw.ipdefs/repo/local/ip/AXI_BayerToRGB/hdl/AXI_BayerToRGB.vhd)
- [`AXI_GammaCorrection.vhd`](../../vivado/Zybo-Z7-10-Pcam-5C-hw.xpr/hw/hw.ipdefs/repo/local/ip/AXI_GammaCorrection/hdl/AXI_GammaCorrection.vhd)