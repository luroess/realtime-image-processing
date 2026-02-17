# Chapter 5: Source Management and Revision Control Recommendations

_Source lines: 3869-4279_

Chapter 5: Source Management and Revision Control Recommendations

Chapter 5

Source Management and Revision
Control Recommendations

Interfacing with Revision Control Systems

The methodologies for source management and revision control can vary depending on user
and company preference, as well as the software used to manage revision control. This section
describes some of the fundamental methodology choices that design teams need to make to
manage their active design projects. Specific recommendations on using the AMD Vivado™
Design Suite with revision control systems are provided later in this section. Throughout this
section, the term manage refers to the process of checking source versions in and out using a
revision control system.

Vivado generates many intermediate files as it compiles a design. This chapter defines the
minimum set of files necessary to recreate the design. In some cases, you might want to keep
intermediate files to improve compile time or simplify design analysis. Managing additional files is
always optional.

Project vs. Non-Project Build Methodologies
Vivado can compile designs using a project mode or a non-project mode. The Vivado project
mode manages file source sets, dependencies, and runs. The project mode can be driven by
scripts or interactively in the GUI. Non-project mode customers use scripts to compile their
designs directly from the design sources. In this mode, you are responsible for ensuring that your
scripts are up to date and the correct steps are re-run properly as sources are modified. This
chapter will primarily focus on how you should revision control Vivado projects, but, non-project
customers closely align to the script-based (project) method of revision controlling a Vivado
project described in the following sections. Although revision control should not dictate how
your designs are compiled, it is very important to understand the relationship between your
chosen compilation method and its impact on your revision control strategy.

UG892 (v2025.1) May 29, 2025
Design Flows Overview

85

Send Feedback
Chapter 5: Source Management and Revision Control Recommendations

Project Source Types

RTL, XDC, and DCP

In general, it is recommended that all design sources including RTL, XDC, and DCP files be kept
external to the project, and revision controlled independently of the Vivado project. The files
should be imported into the project using the add_* tcl commands as opposed to added to the
project using the import_*.

XCI

The recommended method to revision controlling IP includes:

• Preserving the IP repository

• Checking in the XCI file

The IP repository is where the parametrizable IP source code resides and the XCI file contains the
parameters to apply to the source code. The combination of these two sources enables Vivado to
regenerate the instance of the IP for your specific design. To recreate the project, the generated
IP does not need to be preserved because it can be rebuilt. If you are using custom packaged IP,
it is further recommended that you manage the project from which the IP was packaged.

The lastest version of all AMD IP are installed with Vivado. When upgrading a project to the
latest version of Vivado, the AMD IP repository will only contain the latest version of AMD IP.
Report IP Status will prompt you to upgrade your design to incorporate the new IP. Depending
on the IP changes, design modifications might be necessary to preserve the functionality of your
design. It is recommended that you upgrade AMD IP when upgrading to the latest version of
Vivado.

If you do not want to upgrade the IP you must revision control the IP XCI file along with the
IP output products that reside in the project.gen directory. The IP cannot be re-customized
because the original IP repo no longer exists. The generated output product must be preserved
to recreate the design. The output products essentially become project sources. The IP will be
locked and cannot be re-customized.

Locked IP can also be preserved using an XCIX file (also known as an IP core container). The XCIX
file contains the XCI file and the generated output products of the IP. This enables a single file
option for revision controlling a generated IP.

Note: Locked IP can always be upgraded to use the latest version of the IP and have the restrictions
associated with locked IP removed.

UG892 (v2025.1) May 29, 2025
Design Flows Overview

86

Send Feedback
Chapter 5: Source Management and Revision Control Recommendations

The final method for preserving IP uses Tcl. The command write_ip_tcl generates a Tcl script
that will recreate the IP based on the current configuration. Replaying the Tcl script will recreate
the XCI file. The generated Tcl script does not preserve the IP repository and therefor it is
mandatory that the repository be present when replaying the generated Tcl.

BD

To revision control a block design, the only file necessary to check in is the BD file itself.
Similar to IP, the IP repositories used by the BD must also be present. The BD file contains the
configuration of each IP on the canvas and the connections between the IP. The XCI files that
reside under the BD source directory contain the IP customizations after parameter propagation
is run during BD validation. Although these files are not required to recreate the design, they will
be automatically regenerated when the block diagram is re-validated. When the project is rebuilt
from the revision control repository, the BD and the XCI files that reside beneath the BD must be
writable. This is a limitation of the current version of Vivado.

