# Data Format

_Parent: Chapter 1: Introduction_
_Source lines: 367-2102_

Data Format

To transport video data, the DATA vector encodes logical channel subsets of the physical
DATA signals. AXI4-Stream interfaces between video modules can facilitate the transfer of
video using different precision (e.g., 8, 10, or 12 bits per color channel), and/or different
formats (e.g., RGB or YUV 420) and different number of pixels per data beat.

AXI4-Stream Video IP and System Design
UG934 November 16, 2022

www.xilinx.com

6

Send Feedback
Chapter 1:

Introduction

AXI4-Stream Specific Parameterization

Video IP configuration parameters are described in IP Parameterization in Chapter 3. The
specific parameters for the AXI4-Stream interface video protocol are listed in Table 1-3.

Table 1-3: Video over AXI4-Stream Specific IP Parameters

Parameter Name

C_tk_DATA_WIDTH

C_tk_VIDEO_FORMAT

C_tk_AXIS_TDATA_WIDTH

Function

Width of color/component data

Video format code

Width of interface signal TDATA

C_tk_MAX_SAMPLES_PER_CLOCK

Maximum number of samples/pixels per data beat

The C_tk_AXIS_TDATA_WIDTH parameter determines the width of variable-width
interface signal TDATA on AXI4-Stream interface tk, where interface type t can have the
values [m,s] designating a master or slave interface, while optional integer k specifies the
interface ID. Typically, C_tk_AXIS_TDATA_WIDTH is a function of the component data
width, the number of pixels/samples per data beat, and the number of components the
actual video format is using.

The recommended parameter names for component data width is C_tk_DATA_WIDTH. The
optional format parameter C_tk_VIDEO_FORMAT can help the IP determine the number of
color components present on DATA using a HDL function. Video IP typically requires
specific formats on the input interfaces and can have the number of color component
channels hard coded in the IP. However, when C_tk_VIDEO_FORMAT (set by a default value
on the master interface) is propagated in HDL designs to slave interfaces, the IP source
code can perform DRC using assertions to ensure that AXI4-Stream video interfaces are
driven by video that was encoded in the expected format.

Encoding

The DATA bits are represented using the [N-1:0] bit numbering convention (N-1 through
0). The components of implicit subfields of DATA should be packed tightly together; for
example, a DW=10 bit RGB data packed together to 30 bits. If necessary, the packed data
word should be zero padded with most significant bits (MSBs) so the width of the resulting
word is an integer that is a multiple of eight as shown in Figure 1-4.

X-Ref Target - Figure 1-4

Figure 1-4: Video Data Padding for TDATA for Multiple Pixels

AXI4-Stream Video IP and System Design
UG934 November 16, 2022

www.xilinx.com

7

Send Feedback
Chapter 1:

Introduction

The detailed representation of different formats is listed in Table 1-4, with
DW = C_DATA_WIDTH and VF = C_VIDEO_FORMAT.

Table 1-4: Video Format Codes and Data Representation for C_tk_MAX_SAMPLES_PER_CLOCK =1

VF Code

Video Format

[4DW-1: 3DW]

[3DW-1: 2DW]

[2DW-1: DW]

[DW-1:0]

0

1

2

3

4

5

6

7

8

9

10

11

12

13

14

15

YUV 4:2:2

YUV 4:4:4

RGB

YUV 4:2:0

YUVA 4:2:2

YUVA 4:4:4

RGBA

YUVA 4:2:0

YUVD 4:2:2

YUVD 4:4:4

RGBD

YUV 4:2:0

Mono/Bayer
Sensor (RAW)

Custom2

Custom3

Custom4

α

α

D

D

V, Cr

R

α

V/U, Cr/Cb

U, Cb

B

V/U, Cr/Cb

V/U, Cr/Cb

V, Cr

U, Cb

R

D

V, Cr

R

D

B
α , V/U, Cr/Cb

V/U, Cr/Cb

U, Cb

B

