# Interfacing with Revision Control Systems

_Parent: Chapter 5: Source Management and Revision Control Recommendations_
_Source lines: 3876-3890_

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
