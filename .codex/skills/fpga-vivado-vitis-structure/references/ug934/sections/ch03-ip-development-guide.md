# Chapter 3: IP Development Guide

_Source lines: 6263-7907_

Chapter 3

IP Development Guide

IP Parameterization

General IP configuration parameters are not covered in this specification. However,
commonly used video IP parameters generally are listed in Table 3-1.

Table 3-1:

Standard Video IP Parameters

Parameter Name

Parameter Function

C_HAS_AXI4_LITE 0 or 1 determines whether the core has an AXI4-Lite control interface

C_ACTIVE_ROWS Number of active (non-blank) scan lines per frame

C_ACTIVE_COLS Number of active (non-blank) pixels per scan line

C_MAX_COLS

Maximum number of active (non-blank) pixels per scan line supported by a particular core
instance

Only one video format can be supported in video IP core systems that use an AXI-4
interface without an embedded processor. For this configuration (C_HAS_AXI4_LITE=0),
you can define the supported resolution through generic parameters C_ACTIVE_ROWS and
C_ACTIVE_COLS defined in the core GUI. When C_HAS_AXI4_LITE=0, C_ MAX_COLS
should be equal to C_ACTIVE_COLS.

When an embedded processor is present and the Video core is instantiated with an
AXI4-Lite interface (C_HAS_AXI4_LITE=1), generic parameters C_ACTIVE_ROWS and
C_ACTIVE_COLS assign default values to control registers to define the active resolution.
As an upper bound on the active scanline length supported by the core instance,
C_MAX_COLS is used to define line buffer depths, which have a direct effect on block RAM
footprint. For example, a video core, instantiated to service 720p video (1650 total pixels,
1280 active pixels per line), needs to have C_MAX_COLS set to 1280. This core instance is
not be able to service 1080p video, but works with 720p or any lower resolutions, such as
480p, when the active_size register in the AXI4-Lite control interface is set according to
720p or 480p.

C_MAX_COLS refers to the maximum number of non-blank pixels a core instance must
service. This parameter is often used to allocate block RAMs for line buffers within the core.
For example, a core instance targeting resolutions up to 720p must have this parameter set
to 1280.

AXI4-Stream Video IP and System Design
UG934 November 16, 2022

www.xilinx.com

59

Send Feedback
General IP Structure

General IP Structure

Video IP cores should provide an AXI4-Lite interface option to allows dynamic read and
write processing parameters, status and control data, and timing parameters. For embedded
systems using either a processor or dedicated IP acting as the AXI4-Lite master, an AXI4-Lite
interface should be provided with a standardized register API. For systems without an
embedded processor, video cores should provide a way to be instantiated, supporting one
fixed video resolution.

Figure 3-1 is a schematic for a typical video processing core with one AXI4-Stream slave
input, one AXI4-Stream master output, and an AXI4-Lite interface. In this example, the IP
core processing the input and the output AXI4-Stream interfaces are apart of the same clock
domain (ACLK), but the AXI4-Lite processor interface input is in the AXI4-Lite processor
clock domain. Typically the AXI4-Lite interface does not use the same clock as the
AXI4-Stream video slave and master interfaces. Therefore, the IP should contain
Clock-Domain Crossing (CDC) logic to facilitate re-sampling the AXI4-Lite register data to
the processing core clock domain.

Core Signal
Processing
Function

Control Logic

CE

SCLR

DATA

VALID

READY

SOF

EOL

IRQ

X-Ref Target - Figure 3-1

DATA

VALID

READY

SOF

EOL

ACLK

ACLKEN

ARESE Tn

AXI4 Lite

CDC
Logic

Core
Register
Interface

sw_en
sw_rst
user
timing

Figure 3-1: General Video IP Structure with AXI4-Lite and AXI4-Stream Interfaces

X22110-121018

All video IP cores should contain control logic to govern the propagation of VALID and
READY signals, enable/disable/initialize the core Signal Processing Function, manage

AXI4-Stream Video IP and System Design
UG934 November 16, 2022

www.xilinx.com

60

Send Feedback
General IP Structure

internal buffers, generate SOF and EOL signals, and monitor error conditions. See READY –
VALID Propagation and Flushing Pipelined Cores for more information.

AXI4-Lite Interface

Many video applications have an embedded processor that can dynamically monitor and
control processing parameters within IP cores. The AXI4-Lite interface provides a
standardized API across which core functionality can be controlled and monitored. Layers of
the API consist of a memory-mapped interface with programmable registers, a low level
driver to identify physical memory locations, and higher level driver functions to control
multiple registers or complex processes. The proposed standard set of memory mapped
registers is described in Table 3-2.

