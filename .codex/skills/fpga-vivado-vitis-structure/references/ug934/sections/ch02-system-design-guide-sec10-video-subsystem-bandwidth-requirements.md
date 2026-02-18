# Video Subsystem Bandwidth Requirements

_Parent: Chapter 2: System Design Guide_
_Source lines: 4703-6262_

Video Subsystem Bandwidth Requirements

XScaler_SetActiveCoeffSet(ScalerInstPtr, COEFF_SET_INDEX,
COEFF_SET_INDEX);

/*
* Enable the scaling operation
*/
XScaler_EnableRegUpdate(ScalerInstPtr);

return 1;
}

Video Subsystem Bandwidth Requirements

Video data is typically transmitted in contiguous bursts. Each burst comprises active pixel
data. This data is transmitted in contiguous clock cycles which can be followed by clock
cycles of no active data. These cycles of “no data” are called blanking periods. There are
horizontal blanking periods which occur during each between video lines, and vertical
blanking periods that equate to full video lines with no active pixel data at all.

To a memory subsystem, this translates to periods of bursts of video data the size of the
active video frame size followed by burst gaps the length of the video blanking period.
Therefore, for a given video frame, there are periods that require a certain peak bandwidth,
or BWpeak, followed by quiescent periods of no data transmittal. This equates to a peak
bandwidth requirement, or BWpeak.

BWpeak is calculated from the data width, or bits-per-pixel (bpp), and from the video pixel
clock frequency, Fvid. Fvid can be calculated from the video frame rate (Fframe) measured in
frames-per-second, the number of lines-per-frame (including blanking lines) and the
number of pixel clock-cycles-per-line (including blanking clock cycles), shown in
Equation 2-1.

Fvid = Fframe * Nfull lines * Npixels

Equation 2-1

The BWpeak is calculated by multiplying the Video Pixel clock frequency by the number of
bits-per pixel, shown in Equation 2-2.

BWpeak = Fvid * bpp

Equation 2-2

The average bandwidth requirement is defined as the overall number of bits within a frame
over a one entire times the frame rate video frame period (not just during the bursts). This
is the average bandwidth and is always lower than the peak bandwidth requirement. For a
given video frame period, the average bandwidth is BWave. This is shown in Equation 2-3.

Fave= Fframe * Nactive lines * Nactive pixels

Equation 2-3

The BWave is calculated the same as BWpeak by multiplying the Video Pixel clock frequency
by the number of bits-per pixel. This is shown in Equation 2-4.

BWave = Fave * bpp

Equation 2-4

AXI4-Stream Video IP and System Design
UG934 November 16, 2022

www.xilinx.com

46

Send Feedback
Video Subsystem Bandwidth Requirements

It is important to keep the BWpeak and BWave in mind when designing video subsystems, as
these numbers define the clock frequencies and data width of the video IP core(s) and of the
memory subsystem.

Bandwidth and Clocking

Live Video to/from Memory

If a memory subsystem is connected to a video subsystem that drives a live video output or
is driven by a live video input, the memory subsystem must be able to accommodate the
peak frame bandwidth requirements.

X-Ref Target - Figure 2-15

Memory
Subsystem

BWmem

Video
Subsystem

Video Output
BWpeak

Video Input
BWpeak

Video
Subsystem

BWmem

Memory
Subsystem

Figure 2-15: Video Bandwidth and Live Video

AXI4-Stream Video IP and System Design
UG934 November 16, 2022

www.xilinx.com

47

Send Feedback
Video Subsystem Bandwidth Requirements

Memory to/from Memory

If a memory subsystem is connected to a video subsystem that writes to an external memory
interface (to Frame Buffer) or reads from an external memory interface (from frame buffer)
ONLY (thus, no live external video input/outputs), the memory subsystem must be only able
to accommodate the average frame bandwidth requirements.

X-Ref Target - Figure 2-16

Video
Subsystem

BWave

Video
Subsystem

BWave

Video
Subsystem

BWmem

BWmem

Memory
Subsystem

Figure 2-16: Video Bandwidth and External Memory

Bandwidth Examples

Scaling: Down-Scaling/Decimation

In the down-scaling system case, the input video frame is larger than the output video
frame. The average bandwidth of the output is less than the input.

Down-scaling Memory-to-Memory

