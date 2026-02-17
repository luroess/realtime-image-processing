# Project vs. Non-Project Build Methodologies

_Parent: Chapter 5: Source Management and Revision Control Recommendations_
_Source lines: 3891-3910_

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