Table 3-2:

Standard Video IP Registers

Offset

0x0000

Function

CONTROL

0x0004

STATUS

0x0008

ERROR

0x000C

IRQ_ENABLE

0x0010

VERSION

0x0014

SYSDEBUG0

Default

0

0

0

0

0

Access

R/W

R/W

R/W

Bit-field Definitions

Bit 0: SW_ENABLE
Bit 1: REG_UPDATE
Bit 4: BYPASS (Optional. See Core Bypass
Option.)
Bit 5: TEST_PATTERN
(Optional. See Built in Test-Pattern
Generator.)
Bit 31: SW_RESET (1: reset)

Bit 0: Frame processing Started
Bit 1: Frame Processing Complete
Bits 2-15: Core specific Status Flags
Bit 16: Slave0 error
Bit 17: Slave1 error (Optional)
Bit 18: Slave2 error (Optional)
Bit 19: Slave3 error (Optional)

Bit 0: Slave0 EOL early
Bit 1: Slave0 EOL late
Bit 2: Slave0 SOF early
Bit 3: Slave0 SOF late
Bit 4: Slave1 EOL early (Optional)
Bit 5: Slave1 EOL late (Optional)
Bit 6: Slave1 SOF early (Optional)
Bit 7: Slave1 SOF late (Optional)

R/W

Bit 0-31: Interrupt enable bits
corresponding to STATUS conditions

R

R

31-16: Core version in 4bits. 4bits
format.
0-15: CRC generated by CORE Generator
(Optional. See Version Register.)

Frame Throughput monitor (Optional)

AXI4-Stream Video IP and System Design
UG934 November 16, 2022

www.xilinx.com

61

Send Feedback
General IP Structure

Table 3-2:

Standard Video IP Registers (Cont’d)

Offset

0x0018

0x001C

0x0020

0x005C

0x0060

0x009C

0x00A0
-
0x00FC

0x0100

0x3FFC

Function

Default

Access

Bit-field Definitions

SYSDEBUG1

SYSDEBUG2

Timing Register
Set 0

Timing Register
Set 1

Reserved

0

0

R

R

Line Throughput monitor (Optional)

Pixel Throughput monitor (Optional)

Application
Dependent

See Timing Representation.

Application
Dependent

Optional for IP using multiple interfaces
with different Encoding or Timing.

Core Specific
Registers

Application
Dependent

Defined in Core Data Sheets

For more information on optional debugging, see Debugging Features.

Control Register

The SW_ENABLE flag, located on bit 0 of the CONTROL register, allows the core to be
dynamically enabled or disabled. Disabling the core from software has similar effects as
deasserting ACLKEN. When disabled, the core AXI4-Lite decoding units remain active to
facilitate re-enabling the core. The default value of Software Enable is 1 (enabled).

Flags of the CONTROL register are not buffered, which means changes take effect
immediately. The application or higher-level driver functions need to deassert these flags to
re-enable status/error acquisition.

Status and Error Registers

When using the AXI4-Lite interface, it is recommended that processing events and errors
assert STATUS and ERROR register flags. The event flags should remain set until the
application clears the flags, or the core is reset. STATUS register flags should be able to
trigger interrupts through an IRQ pin. Bits of the STATUS and ERROR registers should be
individually toggled when the application writes a '1' to the appropriate bit position of the
STATUS and ERROR registers.

If the core does not provide an AXI4-Lite interface, the IP should be configured to provide
notification of critical status and error events through a dedicated set of pins. These pins
can be connected to an external interrupt controller (INTC) core in an EDK system to
facilitate interrupt requests, identification, and clearing of interrupt sources. For this
application, it is recommended that the dedicated output signals remain asserted only as
long as the status or error event persists.

AXI4-Stream Video IP and System Design
UG934 November 16, 2022

www.xilinx.com

62

Send Feedback
General IP Structure

IRQ_ENABLE (0x000C) Register

Any bits of the STATUS register can generate a host-processor interrupt request through
the IRQ pin. The Interrupt Enable register facilitates selecting which bits of STATUS register
asserts IRQ. Bits of the STATUS registers are masked by (AND) corresponding bits of the
IRQ_ENABLE register and the resulting terms are combined (OR) together to generate IRQ.
For more information, see Debugging Features.

Version (0x0010) Register

Bit fields of the Version register facilitate software identification of the exact version of the
hardware peripheral incorporated into a system. The core driver can use this Read-Only
value to verify that the software version is matched to the hardware. For more information,
see Debugging Features.

SYSDEBUG0 (0x0014) Register