Figure 2-17 shows an example of down-scaling a video frame. It assumes that the video
frame is read from external memory and written back to external memory. This allows for a
slower minimum operating clock frequency and a lower bandwidth requirement.

AXI4-Stream Video IP and System Design
UG934 November 16, 2022

www.xilinx.com

48

Send Feedback
X-Ref Target - Figure 2-17

0
2
7

Video Subsystem Bandwidth Requirements

Input

Output

0
8
4

1280

640

Figure 2-17: Down-scaling Memory-to-Memory (720p@60 to 640x480p@60)

For the example in Figure 2-17, Table 2-1 shows the input and output minimum frequency
and minimum bandwidth requirements, assuming a data width of 16 and a 60
frames-per-second frame rate.

Table 2-1: Down-scaling Mem-to-Mem Example Minimum Bandwidth and Frequency
Requirements

Minimum Frequency

Minimum Bandwidth

55.3 MHz

0.88 Gb/s

Down-scaling Live External Video

Input

Output

18.43 MHz

0.29 Gb/s

Figure 2-18 shows an example of down-scaling a video frame. It assumes that the input
video frame is from live external video and the output video frame is to live external video.
The bandwidth requirement in this case is the peak bandwidth and has to take into account
bursts of video at the higher frequency.

AXI4-Stream Video IP and System Design
UG934 November 16, 2022

www.xilinx.com

49

Send Feedback
X-Ref Target - Figure 2-18

Input

0
2
7

0
5
7

1280

1650

Video Subsystem Bandwidth Requirements

0
8
4

5
2
5

Output

640

800

Figure 2-18: Down-scaling Live Video (720p@60 to 640x480p@60)

In the example in Figure 2-18, Table 2-2 shows the input and output minimum frequency
and minimum bandwidth requirements, assuming a data width of 16 and a 60
frames-per-second frame rate.

Table 2-2: Down-scaling Live-Video Example Minimum Bandwidth and Frequency
Requirements

Minimum Frequency

Minimum Bandwidth

Down-scaling Example System

Input

74.25 MHz

1.19 Gb/s

Output

25.20 MHz

0.40 Gb/s

Figure 2-19 shows a video system that includes live-external video (peak) bandwidth and
memory (average) bandwidth requirements.

AXI4-Stream Video IP and System Design
UG934 November 16, 2022

www.xilinx.com

50

Send Feedback
Video Subsystem Bandwidth Requirements

X-Ref Target - Figure 2-19

Mem Write
1280x720p@60
16 bits
BWpeak = 1.19Gbps
Fpeak = 74.25MHz

Mem Read
1280x720p@60
16 bits
BWave = 0.88Gbps
Fave = 55.30MHz

Mem Write
640x480p@60
16 bits
BWave = 0.29Gbps
Fave = 18.43MHz

Mem Read
640x480p@60
16 bits
BWpeak = 0.40Gbps
Fpeak =25.20MHz

M
M
-
4
X
A

I

I

A
X
4
-
M
M

M
M
-
4
X
A

I

I

A
X
4
-
M
M

From
Camera

Video
In

AXI4-
Stream

VDMA 1

AXI4
Stream

Scaler

AXI4
Stream

VDMA 2

AXI4
Stream

Video
Out

To Display

Video Input
1280x720p@60
16 bits
BWpeak = 1.19Gbps
Fpeak = 74.25MHz

Vieo Output
640x480p@60
16 bits
BWpeak = 0.40Gbps
Fpeak = 25.20MHz

Figure 2-19: Down-scaling (720p@60 to 640x480p@60) Subsystem Example

In Figure 2-19, 720p live video frames are written to external memory with a bandwidth of
1.19 Gb/s. These frames can be read at an average bandwidth of 0.88 Gb/s. These frames are
then downscaled and written at an average bandwidth of 0.29 Gb/s. The downscaled frames
can then be read from external memory at a peak bandwidth of 0.40 Gb/s to display to
external video.

Thus, video input bandwidth is BWpeak of input size. Video output bandwidth is BWpeak of
output size. Intermediate memory read bandwidth is BWave of input size. Intermediate
memory write bandwidth is BWave of output size.

AXI4-Stream Video IP and System Design
UG934 November 16, 2022

www.xilinx.com

