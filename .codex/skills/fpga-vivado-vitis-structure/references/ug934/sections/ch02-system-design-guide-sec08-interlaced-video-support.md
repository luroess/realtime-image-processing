# Interlaced Video Support

_Parent: Chapter 2: System Design Guide_
_Source lines: 3143-3822_

Interlaced Video Support

Interlaced Video Support

Interlaced video is a technique for doubling the perceived frame rate of a video display
without consuming extra bandwidth. The interlaced signal contains two fields of a video
frame captured at two different times. This enhances motion perception to the viewer, and
reduces flicker by taking advantage of the phi phenomenon.

This effectively doubles the time resolution (also called temporal resolution) as compared to
non-interlaced footage (for frame rates equal to field rates). Interlaced signals require a
display that is natively capable of showing the individual fields in a sequential order. CRT
displays and ALiS plasma displays are made for displaying interlaced signals.

Interlaced video standards have several differences over progressive standards:

•

•

•

Each field consists of a different set of lines. The set of odd lines is separated in time
from the set of even lines.

The timing may vary on a per frame basis. Because there are usually an odd number of
lines per frame, the number of total lines per field is different by one line. Moreover,
this line difference may appear in the active period or in the blanking period depending
on the particular line standard. This means that timing intervals may be different in odd
frames and even frames.

There is a need to distinguish fields from each other. For progressive video, it is
sufficient to mark video frames, because the timing and line composition of each frame
is identical, however for interlace the two frames must be distinguished from each
other, and the correct set of lines must be presented with frame timing for the picture
to be displayed properly.

AXI4-Stream Video IP and System Design
UG934 November 16, 2022

www.xilinx.com

29

Send Feedback
Interlace Video Timing

Figure 2-8 shows examples of interlaced line standards, including details of the vertical
timing.

Interlaced Video Support

X-Ref Target - Figure 2-8

NTSC

line#

525 1

vblank

263 264

282 283

525 1

19

20

20

3 4

244

20

265 266

243

3 4

Field 0 (262 lines)

Field 1 (263 lines)

field_id

PAL

line#

623 624

625 1 22 23

310 311

335 336

623 624

6251

22

23

vblank

1080i

field_id

line#

vblank

field_id

X22105-121018

24

625 1

288

25

312 313

288

625 1

Field 0 (312 lines)

Field 1 (313 lines)

1
1
2
3

1
1
2
4

1
1
2
5

2
0

2
1

1

5
6
0

5
6
1

5
8
3

5
8
4

1
1
2
3

1
1
2
4

1
1
2
5 1

2
0

2
1

22

1
1
2
5 1

540

23

5
6
3

5
6
4

540

1
1
2
5 1

Field 0 (563 lines)

Field 1 (562 lines)

Figure 2-8:

Interlaced Video Line Standards

Xilinx IP Interlace Video Support

Xilinx Video IP supports Interlace content using field_id or fid interface as a separate
port along with AXI4S-Video interface. The field_id signal indicates the polarity of the
field when the video is interlaced. This signal is only used with interlaced data and set to
zero for progressive video inputs. The field_id signal changes with the rising edge of
Start of Frame/Field (TUSER) of the AXI4-Stream interface. The following IPs help handle the
interlaced content effectively using field_id signal.

Deinterlacer

The Video Deinterlacer converts live incoming interlaced video streams into progressive
video streams. Interlaced images may have temporal motion between the two fields that
comprise an interlaced frame. The conversion to a progressive format recombines these two
fields into one single progressive scan frame. The combining of interlaced video streams

AXI4-Stream Video IP and System Design
UG934 November 16, 2022

www.xilinx.com

30

Send Feedback
Interlaced Video Support

results in unsightly motion artifacts in the progressive output image. For this reason, the
Video Deinterlacer can be configured to use three field buffers and produce progressive
frames based on a combination of spatial and temporal processing. This core is part of
Video processing sub system, refer to the Video Processing Subsystem LogiCORE PIP Product
Guide (PG231)for more information on this IP.

AXI4-Stream Video Bridges

There are two AXI4-Stream bridges which convert native video to AXI4-Stream Video
protocol and vice versa, as depicted in Figure 2-9.

X-Ref Target - Figure 2-9

Figure 2-9: AXI4-Stream Data Timing Diagram with field id Signal

AXI4-Stream to Video Out

The Xilinx LogiCORE™ IP AXI4-Stream to Video Out core is designed to interface from the
AXI4-Stream interface implementing a Video Protocol to a video source (parallel video data,
video syncs, and blanks). This core works with the Xilinx Video Timing Controller (VTC) core.
This core provides a bridge between video processing cores with AXI4-Stream interfaces
and a video output. The interlace content is supported by field_id signal.

Video In to AXI4-Stream

The Xilinx LogiCORE IP Video In to AXI4-Stream core is designed to interface from a video
source (clocked parallel video data with synchronization signals - active video with either
syncs, blanks or both) to the AXI4-Stream Video Protocol Interface. This core works with the
timing detector portion of the Xilinx Video Timing Controller (VTC) core. This core provides
a bridge between a video input and video processing cores with AXI4-Stream Video
Protocol interfaces. The interlace content is supported by field_id signal.

AXI4-Stream Video IP and System Design
UG934 November 16, 2022

www.xilinx.com

31

Send Feedback
Interlaced Video Support

Frame Buffer Read/Write

