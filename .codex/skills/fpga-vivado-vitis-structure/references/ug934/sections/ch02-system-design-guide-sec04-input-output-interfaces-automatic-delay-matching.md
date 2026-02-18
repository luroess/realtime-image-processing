# Input/Output Interfaces - Automatic Delay Matching

_Parent: Chapter 2: System Design Guide_
_Source lines: 2286-2872_

Input/Output Interfaces - Automatic Delay Matching

Input/Output Interfaces - Automatic Delay
Matching

The handshaking mechanism of AXI4-Stream provides a framework that allows building
video systems that align data and timing signals without having to manually calculate
propagation delay through processing blocks, as well as creating frame sync signals to
trigger certain blocks. For data and output sync signal alignment, consider the following
design constraints:

•

Is it possible to hold up the input video stream? Is there a back pressure signal?

• Must the output stream be phase-locked to an external Frame Sync signal?

• Are the input and output video clocks the same or phase-locked to each other?

Based on the above consideration, typical use cases include:

•

•

Timed video input, such as DVI, that cannot be delayed. Timed video output using the
same video clock. For automatic delay matching, synchronization is necessary.

Input and output are in unrelated clock domains (scaled video), and a frame buffer is
necessary.

No delay matching is necessary in a hardware accelerator scenario where input is coming
from memory or from a processor. Processing and output blocks can generate output when
the input is available. If input and output are in unrelated clock domains, a frame buffer is
necessary. The following sections contain recommendations for implementing
protocol-based delay matching for scenarios with or without frame buffers.

In all cases, the input interface module is expected to have a “locked” output, originating
from the VTC timing detector. The VTC timing detector issues a signal when the input timing
measurements are stabilized. The input interface module is expected to drop pixel data until
input timing has locked.

Periodic Input Stream, Unconstrained Output Stream, No Frame
Buffer

This section provides an algorithm (Figure 2-2) describing how automatic data-sync signal
alignment can be achieved at the output interface for a video system that contains

•

•

•

no frame buffer

a periodic input stream that cannot be held off

an output video pixel clock that is either the same, or a derivative of the input pixel
clock, and

AXI4-Stream Video IP and System Design
UG934 November 16, 2022

www.xilinx.com

19

Send Feedback
Input/Output Interfaces - Automatic Delay Matching

•

the output video stream does not have to be phase locked to an external Frame Sync
signal.

X-Ref Target - Figure 2-2

n
u
r
r
e
d
n
u

r
e
f
f
u
b

r
o
T
E
S
E
R

Reset / POR State

Output timing
generator stopped
at first active pixel

Input
Timing
Locked?

No

Yes

Waiting for
Input buffer to fill
up over 50%

Output timing
generator running
locked to input
video clock

Figure 2-2: Output Timing Generator Control Flowchart for Unconstrained Output Video Stream

This scenario applies to a sensor image pre-processing pipeline, where input and output
pixel rates are identical, and the output timing generator does not have to be locked to an
external frame sync source. After power on or reset, the output AXI4-Stream interface
deasserts READY, and the output timing signal generator state machine is initialized to wait
in the state just before the start of active video.

Note:
stream cannot be held back.

In this case, the function of READY is limited to what the internal buffers allow if the input

The output timing generator waits for the input interface to signal that timing information
has stabilized (locked). Now, the output AXI4-Stream interface should assert READY, which
propagates backward towards the input of the pipeline. As a result, pixel data is propagated
down the pipeline. Processed pixel data reaches the output interface module when its
VALID input is sampled high. When the input data buffer of the output video interface gets
50% full, the output timing generator can start generating periodic output sync/blank
signals, and pixel data can be fed forward to the output.

AXI4-Stream Video IP and System Design
UG934 November 16, 2022

www.xilinx.com

20

Send Feedback


Input/Output Interfaces - Automatic Delay Matching

Output Stream Generation for Pixel Data from Frame Buffer

This section provides an algorithm for automatic data–sync signal alignment at the output
interface for a video system that contains a frame buffer, and the output video stream might
be in a separate clock domain or might have to be phase-locked to an external Frame Sync
signal (Figure 2-3).

X-Ref Target - Figure 2-3

DVI

Video
to
AXI4-Stream

AXI4-S

Video
Processing
Pipeline

AXI4-S

External Memory

AXI-
VDMA

Video to
Frame
Buffer

AXI-
VDMA

Video
from
Frame
Buffer

Video
Timing
Detector

AXI4-Lite

uBlaze or A9
AXI4-Lite master