A second method to preserve a BD is to use the write_bd_tcl command. This command
will generate a Tcl script to recreate the BD. The Tcl script preserves the IP customizations,
connections between the IP, and all BD properties that effect the design.

Note: To view the differences between two versions of a block diagram, see Vivado Design Suite User Guide:
Designing IP Subsystems Using IP Integrator (UG994) to learn more about the diffbd utility.

Note: When a block design container is used in a project the source BD resides in the .srcs folder. The
instances that are uniquified by parameter propagation reside in the .gen directory. When you restore the
project, only the source BD will be visible in the project, and the instance BDs will appear as missing files
in the hierarchical sources view. This is expected behavior. Regenerating the parent BD will recreate the
block design container instance BDs and recreate the original project.

Methods to Revision Control a Project

There are two primary methods for revision controlling a project: a script-based method and
a source-based method. The script-based method focuses on recreating the project from its
sources using a Tcl script. The source-based method revision controls the project sources and the
project file (.xpr) directly.

Note: An alternative to the two methods is to revision control the entire Vivado project directory. The
drawback to this method is the large amount of disk space required.

Script-based Revision Control Methodology

The following steps outline how revision controlling a project using a script-based method can be
achieved.

UG892 (v2025.1) May 29, 2025
Design Flows Overview

87

Send Feedback
Chapter 5: Source Management and Revision Control Recommendations

1. Keep source files external to the project. Ideally, the source files are kept outside of the

Vivado build directory.

2. Revision control the source repository. All sources should be managed by the revision control

system.

IMPORTANT! When Vivado is using the source files, they should be writable.

3. Generate a script to recreate the design.

4. Revision control the script. Once the script is created, it is important to manage this file as a

source too. As the design changes, this script must be updated to accommodate new sources
or to capture new design configurations. It is important that this script is managed like any
other design source.

5. Test your methodology. Ideally, to ensure no files are missed and the design rebuilds

completely from design sources using a script, the design would be regressed at a regular
cadence. By rebuilding the design regularly, any issues with the revision control methodology
can be caught and addressed in a timely manner.

Generating a Script to Recreate a Design

For a project flow, a script to recreate your design can be generated manually or by using
the write_project_tcl command. The advantages of manually creating the script, is that it
remains short and well organized. The drawback is that you could easily miss a project setting
and fail to faithfully recreate the original design. Any settings modified when the design is open
using either the GUI or the Tcl console must be reflected back to the script or there is a risk
the design is identical to the original project. Alternatively, the write_project_tcl script is
robust in ensuring all files are captured appropriately. Its versatility results in a more complicated
and more verbose script. Regardless of how this script is generated, it must be maintained as the
design evolves

Note: write_project_tcl recreates the design as originally created by the user. For designs using IP
integrator, propagated parameters do not reflect in the recreated design until validate_bd_design is
re-run.

Write_project_tcl provides two options to preserve block diagrams contained in the
project. The default option is to recreate the BD from Tcl. In this case, write_project_tcl
calls write_bd_tcl for each BD in the project. The resulting write_project_tcl script
contains the Tcl commands necessary to recreate each BD in the project. Alternatively, the BDs
can be included directly as a project source. In this case, the resulting Tcl script adds each BD
file, from the original project, directly to the project it recreates. If manually creating this project
script, a similar approach can be taken.

UG892 (v2025.1) May 29, 2025
Design Flows Overview

88

Send Feedback
Chapter 5: Source Management and Revision Control Recommendations

Source-based Revision Control Methodology

The source-based method for preserving a Vivado project relies on the separation of project
sources from their generated output products. The source-based method for preserving a Vivado
project relies on the separation of project sources from their generated output products. All
files added to a project reside in the project.srcs directory. All tool-generated output
products reside in a parallel directory called project.gen. The source-based method of
revision controlling can be achieved by:

• Keeping source files external to the project. Ideally, the source files are kept outside of the

Vivado build directory.

• Managing revision control of the source repository. All sources are managed by the revision

control system.

IMPORTANT! When Vivado is using the source files, they need to be writable.

• Managing revision control of the project.xpr file.

• Managing revision control of the project.srcs directory.

• Testing your methodology. Ideally, to ensure no files are missed and the design rebuilds

