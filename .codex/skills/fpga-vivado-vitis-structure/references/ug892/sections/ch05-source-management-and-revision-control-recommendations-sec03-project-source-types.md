# Project Source Types

_Parent: Chapter 5: Source Management and Revision Control Recommendations_
_Source lines: 3911-3990_

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