51

Send Feedback
Table 2-3:

Downscaling Subsystem Example Total Bandwidth and Minimum Frequency Requirements

Video Subsystem Bandwidth Requirements

Minimum
Frequency

Minimum
Bandwidth

Video Input

(Memory Write) Memory Read Memory Write
74.25 MHz

18.43 MHz

55.3 MHz

Memory Read
(Video Output) Total/Maximum
25.20 MHz

74.25 MHz
(Max)

1.19 Gb/s

0.88 Gb/s

0.29 Gb/s

0.40 Gb/s

2.76 Gb/s
(Sum)
1.48 Gb/s (W)
1.28 Gb/s (R)

Up-Scaling

In the up-scaling case, the input video frame is smaller than the output video frame. The
average bandwidth of the output is more than the input.

Up-scaling Memory-to-Memory

Figure 2-20 shows an example of up-scaling a video frame. It assumes that the video frame
is read from external memory and written back to external memory. This allows for a slower
minimum operating clock frequency and a lower bandwidth requirement.

X-Ref Target - Figure 2-20

Input

Output

0
8
4

0
2
7

640

1280

Figure 2-20: Up-scaling Memory-to-Memory (640x480p@60 to 720p@60)

In the example in Figure 2-20, the Table 2-4 shows the input and output minimum
frequency and minimum bandwidth requirements, assuming a data width of 16 and a 60
frames-per-second frame rate.

Table 2-4: Up-scaling Mem-to-Mem Example Minimum Bandwidth and Frequency Requirements

Minimum Frequency

Minimum Bandwidth

Input

18.43 MHz

0.29 Gb/s

Output

55.3 MHz

0.88 Gb/s

AXI4-Stream Video IP and System Design
UG934 November 16, 2022

www.xilinx.com

52

Send Feedback

Video Subsystem Bandwidth Requirements

Up-scaling Live External Video

Figure 2-21 shows an example of up-scaling a video frame. It assumes that the input video
frame is from live external video and the output video frame is to live external video. The
bandwidth requirement in this case is the peak bandwidth and has to take into account
bursts of video at the higher frequency.

X-Ref Target - Figure 2-21

Input

0
8
4

5
2
5

640

800

Output

1280

1650

0
2
7

0
5
7

Figure 2-21: Up-scaling Live Video (640x480p@60 to 720p@60)

In the example in Figure 2-21 and Table 2-5 describe the input and output minimum
frequency and minimum bandwidth requirements, assuming a data width of 16 and a 60
frames-per-second frame rate.

Table 2-5: Up-scaling Live-Video Example Minimum Bandwidth and Frequency Requirements

Frequency

Bandwidth

Input

25.20 MHz

0.40 Gb/s

Output

74.25 MHz

1.19 Gb/s

AXI4-Stream Video IP and System Design
UG934 November 16, 2022

www.xilinx.com

53

Send Feedback
Video Subsystem Bandwidth Requirements

Up-scaling Example System

Figure 2-22 shows a video system that includes live-external video (peak) bandwidth and
memory (average) bandwidth requirements.

X-Ref Target - Figure 2-22

Mem Write
640x480p@60
16 bits
BWpeak = 0.40Gbps
Fpeak =25.20MHz

Mem Read
640x480p@60
16 bits
BWave = 0.29Gbps
Fave = 18.43MHz

Mem Write
1280x720p@60
16 bits
BWave = 0.88Gbps
Fave = 55.30MHz

Mem Read
1280x720p@60
16 bits
BWpeak = 1.19Gbps
Fpeak = 74.25MHz

M
M
-
4
I
X
A

I

A
X
4
-
M
M

M
M
-
4
I
X
A

I

A
X
4
-
M
M

From
Camera

Video
In

AXI4-
Stream

VDMA 1

AXI4
Stream

Scaler

AXI4
Stream

VDMA 2

AXI4
Stream

Video
Out

To Display

Video input
640x480p@60
16 bits
BWpeak = 0.40Gbps
Fpeak = 25.20MHz

Video Output
1280x720p@60
16 bits
BWpeak = 1.19Gbps
Fpeak = 74.25MHz

Figure 2-22: Up-scaling (640x480p@60 to 720p@60) Subsystem Example

