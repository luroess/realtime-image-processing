# Methods to Revision Control a Project

_Parent: Chapter 5: Source Management and Revision Control Recommendations_
_Source lines: 3991-4204_

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