AXI4-S

Video
Processing
Pipeline

AXI4-S

AXI4-Stream
To
Video

DVI

Video
Timing
Generator

clk

Fsync

Figure 2-3:

Example System with Output Sync Tied to an External Frame Sync Signal

The portion of this system relevant to output stream synchronization is the leg from the
frame buffer to the output interface core, which can contain processing cores. These
processing cores can change the effective pixel rate. The example presented in Figure 2-4
uses a video scaler, which typically changes the pixel rate, and can operate in three different
clock domains:

•

•

•

its input interface running at the memory system clock rate

the core processing data at a processing clock rate

its output interface running at the same clock as the output interface, which can come
from an external clock source

The choice of external frame buffer for AXI4-Stream based IP video systems is the
AXI-VDMA core, which must be configured to the desired frame size using an AXI4-Lite
interface. Figure 2-4 illustrates timing information (from an input interface core, or from
software) distributed using this interface.

AXI4-Stream Video IP and System Design
UG934 November 16, 2022

www.xilinx.com

21

Send Feedback
Input/Output Interfaces - Automatic Delay Matching

X-Ref Target - Figure 2-4

Fsync

Ext
Fsync

AXI-
VDMA

AXI4-S Video Scaler

AXI4-S

AXI4-
Stream
To
Video

a
t
a
d

g
n
m

i

i
t

e
z
s

i

r
t
p

e
d
o
m

e
e
m
m
a
a
Video
r
r
f
f
Timing
Generator

AXI4-Lite

DVI

Ext
clk

Figure 2-4:

Example System with a Video Scaler

Three possible scenarios are addressed in this setup:

1. External output clock (Ext clk) is different from the input clock, but there is no external

Fsync signal.

2. Output Timing Generator needs to be locked to an external Fsync.

3. External Fsync driving the AXI-VDMA readouts.

For scenario 1, the data – sync signal alignment algorithm is as follows:

After power up or reset, the output interface core should deassert READY and set all outputs
to defaults until timing information is locked (Figure 2-7). The AXI-VDMA should be
configured with the write side being Fsync and Genlock master. When the input buffer of
the Video output core is 50% filled with data from the AXI-VDMA, the output timing signal
generation should commence. When the timing generator gets to the phase where active
video needs to be sent, but pixels are not present yet, blank frames should be generated. If
the output interface data buffer gets full, the output interface core should deassert TREADY.

For scenario two, the setup and protocol are identical, but the video timing generator
should be configured to sync with the external Fsync.

For scenario 3, a frame sync signal originating from the output timing generator or an
external fsync is used to trigger AXI-VDMA frame reads. If an external frame sync signal is
present, ensure that the phase relationship between the external Fsync pulse and the VTC
generator Fsync allows pixel data to be fetched from the AXI-VDMA and propagated
through subsequent cores between the AXI-VDMA and the output interface module. This
allows data and timing signals on the output interface to be synchronized.

A good example of this is when the external frame sync is in phase with the start of vertical
blanking. If output pixels are needed immediately, this sync is too late to trigger readout
from the AXI-VDMA.

AXI4-Stream Video IP and System Design
UG934 November 16, 2022

www.xilinx.com

22

Send Feedback


Input/Output Interfaces - Automatic Delay Matching

The timing generator core contains logic which can generate frame sync pulses at arbitrary
phases after the generator is generating periodic timing signals. For scenarios when the
external frame sync is too late to trigger data readout, an earlier, regenerated frame sync
pulse should be used. This ensures that pixel data gets to the output interface core before
it needs to be sent in phase with the periodic output timing signals.

For video systems with a Frame Buffer but no external output frame sync source, the
AXI-VDMA core can automatically fetch the last frame finished on the write-side to be
picked up immediately when the read size is in idle (reading a frame has completed).

When pixel data propagates to the output interface core, the output interface core should
deassert its READY output and start driving pixel data using READY to maintain synchrony
between the input pixel flow and output sync signals.

When Sync is Lost

When output interface cores are used in conjunction with a frame buffer (see Periodic Input
Stream, Unconstrained Output Stream, No Frame Buffer), output timing signal generation
should start immediately after timing has locked, regardless of whether an external frame
sync pulse is present.

When an out-of-sync external frame sync pulse is received, output timing generation should
re-initialize. A new fsync pulse should be generated for the AXI-VDMA, and input pixels
from the existing frame should be dropped until the arrival of the SOF pulse. If necessary, a
blank frame should be sent on the output until sync is reestablished.

