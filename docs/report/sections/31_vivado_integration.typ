#import "../shared/macros.typ": *

= Vivado Integration
#component_owner("Valentin Bumeder")

== Initial Integration of RTL-Module

The initial integration of own modules into the #blink("https://digilent.com/reference/programmable-logic/zybo-z7/demos/pcam-5c")[Digilent's Zybo Z7 Pcam 5C demo] project was done by integrating the `DebouncedClickDetector` directly as RTL-module. 
As a starting point, the Zybo base project was imported into Vivado. Since the regeneration of the output products of the system design led to errors, certain IP-Blocks needed to be locked. By applying the lock, the IP Blocks were prevented from being updated automatically and resulting issues from the update were resolved. 

To make the boards buttons and LEDs usable within RTL-Modules, constraints and corresponding ports in the block design were created in the project. 

The `Debouncer` and `ClickDetector` modules were added to the block design and wired to the ports as well as the processing systems `FCLK_CLK0` clock. The created hardware handoff and bitstream from Vivado Synthesis and Implementation could afterwards be integrated in the Vitis Demo Project and from there programmed onto the FPGA-Board.

#figure(
	image("../figures/artifacts/vivado_block_wiring.png", width: 100%),
	caption: [Wiring of ports and modules in the Vivado block design.],
)


== Creation and Integration of Pipeline IP Block

For the further integration of RTL-Modules into the existing Vivado block design, a single IP Block should be used to minimize the manual integration effort. Therefor a top level pipeline module was implemented as described in @sec-pipeline-deep-dive and packaged as IP Block. 

The packaging workflow follows the project convention documented in #repo_link("rtl/README.md", line: 1, branch: "feat/rollback").
The folder `rtl/` is used as the source of truth for all custom IP components, and each component keeps its own `component.xml`, HDL sources, edit-IP project, and generated `xgui` files.
This structure avoids duplicated packaged IP artifacts across multiple Vivado repository folders and keeps the integration reproducible.

For IP creation, Vivado was used in *Create and Package New IP* mode with a dedicated edit project (`edit_<IP_NAME>`) stored below the component-local `ip/` folder.
After adding the component directory as design source and setting the intended top wrapper, the current project was packaged directly into the component folder inside `rtl/`.
During packaging, the AXI interfaces were explicitly associated with the correct clock to ensure consistent interface detection and block-design integration.

After packaging, the top-level Vivado project was configured to use `rtl/` as the central IP repository so all packaged custom components can be discovered via one repository entry.
In the migration phase, the legacy project-local repository remained enabled in parallel.
The catalog was then refreshed/rebuilt so newly packaged pipeline versions became available in the IP integrator.

```tcl
set proj_dir    [get_property DIRECTORY [current_project]]
set legacy_repo [file normalize [file join $proj_dir hw.ipdefs/repo]]
set rtl_repo    [file normalize [file join $proj_dir ../../../rtl]]
set repos [list]

if {[file isdirectory $legacy_repo]} { lappend repos $legacy_repo }
if {[file isdirectory $rtl_repo]}    { lappend repos $rtl_repo }

set_property IP_REPO_PATHS $repos [current_fileset]
catch {close_bd_design [current_bd_design]}
update_ip_catalog -rebuild -scan_changes
```

To keep the edit-IP projects shareable in Git, local absolute paths in `.xpr` files were normalized before commits using #repo_link("rtl/normalize_local_ip_xpr_paths.tcl", line: 1, branch: "feat/rollback").
This completed the workflow from RTL source changes to reusable packaged pipeline IP blocks in the Vivado block-design environment.