The SYSDEBUG0, or Frame Throughput Monitor, register indicates the number of frames
processed because power-up or the last time the core was reset. The SYSDEBUG registers
can be useful to identify external memory, Frame buffer, or throughput bottlenecks in a
video system. For more information, see Debugging Features.

SYSDEBUG1 (0x0018) Register

The SYSDEBUG1, or Line Throughput Monitor, register indicates the number of lines
processed because power-up or the last time the core was reset. The SYSDEBUG registers
can be useful to identify external memory, Frame buffer, or throughput bottlenecks in a
video system. For more information, see Debugging Features.

SYSDEBUG2 (0x001C) Register

The SYSDEBUG2, or Pixel Throughput Monitor, register indicates the number of pixels
processed because power-up or the last time the core was reset. The SYSDEBUG registers
can be useful to identify external memory, Frame buffer, or throughput bottlenecks in a
video system. For more information, see Debugging Features.

Register Synchronization

Most control registers that provide frame-by-frame control over processing should be
double-buffered to ensure no image tearing occurs if register values are modified while a
frame is being processed. Exceptions are registers which command immediate actuation
(CONTROL, STATUS, ERROR and IRQ_ENABLE registers) or need to be changed multiple
times within a frame (a readout or coefficient address register). With double buffering,
register writes are updating the first set of registers while the processing core uses values
from a second set of registers. All writable registers are also readable. Any reads from
writable registers return values that are stored in the first set of registers.

AXI4-Stream Video IP and System Design
UG934 November 16, 2022

www.xilinx.com

63

Send Feedback
Timing Representation

A semaphore mechanism allows you to update multiple registers without having all updates
take place within a single frame or between frames.

Values from the first register set should be copied over (committed) to the second register
set when processing cores receive the SOF signal and semaphore flag REG_UPDATE, located
on bit 1 of register CONTROL, is set.

deasserting REG_UPDATE allows applications to modify multiple registers at any time
without causing any artifacts with incomplete intra-frame updates. By asserting
REG_UPDATE, congruently updated registers are being used for the subsequent frames
starting at the next frame boundary.

Timing Representation

Timing information captures the phase/edge relationships between four periodic timing
signals:

• Vertical Sync (VSync)

• Horizontal Sync (HSync)

• Vertical Blank (VBlank)

• Horizontal Blank (HBlank)

Timing detector/timing generator modules provided as part of the Xilinx Video Timing
Controller core measure and regenerate timing signals. For an embedded processor with
AXI4-Lite interface, measured timing information is accessible through a standardized
register set, described in Table 3-3.

Blank/Sync Polarities

The input interface core automatically detects if timing signals (VSync, HSync, VBlank,
HBlank) are inverted. Periodic sync pulses are defined as Active Low if the low portion of
the signal is shorter than the high portion (signal pulses low). Bits 0 and 1 of timing variable
POLARITY correspond to VSync and HSync respectively, and should be set to 1 when
Active Low sync pulses are detected or to 0 when Active Low sync pulses are not detected

Periodic Blank signals are defined Active Low if the low portion of the signal is shorter than
the high portion because an active area is expected to be longer than the blanked area. Bits
2 and 3 of timing variable POLARITY correspond to VBlank and HBlank respectively, and
should be set to 1 when active low blank signals are detected or 0 when Active Low blank
signals are not detected.

AXI4-Stream Video IP and System Design
UG934 November 16, 2022

www.xilinx.com

64

Send Feedback
Timing Representation

Description of Timing Variables

A frame period for progressive video is defined by the number of video clock cycles
between Vsync pulses. Similarly, a field period for interlaced video is defined by the
number of video clock cycles between Vertical Sync pulses.

The field periods for even (F0) and odd (F1) fields can differ. A frame period for interlaced
video is defined by the sum of two subsequent (odd + even) field periods. The frame
periods for both interlaced and progressive video is expected to be constant for any given
video format.

The intervals when both HBlank and VBlank are inactive mark the active video area of the
frame, where pixel data is considered valid and should be translated from a periodic
standard such as DVI to AXI4-Stream.

X-Ref Target - Figure 3-2

0
(SAV)

0

Hblank Start
(H EAV)

Hsync
End

Hsync
Start

HSIZE

l

V
B
a
n
k

V
S
y
n
c

Active Video

i

g
n
k
n
a
B

l

l

a
t
n
o
z
i
r
o
H

Vertical Blanking

Vblank Start
(V EAV)

Vsync Start

Vsync End

VSIZE

H Blank

H Sync

Figure 3-2: Definition of Timing Variables – Falling Edge of Blanks

X22111-121018

