# Chapter 1: Introduction

_Source lines: 34-875_

Chapter 1: Introduction
Navigating Content by Design Process
AMD Adaptive Computing documentation is organized around a set of standard design processes to
help you find relevant content for your current development task. You can access the AMD Versal™
adaptive SoC design processes on the Design Hubs page. You can also use the Design Flow Assistant to
better understand the design flows and find content that is specific to your intended design needs. This
document covers the following design processes:

Hardware, IP, and Platform Development

Creating the PL IP blocks for the hardware platform, creating PL kernels, functional simulation,
and evaluating the AMD Vivado™ timing, resource use, and power closure. Also involves
developing the hardware platform for system integration.

System Integration and Validation

Integrating and validating the system functional performance, including timing, resource use, and
power closure.

Board System Design

Designing a PCB through schematics and board layout. Also involves power, thermal, and signal
integrity considerations.


Overview of Tcl Capabilities in Vivado
The Tool Command Language (Tcl) is the scripting language integrated in the AMD Vivado™ tool
environment. Tcl is a standard language in the semiconductor industry for application programming
interfaces, and is used by Synopsys Design Constraints (SDC).
®


SDC is the mechanism for communicating timing constraints for FPGA synthesis tools from Synopsys
Synplify as well as other vendors, and is a timing constraint industry standard; consequently, the Tcl
infrastructure is a best practice for scripting language.

Tcl lets you perform interactive queries to design tools in addition to executing automated scripts. Tcl
offers the ability to ask questions interactively of design databases, particularly around tool and design
settings and state. Examples are: querying specific timing analysis reporting commands live, applying
incremental constraints, and performing queries immediately after to verify expected behavior without
re-running any tool steps.

The following sections describe some of the basic capabilities of Tcl with Vivado.


UG835 v2025.2 3
Send Feedback
November 20, 2025

## Page 004
<!-- page:4 -->
Introduction


Note: This manual is not a comprehensive reference for the Tcl language. It is a reference to the
specific capabilities of the Vivado Design Suite Tcl shell, and provides reference to additional Tcl
programming resources.


Launching the Vivado Design Suite
You can launch the Vivado Design Suite and run the tools using different methods depending on your
preference. For example, you can choose a Tcl script-based compilation style method in which you
manage sources and the design process yourself, also known as Non-Project Mode. Alternatively, you
can use a project-based method to automatically manage your design process and design data using
projects and project states, also known as Project Mode. Either of these methods can be run using a Tcl
scripted batch mode or run interactively in the Vivado IDE. For more information on the different design
flow modes, see the Vivado Design Suite User Guide: Design Flows Overview (UG892).

Tcl Shell Mode
If you prefer to work directly with Tcl commands, you can interact with your design using Tcl commands
with one of the following methods:
• Enter individual Tcl commands in the Vivado Design Suite Tcl shell outside of the Vivado IDE.
• Enter individual Tcl commands in the Tcl Console at the bottom of the Vivado IDE.
• Run Tcl scripts from the Vivado Design Suite Tcl shell.
• Run Tcl scripts from the Vivado IDE.

Use the following command to invoke the Vivado Design Suite Tcl shell either at the Linux command
prompt or within a Windows Command Prompt window:
vivado -mode tcl


Tip: On Windows, you can also select Start > All Programs > Xilinx Design Tools > Vivado yyyy.x >
Vivado yyyy.x Tcl Shell, where “yyyy.x” is the installed version of Vivado.

For more information about using Tcl and Tcl scripting, see the Vivado Design Suite User Guide: Using
Tcl Scripting (UG894). For a step-by-step tutorial that shows how to use Tcl in the Vivado tool, see the
Vivado Design Suite Tutorial: Design Flows Overview (UG888).

Tcl Batch Mode
You can use the Vivado tools in batch mode by supplying a Tcl script when invoking the tool. Use the
following command either at the Linux command prompt or within a Windows Command Prompt
window:
vivado -mode batch -source <your_Tcl_script>

The Vivado Design Suite Tcl shell will open, run the specified Tcl script, and exit when the script
completes. In batch mode, you can queue up a series of Tcl scripts to process a number of designs


UG835 v2025.2 4
Send Feedback
November 20, 2025

## Page 005
<!-- page:5 -->
Introduction


