# Timing Representation

_Parent: Chapter 3: IP Development Guide_
_Source lines: 6702-7240_

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