In the Figure 2-22, 640x480p live video frames are written to external memory with a
bandwidth of 0.40 Gb/s. These frames can be read at an average bandwidth of 0.29 Gb/s.
These frames are then up-scaled and written at an average bandwidth of 0.88 Gb/s. The
upscaled frames can then be read from external memory at a peak bandwidth of 1.19 Gb/s
to display to external video.

Thus, video input bandwidth is BWpeak of input size. Video output bandwidth is BWpeak of
output size. Intermediate memory read bandwidth is BWave of input size. Intermediate
memory write bandwidth is BWave of output size.

AXI4-Stream Video IP and System Design
UG934 November 16, 2022

www.xilinx.com

54

Send Feedback
Video Subsystem Bandwidth Requirements

Table 2-6: Up-scaling Subsystem Example Total Bandwidth and Minimum Frequency Requirements

Video Input

(Memory Write) Memory Read Memory Write

Memory Read
(Video Output)

Total/Maximum

Minimum
Frequency

Minimum
Bandwidth

Zoom

25.20 MHz

18.43 MHz

55.3 MHz

74.25 MHz

74.25 MHz (Max)

0.40 Gb/s

0.29 Gb/s

0.88 Gb/s

1.19 Gb/s

2.76 Gb/s (Sum)
1.28 Gb/s (W) 1.48
Gb/s (R)

In the zoom system case, the input video frame is the same as the output video frame. The
average bandwidth at the output is same as the input.

Zoom Memory-to-Memory

Figure 2-23 shows an example of zooming a video frame. It assumes that the video frame is
read from external memory and written back to external memory. This allows for a slower
minimum operating clock frequency and a lower bandwidth requirement.

Input

Output

X-Ref Target - Figure 2-23

0
2
7

1280

1280

Figure 2-23:

Zoom Memory-to-Memory (to 720p@60 to 720p@60)

In the example in Figure 2-23, Table 2-7 shows the input and output minimum frequency
and minimum bandwidth requirements, assuming a data width of 16 and a 60
frames-per-second frame rate.

Table 2-7:

Zoom Mem-to-Mem Example Minimum Bandwidth and Frequency Requirements

Minimum Frequency

Minimum Bandwidth

Input

55.3 MHz

0.88 Gb/s

Output

55.3 MHz

0.88 Gb/s

AXI4-Stream Video IP and System Design
UG934 November 16, 2022

www.xilinx.com

55

Send Feedback

Video Subsystem Bandwidth Requirements

Zoom Live External Video

Figure 2-24 shows an example of zooming a video frame. It assumes that the input video
frame is from live external video and the output video frame is to live external video. The
bandwidth requirement in this case is the peak bandwidth and has to take into account
bursts of video at the higher frequency.

X-Ref Target - Figure 2-24

Input

Output

0
2
7

0
5
7

1280

1650

1280

1650

Figure 2-24:

Zoom Live Video (640x480p@60 to 720p@60)

In the example in Figure 2-24 and Table 2-8 describe the input and output minimum
frequency and minimum bandwidth requirements, assuming a data width of 16 and a 60
frames-per-second frame rate.

Table 2-8:

Zoom Live-Video Example Minimum Bandwidth and Frequency Requirements

Minimum Frequency

Minimum Bandwidth

Input

74.25 MHz

1.19 Gb/s

Output

74.25 MHz

1.19 Gb/s

AXI4-Stream Video IP and System Design
UG934 November 16, 2022

www.xilinx.com

56

Send Feedback
Video Subsystem Bandwidth Requirements

Zoom Example System

Figure 2-25 shows a video system that includes live-external video (peak) bandwidth and
memory (average) bandwidth requirements.

X-Ref Target - Figure 2-25

Mem Write
1280x720p@60
16 bits
BWpeak = 1.19Gbps
Fpeak = 74.25MHz

Mem Read
640x480p@60
16 bits
BWave = 0.29Gbps
Fave = 18.43MHz

Mem Write
1280x720p@60
16 bits
BWave = 0.88Gbps
Fave = 55.30MHz

Mem Read
1280x720p@60
16 bits
BWpeak = 1.19Gbps
Fpeak = 74.25MHz

M
M
-
4
I
X
A

I

A
X
4
-
M
M

M
M
-
4
I
X
A

I

A
X
4
-
M
M