overnight through synthesis, simulation, and implementation, and review the results on the following
morning.

You can also pass arguments to the Vivado command when sourcing a Tcl script in batch mode. The -
tclargs option lets you specify arguments for the Tcl script you are running. For example:
vivado -mode batch -source script.tcl -tclargs "FPGA=115-2"


Important: You must enclose the Tcl argument and value in quotes as shown in the example above, or
there can be an error in handling the argument.


Vivado IDE Mode
You can launch the Vivado Design Suite and run the tools using different methods depending on your
preference. For example, you can choose a Tcl script-based compilation style method in which you
manage sources and the design process yourself, also known as Non-Project Mode. Alternatively, you
can use a project-based method to automatically manage your design process and design data using
projects and project states, also known as Project Mode. Either of these methods can be run using a Tcl
scripted batch mode or run interactively in the Vivado IDE. For more information on the different design
flow modes, see the Vivado Design Suite User Guide: Design Flows Overview (UG892).

If you prefer to work in a GUI, you can launch the Vivado IDE from Windows or Linux. For more
information on the Vivado IDE, see the Vivado Design Suite User Guide: Using the Vivado IDE (UG893).

Launch the Vivado IDE from your working directory. By default the Vivado journal and log files, and any
generated report files, are written to the directory from which the Vivado tool is launched. This makes it
easier to locate the project file, log files, and journal files, which are written to the launch directory.

In the Windows OS, select Start > All Programs > Xilinx Design Tools > Vivado yyyy.x > Vivado yyyy.x
Tcl Shell, where “yyyy.x” is the installed version of Vivado.

Tip: You can also double-click the Vivado IDE shortcut icon on your Windows desktop.

In the Linux OS, enter the following command at the command prompt:
vivado -or- vivado -mode gui

If you need help, with the Vivado tool command line executable, type:
vivado -help

If you are running the Vivado tool from the Vivado Design Suite Tcl shell, you can open the Vivado IDE
directly from the Tcl shell by using the start_gui command.

From the Vivado IDE, you can close the Vivado IDE and return to a Vivado Tcl shell by using the
stop_gui command.


UG835 v2025.2 5
Send Feedback
November 20, 2025

## Page 006
<!-- page:6 -->
Introduction


Tcl Journal Files
When you invoke the Vivado tool, it writes the vivado.log file to record the various commands and
operations performed during the design session. The Vivado tool also writes a file called vivado.jou which
is a journal of just the Tcl commands run during the session. The journal file can be used as a source to
create new Tcl scripts.

Note: Backup versions of the journal file, named vivado_<id>.backup.jou, are written to save the
details of prior runs whenever the Vivado tool is launched. The <id> is a unique identifier that allow
the tool to create and store multiple backup versions of the log and journal files.


Tcl Help
The Tcl help command provides information related to the supported Tcl commands.
• help – Returns a list of Tcl command categories.

help
Command categories are groups of commands performing a specific function, like File I/O for
instance.
• help -category category – Returns a list of commands found in the specified category.

help -category object
This example returns the list of Tcl commands for handling objects.
• help pattern – Returns a list of commands that match the specified search pattern. This form can be
used to quickly locate a specific command from a group of commands.
help get_*
This example returns the list of Tcl commands beginning with get_.
• help command – Provides detailed information related to the specified command.

help get_cells
This example returns specific information of the get_cells command.
• help -args command – Provides an abbreviated help text for the specified command, including the
command syntax and a brief description of each argument.
help -args get_cells
• help -syntax command – Reports the command syntax for the specified command.

help -syntax get_cells


UG835 v2025.2 6
Send Feedback
November 20, 2025

## Page 007
<!-- page:7 -->
Introduction


Scripting in Tcl
Tcl Initialization Scripts

Tip: The following describes where you can place Vivado_init.tcl scripts if you would like to customize
Vivado on startup. No Vivado_init.tcl scripts are provided in the Vivado release by default.
When you start the Vivado tool, it looks for a Tcl initialization script in three different locations, each one
overriding the last one found:

1. Enterprise: In the software installation directory, <installdir>/Vivado/<version>/scripts/Vivado_init.tcl
2. Vivado Version: In a local user directory, for a specific version of the Vivado Design Suite:
◦ For Windows 7: %APPDATA%/Xilinx/Vivado/<version>/Vivado_init.tcl
◦ For Linux: $HOME/.Xilinx/Vivado/<version>/Vivado_init.tcl

