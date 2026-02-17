# Other Files to Revision Control

_Parent: Chapter 5: Source Management and Revision Control Recommendations_
_Source lines: 4205-4234_

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