The frame period contains blank and active areas and can be visualized as a set of
rectangles, as seen in Figure 3-2. In the top-left corner of the frame, pixel index 0 (scan line
index 0) is designated to be the first active pixel on the first complete active line.

The total number of scan lines per frame is defined as the number of scan-lines per frame,
or VSIZE. The timing variable VSIZE reflects the total number of active and blank lines per
frame. The index of the last scan line in a frame is VSIZE-1.

The number of video clock cycles between the HBlank pulses is expected to be equal to the
number of video clock cycles between the HSync pulses in each field. The timing variable
HSIZE reflects the total number of active and blank pixels per scan line. The index of the last
pixel in scan lines is HSIZE-1.

AXI4-Stream Video IP and System Design
UG934 November 16, 2022

www.xilinx.com

65

Send Feedback


Timing Representation

The Xilinx Video Timing Controller IP works with complete scan lines, so the total number of
video clock cycles in a frame period is expected to be an integer multiple of the total
number of pixels per scan line (HSIZE * VSIZE).

For progressive video, the period between the VBlank pulses is expected to have the same
number of video clock cycles as the period between the VSync pulses. For interlaced video,
the number of total scan lines in even and odd fields can differ. Therefore, two sets of timing
registers (F0 for even fields and F1 for odd fields) keep track of timing variables for
interlaced video fields.

For progressive video, only the F0 bank of timing registers are used.

The falling and rising edges of VBlank might not coincide with the falling edge of HBlank,
which could be visualized as VBlank falling on a pixel position other than 0 in a scan line
(Figure 3-2). Also, the phase difference between VBlank and HBlank can change between
even and odd fields. This phase difference between the falling and rising edges of VBlank
is captured in the nibbles of the registers F0_VBLANK_H and F1_VBLANK_H.

The phase relationships of the VSync and HSync signals can be arbitrary in relationship to
the first active pixel, the origin of the V/H coordinate system (Figure 3-2), and might be
different between even and odd fields. Nibbles in registers F0_VSYNC_V and F0_VSYNC_H
capture the horizontal and vertical positions of falling and rising edges of VSYNC for even
fields. Similarly, nibbles in registers F1_VSYNC_V and F1_VSYNC_H capture the horizontal
and vertical positions of falling and rising edges of VSYNC for odd fields.

The scan line index where VBlank transitions high1 (VBlank start) marks the vertical end of
the active area and the start of the vertical blank area. The pixel index where HBlank
transitions high1 (HBlank start) marks the horizontal end of the active area, and the start of
the horizontal blank area.

Nibbles of timing registers ACTIVE_SIZE denote the vertical (number of scan lines), and
horizontal sizes (number of pixels) in the active area.

Table 3-3:

Standardized Timing Registers

Offset

0x0020

Name

ACTIVE_SIZE

Function

Bit fields

Horizontal and Vertical Frame
Size (without blanking)

15-0: Horizontal active frame size
31-16: Vertical active frame size

0x0024

TIMING_STATUS

Timing Measurement Status

0x0028

ENCODING

Frame encoding

0: LOCKED
1: VBLANK_START_DETECT
2: VBLANK_END_DETECT

0-3: VIDEO_FORMAT
4-5: NBITS
6: INTERLACED/Progressive(0)
7: FIELD_PARITY
8: CHROMA_PARITY

AXI4-Stream Video IP and System Design
UG934 November 16, 2022

www.xilinx.com

66

Send Feedback
Offset

0x0032

0x0030

0x0034

Table 3-3:

Standardized Timing Registers (Cont’d)

Timing Representation

Name

Function

Bit fields

POLARITY

Blank, Sync polarities

0: Vertical Blank pulse polarity
1: Horizontal Blank pulse polarity
2: Vertical Sync polarity
3: Horizontal Sync polarity

15-0: Horizontal frame size

HSIZE

VSIZE

Horizontal Frame Size (with
blanking)

Vertical Frame Size (with
blanking)

15-0: Vertical frame size for field 0
31-16: Vertical frame size for field 1

0x0038

HSYNC

Start and end cycle index of
HSync

15:0: Start cycle index of HSync.
31-16: End cycle index of HSync.

0x003C

F0_VBLANK_H

Start and end cycle index of
VBlank for field 0.

15:0: Start cycle index of VBlank
31-16: End cycle index of VBlank

0x0040

F0_VSYNC_V

Start and end line index of
VSync for field 0.

15:0: Start line index of VSync
31-16: End line index of VSync

0x0044

F0_VSYNC_H

Start and end cycle index of
VSync for field 0.

15:0: Start cycle index of VSync
31-16: End cycle index of VSync

0x0048

F1_VBLANK_H