3. Vivado User: In a local user directory, for the general Vivado Design Suite:
◦ For Windows 7: %APPDATA%/Xilinx/Vivado/Vivado_init.tcl
◦ For Linux: $HOME/.Xilinx/Vivado/Vivado_init.tcl

Where:
• <installdir> is the installation directory where the Vivado Design Suite is installed.

If Vivado_init.tcl exists, in one or all of these locations, the Vivado tool sources this file, in the order
described above.
• The Vivado_init.tcl file in the installation directory allows a company or design group to support
a common initialization script for all users. Anyone starting the Vivado tool from that installation
location sources the enterprise Vivado_init.tcl script.
• A user's Vivado_init.tcl file in the home directory allows each user to specify additional commands, or
to override commands from the software installation to meet their specific design requirements.
• No Vivado_init.tcl file is provided with the Vivado Design Suite installation. You must create the
Vivado_init.tcl file and place it in either the installation directory, or your home directory, as discussed
to meet your specific needs.

Tip: Other tools in the Vivado Design Suite also support initialization scripts in the following
form: <tool>_init.tcl, where <tool> can include Vivado, vivado_lab, xsim, and xelab.

The Vivado_init.tcl file is a standard Tcl command file that can contain any valid Tcl command supported
by the Vivado tool. You can also source another Tcl script file from within Vivado_init.tcl by adding the
following statement:

source <path_to_file>/<file_name>.tcl


UG835 v2025.2 7
Send Feedback
November 20, 2025

## Page 008
<!-- page:8 -->
Introduction


Note: You can also specify the -init option when launching the Vivado Design Suite from the
command line. Type vivado -help for more information.


Sourcing a Tcl Script
A Tcl script can be sourced from either one of the command-line options or from the GUI. Within the
Vivado Integrated Design Environment (IDE) you can source a Tcl script from Tools > Run Tcl Script.

You can source a Tcl script from a Tcl command-line option:
source <file_name>

When you invoke a Tcl script from the Vivado IDE, a progress bar is displayed and all operations in the
IDE are blocked until the scripts completes.

There is no way to interrupt script execution during run time; consequently, standard OS methods of
killing a process must be used to force interruption of the tool. If the process is killed, you lose any work
done since your last save.

Typing help source in the Tcl console will provide additional information regarding the source command.

Using Tcl.pre and Tcl.post Hook Scripts
Tcl Hook scripts allow you to run custom Tcl scripts prior to (tcl.pre) and after (tcl.post) synthesis and
implementation design runs, or any of the implementation steps. Whenever you launch a run, the
Vivado tool uses a predefined Tcl script which executes a design flow based on the selected strategy. Tcl
Hook scripts let you customize the standard flow, with pre-processors or post-processors, such as for
generating custom reports. The Tcl Hook script must be a standard Tcl script.

Every step in the design flow has a pre- and post-hook capability. Common examples are:
• Custom reports: timing, power, utilization, or any user-defined tcl report.
• Temporary parameters for workarounds.
• Over-constraining timing constraints for portions of the flow.
• Multiple iterations of stages (e.g. multiple calls to phys_opt_design).
• Modifications to netlist, constraint, or device programming.

Important: Relative paths within the tcl.pre and tcl.post scripts are relative to the appropriate run
directory of the project they are applied to: <project>/<project.runs>/<run_name>. You can use the
DIRECTORY property of the current project or current run to define the relative paths in your Tcl
hook scripts:
get_property DIRECTORY [current_project]
get_property DIRECTORY [current_run]


For more information on defining Tcl Hook scripts, refer to the Vivado Design Suite User Guide: Using Tcl
Scripting (UG894).


UG835 v2025.2 8
Send Feedback
November 20, 2025

## Page 009
<!-- page:9 -->
Introduction


General Tcl Syntax Guidelines
Tcl uses the Linux file separator (/) convention regardless of which Operating System you are running.

The following subsections describe the general syntax guidelines for using Tcl in the Vivado Design Suite.

Using Tcl Eval
When executing Tcl commands, you can use variable substitution to replace some of the command line
arguments accepted or required by the Tcl command. However, you must use the Tcl eval command to
evaluate the command line with the Tcl variable as part of the command.

