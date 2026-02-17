# Top-Level BD Inspection Order

Use this order when answering which files are most important for understanding the Vivado project.

1. `vivado/Zybo-Z7-10-Pcam-5C-hw.xpr/hw/hw.xpr` (`source-controlled`)
- Resolve active file sets (`sources_1`, `constrs_1`) and top module.
2. `vivado/Zybo-Z7-10-Pcam-5C-hw.xpr/hw/hw.srcs/sources_1/bd/system/system.bd` (`source-controlled`)
- Parse components, interfaces, nets, and address segments.
3. `vivado/Zybo-Z7-10-Pcam-5C-hw.xpr/hw/hw.srcs/sources_1/imports/hdl/system_wrapper.vhd` (`source-controlled`)
- Confirm top integration and IO mapping around the BD.
4. `vivado/Zybo-Z7-10-Pcam-5C-hw.xpr/hw/hw.srcs/constrs_1/imports/constraints/auto.xdc` (`source-controlled`)
 - Board/project auto-generated constraints that still affect integration timing and IO behavior.
5. `vivado/Zybo-Z7-10-Pcam-5C-hw.xpr/hw/hw.srcs/constrs_1/imports/constraints/timing.xdc` (`source-controlled`)
 - Custom timing constraints for clocks, exceptions, and interface timing closure targets.
6. `vivado/Zybo-Z7-10-Pcam-5C-hw.xpr/hw/hw.srcs/constrs_1/imports/constraints/ZyboZ7_A.xdc` (`source-controlled`)
- Confirm board pins and project timing constraints bound to `constrs_1`.
7. Generated/handoff context only:
- `vivado/Zybo-Z7-10-Pcam-5C-hw.xpr/hw/hw.gen/sources_1/bd/system/system.bxml` (`generated`)
- `vivado/Zybo-Z7-10-Pcam-5C-hw.xpr/hw/hw.gen/sources_1/bd/system/system.bda` (`handoff artifact`)
- `vivado/Zybo-Z7-10-Pcam-5C-hw.xpr/hw/hw.gen/sources_1/bd/system/system_ooc.xdc` (`generated`)
- `vivado/Zybo-Z7-10-Pcam-5C-hw.xpr/hw/hw.gen/sources_1/bd/system/synth/system.vhd` (`generated`)
- `vivado/Zybo-Z7-10-Pcam-5C-hw.xpr/hw/hw.gen/sources_1/bd/system/hdl/system_wrapper.vhd` (`generated`)
- `vivado/Zybo-Z7-10-Pcam-5C-hw.xpr/hw/hw.gen/sources_1/bd/system/hw_handoff/system.hwh` (`handoff artifact`)