Start and end cycle index of
VBlank for field 1.

15:0: Start cycle index of VBlank
31-16: End cycle index of VBlank

0x004C

F1_VSYNC_V

Start and end line index of
VSync for field 1.

15:0: Start line index of VSync
31-16: End line index of VSync

0x0050

F1_VSYNC_H

Start and end cycle index of
VSync for field 1.

15:0: Start cycle index of VSync
31-16: End cycle index of VSync

0x0058

0x005C

Reserved

Reserved

Reserved

Reserved

Reserved

Reserved

ACTIVE_SIZE (0x0020) Register

The ACTIVE_SIZE register encodes the number of active pixels per scan line and the
number of active scan lines per frame. The lower half-word (bits 12:0) encodes the number
of active pixels per scan line. Supported values should be between 32 and the value
provided in the Maximum number of pixels per scan line field in the GUI. The upper
half-word (bits 28:16) encodes the number of active pixels per scan line. Supported values
should be 32 to 7680. To avoid processing errors, restrict values written to ACTIVE_SIZE to
the range supported by the core instance.

AXI4-Stream Video IP and System Design
UG934 November 16, 2022

www.xilinx.com

67

Send Feedback
Timing Representation

Frame Encoding

Bits 0 to 3 (VIDEO_FORMAT) define the sampling structure of video using the video format
codes (VF) defined in Table 1-4. Bits 4-5 define the data representation, the number of bits
per component channel, as defined in Table 3-4.

Table 3-4: Data Representation Codes

ENCODING[5:4]

Bits per Component Channel

00

01

10

11

8

10

12

16

Bit 6 (INTERLACED) should be set if the video processed is interlaced (1). For progressive
video, this bit should be set to 0. Corresponding Bit 7, indicates field polarity (0: even field,
1: odd field) if interlaced video is used. Processing cores should not expect the host
processor to update this register value on a frame-by-frame basis. Instead, the IP is
expected to toggle automatically after processing fields, using the programmed value as the
initial value for the first field after the value is committed.

Bit 8 (CHROMA_PARITY) of the ENCODING register specifies whether the first line of video
contains chroma information (1) or not (0) when YUV 420 encoded video is being processed.
Processing cores should not expect the host processor to update this register value on a
line-by-line basis to reflect whether the current line contains chroma or not. Instead, the IP
is expected to toggle automatically after each line was processed, using the programmed
value as the initial value for the first line of the first frame after the value is committed.
Table 3-5 provides example values for timing variable assignments for typical video
standards using 8 bit data.

Table 3-5:

Typical Values for Timing Variables

Name

720p@59.94/60 RGB

1080p@59.94/60 YUV422

1080i@59.94/60 YUV420

ENCODING

0x0000_0002

0x0000_0000

0x0000_0043

POLARITY

ACTIVE_SIZE

HSIZE

0x0000_000F
0: VB Active-High
1: HB Active-High
2: VS Active-High
3: HS Active-High

0x02D0_0500
15-0: HSIZE = 1280
31-16: VSIZE = 720

0x0000_000F
0: VB Active-High
1: HB Active-High
2: VS Active-High
3: HS Active-High

0x0438_0780
15-0: HSIZE = 1920
31-16: VSIZE = 1080

0x0000_000F
0: VB Active-High
1: HB Active-High
2: VS Active-High
3: HS Active-High

0x021C_0780
15-0: HSIZE = 1920
31-16: VSIZE = 540

0x0000_0672
15-0: HSIZE_F0= 1650
31-16: Reserved

0x0000_0898
15-0: HSIZE_F0 = 2200
31-16: Reserved

0x0000_0898
15-0: HSIZE_F0= 2200
31-16: Reserved

AXI4-Stream Video IP and System Design
UG934 November 16, 2022

www.xilinx.com

68

Send Feedback
Table 3-5:

Typical Values for Timing Variables (Cont’d)

Name

720p@59.94/60 RGB

1080p@59.94/60 YUV422

1080i@59.94/60 YUV420

Input/Output Timing

VSIZE

HSYNC

0x0000_02EE
VSIZE_F0 = 750
VSIZE_F1 = 0

0x0596_056E
15-0: START = 1390
31-16: END = 1430

0x0000_0465
VSIZE_F0 = 1125
VSIZE_F1 = 0

0x0804_07D8
15-0: START = 2008
31-16: END = 2052

F0_VBLANK_H

0x0000_0000

0x0000_0000

F0_VSYNC_V

0x02DA_02D5
15-0: START = 725
31-16: END = 730

0x0441_043C
15-0: START = 1084
31-16: END = 1089

F0_VSYNC_H