For instance, the help command can take the -category argument, with one of a number of command
categories as options:
help -category ipflow

You can define a variable to hold the command category:
set cat "ipflow"

Where:
• set is the Tcl keyword that defines the variable.
• cat is the name of the variable being defined.
• "ipflow" is the value assigned to the variable.

You can then evaluate the variable in the context of the Tcl command:
eval help -category $cat

or,
set cat "category ipflow" eval help $cat

You can also use braces {} in place of quotation marks “” to achieve the same result:
set runblocksOptDesignOpts { -sweep -retarget -propconst -remap }
eval opt_design $runblocksOptDesignOpts

Typing help eval in the Tcl console will provide additional information regarding the eval command.


Using Special Characters
Some commands take arguments that contain characters that have special meaning to Tcl. Those
arguments must be surrounded with curly braces {} to avoid unintended processing by Tcl. The most
common cases are as follows.

Bus Indexes - Because square brackets [] have special meaning to Tcl, an indexed (bit- or part-selected)
bus using the square bracket notation must be surrounded with curly braces. For example, when adding
index 4 of a bus to the Vivado Common Waveform Viewer window using the square bracket notation,
you must write the command as:
add_wave {bus[4]}


UG835 v2025.2 9
Send Feedback
November 20, 2025

## Page 010
<!-- page:10 -->
Introduction


Parentheses can also be used for indexing a bus, and because parentheses have no special meaning to
Tcl, the command can be written without curly braces. For example:
add_wave bus(4)

Verilog Escaped Identifiers - Verilog identifiers containing characters or keywords that are reserved by
Verilog need to be “escaped” both in the Verilog source code and on the simulator command line by
prefixing the identifier with a backslash "\" and appending a space. Additionally, on the Tcl command line
the escaped identifier must be surrounded with curly braces.

Note: If an identifier already includes a curly brace, then the technique of surrounding the identifier
with curly braces does not work, because Tcl interprets curly braces as reserved characters even
nested within curly braces. Instead, you must use the technique described below, in VHDL Extended
Identifiers.

For example, to add a wire named "my wire" to the Vivado Common Waveform Viewer window, you
must write the command as:
add_wave {\my wire }


Note: Be sure to append a space after the final character, and before the closing brace.

Verilog allows any identifier to be escaped. However, on the Tcl command line do not escape identifiers
that are not required to be escaped. For example, to add a wire named "w" to the Vivado Common
Waveform Viewer window, the Vivado simulator would not accept:
add_wave {\w }

as a valid command, since this identifier (the wire name "w") does not required to be escaped. The
command must be written as:
add_wave w

VHDL Extended Identifiers - VHDL extended identifiers contain backslashes, "\", which are reserved
characters in Tcl. Because Tcl interprets a backslash next to a close curly brace \} as being a close curly
brace character, VHDL extended identifiers cannot be written with curly braces. Instead, the curly
braces must be absent and each special character to Tcl must be prefixed with a backslash. For example,
to add the signal \my sig\ to the Wave window, you must write the command as:
add_wave \\my\ sig\\


Note: Both the backslashes that are part of the extended identifier, and the space inside the
identifier are prefixed with a backslash.


General Syntax Structure
The general structure of Vivado Design Suite Tcl commands is:

command [optional_parameters] required_parameters


UG835 v2025.2 10
Send Feedback
November 20, 2025

## Page 011
<!-- page:11 -->
Introduction


Command syntax is of the verb-noun and verb-adjective-noun structure separated by the underscore
(“_”) character.

Commands are grouped together with common prefixes when they are related.
• Commands that query things are generally prefixed with get_.
• Commands that set a value or a parameter are prefixed with set_.
• Commands that generate reports are prefixed with report_.
The commands are exposed in the global namespace. Commands are “flattened,” meaning there are no
“sub-commands” for a command.


Example Syntax
The following example shows the return format on the get_cells -help command:
get_cells

Description:
Get a list of cells in the current design

Syntax:
get_cells [-hsc <arg>] [-hierarchical] [-regexp] [-nocase] [-filter <arg>]
[-of_objects <args>] [-match_style <arg>] [-quiet] [-verbose]
[<patterns>]

Returns:
list of cell objects