If the external frame sync pulse is not present when expected, output timing generation
should continue freewheeling.

Input Interface cores should not start sending incomplete frames. If the timed video source
is disconnected or reconnected, or when the system recovers from reset or power-up, the
input AXI4-Stream interface core should wait until the start of the first frame after timing is
locked before sending data over the AXI4-Stream master interface.

When Timing Information Is Incorrect

This situation can arise if any of the AXI-VDMA frame dimensions, the scaler frame
dimensions or ratios, or the output interface timing parameters are programmed incorrectly
(Figure 2-4).

There could be a discrepancy between measured frame dimensions based on EOL and SOF
locations and the frame dimensions provided to the VTC generator side and the processing
cores through the core GUI or the AXI4-Lite register interface.

If the SOF and EOL framing signals occur early, processing cores should immediately start
processing the new line or new frame. If the framing signals are late, processing cores

AXI4-Stream Video IP and System Design
UG934 November 16, 2022

www.xilinx.com

23

Send Feedback
Input/Output Interfaces - Automatic Delay Matching

should purge partial frames by dropping pixels until the expected SOF or EOL signal is
received.

Streaming Video Input Connection

As illustrated in Figure 2-3, the Video In to AXI4-Stream core (VID-IN) is provided to
interface periodic video, such as HDMI or DVI to AXI4-Stream, and is intended for use with
the Video Timing Controller (VTC). Together, the VTC processes timing signals and the
VID-IN core buffers input video data (as necessary) before transmission over AXI4-Stream.
The VTC core can process one of the following sets of timing signals:

• Vsync, Hsync, and DE

• Vblank, Hblank, and DE

• Vsync, Hsync, Vbank, Hblank, and DE

The choice of timing signal sets should be specified when generating the VTC core.

Figure 2-5 shows a typical example of connecting the VID-IN and VTC cores to downstream
video processing cores (“Video IP Sink”) through AXI4-Stream interfaces.

X-Ref Target - Figure 2-5

Video In to AXI4-Stream

Video IP “Sink”

vid_data
vid_de
vid_vblank
vid_hblank
vid_vsync
vid_hsync
vid_in_clk

m_axis_video_tdata
m_axis_video_tvalid
m_axis_video_tready
m_axis_video_tlast
m_axis_video_tuser
aclk
aclken
aresetn

axis_enable

vtd_active_video
vtd_vblank
vtd_hblank
vtd_vsync
vtd_hsync

s_axis_video_tdata
s_axis_video_tvalid
s_axis_video_tready
s_axis_video_tlast
s_axis_video_tuser
aclk
aclken
aresetn

m_axis_video_tdata
m_axis_video_tvalid
m_axis_video_tready
m_axis_video_tlast
m_axis_video_tuser

Video Timing Controller (detector)

INTC_IF[8] - locked

active_video_in
vblank_in
hblank_in
vsync_in
hsync_in

INTC_IF

aclk
aclken
aresetn

Figure 2-5: Connecting the Video to AXI4-Stream Core to the Video Timing Controller

AXI4-Stream Video IP and System Design
UG934 November 16, 2022

www.xilinx.com

24

Send Feedback
Input/Output Interfaces - Automatic Delay Matching

At startup, the following points should be considered:

•

•

The VID-IN core should not start sending data to downstream core(s) until they are
enabled and initialized.

The VID-IN core should not start sending data to downstream cores until the VTC cores
is enabled, initialized, and locked.

After the start of streaming video, bootup, or resetting the system, the VTC core can take
more than a full frame of data to accurately measure all timing parameters. During this time
the locked status bit of the VTC, available through bit 8 of the optional INTC_IF interface, is
0. It is recommended to connect INTC_IF[8] to the axis_enable input of VID-IN core. This
hardware configuration ensures that no video is sent before the VTC is locked.

Xilinx recommends that the VTC detector be enabled only after the rest of the downstream
processing cores are all initialized and enabled. Otherwise, the output FIFO within the
VID-In core can become full while downstream cores initialize in the pipe, ultimately
resulting to lost pixels, lines, and/or frames of video.

If the downstream IP core need to know the input resolution before it can be configured, the
you should:

1. SW Reset and SW disable all processing cores and the VTC

2. Enable the VTC to detect input resolution.

3. Once the VTC is locked, read measured resolution.

4. Reset the VTC

5. Configure the downstream IP.

6. Enable the downstream IP.

7. Enable the VTC

AXI4-Stream Video IP and System Design
UG934 November 16, 2022

www.xilinx.com

25

Send Feedback