0x0000_0000

0x0000_0000

F1_VBLANK_H

0x0000_0000

0x0000_0000

F1_VSYNC_V

0x0000_0000

0x0000_0000

F1_VSYNC_H

0x0000_0000

0x0000_0000

0x0233_0232
VSIZE_F0 = 562
VSIZE_F1 = 563

0x0804_07D8
15-0: START = 2008
31-16: END = 2052

0x0000_0000
15-0: H_START = 0
31-16: H_END = 0

0x0223_021E
15-0: START = 542
31-16: END = 547

0x0000_0000
15-0: H_START = 0
31-16: H_END = 0

0x0000_0000
15-0: H_START = 0
31-16: H_END = 0

0x0223_021E
15-0: START = 542
31-16: END = 547

0x044C_044C
15-0: H_START = 1100
31-16: H_END = 1100

Input/Output Timing

The recommended design convention for AXI4-Stream component interfaces suggests that
outputs should be registered or driven directly by flip-flops or FIFO/block RAM primitives.
Ideally, inputs are also registered but can be combinatorial. Combinatorial inputs can limit
Fmax so the amount of combinatorial logic present on inputs should be limited.

There must be no combinatorial paths between input and output signals on either master or
slave interfaces. Combinatorial paths between input and output signals are not permitted
across separate AXI4-Stream interfaces. In some cases, outputs driven by combinatorial
logic are a suitable design choice or a reasonable design trade-off, such as when latency is
critical. The IP core data sheet describes AXI4-Stream output signals that are not registered.

AXI4-Stream Video IP and System Design
UG934 November 16, 2022

www.xilinx.com

69

Send Feedback
Buffering Requirements

Buffering Requirements

The output interface module does not start generating valid output frames until it receives
valid data on its input AXI4-Stream interface. However, after periodic output frame
generation starts, all cores in the processing pipeline should be able to provide data at the
rate required by the output standard.

For most output standards three different data rates should be defined. As an example,
720p30 video over DVI rates are used. Table 3-6 describes the three data rates.

Table 3-6: Output Data Rates

Pixel Rate

Description

Active Within the active portion of each row, pixels are sent back to back on each clock cycle, at 37.125 MHz.

Line

Frame

Active video lines typically contain active and non-active (horizontally blanked) periods. As no pixels
need to be transmitted in the non-active period, the average data rate within an active line is less
than the active pixel rate. For 720p30 over DVI, this rate is 28.8 Mega-samples per second (Msps).

Video frames typically contain active, and non-active (vertically blanked) periods. As no pixels need
to be transmitted in the non-active period, the average data rate within a frame is less than line pixel
rate. For 720p30 over DVI, this rate is 27.648 Msps.

Identifying the above rates helps determine what type of buffering is necessary, if any,
within or between processing cores. If a processing core can maintain the active pixel rate
indefinitely, such as a test-pattern generator core, no buffering is necessary.

•

•

•

If a processing core cannot maintain the active pixel rate but can maintain the line pixel
rate, a line buffer is necessary on the processing core output.

If a processing core cannot maintain the line pixel rate but can maintain the frame pixel
rate, a frame buffer is necessary on the processing core output. It is assumed that the
frame buffer IP also contains line buffers to smooth access bursts.

If a processing core cannot maintain the frame pixel rate due to insufficient throughput,
no amount of buffering is sufficient to produce uninterrupted output video for the
desired output standard.

Line Buffer Placement

All cores that cannot process pixels fast enough to sustain one pixel per output clock need
output line-buffer(s) to avoid stalling the pipeline. Although combining line buffers at the
end of a processing pipeline (by taking advantage of an output interface core with
programmable line-buffer depth) might seem like an attractive option to save resources, it
can also defeat the purpose of buffering.

In this example, (Figure 3-3) a hypothetical output interface needs to generate frames with
320 clock cycles per line, with 200 active pixels per line. The external memory interface
retrieves pixels in 64 pixel bursts after which it is unavailable for 16 clock cycles. Core A takes

AXI4-Stream Video IP and System Design
UG934 November 16, 2022

www.xilinx.com

70

Send Feedback
Buffering Requirements

3 clock cycles to generate 2 output pixels. Core B takes three line periods to generate two
active lines (no output for the 960 pixels, then 400 pixels consecutively).

X-Ref Target - Figure 3-3

External
Memory

D

Core A

Core B

Q

D

Q

D

Q

D

Output
Interface

Q
vblank

valid

valid

valid

valid

valid

valid

ready

ready

ready

ready

ready

ready

valid

ready

hblank
a_video
a_chroma

v_sync

X22112-121018