Usage:
Name Description
----------------------------
[-hsc] Hierarchy separator
Default: /
[-hierarchical] Search level-by-level in current instance
[-regexp] Patterns are full regular expressions
[-nocase] Perform case-insensitive matching (valid only when -regexp
specified)
[-filter] Filter list with expression
[-of_objects] Get cells of these pins, timing paths, nets, bels, sites
or drc violations
[-match_style] Style of pattern matching
Default: sdc
Values: ucf, sdc
[-quiet] Ignore command errors
[-verbose] Suspend message limits during command execution
[<patterns>] Match cell names against patterns
Default: *

Categories:
SDC, XDC, Object


Unknown Commands
Tcl contains a list of built-in commands that are generally supported by the language, Vivado tool specific
commands which are exposed to the Tcl interpreter, and user-defined procedures.

UG835 v2025.2 11
Send Feedback
November 20, 2025

## Page 012
<!-- page:12 -->
Introduction


Commands that do not match any of these known commands are sent to the OS for execution in the
shell from the exec command. This lets users execute shell commands that might be OS-specific. If there
is no shell command, then an error message is issued to indicate that no command was found.


Return Codes
Some Tcl commands are expected to provide a return value, such as a list or collection of objects on
which to operate. Other commands perform an action but do not necessarily return a value that can be
used directly by the user. Some tools that integrate Tcl interfaces return a 0 or a 1 to indicate success or
error conditions when the command is run.

To properly handle errors in Tcl commands or scripts, you should use the Tcl built-in command catch.
Generally, the catch command and the presence of numbered info, warning, or error messages should be
relied upon to assess issues in Tcl scripted flows.

Vivado tool Tcl commands return either TCL_OK or TCL_ERROR upon completion. In addition, the
Vivado Design Suite sets the global variable $ERRORINFO through standard Tcl mechanisms.

To take advantage of the $ERRORINFO variable, use the following line to report the variable after an
error occurs in the Tcl console:

puts $ERRORINFO

This reports specific information to the standard display about the error. For example, the following code
example shows a Tcl script (procs.tcl) being sourced, and a user-defined procedure (loads) being run.
There are a few transcript messages, and then an error is encountered at line 5.
Line 1: Vivado % source procs.tcl
Line 2: Vivado% loads
Line 3: Found 180 driving FFs
Line 4: Processing pin a_reg_reg[1]/Q...
Line 5: ERROR: [HD-Tcl 53] Cannot specify '-patterns' with '-of_objects'.
Line 6: Vivado% puts $errorInfo
Line 7: ERROR: [HD-Tcl 53] Cannot specify '-patterns' with '-of_objects'.
While executing "get_ports -of objects $pin" (procedure "my_report" line 6)
invoked from within procs.tcl

You can add puts $ERRORINFO into catch clauses in your Tcl script files to report the details of an error
when it is caught, or use the command interactively in the Tcl console immediately after an error is
encountered to get the specific details of the error.

In the example code above, typing the puts $ERRORINFO command in line 6, reports detailed information
about the command and its failure in line 7.


First Class Tcl Objects and Relationships
The Tcl commands in the Vivado Design Suite provide direct access to the object models for netlist,
devices, and projects. These are Vivado first-class objects, which means they are more than just a string
representation, and they can be operated on and queried. There are a few exceptions to this rule, but


UG835 v2025.2 12
Send Feedback
November 20, 2025

## Page 013
<!-- page:13 -->
Introduction


generally “things” can be queried as objects, and these objects have properties that can be queried and
they have relationships that allow you to get to other objects.

Object Types and Definitions
There are many object types in the Vivado Design Suite; this chapter provides definitions and
explanations of the basic types. The most basic and important object types are associated with entities in
a design netlist, and these types are listed in the following subsections:

Cell

A cell is an instance, either primitive or hierarchical inside a netlist. Examples of cells include flip-
flops, LUTs, I/O buffers, RAM and DSPs, as well as hierarchical instances which are wrappers for
other groups of cells.

Pin

A pin is a point of logical connectivity on a cell. A pin allows the internals of a cell to be
abstracted away and simplified for easier use, and can either be on hierarchical or primitive cells.
Examples of pins include clock, data, reset, and output pins of a flop.

Port