The Xilinx LogiCORE IP Video Frame Buffer Read and Video Frame Buffer Write cores
provide high-bandwidth direct memory access between memory and AXI4-Stream video
type target peripherals, which support the AXI4-Stream Video protocol. Interlaced content
is supported using field_id signal over AXI4-Stream interface.

Video Test Pattern Generator

The Xilinx LogiCORE IP Video Test Pattern Generator core generates test patterns for video
system bring up, evaluation, and debugging. The core provides a wide variety of tests
patterns enabling you to debug and assess video system color, quality, edge, and motion
performance. The core can be inserted in an AXI4-Stream video interface that allows
user-selectable pass-through of system video signals or insertion of test patterns. Interlaced
content is supported using field_id signal over AXI4-Stream interface.

Basic Video System with Interlace Content

Figure 2-10 shows the interfaces on Video In to AXI4-Stream, AXI4-Stream to Video Out,
and VTC cores to support the video field ID with the interlace-related signals highlighted in
red.

AXI4-Stream to Video Out

Video Output

X-Ref Target - Figure 2-10

Video In to AXI4-Stream

Video Input

Data in

data_valid

vblank

hblank

vsync

hsync

field_id

AXI4-Stream
Master

Lvalid

Lready

Ldata

Llas |EOL|

Luser|Q||SOF|

i

V
d
e
o
P
r
o
c
e
s
s
n
g
C
o
r
e
(
s
)

i

AXI4-Stream
Slave

Lvalid

Lready

Ldata

Llas |EOL|

Luser|Q||SOF|

axi_field_id

axi_field_id

VTIMING

Video Timing
Controller

(detector)

Video Timing
Controller

(generator)

Data in

data_valid

vblank

hblank

vsync

hsync

field_id

X22106-121018

Figure 2-10: Video System with Interlaced Content Using AXI4-Stream Bridges

Most video processing cores are field-agnostic, and not aware of whether the picture being
processed is an odd or even frame, or a progressive field. Therefore, interlace has no impact
on these cores. The Video In to AXI4-Stream core has a frame ID output, fid, timed to the
native video bus. This signal can be used as needed in the system. The only cores that use
this fid bit are the AXI4-Stream to Video Out.

AXI4-Stream to Video Out core aligns the axi_field_id signal with the field_id signal
generated by Video Timing Controller module. You can directly connect the field_id

AXI4-Stream Video IP and System Design
UG934 November 16, 2022

www.xilinx.com

32

Send Feedback


Interlaced Video Support

signal to AXI4-Stream to Video Out core bypassing the Video processing cores as shown in
Figure Figure 2-10 only when latency of the processing core is less than one Video frame. If
the latency is more than one video frame, respective video processing cores should delay
the field id signal accordingly.

On the Video In to AXI4-Stream core, the fid bit changes coincident with SOF and remains
constant throughout the remainder of the field. On the AXI4-Stream to Video Out core, the
fid bit is sampled coincident with SOF in Figure 2-11. Therefore, the Video In to AXI4-Stream
can provide the field bit directly to the AXI4-Stream to Video Out core if no intervening
frame buffer exists. When a deinterlacer or frame buffer is used, a similar scheme can be
employed: generate the field ID coincident with the start of the field, and on the receiving
side sample the field ID coincident with the first received pixel.

X-Ref Target - Figure 2-11

AXI4-Stream Data

Field 0

Field 1

Vid In

SOF (tuser[0])

Axi_field_id

processing latency

AXI4-Stream Data

Field 0

Vid Out

SOF (tuser[0])

Axi_field_id

Figure 2-11: AXI4-Stream Data Timing Diagram with field ID Signal

X22107-121018

AXI4-Stream Video IP and System Design
UG934 November 16, 2022

www.xilinx.com

33

Send Feedback
Interlaced Video Support

Frame buffer read/Write and Video Deinterlacer cores. The AXI4-Stream to Video Out core
has a field ID input (fid), sampled in time with the AXI4-Stream input bus. This fid bit
must be asserted by the upstream source of AXI4-Stream video. For systems without a frame
buffer or deinterlacing, the field ID input originates from the Video In core, as shown in
Figure 2-12.

Video In to AXI4-Stream

X-Ref Target - Figure 2-12

Video Input

Data in

data_valid

vblank

hblank

vsync

hsync

field_id

DDR

F
r
a
m
e
B
u
f
f
e
r

W
h
i
t
e

F
r
a
m
e
B
u
f
f
e
r
R
e
d

field_id

i

V
d
e
o
P
r
o
c
e
s
s
n
g
C
o
r
e
(
s
)

i

i

V
d
e
o
P
r
o
c
e
s
s
n
g
C
o
r
e
(
s
)

i

axi_field_id

axi_field_id

VTIMING

Video Timing
Controller

(detector)

Video Timing
Controller

(generator)

AXI4-Stream to Video Out

Video Output

Data in

data_valid

vblank

hblank

vsync

hsync

field_id

X22108-121018

Figure 2-12: Video System with Interlaced Content Using Frame Buffer Write/Read

For systems with a frame buffer, the field ID input can come from any core containing a
frame buffer. The field ID from the Video In to AXI4-Stream core can be used by the frame
buffer if necessary, shown in Figure 2-12.

Note:

In Figure 2-12, the AXI4-Stream to Video Out core is operating in slave mode.

AXI4-Stream Video IP and System Design
UG934 November 16, 2022

www.xilinx.com

34

Send Feedback