V/U, Cr/Cb

Y

Y

G

Y

Y

Y

G

Y

Y

Y

G

Y

Y, RGB, CMY

2 Components – No DRC

3 Components – No DRC

4 Components – No DRC

Note: For any of the 4:2:2 and 4:2:0 formats, Cb (or U) and Cr (or V) samples are split over two data
beats but only in a one sample per clock mode. The first data beat holds Cb (or U); the second data
beat holds Cr (or V). In other words, the first active pixel of the frame contains [Cb0:Y0] and the next
pixel contains [Cr0:Y1]. The 4:2:0 format adds vertical subsampling to the 4:2:2 format, which is
implemented in Video over AXI4-Stream by omitting the chroma data on every other line.

Note: Bayer Sensor data is also referred to as RAW data, which is generally in
RAW8/RAW10/RAW12/RAW14/RAW16, etc. formats.

Encoding Multiple Pixels - Static TDATA Configuration

When multiple samples/pixels are carried by AXI4-Stream, pixels should be packed from
least significant bit (LSB) to MSB, e.g., the least significant pixel should correspond to the
left-most pixel in a scanline, or to the pixel captured earliest in time. For example, if 4
samples/pixels are sent per data beat, the first sample sits in the least significant, the 4th
sample sits in the most significant bit positions.

When multiple pixels or samples are transferred using the video protocol over AXI4-Stream,
color components pertinent to the individual pixels are arranged according to Table 1-5,
presenting examples for transferring two pixels for video modes 0, 1, 2, 3, 12. Pixel data is
packed continuously without any padding between pixels. When N*DW is not an integer

AXI4-Stream Video IP and System Design
UG934 November 16, 2022

www.xilinx.com

8

Send Feedback


Chapter 1:

Introduction

multiple of 8, video data is zero padded on the MSBs, as presented on Figure 1-5. If the line
size is not divisible by the number pixels/samples per data beat, then the last beat of the
line should use the LSBs. Then, the unused pixel in the MSBs of the last data beat of the line
should be padded with zeros.

X-Ref Target - Figure 1-5

Component R

Component B

Component G

Component R

Component B

Component G

64

56

48

40

32

24

16

8

bit 0

Figure 1-5: Video Data Padding for TDATA

Table 1-5: Video Format Codes and Data Representation

VF
Code

Video
Format

[6DW-1:
5DW]

[5DW-1:
4DW]

[4DW-1: 3DW]

[3DW-1:
2DW]

[2DW-1: DW]

[DW-1:0]

0

1

2

3

12

YUV 4:2:2

V0, Cr0

Y1

YUV 4:4:4

V1, Cr1

U1, Cb1

RGB

R1

B1

YUV 4:2:0

Mono/Bay
er Sensor
(RAW)

Y1

G1

V0, Cr0

V0, Cr0

R0

Y1

U0, Cb0

U0, Cb0

B0

U0, Cb0

Y0

Y0

G0

Y0

RGB1, CMY1

RBGB0, CMY0

Encoding Multiple Pixel - Dynamic TDATA Configuration

For applications where video IP can dynamically change color-component width, video
format, or the number of pixels/samples per data beat, pixels and components should
remain at the static locations determined by the generic parameters for instantiation. For
example, if only one pixel is transmitted over an interface supporting at most two pixels per
data beat, the sample/pixel should be aligned to the least significant pixel position.
Similarly, if only 8 bits per component are transmitted over an interface generated for 10
bits per component, the active bits should be MSB aligned and LSB padded with zeros.
Three examples are shown in Figure 1-6 through Figure 1-9.

IMPORTANT: Although this specification supports dynamically changing the number of pixels/samples
per data beat, this is not recommended because not all IPs support this feature.

X-Ref Target - Figure 1-6

Component R

Component B

Component G

64

56

48

40

32

24

16

8

bit 0

X22096-121018

Figure 1-6: One Pixel per Data Beat, Eight Bits per Component over a Two-Pixel per Data Beat, 10-Bits
per Component Bus