completely from design sources using a script, the design would be regressed at a regular
cadence. By rebuilding the design regularly, any issues with the revision control methodology
can be caught and addressed in a timely manner.

Note: Prior to 2020.2 all generated files coexisted in the project.srcs directory.

The project can be re-created by restoring the project.srcs directory and the project.xpr
file. The project.xpr file can be opened and the user can proceed with synthesis and
implementation.

Comparison between Script-based and Source-based
Revision Control Methodologies

The following table compares the two methods of revision controlling a Vivado project.

Table 5: Script-based and Source-based Revision Control Methodologies Comparison

Script-based

Source-based

Files to check in

Project XPR and .srcs directory

A script to regenerate the project
• Auto-generate with

write_project_tcl

○

Verbose
• Manually-generate

○

User must keep up-to-date

Size

Small

Medium

UG892 (v2025.1) May 29, 2025
Design Flows Overview

89

Send Feedback
Chapter 5: Source Management and Revision Control Recommendations

Table 5: Script-based and Source-based Revision Control Methodologies Comparison
(cont'd)

Compile time
• BD and IP sources
• Output products

External sources

Read-only capable
• BD sources
•
IP sources

Notes:

Script-based

Source-based

Slow
Must be rebuilt
Must be regenerated1

Medium
Available immediately
Must be regenerated1

Revision control separately

Revision control separately

Must be writable
Can be locked

Must be writable
Can be locked

1. Using out-of-context synthesis with external caching enabled, the compile time differences are negligible.

Comparing the files that need to be revision controlled, the script based is much smaller. No
matter if you auto generate the build script or manually create it, the only thing that needs to
be revision controlled is the script. Using the source based method, the XPR file and the .srcs
directory both need to be managed. These are much bigger than a text script. The benefits to
using the source-based methodology is that the project is available immediately. Once you check
out the XPR file and the .srcs directory, you can open the project. Using the script-based
methodology, the script needs to run to completion before you can open the project. In both
cases, AMD does not tend to revision control output products, and therefore to recompile the
designs, there will be considerable compute time spent recreating the output products. In both
cases, if an external cache is maintained, the compile time can be reduced significantly.

The remaining items are similar between the two flows. In both cases, all external sources need
to be revision controlled separately from the project. Also, in both cases, AMD does not fully
support having BDs or IPs completely read-only. BDs must be writable to run validation. Running
validation updates XCI files under the BD directory structure even if there are no design changes.
IP can be read-only, but if they are in this state the IP will be locked and unable to upgrade.

Other Files to Revision Control

The project manages many other types of files required to rebuild a design. Following are a few
examples:

• Simulation test benches

• HLS IP

• Pre/post Tcl hook scripts used for synthesis or implementation

• Incremental compile DCPs

• ELF and MEMDATA files

UG892 (v2025.1) May 29, 2025
Design Flows Overview

90

Send Feedback
Chapter 5: Source Management and Revision Control Recommendations

• AI Engine archives

Pay special attention to files that are used in the project but are not added directly. For example,
files that are referenced by a set_property command that is not added to the project sources.
These files should reside external to the project directory structure and revision controlled
separately.

Output Files to Optionally Revision Control

Following is a list of additional files you might consider revision controlling:

• Simulation scripts for third-party simulators generated by export_simulation. Because

these are typically hand-off files between design and verification, you might want to snapshot
them at different stages of the design process.

• XSA files. These are hardware hand-off files between Vivado and AMD Vitis™ software

platform.

• Bitsteams/PDIs.

• LTX files for hardware debug.

• Intermediate DCP files created during the flow.

• IP output products.

Archiving Designs

The archive_project command can compress your entire project into a zip file. This
command has several options for storing sources and to run results. Essentially, the entire project
is copied locally in the memory and then zipped into a file on the disk while leaving the original
project intact. This command also copies any remote source into the archive.

This feature is useful for sending your design description to another person or to store as a self
contained entity. You might also need to send your version of vivado_init.tcl if you are
using this file to set specific parameters or variables that affect the design. For more information,
see the following resources:

• Vivado Design Suite User Guide: System-Level Design Entry (UG895)

• Vivado Design Suite QuickTake Video: Creating Different Types of Projects

• Vivado Design Suite QuickTake Video: Managing Sources with Projects

UG892 (v2025.1) May 29, 2025
Design Flows Overview

91

Send Feedback