From
Camera

Video
In

AXI4-
Stream

VDMA 1

AXI4
Stream

Scaler

AXI4
Stream

VDMA 2

AXI4
Stream

Video
Out

To Display

Video Input
1280x720p@60
16 bits
BWpeak = 1.19Gbps
Fpeak = 74.25MHz

Video Output
1280x720p@60
16 bits
BWpeak = 1.19Gbps
Fpeak = 74.25MHz

Figure 2-25:

Zoom (640x480p@60 to 720p@60) Subsystem Example

In the Figure 2-25, 1280x720p live video frames are written to external memory with a
bandwidth of 1.19 Gb/s. A 640x480 region in the video frame is read at an average
bandwidth of 0.29 Gb/s. These frames are then up-scaled and written at an average
bandwidth of 0.88 Gb/s. The upscaled frames can then be read from external memory at a
peak bandwidth of 1.19 Gb/s to display to external video (Same as the input).

Thus, video input bandwidth is BWpeak of input size. Video output bandwidth is BWpeak of
output size. Intermediate memory read bandwidth is BWave of input size. Intermediate
memory write bandwidth is BWave of output size.

AXI4-Stream Video IP and System Design
UG934 November 16, 2022

www.xilinx.com

57

Send Feedback
Video Subsystem Bandwidth Requirements

Table 2-9:

Zoom Subsystem Example Total Bandwidth and Minimum Frequency Requirements

Video Input

(Memory Write) Memory Read Memory Write

Memory Read
(Video Output)

Total/Maximum

Minimum
Frequency

Minimum
Bandwidth

74.25 MHz

18.43 MHz

55.3 MHz

74.25 MHz

74.25 MHz Max

1.19 Gb/s

0.29 Gb/s

0.88 Gb/s

1.19 Gb/s

3.55 Gb/s (Sum)
2.07 Gb/s (W)
1.48 Gb/s (R)

Typical Video Formats

Typical video formats and their operating frequency and bandwidth (average and peak) in
Table 2-10.

Table 2-10:

Typical Video Format Sizes, Frequencies and Bandwidths

Video Format

Frequency

BPP

Active
H

Active V

FPS

Full H

Full V

Min
Frame/
Ave
MHz

Min
Line/Pe
ak MHz

Average
Bandwidth
BWave

Peak Burst
Bandwidth
BWpeak

Gb/s

Gb/s2

Gb/s3 GB/s4

16

32

16

32

16

32

16

36

16

16

16

16

16

16

16

16

16

16

1920

1920

800

800

1280

1280

4096

4096

640

720

720

1024

1280

1280

1280

1280

1440

1680

1080

1080

600

600

720

720

2048

2048

480

480

576

768

768

800

960

1024

900

1050

60

60

60

60

60

60

60

60

60

60

50

60

60

60

60

60

60

60

2200

2200

1056

1056

1650

1650

4300

4300

800

858

864

1344

1440

1680

1800

1688

1904

2240

1125

124.42

148.50

1125

124.42

148.50

628

628

750

750

28.80

39.79

28.80

39.79

55.30

74.25

55.30

74.25

2300

503.32

593.40

1.99

3.98

0.46

0.92

0.88

1.77

8.05

2300

503.32

593.40

18.12

525

525

625

806

790

831

18.43

25.20

20.74

27.03

20.74

27.00

47.19

65.00

58.98

68.26

61.44

83.76

1000

1066

73.73

108.00

78.64

107.96

934

77.76

106.70

1089

105.84

146.36

0.29

0.33

0.33

0.75

0.94

0.98

1.18

1.26

1.24

1.69

0.25

0.50

0.06

0.12

0.11

0.22

1.01

2.26

0.04

0.04

0.04

0.09

0.12

0.12

0.15

0.16

0.16

0.21

2.38

4.75

0.64

1.27

1.19

2.38

9.49

21.36

0.40

0.43

0.43

1.04

1.09

1.34

1.73

1.73

1.71

2.34

AXI4-Stream Video IP and System Design
UG934 November 16, 2022

www.xilinx.com

0.30

0.59

0.08

0.16

0.15

0.30

1.19

2.67

0.05

0.05

0.05

0.13

0.14

0.17

0.22

0.22

0.21

0.29

58

Send Feedback