AXI4-Stream Video IP and System Design
UG934 November 16, 2022

www.xilinx.com

9

Send Feedback
Chapter 1:

Introduction

X-Ref Target - Figure 1-7

Pixel 1

Pixel 0

Component R

Component B

Component G

Component R

Component B

Component G

64

56

48

40

32

24

16

8

bit 0

X22097-121018

Figure 1-7:

Two Pixels per Data Beat, Eight Bits per Component over a Two-Pixel per Data Beat,

10-Bits per Component Bus

Figure 1-8. captures RGB888 (pixel with three components, component width of 8).

X-Ref Target - Figure 1-8

Pixel 1

Pixel 0

Component R

Component B

Component G

Component R

Component B

Component G

88

80

72

64

56

48

40

32

24

16

8

bit 0

X22098-121018

Figure 1-8:

Two Pixels per Data Beat, Eight bits per Component (RGB888, VF Code 2) over a

Two-Pixel per Data Beat, 14-bits per Component Bus

Notes:
1. Each G,B,R component sits in 14-bit component space with MSB alignment.

Figure 1-9. captures RAW14 (pixel with single component, component width of 14).

X-Ref Target - Figure 1-9

Pixel 1

Pixel 0

88

80

72

64

56

48

40

32

24

16

8

bit 0

X22099-121018

Figure 1-9:

Two Pixels per Data Beat, 14 Bits per Component (RAW14, VF Code 12) over a

Two-Pixel per Data Beat, 14-bits per Component Bus

Notes:
1. Although RAW14 may only use the lower 28 bits, the full AXI4-Stream interface remains 88-bits because it must

accommodate the possibility of switching to RGB at full 14-bits per color if requested when dealing with dynamic
TDATA. Down stream logic must be aware of this and should provide the appropriate bus interface and then
internally discard bits if it does not use them.

Comparing the two data type component widths in Figure 1-8 and Figure 1-9, the RAW14,
VF Code 2 data type has 14-bit component and RGB888 (VF Code 2) 8-bit component.
Therefore, the RGB888 components are placed with MSB aligned and LSB padded with zeros
on 14-bit component bus. Additionally, the RAW14 pixels are packed tightly together.

AXI4-Stream Video IP and System Design
UG934 November 16, 2022

www.xilinx.com

10

Send Feedback
Chapter 1:

Introduction

Example Multi Pixel Encoding

The AXI4-Stream video interface supports dual or quad pixels per clock with 8 bits, 10 bits,
12 bits and 16 bits per component for RGB, YUV444, and YUV420 color spaces. When the
parameter, Max Bits Per Component, is set to 16, Figure 1-10 shows the data format for
quad pixels per clock to be fully compliant with the AXI4-Stream video protocol.

X-Ref Target - Figure 1-10

RGB / YUV444
8-bits

R3 / V3
8-bits

B3 / U3
8-bits

G3 / Y3
8-bits

R2 / V2
8-bits

B2 / U2
8-bits

G2 / Y2
8-bits

R1 / V1
8-bits

B1 / U1
8-bits

G1 / Y1
8-bits

R0 / V0
8-bits

B0 / U0
8-bits

G 0/ Y0
8-bits

RGB / YUV444
10-bits

R3 / V3
10-bits

B3 / U3
10-bits

G3 / Y3
10-bits

R2 / V2
10-bits

B2 / U2
10-bits

G2 / Y2
10-bits

R1 / V1
10-bits

B1 / U1
10-bits

G1 / Y1
10-bits

R0 / V0
10-bits

B0 / U0
10-bits

G 0/ Y0
10-bits

RGB / YUV444
12-bits

R3 / V3
12-bits

B3 / U3
12-bits

G3 / Y3
12-bits

R2 / V2
12-bits

B2 / U2
12-bits

G2 / Y2
12-bits

R1 / V1
12-bits

B1 / U1
12-bits