A port is a connection at an object boundary used to connect internal content to the outside of
the object. Ports in the top-level netlist or design are normally attached to I/O pads on the die,
connected to pins on the device package, and connected externally to the device in a system-
level design. Ports inside of a hierarchical cell, module, or entity, are represented as pins on the
hierarchical cell.

Net

A net is a wire or list of wires that eventually be physically connected directly together. Nets can
be hierarchical or flat, but always sorts a list of pins together.

Clock

A clock is a periodic signal that propagates to sequential logic within a design. Clocks can be
primary clock domains or generated by clock primitives such as a DCM, PLL, or MMCM. A clock
is the rough equivalent to a TIMESPEC PERIOD constraint in UCF and forms the basis of static
timing analysis algorithms.


Querying Objects
All first class objects can be queried by a get_* Tcl command that generally has the following syntax:
get_<object_type> <pattern>

Where pattern is a search <pattern>, which includes if applicable a hierarchy separator to get a fully
qualified name. Objects are generally queried by a string pattern match applied at each level of the


UG835 v2025.2 13
Send Feedback
November 20, 2025

## Page 014
<!-- page:14 -->
Introduction


hierarchy, and the search pattern also supports wildcard style search patterns to make it easier to find
objects, for example:
get_cells */inst_1

This command searches for a cell named inst_1 within the first level of hierarchy under the top-level of
hierarchy. To recursively search for a pattern at every level of hierarchy, use the following syntax:
get_cells -hierarchical inst_

This command searches every level of hierarchy for any instances that match inst_1.

For complete coverage of the command syntax, see the specific online help for the individual command:
help get_cells

or

get_cells -help


Object Properties
Objects have properties that can be queried. Property names are unique for any given object type. To
query a specific property for an object, the following command is provided:
get_property <property_name> <object>

For example, the lib_cell property on cell objects tells you what UniSim component a given instance is
mapped to:
get_property lib_cell [get_cell inst_1]

To discover all of the available properties for a given object type, use the report_property command:
report_property [get_cells inst_1]


Table 1: Properties Returned by Object

Key Value Type
bel OLOGICE1.OUTFF string
class cell string
iob TRUE string
is_blackbox 0 bool
is_fixed 0 bool
is_partition 0 bool
is_primitive 1 bool
is_reconfigurable 0 bool
is_sequential 1 bool
lib_cell FD string
loc OLOGIC_X1Y27 string
name error string
primitive_group FD_LD string
primitive_subgroup flop string
site OLOGIC_X1Y27 string
type FD & LD string
XSTLIB 1 bool

UG835 v2025.2 14
Send Feedback
November 20, 2025

## Page 015
<!-- page:15 -->
Introduction


Some properties are read-only and some are user-settable. Properties that map to attributes that can be
annotated in UCF or in HDL are generally user-settable through Tcl with the set_property command:
set_property loc OLOGIC_X1Y27 [get_cell inst_1]


Filtering Based on Properties
The object query get_* commands have a common option to filter the query based on any property
value attached to the object. This is a powerful capability for the object query commands. For example,
to query all cells of primitive type FD do the following:
get_cells * -hierarchical -filter “lib_cell == FD”

To do more elaborate string filtering, utilize the =~ operator to do string pattern matching. For example,
to query all flip-flop types in the design, do the following:
get_cells * -hierarchical -filter “lib_cell =~ FD*”

Multiple filter properties can be combined with other property filters with logical OR (||) and AND (&&)
operators to make very powerful searches. To query every cell in the design that if of any flop type and
has a placed location constraint:
get_cells * -hierarchical -filter {lib_cell =~ FD* && loc != “”}


Note: In the example, the filter option value was wrapped with curly braces {} instead of double
quotes. This is normal Tcl syntax that prevents command substitution by the interpreter and allows
users to pass the empty string (“”) to the loc property.


Handling Lists of Objects
Commands that return more than one object, such as get_cells or get_sites, return a collection
in the Vivado tool that looks and behaves like a native Tcl list. This feature allows performance
gains when handling large lists of Tcl objects without the need to use special commands like the
foreach_in_collection command. In the Vivado Design Suite collections can be processed like Tcl lists
using built-in commands such as lsort, lsearch, and foreach.

