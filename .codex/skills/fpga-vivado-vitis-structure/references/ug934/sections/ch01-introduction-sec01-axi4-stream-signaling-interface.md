# AXI4-Stream Signaling Interface

_Parent: Chapter 1: Introduction_
_Source lines: 95-366_

AXI4-Stream Signaling Interface

The AXI4-Stream carries active video data, driven by both the master and slave interfaces as
seen in Figure 1-1.

X-Ref Target - Figure 1-1

From
Video IP or
AXI VDMA

From
Video IP or
AXI VDMA

Video IP

s_axis_video0_tdata
s_axis_video0_tvalid

s_axis_video0_tready
s_axis_video0_tlast
s_axis_video0_tuser

m_axis_video0_tdata

m_axis_video0_tvalid

m_axis_video0_tready
m_axis_video0_tlast

m_axis_video0_tuser

s_axis_video1_tdata

s_axis_video1_tvalid

m_axis_video1_tdata

m_axis_video1_tvalid

s_axis_video1_tready

m_axis_video1_tready

s_axis_video1_tlast
s_axis_video1_tuser

m_axis_video1_tlast

m_axis_video1_tuser

To
Video IP or
AXI VDMA

To
Video IP or
AXI VDMA

clk_proc

aclk_s
aclken_s
aresetn_s
aclk_m
aclken_m
aresetn_m

Figure 1-1: Video IP with Multiple AXI4-Stream Slave (Input) and Master (Output) Interfaces

Blank periods, audio data, and ancillary data packets are not transferred through the video
protocol over AXI4-Stream. All signals listed in Table 1-1 and Table 1-2 are required for
video over AXI4-Stream interfaces.

Table 1-1 shows the interface signal names and functions for the input (slave) side
connectors. To avoid naming collisions, the signal prefix s_axis_video should be
appended to s_axis_videok, for IP with multiple AXI4-Stream input interfaces, where k is
the index of the respective input AXI4-Stream; for example, axis_video_tvalid
becomes s_axis_video0_tvalid for stream 0 and s_axis_video1_tvalid for
stream 1.

AXI4-Stream Video IP and System Design
UG934 November 16, 2022

www.xilinx.com

4

Send Feedback
Chapter 1:

Introduction

Table 1-1: AXI4-Stream Video Protocol Input (Slave) Interface Signals

Function

Width

Direction AXI4-Stream Signal Name Video Specific Name

Video Data

Any number of bytes

Valid

Ready

Start Of Frame

End Of Line

1

1

1

1

In

In

Out

In

In

s_axis_video_tdata

s_axis_video_tvalid

s_axis_video_tready

s_axis_video_tuser

s_axis_video_tlast

DATA

VALID

READY

SOF

EOL

1.

InterfaceX Name mandates the top-level IP port names.

2. Video Specific Name should be short, descriptive signal names referring to AXI4-Stream ports that are to be used

in HDL code, timing diagrams, and test benches.

Table 1-2 shows the interface signal names and functions for the output (master) side
connectors. Similarly, for IP with multiple AXI4-Stream output interfaces, the signal prefix
m_axis_video should be appended to m_axis_videok_, where k is the index of the
respective output AXI4-Stream; for example, axis_video_tvalid becomes
m_axis_video0_tvalid for stream 0 and m_axis_video1_tvalid for stream 1.

Table 1-2: AXI4-Stream Video Protocol Output (Master) Interface Signals

Function

Width

Direction

AXI4-Stream Signal Name

Video Specific Name

Video Data

Any number of bytes

Valid

Ready

Start Of Frame

End Of Line

1

1

1

1

Out

Out

In

Out

Out

m_axis_video_tdata

m_axis_video_tvalid

m_axis_video_tready

m_axis_video_tuser

m_axis_video_tlast

DATA

VALID

READY

SOF

EOL

READY/VALID Handshake

A valid transfer occurs whenever READY, VALID, ACLKEN, and ARESETn signals are High at
the rising edge of ACLK, as shown in Figure 1-2.

X-Ref Target - Figure 1-2

Figure 1-2:

Example of READY/VALID Handshake, Start of a New Frame

AXI4-Stream Video IP and System Design
UG934 November 16, 2022

www.xilinx.com

5

Send Feedback
Chapter 1:

Introduction

During valid transfers, DATA only carries active video data. Blank periods and ancillary data
packets are not transferred by video over AXI4-Stream.

Start of Frame Signal

The start of frame (SOF) signal is physically transmitted over the AXI4-Stream TUSER0
signal, and signifies the first pixel of a video field or frame. The SOF pulse is one valid
transaction wide, and must coincide with the first pixel of the field or frame (Figure 1-2).
SOF functions as a frame synchronization signal, allowing downstream cores to reinitialize,
and detect the first pixel of a field or frame.

End of Line Signal

The end of line (EOL) signal is physically transmitted over the AXI4-Stream TLAST signal,
and signifies the last pixel of a line. The EOL pulse is one valid transaction wide, and must
coincide with the last pixel of a scan-line (Figure 1-3).

X-Ref Target - Figure 1-3

Figure 1-3: Use of EOL and SOF Signals