G1 / Y1
12-bits

R0 / V0
12-bits

B0 / U0
12-bits

G 0/ Y0
12-bits

RGB / YUV444
16-bits

R3 / V3
16-bits

B3 / U3
16-bits

G3 / Y3
16-bits

R2 / V2
16-bits

B2 / U2
16-bits

G2 / Y2
16-bits

R1 / V1
16-bits

B1 / U1
16-bits

G1 / Y1
16-bits

R0 / V0
16-bits

B0 / U0
16-bits

G 0/ Y0
16-bits

RGB / YUV444
12-bits

V2
12-bits

Y3
12-bits

U2
12-bits

Y2
12-bits

V0
12-bits

Y1
12-bits

U0
12-bits

Y0
12-bits

192

176

160

144

128

112

96

80

64

48

32

16

0

X22100-121018

Figure 1-10: Quad Pixels Data Format (Max Bits Per Component = 16)

A data format for a fully compliant AXI4-Stream video protocol dual pixel per clock is
illustrated in Figure 1-11.

X-Ref Target - Figure 1-11

RGB / YUV444
8-bits

R1 / V1
8-bits

RGB / YUV444
10-bits

R1 / V1
10-bits

RGB / YUV444
12-bits

R1 / V1
12-bits

RGB / YUV444
16-bits

R1 / V1
16-bits

YUV422
12-bits

B1 / U1
8-bits

B1 / U1
10-bits

B1 / U1
12-bits

B1 / U1
16-bits

G1 / Y1
8-bits

G1 / Y1
10-bits

R0 / V0
8-bits

R0 / V0
10-bits

B0 / U0
8-bits

B0 / U0
10-bits

G0 / Y0
8-bits

G0 / Y0
10-bits

G1 / Y1
12-bits

G1 / Y1
16-bits

V0
12-bits

R0 / V0
12-bits

R0 / V0
16-bits

Y1
12-bits

B0 / U0
12-bits

B0 / U0
16-bits

U0
12-bits

G0 / Y0
12-bits

G0 / Y0
16-bits

Y0
12-bits

96

80

64

48

32

16

0

X22101-121018

Figure 1-11: Dual Pixels Data Format (Max Bits Per Component = 16)

When the parameter, Max Bits Per Component, is set to 12, video formats with actual bits
per component larger than 12 is truncated to the Max Bits Per Component. The remaining
least significant bits are discarded. If the actual bits per component is smaller than Max Bits
Per Component set in the Vivado® IDE, all bits are transported with the MSB aligned and
the remaining LSB bits are padded with 0. This applies to all Max Bits Per Component
settings.

As an illustration, when Max Bits Per Component is set to 12, Figure 1-12 shows the data
format for quad pixels per clock to be fully compliant with the AXI4-Stream video protocol.

AXI4-Stream Video IP and System Design
UG934 November 16, 2022

www.xilinx.com

11

Send Feedback
Chapter 1:

Introduction

A data format for a fully compliant AXI4-Stream video protocol with dual pixels per clock is
illustrated in Figure 1-13.

X-Ref Target - Figure 1-12

RGB / YUV444
8-bits

R3 / V3
8-bits

B3 / U3
8-bits

G3 / Y3
8-bits

R2 / V2
8-bits

B2 / U2
8-bits

G2 / Y2
8-bits

R1 / V1
8-bits

B1 / U1
8-bits

G1 / Y1
8-bits

R0 / V0
8-bits

B0 / U0
8-bits

G 0/ Y0
8-bits

RGB / YUV444
10-bits

R3 / V3
10-bits

B3 / U3
10-bits

G3 / Y3
10-bits

R2 / V2
10-bits

B2 / U2
10-bits

G2 / Y2
10-bits

R1 / V1
10-bits

B1 / U1
10-bits

G1 / Y1
10-bits

R0 / V0
10-bits

B0 / U0
10-bits

G 0/ Y0
10-bits

RGB / YUV444
12-bits

