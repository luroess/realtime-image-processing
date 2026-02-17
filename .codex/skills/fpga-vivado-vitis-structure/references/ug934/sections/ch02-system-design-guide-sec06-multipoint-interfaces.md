# Multipoint Interfaces

_Parent: Chapter 2: System Design Guide_
_Source lines: 3003-3061_

Multipoint Interfaces

• Genlock mode: Write side and read side individually freewheels.

•

•

Same Frame Readout mode: Write side freewheels, but all read sides need to read out
the same frame.

Synchronizer mode: All frames written need to be read out on all ports.

Incorrect Timing Information

There can be some discrepancy between the measured frame dimensions based on EOL and
SOF locations and the frame dimensions the AXI-VDMA programmed through the AXI4-Lite
interface. This is often due to programming or communication errors.

When the number of pixels between subsequent EOL pulses is less than the line-length
programmed into the AXI-VDMA core, the core triggers an interrupt indicating the error.
The AXI-VDMA line pointer moves forward to the next line. Data received after received EOL
is written to the start of a new line. No padding data is written to the frame buffer to
complete the line as programmed to the core.

When the number of pixels between subsequent EOL pulses is more than the line-length
programmed into the AXI-VDMA, the core triggers an interrupt indicating the error and
drops extraneous pixels until EOL is received.

When the number of lines between subsequent SOF pulses is less than the line-length
programmed into the AXI-VDMA, the core triggers an interrupt indicating the error and the
frame pointer moves forward to the next line. Data received after received SOF is written to
the next frame in the buffer. No padding data is written to the buffer to complete the frame
as programmed to the AXI-VDMA core.

When the number of lines between subsequent SOF pulses is more than the line-length
programmed into the AXI-VDMA, the core triggers an interrupt indicating the error and
drops extraneous lines until SOF is received.

Multipoint Interfaces

Some applications require a single AXI4-Stream master interface connected to multiple
slaves, such as a stream splitter, or multiple master interfaces to be connected to a single
slave, such as a stream combiner.

For video applications, the use of stream combiners is discouraged. Without the TID and
TDEST fields, pixel sources are ambiguous. The recommended solution is to create separate
slave component interfaces on the receiver IP to the IP to distinguish data received from
different sources, if necessary. No explicit video IP is provided to split AXI4-Streams. HDL
and EDK users can easily implement the video splitter with AND gates.

AXI4-Stream Video IP and System Design
UG934 November 16, 2022

www.xilinx.com

27

Send Feedback