Figure 3-3:

Simple Pipeline with Internal Line Buffers

Although all cores (external memory, Core A, Core B) have the throughput necessary to
generate 200 pixels per 320 clock cycles on the average, the throughput degrades unless
there are line buffers on each core output when connected as a system. For example, if the
external memory provides data in 64 cycle bursts, Core A produces 42 output samples per
burst or 170 pixels per line. Core A requires the whole line period to produce the active
pixels, but it is forced to idle during the 4x16 cycles when the external memory is not
available.

To avoid processing bubbles, all cores should be appropriately buffered on the output of the
core as if the core was driving the output interface directly. Figure 3-3 illustrates the
scenario when processing cores can maintain the line-pixel rate, but cores need output
buffers to avoid processing bubbles. Green arrows represent subsequent cores reading from
the output buffers of preceding cores.

Buffer Management

Even if sufficiently deep line buffers (FIFOs) are present on the output of processing cores,
bubbles can form if buffers under-run. This can happen when a core master interface asserts
its VALID output immediately when the core output FIFO is not empty. In this case, data
percolates through a processing pipeline rapidly and trigger the output interface to start
output timing generation, after which output pixels have to be supplied consistently. Now,
if any of the cores cannot sustain the uninterrupted data rate and have to deassert its VALID
output, processing bubbles form, which eventually cause a buffer under-run at the output
interface core and break the output data–sync alignment.

AXI4-Stream Video IP and System Design
UG934 November 16, 2022

www.xilinx.com

71

Send Feedback
READY – VALID Propagation

X-Ref Target - Figure 3-4

External
Memory

D

Core A

Core B

Q

D

Q

D

Q

D

Output
Interface

Q
vblank

valid

valid

valid

valid

valid

valid

ready

ready

ready

ready

ready

ready

valid

ready

hblank
a_video
a_chroma

v_sync

X22113-121018

Figure 3-4: Processing Bubble Example

1. Core A and Core B ran out of valid samples.

Figure 3-4 presents an example scenario when processing cores A and B run out of valid
samples mid-frame, so when the output interface asserts its ready output to start a new line,
samples must be retrieved from external memory and must be processed by Core A and
Core B, causing significant delay, which can break the sync - data alignment at the output
interface.

To avoid processing bubbles, cores should not assert the VALID signal on the output
interfaces until internal FIFOs are almost full and keep VALID asserted until output FIFOs
and internal pipeline stages are empty.

The READY output should be driven in a greedy fashion; asserted unless all pipeline stages
are full, internal FIFOs are almost full, and the master interface READY is sampled low, as
described in READY – VALID Propagation, or internal pipelines need to be flushed as
described in Flushing Pipelined Cores. This behavior ensures processing efficiency and
proper flushing of pipelines and processing systems at line and frame ends.

READY – VALID Propagation

For very simple IP cores, propagating VALID from master to slave and propagating READY
from slave to master seems straight-forward. However, when the IP core has pipeline
registers and/or FIFOs, the internal state of pipelines and FIFOs must be factored in to the
READY/VALID output assignments. See Buffer Management for more information.

As stated in Input/Output Timing, the READY output on the slave interface and VALID
output on the master interface must be registered. This requirement inserts a propagation
delay of at least one clock cycle between the deasserted READY signal on the IP core slave
interface input and the master interface READY output. The logic controlling these outputs,
as well as the latching in of new pixels from the slave interface to internal FIFOs or pipeline
registers, must consider the scenario when all internal buffers (pipeline registers and FIFOs)
are full, the downstream slave interface just deasserted READY, but the upstream master
interface sends one more pixel due to the core master interface READY signal lagging
behind the slave interface.

AXI4-Stream Video IP and System Design
UG934 November 16, 2022

www.xilinx.com

72

Send Feedback
Flushing Pipelined Cores

To avoid pixel drops in the above situation, pipelined cores without internal FIFOs should
contain one (or more) additional pipeline stage(s) to accept one (or more) pixel(s). These
cores should keep the master interface READY output deasserted until the extra pipeline
stage is processed.

To mitigate the pixel drop condition for cores with internal FIFOs the master interface
READY output should be asserted unless:

•

•

all pipeline stages are full, internal FIFOs are almost full, and the master interface
READY is sampled low.

internal pipelines need to be flushed.

Flushing Pipelined Cores

