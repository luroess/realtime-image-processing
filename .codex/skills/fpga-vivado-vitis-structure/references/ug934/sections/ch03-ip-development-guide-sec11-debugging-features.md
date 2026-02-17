# Debugging Features

_Parent: Chapter 3: IP Development Guide_
_Source lines: 7811-7907_

Debugging Features

In EDK, the interrupt controller (INTC) IP can be used to integrate IRQ pins for the system
processor. For Vivado® tools, you might need to create a custom built priority interrupt
controller to aggregate interrupt requests and identify interrupt sources.

Video IP core APIs, including registers and driver functions, should enable application
software developers to identify and clear interrupt sources within the IP.

Debugging Features

The following sections recommend video IP core features which ease and accelerate system
design, starting up and debug.

Version Register

Bit fields of the Version Register facilitate identification of the exact version of the hardware
peripheral incorporated into a system. The core driver uses this Read-Only value to verify
that the software is matched to the correct version of the hardware.

Recommended bit assignments of the version register are:

•

•

•

•

•

Bits 7-0: REVISION_NUMBER

Bits 11-8: PATCH_ID

Bits 15-12: VERSION_REVISION

Bits 23-16: VERSION_MINOR

Bits 31-24: VERSION_MAJOR

Core Bypass Option

If conceptually possible, video processing IP cores should facilitate an optional straight
through connection between input (AXI4-Stream slave) and output (AXI4-Stream master)
by-passing any processing functionality.

Use Flag BYPASS, located on bit 4 of the CONTROL register, to turn bypassing on (1) or off.
For single-clock-domain IP cores, this switch can control multiplexers in the AXI4-Stream
path. For applications where the input and output AXI4-Stream interfaces are in different
clock domains, the bypass multiplexers select between a clock-domain crossing FIFO
implemented using distributed memory and the actual video processing core.

AXI4-Stream Video IP and System Design
UG934 November 16, 2022

www.xilinx.com

76

Send Feedback
Debugging Features

Built in Test-Pattern Generator

If conceptually possible, video processing IP should offer an optional built-in test-pattern
generator to temporarily feed the output AXI4-Stream master interface with a predefined
pattern.

Use Flag TEST_PATTERN, located on bit 5 of the CONTROL register to turn test-pattern
generation on (1) or off. This switch can control multiplexers driving the AXI4-Stream master
output and switch between the regular core processing output and the test-pattern
generator. When enabled, a set of counters should generate 256 scan-lines of color-bars,
each color bar 64 pixels wide, repetitively cycling through the colors Black, Red, Green,
Yellow, Blue, Magenta, Cyan, and White until the end of each scan line. After the Color-Bars
segment is processed, the remainder of the frame should be filled with a monochrome
horizontal + vertical ramp.

Throughput Monitors

To debug frame-buffer bandwidth limitation issues, and if possible allow video application
software to balance memory pathways, video IP cores should offer frame, line, and pixel
counter registers.

The recommended name and location of these registers are SYSDEBUG0, SYSDEBUG1 and
SYSDEBUG2, as indicated in Table 3-2. The registers should initialize to 0 after reset, but the
core might implement other, additional mechanisms to clear the counters.

AXI4-Stream Video IP and System Design
UG934 November 16, 2022

www.xilinx.com

77

Send Feedback