R3 / V3
12-bits

B3 / U3
12-bits

G3 / Y3
12-bits

R2 / V2
12-bits

B2 / U2
12-bits

G2 / Y2
12-bits

R1 / V1
12-bits

B1 / U1
12-bits

G1 / Y1
12-bits

R0 / V0
12-bits

B0 / U0
12-bits

G 0/ Y0
12-bits

YUV422
12-bits

X22102-121018

V2
12-bits

Y3
12-bits

U2
12-bits

Y2
12-bits

V0
12-bits

Y1
12-bits

U0
12-bits

Y0
12-bits

144

132

120

108

96

84

72

60

48

36

24

12

0

Figure 1-12: Quad Pixels Data Format (Max Bits Per Component = 12)

X-Ref Target - Figure 1-13

RGB / YUV444
8-bits

R1 / V1
8-bits

RGB / YUV444
10-bits

R1 / V1
10-bits

B1 / U1
8-bits

B1 / U1
10-bits

RGB / YUV444
12-bits

R1 / V1
12-bits

B1 / U1
12-bits

YUV422
12-bits

G1 / Y1
8-bits

G1 / Y1
10-bits

G1 / Y1
12-bits

V0
12-bits

R0 / V0
8-bits

R0 / V0
10-bits

R0 / V0
12-bits

Y1
12-bits

B0 / U0
8-bits

B0 / U0
10-bits

B0 / U0
12-bits

U0
12-bits

G0 / Y0
8-bits

G0 / Y0
10-bits

G0 / Y0
12-bits

Y0
12-bits

72

60

48

36

24

12

0
X22103-121018

Figure 1-13: Dual Pixels Data Format (Max Bits Per Component = 12)

When the parameter, Max Bits Per Component, is set to 12, video formats with actual bits
per component larger than 12 is truncated to the Max Bits Per Component. The remaining
least significant bits are discarded. If the actual bits per component is smaller than Max Bits
Per Component set in the Vivado IDE, all bits are transported with the MSB aligned and the
remaining LSB bits are padded with 0. This applies to all Max Bits Per Component settings.

Table 1-6: Max Bits Per Component Support

Max Bits Per Component

Actual Bits Per Component

Bits Transported by Hardware

16

12

8

10

12

16

8

10

12

16

[7:0]

[9:0]

[11:0]

[15:0]

[7:0]

[9:0]

[11:0]

[15:4]

AXI4-Stream Video IP and System Design
UG934 November 16, 2022

www.xilinx.com

12

Send Feedback
Table 1-6: Max Bits Per Component Support (Cont’d)

Max Bits Per Component

Actual Bits Per Component

Bits Transported by Hardware

Chapter 1:

Introduction

10

8

8

10

12

16

8

10

12

16

[7:0]

[9:0]

[11:2]

[15:6]

[7:0]

[9:2]

[11:4]

[15:8]

As an illustration, when Max Bits Per Component is set to 12, Figure 1-14 shows the data
format for quad pixels per clock to be fully compliant with the AXI4-Stream video protocol.
A data format for a fully compliant AXI4-Stream video protocol with dual pixels per clock is
illustrated in Figure 1-15.

X-Ref Target - Figure 1-14

RGB / YUV444
8-bits

R3 /
V3
8-bits

B3 /
U3
8-bits

G3 /
Y3
8-bits

R2 /
V2
8-bits

B2 /
U2
8-bits

G2 /
Y2
8-bits

R1 /
V1
8-bits

B1 /
U1
8-bits

G1 /
Y1
8-bits

R0 /
V0
8-bits

B0 /
U0
8-bits

G0 /
Y0
8-bits

RGB / YUV444
10-bits

R3 / V3
10-bits

B3 / U3
10-bits

G3 / Y3
10-bits

R2 / V2
10-bits

B2 / U2
10-bits

G2 / Y2
10-bits

R1 / V1
10-bits

B1 / U1
10-bits