Typically, when you run a get_* command, the returned results are echoed to the console and to the
log file as a Tcl string, rather than as a list due to a feature of Tcl called "shimmering". Internally, Tcl can
store a variable or value both as a string and as a faster native object such as a float or a list object. In
Tcl, shimmering occurs when the representation of the object or value changes from the list object to the
string object, or from string to list. A list of Vivado objects is returned by the get_* command, but the
shimmered string representation is written to the log file and Tcl console.

However, to improve performance and prevent overloading memory buffers, the Vivado Design
Suite limits and truncates the shimmered string to a default character length defined by the
tcl.collectionResultDisplayLimit parameter, which has a default value of 500. Commands
that can return a significant number of objects, such as get_cells or get_sites, will truncate the
returned string, ending it with an ellipsis ('...'). You can use the set_param command to change the
tcl.collectionResultDisplayLimit parameter value to return more or fewer results.


UG835 v2025.2 15
Send Feedback
November 20, 2025

## Page 016
<!-- page:16 -->
Introduction


CAUTION: The combination of shimmering and the tcl.collectionResultDisplayLimit parameter
prevents the use of in and ni list operators in the Vivado Design Suite. Since a string shimmered
from the list may be truncated, the in and ni operators cannot effectively determine if a specified
object is in, or not-in, a list of objects. You should use list commands such as lsearch and lsort
instead of in or ni.
if {[lsearch -exact [get_cells *] $cellName] != -1} {...}


You can capture the complete list returned by the get_* command by assigning the results to a Tcl
variable:
set allSites [get_sites]

The actual list in the variable assignment includes the complete result set, and is not truncated by the
tcl.collectionResultDisplayLimit parameter. An example of this is seen in hierarchically querying all
the cells in a design:
%set allCells [get_cells -hierarchical]
DataIn_pad_0_i_IBUF[0]_inst DataIn_pad_0_i_IBUF[1]_inst \
DataIn_pad_0_i_IBUF[2]_inst DataIn_pad_0_i_IBUF[3]_inst \
DataIn_pad_0_i_IBUF[4]_inst ...
%llength $allCells
42244
%lindex $allCells end
wbArbEngine/s4/next_reg

In the preceding example, the result of the hierarchical get_cells command was assigned to the
$allCells variable. In appearance, the results are truncated. However, a check of the length of the list
reports more than forty thousand cell objects, and the last index in the list returns an actual object, and
not an ellipsis.


Tip: If necessary, you can also use the join command, to join the list of objects returned by the get_*
Tcl command, with a newline (\n), tab (\t), or a space (" "), to display the un-truncated list of objects:
join [get_parts] " "


Object Relationships
Related objects can be queried using the -of option to the relevant get_* command. For example, to get
a list of pins connected to a cell object, do the following:
• get_pins -of [get_cells inst_1]

The following image shows object types in the Vivado tool and their relationships, where an arrow from
one object to another object indicates that you can use the -of option to the get_* command to traverse
logical connectivity and get Tcl references to any connected object. For more information on first class
objects and their relationships, refer to the Vivado Design Suite Properties Reference Guide (UG912).


UG835 v2025.2 16
Send Feedback
November 20, 2025

## Page 017
<!-- page:17 -->
Introduction


Figure 1: First Class Object Relationships


Net
Port


Pin
Clock

Timing
Cell
Path


Bel Pin

Clock
Bel
Region

Package
S ite S ite Pin
Pin


I/O Bank
Tile
I/O
S tandard


X 25296- 040621


Errors, Warnings, Critical Warnings, and Info Messages
Messages that result from individual commands appear in the log file as well as in the GUI console if it
is active. These messages are generally numbered to identify specific issues and are prefixed in the log
file with “INFO”, “WARNING”, “CRITICAL_Warning”, “ERROR” followed by a subsystem identifier and a
unique number.

The following example shows an INFO message that appears after reading the timing library.
INFO: [HD-LIB 1] Done reading timing library

These messages make it easier to search for specific issues in the log file to help to understand the
context of operations during command execution.

Generally, when an error occurs in a Tcl command sourced from a Tcl script, further execution of
subsequent commands is halted. This is to prevent unrecoverable error conditions. There are Tcl built-ins
that allow users to intercept these error conditions, and to choose to continue. Consult any Tcl reference
for the catch command for a description of how to handle errors using general Tcl mechanisms.


UG835 v2025.2 17
Send Feedback
November 20, 2025

## Page 018
<!-- page:18 -->
Tcl Commands