Pipelined IP cores must maintain the consistent validity of data in pipeline stages from
beginning to end of video lines. For example, if horizontal FIR filtering is performed to
generate valid output samples, all taps of the FIR filter delay line should only contain valid
pixels. If valid data is not always present on the input (slave) interface of the filtering core,
the clock-enable pins of the delay-line and the filter arithmetic should be pulsed to latch in
and process only valid input samples. This implies that data in the processing pipeline of the
IP core only moves forward when new, valid samples are available to process. Take for
example a Color-Space Converter processing streaming video with horizontal and vertical
blanking periods where no valid samples are transferred over the AXI4-Stream video
interfaces for a large number of ACLK cycles. This behavior would imply that the results
corresponding to the end of scan line are only available when the samples from the
beginning of the next line clock them out. Similarly, the last samples from the end of a frame
only become available at the beginning of the next frame. Both behaviors are prohibited
because they introduce processing bubbles that break the output interface data-sync
alignment.

Instead, processing pipelines must be flushed at the end of each scan-line. If samples for the
next line (and next frame) are available immediately, processing cores can use these
samples. If samples are not available, processing cores can flush pipelines by repeating the
last valid pixel or applying a more sophisticated edge padding solution. If padding by zeros
or repeated samples from the next line are needed in preparation for the next line or next
frame, a processing core might deassert its READY input for as many clock cycles as it takes
to empty valid data samples from the pipeline or to pad and re-initialize for a new line.

AXI4-Stream Video IP and System Design
UG934 November 16, 2022

www.xilinx.com

73

Send Feedback
Flushing Pipelined Cores

Example IP

s_axis_video_tdata
s_axis_video_tvalid

s_axis_video_tready

s_axis_video_tlast
s_axis_video_tuser

m_axis_video_tdata

m_axis_video_tvalid

m_axis_video_tready
m_axis_video_tlast

m_axis_video_tuser

aclk

aclken

aresetn

Figure 3-5:

Simple Video IP with One Slave and One Master AXI4-Stream Interfaces

When flushing is completed and the pipeline is empty, processing cores should assert the
READY output signals on the slave interfaces irrespective of the READY inputs of the master
interfaces, as seen in the READY_out and READY_in signals of Figure 3-5 and described in
READY – VALID Propagation.

X-Ref Target - Figure 3-5

X-Ref Target - Figure 3-6

Figure 3-6:

Inefficient Flushing Growing a Processing Bubble at the End of Frame

If the READY output signal (READY_out) assertion is delayed until the slave interface
READY_in is asserted, subsequent cores would keep inserting longer breaks between
lines/frames, as illustrated on Figure 3-6. In this example, the gap between frames/lines of
the input stream grows because the flushing periods of subsequent cores accumulate if the
IP core holds off re-asserting its READY_out output until its READY_in is asserted.

AXI4-Stream Video IP and System Design
UG934 November 16, 2022

www.xilinx.com

74

Send Feedback
Propagating SOF and EOL Signals

Propagating SOF and EOL Signals

Video processing IP cores either delay or re-generate the SOF and EOL pulses. No
recommendations are given for which method to use when generating output SOF and EOL
pulses. However, for simple pipelined IP cores without line buffers, such as a Color Space
Converter, delay lines matching pipeline latency is recommended. For complex IP with line
buffers, generating SOF and EOL pulses is recommended.

In accordance with AXI4-Stream Signaling Interface, complex video IP can detect a
discrepancy between expected number of active lines (as programmed by timing variables)
and the actual number of EOL pulses received between consecutive SOF pulses.

When SOF is detected early, the output SOF signal should be generated early as well,
meaning the previous frame is not padded to match programmed frame dimensions. When
SOF is detected late, extra lines/pixels from the previous frame should be dropped and the
output SOF signal should be generated according to the programmed values.

In accordance with End of Line Signal, complex video IP can detect a discrepancy between
expected number of active pixels, as programmed by timing variables, and the actual
number of valid pixels received between consecutive EOL pulses.

When EOL is detected early, the output EOL signal should be generated early as well,
meaning the previous frame is not padded to match programmed frame dimensions. When
EOL is detected late, the output EOL signal should be according to programmed values and
extra pixels from the previous line should be dropped.

Interframe Reinitialization

Some video IP cores, such as the Image Statistics and Image Characterization, take
thousands of clock cycles to initialize between frames because block RAMs holding
statistical data must be cleared or large sets of metadata must be written to external
memory.

As a general recommendation, video IP cores should re-initialize at the end of the frame,
instead of at the beginning of the frame when the SOF pulse is received.

Interrupt Subsystem

Video processing cores should provide optional interrupt pin (IRQ). Timing and core
function related STATUS and ERROR flags, described in Table 3-2, should be individually
selectable to generate an interrupt.

AXI4-Stream Video IP and System Design
UG934 November 16, 2022

www.xilinx.com

75

Send Feedback
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