G1 / Y1
10-bits

R0 / V0
10-bits

B0 / U0
10-bits

G0 / Y0
10-bits

RGB / YUV444
12-bits

R3 / V3
12-bits

B3 / U3
12-bits

G3 / Y3
12-bits

R2 / V2
12-bits

B2 / U2
12-bits

G2 / Y2
12-bits

R1 / V1
12-bits

B1 / U1
12-bits

G1 / Y1
12-bits

R0 / V0
12-bits

B0 / U0
12-bits

G0 / Y0
12-bits

YUV422
12-bits

V2
12-bits

Y3
12-bits

U2
12-bits

Y2
12-bits

V0
12-bits

Y1
12-bits

U0
12-bits

Y0
12-bits

144

132

120

108

96

84

72

60

48

36

24

12

0

X15247-111015

Figure 1-14: Quad Pixels Data Format (Max Bits Per Component = 12)

AXI4-Stream Video IP and System Design
UG934 November 16, 2022

www.xilinx.com

13

Send Feedback
Chapter 1:

Introduction

X-Ref Target - Figure 1-15

RGB / YUV444
8-bits

RGB / YUV444
10-bits

RGB / YUV444
12-bits

YUV422
12-bits

R1 / V1
8-bits

R1 / V1
10-bits

B1 / U1
8-bits

B1 / U1
10-bits

R1 / V1
12-bits

B1 / U1
12-bits

G1 / Y1
8-bits

G1 / Y1
10-bits

G1 / Y1
12-bits

V0
12-bits

R0 / V0
8-bits

R0 / V0
10-bits

R0 / V0
12-bits

Y1
12-bits

B0 / U0
8-bits

B0 / U0
10-bits

B0 / U0
12-bits

U0
12-bits

G0 / Y0
8-bits

G0 / Y0
10-bits

G0 / Y0
12-bits

Y0
12-bits

72

60

48

36

24

12

0

Figure 1-15: Dual Pixels Data Format (Max Bits Per Component = 12)

X15248-031016

The video interface can also transport quad and dual pixels in the YUV420 color space.

Similarly, for YUV 4:2:0 deep color (10, 12, or 16 bits), the data representation is the same.
The only difference is that each component carries more bits (10, 12, and 16). When
transporting using AXI4-Stream, the data representation need to be compliant to the
protocol defined in this user guide. With the remapping feature, the same native video data
will be converted into AXI4-Stream formats, which is shown in Figure 1-16. The 4:2:0 format
adds vertical subsampling to the 4:2:2 format, which is implemented in Video over
AXI4-Stream by omitting the chroma data on every other line.

X-Ref Target - Figure 1-16

Figure 1-16:

YUV 4:2:0 AXI4-Stream Video Data (Dual Pixel per Clock)

Note: For RGB/YUV444/YUV422, Video data are directly mapped from AXI4 Stream to Native Video
interface without any line buffer. Therefore, Figure 1-12 to Figure 1-15 are common to represent
data interface for both AXI4 Stream and Native Video. The control signals are omitted in the figures.

AXI4-Stream Video IP and System Design
UG934 November 16, 2022

www.xilinx.com

14

Send Feedback
Chapter 1:

Introduction

The subsystem provides full flexibility to construct a system using the configuration
parameters, maximum bits per component and number of pixels per clock. Set these
parameters so that the video clock and link clock are supported by the targeted device. For
example, when dual pixels per clock is selected, the AXI4-Stream video need to run at
higher clock rate comparing with quad pixels per clock design. In this case, it is more
difficult for the system to meeting timing requirements. Therefore the quad pixels per clock
data mapping is recommended for design intended to send higher video resolutions.

Some video resolutions (for example, 720p60) have horizontal timing parameters (1650)
which are not a multiple of 4. In this case the dual pixels per clock data mapping must be
chosen.

AXI4-Stream Video IP and System Design
UG934 November 16, 2022

www.xilinx.com

15

Send Feedback
