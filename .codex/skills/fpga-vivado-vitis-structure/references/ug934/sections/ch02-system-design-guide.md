# Chapter 2: System Design Guide

_Source lines: 2103-6262_

Chapter 2

System Design Guide

Video Timing Information

AXI4-Stream carries only video pixel data, SOF, and EOL signals between component
interfaces. Blanking or sync signals are not carried by the signaling interface, and strict
signal periodicity is not required.

In addition to extracting video pixel data from the input stream and sending it to
subsequent modules using video over AXI4-Stream, the interface modules must measure
timing information (including the number of pixels per scan-line, number of active rows per
frame, and so on) when receiving video from a standard periodic video source such as DVI,
HDMI, SDI, or an image sensor. Input interface modules make this information available to
video processing and output interface modules, which then recreate periodic timing signals
and embed output video pixel data that was processed by the video system to recreate a
periodic output stream such as DVI (Figure 2-1).

X-Ref Target - Figure 2-1

DVI

Video
to
AXI4-Stream

AXI4-S

Chroma
Resampler

AXI4-S

Enhance

AXI4-S

AXI4-Stream
To
Video

DVI

Video
Timing
Detector

AXI4-Lite

uBlaze or A9
AXI4-Lite master

Video
Timing
Generator

Figure 2-1:

Timing Information Extraction and Propagation Example

Figure 2-1 illustrates the extraction and propagation of timing information. The Video In to
AXI4-Stream input interface and Video Timing Detector cores measure timing information,
and extract video pixel data. It then transmit the data using the AXI4-Stream (represented
by the AXI4-S arrows in Figure 2-1). Timing information is propagated through optional
AXI4-Lite interfaces. When present, the system processor (AXI4-Lite master) reads out
measured timing information from the timing detector, and programs subsequent

AXI4-Stream Video IP and System Design
UG934 November 16, 2022

www.xilinx.com

16

Send Feedback
Propagating Video Timing Information

processing cores and the timing generator using the AXI4-Lite control register interfaces.
When instantiated without an AXI4-Lite control interface, video cores can only process a
fixed video format / resolution, specified in the core GUI. In Figure 2-1, the Chroma
Resampler and Enhance cores process the video stream. The processing cores might contain
line buffers for which the number of active pixels per scan line is necessary. The processing
cores receive active size (number of pixels per scan line, number of scan lines per frame)
measurement values, among other timing parameters from the Video Timing Detector
module, which is used with the DVI input interface IP. Processing cores also verify the data
by employing pixel counters between subsequent EOL pulses. The AXI4-Stream to Video
output interface core generates Standard Sync, Blank and Active Video timing signals, as
defined by the timing information received, and embeds the video pixel data as received
over the AXI4-Stream input interface.

Propagating Video Timing Information

Input and Output interface IP should provide two interface options to make measured
timing information available for subsequent cores. For embedded systems either using a
processor or dedicated IP acting as the AXI4-Lite master, an AXI4-Lite interface should be
provided with a standardized register API to present timing information. For standalone
video systems without an embedded processor, timing parameters for a fixed
format/resolution should be provided through the IP parameters and/or GUI. The Video
Timing Controller (VTC) core contains the Timing Detector and Timing Generator cores for
use with custom AXI4-Stream interfaces.

The Video to AXI4-Stream and AXI4-Stream to Video cores are delivered as HDL source code
and provided as examples to expedite custom interface development. For embedded
systems using a processor acting as an AXI4-Lite master or dedicated IP acting as the
AXI4-Lite master, an AXI4-Lite pCore interface should be provided with a standardized
register API to present timing information. For more information, see AXI4-Lite Interface.

Using the TUSER signal to transmit periodic sync information, such as hsync or vsync
along with the video data is prohibited as there are no guarantees on IP delay consistency
(aperiodicity), and delay matching between DATA and TUSER bits through IP cores.
Furthermore, when video data is written and retrieved from frame buffers, sync information
from TUSER is not recovered.

Transferring timing information or ancillary data embedded in the AXI4-Stream video
stream is also prohibited, either in the form of a header or as a watermark. No method is
provided for, or expected from processing cores to distinguish timing information or
ancillary data packets from valid pixel data. When video data is re-formatted, for example
video scaling changes the active frame dimensions, no mechanism is provided or expected
to change timing or stream information embedded in video data.

AXI4-Stream Video IP and System Design
UG934 November 16, 2022

www.xilinx.com

17

Send Feedback
Reset Requirements

Reset Requirements

Hardware Reset

Each AXI interface must be designed to accommodate entering or exiting a reset on a
different (preceding or subsequent) cycle than the interface to which it is connected.
Specifically, an IP core must not rely on another connected IP being reset simultaneously
during the same cycle. Video IP should be designed so that any reset of the AXI4-Stream
interfaces re-initializes the IP to reduce disruption on the output video stream.

Although Xilinx® IP can generally have multiple AXI interfaces connected to isolated
interconnection networks to support the localized reset of some interfaces, it is not
recommended. As a practical system design guideline, the reset source(s) should be held
active internally for some minimum number of cycles (of the slowest clock in the system) to
ensure that all IP is properly reinitialized and all AXI interfaces go into the quiescent state
prior to releasing the reset. If internal extension of the reset pulse is not throughble, video
IP data sheets specify the required reset pulse-width, if greater than one cycle.

As stated in the Xilinx AXI Reference Guide guidelines, it is recommended that all AXI
interfaces in a system be globally reset together. When resetting multiple video cores in a
system, all interfaces must be reset before any interface comes out of reset. Video IP should
accept and drop (not propogate) valid samples until the SOF signal is received.

AXI4-Stream interfaces must deassert their VALID and READY outputs while in reset. This
does not need to commence immediately upon sampling the reset input active, but in time
to allow the network of connected IP to reach a quiescent reset state prior to the
deassertion of reset at any IP. This allows for arbitrary (but reasonable) internal pipe-lining
of reset inputs, including resynchronization to a different clock domain, if necessary.

Software Reset

When resetting multiple video cores within a system, all interfaces must be reset before any
interface comes out of reset. When reset is performed in the software (which
asserts/deasserts software reset flags sequentially), the IP cores should be reset from the
output towards the input. The software reset pin of video IP closest to the system output
should be asserted first. Subsequent cores near the signal source should then be reset.
Software reset pins should be deasserted in the same sequence.

If permitted by the application, provide a soft software reset option (SSR) for the video IP,
where reset is synchronized with video frame boundaries. If sufficient time is available
between video frames, (for example, a vertical blanking period is present), a soft reset after
the predicted end-of-frame can facilitate the reset of individual cores without negatively
impacting system performance.

AXI4-Stream Video IP and System Design
UG934 November 16, 2022

www.xilinx.com

18

Send Feedback
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
External Frame Buffers

External Frame Buffers

The choice of an external-frame-buffer solution for AXI4-Stream based video systems is the
AXI-VDMA core. The AXI-VDMA core supports the AXI4-Stream video interfaces natively,
meaning SOF and EOL signals are properly interpreted and generated by the AXI-VDMA
core.

X-Ref Target - Figure 2-6

t
x
E
o
T

y
e
r
o
m
e
M

Line Buffer

t
x
E
m
o
r
F

y
e
r
o
m
e
M

Line Buffer

AXI_VDMA
F-sync

Almost
full

Gen-lock
input

Gen-lock
output

AXI_VDMA
F-sync

Almost
full

Gen-lock
input

Gen-lock
output

AXI4-Stream

AXI Master
(External Memory Write Side)

AXI-VDMA
Layer

S-M_Gen-lock

M-S Gen-lock

S_fsync

M_fsync

Fsync in

AXI Slave
(External Memory Read Side)

AXI4-Stream

X22104-121018

Figure 2-6: AXI-VDMA Layer

As illustrated in Figure 2-6, the AXI-VDMA core supports one master and one slave
interface. Slave/Master interfaces can:

• Use any input SOF signals, or an external Frame Sync input as a source to initiate Frame

transfers (AXI-VDMA Frame sync crossbar).

• AXI Master interfaces to use any AXI Slave interfaces to be the Gen-lock master.

• AXI Slave interfaces to use any AXI Master interfaces to be the Gen-lock master (Genlock

crossbar).

Using a Frame sync crossbar enables video systems with a Frame Buffer, but without external
output Frame sync source, to automatically retrieve the last frame finished on the
write-side. This is picked up immediately after reading a frame has completed on the read
side.

Some IP cores, such as the Video On-Screen Display, can have multiple read channels (slave
interfaces) which must be synchronized. You might need multiple instances of a slower core
running in parallel to achieve sufficient throughput. These parallel core instances can use
multiple write channels (master interfaces), which must be synchronized. Operating modes
for single write - multiple read ports:

AXI4-Stream Video IP and System Design
UG934 November 16, 2022

www.xilinx.com

26

Send Feedback


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
Ancillary Data

Example: 1-to-2 splitter implemented in VHDL

source_READY <= target1_READY and target2_READY;
target1_VALID <= source_VALID and target2_READY;
target2_VALID <= source_VALID and target1_READY;

The example above assumes downstream target interfaces asserting READY as soon as the
target is ready to receive data, independent from VALID. Otherwise, a small, distributed
memory based FIFO must be inserted between the splitter and the target to avoid
deadlocks.

Ancillary Data

Ancillary data (which includes audio, teletext, captions, or metadata) is digital data
embedded in a video stream. Because video over an AXI4-Stream interface is not packetized
to carry video and non-video data, ancillary data must be deembedded or discarded by the
input interface and transmitted from front-to-end using a separate (AXI or non-AXI)
auxiliary channel, as seen in Figure 2-7.

X-Ref Target - Figure 2-7

Ancillary Data Processing

DVI

Video
to
AXI4-Stream

AXI4-S

clk
domain
1

clk
domain
2

AXI4-S

AXI4-Stream
To
Video

DVI

Video
Timing
Detector

AXI4-Lite

uBlaze or A9
AXI4-Lite master

Video
Timing
Detector

clk

Fsync

Figure 2-7: Ancillary Data Management

When video frame rates change, buffering, re-sampling, and other processing may be
required on ancillary data. This must be done separately from the Video over AXI4-Stream
interface by deembedding the ancillary data before the frame rate change, processing it,
and reembedding it into the video stream after the frame rate change.

AXI4-Stream Video IP and System Design
UG934 November 16, 2022

www.xilinx.com

28

Send Feedback
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


Video Subsystem Software Guidelines

Interlace to Progressive Conversion

A deinterlacer can be used after the Video In to AXI4-Stream core to convert the video
format from interlaced to progressive. In this case, the deinterlacer uses the field ID bit, fid,
from the Video In to AXI4-Stream core, as shown in Figure 2-13.

X-Ref Target - Figure 2-13

Video In to AXI4-Stream

Video Input

Data in

data_valid

vblank

hblank

vsync

hsync

field_id

i

D
e
n
t
e
r
l
a
c
e
r

axi_field_id

VTIMING

Video Timing
Controller

(detector)

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

Figure 2-13: Video System with Interlaced Content Using Deinterlacer

X22109-121018

Video Subsystem Software Guidelines

Each video subsystem comprises one or more video pipelines. A video pipeline is any chain
of video IP cores that starts from a Video-In or AXI VDMA (MM2S Channel) core and
terminates on a Video-Out or AXI VDMA (S2MM channel) core.

Each pipeline must be reset, configured, reconfigured, enabled, or disabled starting from
the output (back-end) moving toward the input (front-end). The following is a list of typical
video pipeline operations that must be performed from back-end to front-end:

• Video pipeline reset: Resetting all cores within a pipeline

• Video pipeline configuration: Configuring all cores after reset. Do not Enable the cores

during this step

• Video pipeline dynamic reconfiguration: Configuring all cores without resetting, such

as a frame size change

AXI4-Stream Video IP and System Design
UG934 November 16, 2022

www.xilinx.com

35

Send Feedback


Video Subsystem Software Guidelines

• Video pipeline enable: Enabling all cores within a pipeline

• Video pipeline disable: Disabling all cores within a pipeline

In general, to initialize a video pipe, the following operations should be performed in this
order:

1.

Initialize all video IP drivers.

2. Reset all cores starting from the back-end first, moving forward in the pipe.

3. Configure without enabling all cores starting from the back-end first, moving forward in

the pipe.

4. Enable all cores starting from the back-end first, moving forward in the pipe.

Note: Step one only needs to be done once after boot time. Drivers do not need to be reinitialized
if the video pipeline needs to be reconfigured.

If a video subsystem contains more than one video pipeline, then each pipeline can be
operated upon individually. However, in most applications the input (front-end) pipelines
should be operated upon first, before back-end pipelines to avoid invalid data to be
processed and/or displayed.

Note: Pipelines are operated upon from front-end to back-end. Cores within a pipeline are operated
upon from back-end to front-end.

Video Pipeline Example

Refer to the video subsystem depicted in Figure 2-14 in the following example operations
and C code snippets. This video subsystem contains three video pipelines. The three
pipelines consist of the following cores:

•

Pipeline 1:

Video to AXI4-Stream

Video IP 1

AXI VDMA 1 (S2MM Channel)

°

°

°

•

Pipeline 2:

AXI VDMA 1 (MM2S Channel)

Video Processing Subsystem

AXI VDMA 2 (S2MM Channel)

°

°

°

•

Pipeline 3:

AXI VDMA 2 (MM2S Channel)

Video IP 2

°

°

AXI4-Stream Video IP and System Design
UG934 November 16, 2022

www.xilinx.com

36

Send Feedback
X-Ref Target - Figure 2-14

HDMI

AXI4-Stream to Video

°

Video
To
AXI4
Stream

AXI4-S

Video IP
1

Video Subsystem Software Guidelines

Video IP
2

AXI4-S

AXI4
Stream
To
Video

HDMI

S
-
4
X
A

I

S
-
4
I
X
A

Video
Timing
Controller
Detector

VDMA
1

AXI4-S

Video
Scaler

AXI4-S

VDMA
2

Video
Timing
Controller
Generator

Figure 2-14:

Example Video Subsystem with Three Video Pipelines

To bring up this system in software, the following operations should be performed in the
following order:

1.

Initialize core drivers (Perform One time only) using the <core>_CfgInitialize()
functions.

2. Bring up Pipeline 1 (Input Video Pipeline)

a. SW Reset AXI VDMA 1 (S2MM Channel)

b. SW Reset Video IP 1

c. SW Reset VTC detector

d. Configure AXI VDMA 1 (S2MM Channel)

e. Configure Video IP 1

f. Configure VTC detector

g. Enable AXI VDMA 1 (S2MM Channel)

h. Enable Video IP 1

i.

Enable VTC detector

3. Bring up Pipeline 2 (Scaler Pipeline)

a. SW Reset AXI VDMA 2 (S2MM Channel)

b. SW Reset Scaler

c. SW Reset AXI VDMA 1 (MM2S Channel)

d. Configure AXI VDMA 2 (MM2S Channel)

e. Configure Scaler

AXI4-Stream Video IP and System Design
UG934 November 16, 2022

www.xilinx.com

37

Send Feedback
Video Subsystem Software Guidelines

f. Configure AXI VDMA 1 (MM2S Channel)

g. Enable AXI VDMA 2 (MM2S Channel)

h. Enable Scaler

i.

Enable AXI VDMA 1 (MM2S Channel)

4. Bring up Pipeline 3 (Output Video Pipeline)

a. SW Reset VTC generator

b. SW Reset Video IP 2

c. SW Reset AXI VDMA 2 (MM2S Channel)

d. Configure VTC generator

e. Configure Video IP 2

f. Configure AXI VDMA 2 (MM2S Channel)

g. Enable VTC generator

h. Enable Video IP 2

i.

Enable AXI VDMA 2 (MM2S Channel)

To reconfigure this system, perform the above operations except step 1 (Initialize core
drivers).

Note: VDMA S2MM and MM2S channels should be reset, configured, reconfigured and enabled
separately. Each VDMA channel should be treated as individual cores belonging to separate video
pipelines. Avoid operating on both channels at the same time. The channel operations should be
synchronized to the pipeline to which the channel belongs.

The following C code snippet shows the code needed to bring up the VDMA 1, Scaler, VDMA
2 pipeline:

#include <stdio.h>
#include "platform.h"
#include "xparameters.h"
#include "xscaler.h"
#include "xaxivdma.h"

////////////////////////////////////////////////////////////////////
// Global Defines
////////////////////////////////////////////////////////////////////
#define VIDIN_FBADDR 0x31800000
#define SCALEROUT_FBADDR 0x33000000

#define FRAME_STORE_WIDTH 2048
#define FRAME_STORE_HEIGHT 2048
#define FRAME_STORE_DATA_BYTES 2

#define VDMA_CIRC 1
#define VDMA_NOCIRC 0
#define VDMA_EXT_GENLOCK 0

AXI4-Stream Video IP and System Design
UG934 November 16, 2022

www.xilinx.com

38

Send Feedback
Video Subsystem Software Guidelines

#define VDMA_INT_GENLOCK 2
#define VDMA_S2MM_FSYNC 8
#define COEFF_SET_INDEX 0

////////////////////////////////////////////////////////////////////
// Function Prototypes
////////////////////////////////////////////////////////////////////
void vdma_init(XAxiVdma *VDMAPtr, int device_id);
int vdma_reset(XAxiVdma *VDMAPtr, int direction);
int vdma_setup(XAxiVdma *VDMAPtr,
int direction,
int width,
int height,
int frame_stores,
int start_address,
int mode
);
void scaler_init(XScaler *ScalerPtr, int device_id);
int scaler_setup(XScaler *ScalerInstPtr,
int ScalerInWidth,
int ScalerInHeight,
int ScalerOutWidth,
int ScalerOutHeight);

////////////////////////////////////////////////////////////////////
// Global Core Driver Structures
////////////////////////////////////////////////////////////////////
XAxiVdma VDMA1;
XAxiVdma VDMA2;
XScaler Scaler;

XScalerAperture Aperture;/* Aperture setting */
XScalerStartFraction StartFraction;/* Luma/Chroma Start Fraction setting*/
XScalerCoeffBank CoeffBank;/* Coefficient bank */

////////////////////////////////////////////////////////////////////
// Function: configure_scaler_pipeline()
// Configure Scaler Pipeline (Pipeline 2)
////////////////////////////////////////////////////////////////////
int configure_scaler_pipeline(
int input_x,
int input_y,
int output_x,
int output_y)
{
int Status;
////////////////////////////////////////////////////////////
// Initialize Drivers – Order not important
// Do after clocks are setup
///////////////////////////////////////////////////////////
vdma_init (&VDMA1, 0);
vdma_init (&VDMA2, 1);
scaler_init(&Scaler, 0);

///////////////////////////////////////////////////////////////////////////
// Pipeline 2: Reset Cores
///////////////////////////////////////////////////////////////////////////

AXI4-Stream Video IP and System Design
UG934 November 16, 2022

www.xilinx.com

39

Send Feedback
Video Subsystem Software Guidelines

vdma_reset (&VDMA2, XAXIVDMA_WRITE);
scaler_reset(&Scaler);
vdma_reset (&VDMA1, XAXIVDMA_READ);

///////////////////////////////////////////////////////////////////////////
// Pipeline 2: Configure Cores
///////////////////////////////////////////////////////////////////////////
printf("Setting up VDMA Writer...\n");
vdma_setup(&VDMA2,
XAXIVDMA_WRITE,
output_x,
output_y,
3,
SCALEROUT_FBADDR,
VDMA_NOCIRC|VDMA_INT_GENLOCK);

printf("Setting up Scaler...\n");
scaler_setup(&Scaler, input_x, input_y, output_x, output_y);

printf("Setting up VDMA Reader...\n");
vdma_setup(&VDMA1,
XAXIVDMA_READ,
input_x,
input_y,
3,
VIDIN_FBADDR,
VDMA_NOCIRC|VDMA_INT_GENLOCK|VDMA_S2MM_FSYNC);

///////////////////////////////////////////////////////////////////////////
// Pipeline 2: Enable cores
///////////////////////////////////////////////////////////////////////////

//Enable write VDMA, VDMA2 (S2MM Channel)
Status = XAxiVdma_DmaStart(&VDMA2, XAXIVDMA_WRITE);
if (Status != XST_SUCCESS)
{
printf("ERROR: VDMA2 Start write transfer failed %d\r\n", Status);
return XST_FAILURE;
}

XScaler_Enable(&Scaler);

Status = XAxiVdma_DmaStart(&VDMA1, XAXIVDMA_READ);
if (Status != XST_SUCCESS)
{
printf("ERROR: VDMA1 Start read transfer failed %d\r\n", Status);
return XST_FAILURE;
}

return 1;
}

///////////////////////////////////////////////////////////////////
// Function: vdma_init()
// Initialize VDMA Driver
////////////////////////////////////////////////////////////////////
void vdma_init(XAxiVdma *VDMAPtr, int device_id)
{

AXI4-Stream Video IP and System Design
UG934 November 16, 2022

www.xilinx.com

40

Send Feedback
Video Subsystem Software Guidelines

int Status;
XAxiVdma_Config *VDMACfgPtr;

VDMACfgPtr = XAxiVdma_LookupConfig(device_id);
if (!VDMACfgPtr)
{

printf("ERROR: No VDMA found for ID %d\r\n", device_id);
}

Status = XAxiVdma_CfgInitialize(VDMAPtr,
VDMACfgPtr,
VDMACfgPtr->BaseAddress
);
if (Status != XST_SUCCESS) {
printf( "ERROR: VDMA Configuration Initialization failed %d\r\n",
Status);
}

}
////////////////////////////////////////////////////////////////////
// VDMA Channel Reset
////////////////////////////////////////////////////////////////////
int vdma_reset(XAxiVdma *VDMAPtr, int direction)
{

int Polls;

printf("Resetting VDMA ...\n");
XAxiVdma_Reset(VDMAPtr, direction);
Polls = 100000;

while (Polls && XAxiVdma_ResetNotDone(VDMAPtr, direction)) {
Polls -= 1;
}

if (!Polls) {
printf( "ERROR: VDMA %s channel reset failed %x\n\r",
(direction==XAXIVDMA_READ)?"Read":"Write", 0);

return XST_FAILURE;
}

return 1;
}

////////////////////////////////////////////////////////////////////
// VDMA Channel Configure/Setup
////////////////////////////////////////////////////////////////////
int vdma_setup(XAxiVdma *VDMAPtr, int direction, int width, int height, int
frame_stores, int start_address, int mode)
{
int Status, i, Addr;

XAxiVdma_DmaSetup DmaSetup;

//printf("Setting up VDMA Read Config...\n");
DmaSetup.VertSizeInput = height;

AXI4-Stream Video IP and System Design
UG934 November 16, 2022

www.xilinx.com

41

Send Feedback
Video Subsystem Software Guidelines

DmaSetup.HoriSizeInput = width * FRAME_STORE_DATA_BYTES ;

DmaSetup.Stride = FRAME_STORE_WIDTH * FRAME_STORE_DATA_BYTES ;
DmaSetup.FrameDelay = 0;

DmaSetup.EnableCircularBuf = mode&1;
DmaSetup.EnableSync = mode&1;

DmaSetup.PointNum = (mode>>2) & 1;
DmaSetup.EnableFrameCounter = 0; /* Endless transfers */

DmaSetup.FixedFrameStoreAddr = 0; /* We are not doing parking */

//Only set the number of frames if the VDMA can support more that we need
//NOTE: the VDMA debug features for write to the frame store
// num reg must be enabled.
if(VDMAPtr->MaxNumFrames > frame_stores)
{
Status = XAxiVdma_SetFrmStore(VDMAPtr, frame_stores, direction);
if (Status != XST_SUCCESS) {

printf("WARNING %d: VDMA - Setting Frame Store Number to %d Failed for %s
Channel. Exiting config.\r\n",
Status, frame_stores,
(direction==XAXIVDMA_READ)?"Read":"Write");

return XST_FAILURE;
}
}

Status = XAxiVdma_DmaConfig(VDMAPtr, direction, &DmaSetup);
if (Status != XST_SUCCESS) {
printf("ERROR: VDMA - %s channel config failed. (%d)\r\n",
(direction==XAXIVDMA_READ)?"Read":"Write", Status);

return XST_FAILURE;
}

/* Initialize buffer addresses
*
* These addresses are physical addresses
*/
Addr = start_address;
for(i=0; i < frame_stores; i++) {
printf(" vdma_setup: Address %d = 0x%08x.\n\r", i, Addr);
DmaSetup.FrameStoreStartAddr[i] = Addr;

Addr += FRAME_STORE_WIDTH * FRAME_STORE_HEIGHT * FRAME_STORE_DATA_BYTES;
}

/* Set the buffer addresses for transfer in the DMA engine
* The buffer addresses are physical addresses
*/
Status = XAxiVdma_DmaSetBufferAddr(VDMAPtr, direction,
DmaSetup.FrameStoreStartAddr);
if (Status != XST_SUCCESS) {

AXI4-Stream Video IP and System Design
UG934 November 16, 2022

www.xilinx.com

42

Send Feedback

Video Subsystem Software Guidelines

printf("ERROR: VDMA - %s channel set buffer address failed %d\r\n",
(direction==XAXIVDMA_READ)?"Read":"Write",Status);

return XST_FAILURE;
}

if(direction==XAXIVDMA_WRITE)
{
// use the TUSER bit for the frame sync for the write (S2MM side)
XAxiVdma_FsyncSrcSelect(VDMAPtr,
XAXIVDMA_S2MM_TUSER_FSYNC,
XAXIVDMA_WRITE);
}
else
{
if(mode&0x08)
{
// VDMA Read (MM2S side) for the scaler input must be synced
// to the S2MM frame Sync
XAxiVdma_FsyncSrcSelect(VDMAPtr,
XAXIVDMA_CHAN_OTHER_FSYNC,
XAXIVDMA_READ); // DMA_CR[6:5] = 0b01

}
else
{
// VDMA 2 Read (MM2S side) must be not by synced and in free run
// Its timing is governed by the output VTC generator
// and AXI4-Stream to Video Out
XAxiVdma_FsyncSrcSelect(VDMAPtr, XAXIVDMA_CHAN_FSYNC, XAXIVDMA_READ);
// DMA_CR[6:5] = 0b00
}
}

Status = XAxiVdma_GenLockSourceSelect(VDMAPtr, (mode>>1)&1, direction);
if (Status != XST_SUCCESS) {
printf("ERROR: VDMA - %s channel set gen-lock %s src failed %d\r\n",
(direction==XAXIVDMA_READ)?"Read":"Write",
(((mode>>1)&1)==XAXIVDMA_INTERNAL_GENLOCK)?"Internal":"External",

Status);

return XST_FAILURE;
}

return 1;

}
////////////////////////////////////////////////////////////////////
// Initialize Scaler Driver
////////////////////////////////////////////////////////////////////
void scaler_init(XScaler *ScalerPtr, int device_id)
{
int Status;
XScaler_Config *ScalerCfgPtr;

ScalerCfgPtr = XScaler_LookupConfig(device_id);
if (!ScalerCfgPtr)
{

AXI4-Stream Video IP and System Design
UG934 November 16, 2022

www.xilinx.com

43

Send Feedback
Video Subsystem Software Guidelines

printf("ERROR: No Scaler found for ID %d\r\n", device_id);
}
Status = XScaler_CfgInitialize(ScalerPtr,
ScalerCfgPtr,
ScalerCfgPtr->BaseAddress);
if (Status != XST_SUCCESS) {
printf( "ERROR: Scaler Configuration Initialization failed %d\r\n",
Status);
}

}
////////////////////////////////////////////////////////////////////
// Scaler Configure/Setup
////////////////////////////////////////////////////////////////////
int scaler_setup(XScaler *ScalerInstPtr,

int ScalerInWidth, int ScalerInHeight,
int ScalerOutWidth, int ScalerOutHeight)

{
u8 ChromaFormat;
u8 ChromaLumaShareCoeffBank;
u8 HoriVertShareCoeffBank;

/*
* Disable the scaler before setup and tell the device not to pick up
* the register updates until all are done
*/
XScaler_DisableRegUpdate(ScalerInstPtr);
XScaler_Disable(ScalerInstPtr);

/*
* Load a set of Coefficient values
*/

/* Fetch Chroma Format and Coefficient sharing info */
XScaler_GetCoeffBankSharingInfo(ScalerInstPtr,
&ChromaFormat,
&ChromaLumaShareCoeffBank,
&HoriVertShareCoeffBank);

CoeffBank.SetIndex = COEFF_SET_INDEX;
CoeffBank.PhaseNum = ScalerInstPtr->Config.MaxPhaseNum;
CoeffBank.TapNum = ScalerInstPtr->Config.VertTapNum;

/* Locate coefficients for Horizontal scaling */
CoeffBank.CoeffValueBuf = (s16 *)
XScaler_CoefValueLookup(ScalerInWidth,
ScalerOutWidth,
CoeffBank.TapNum,
CoeffBank.PhaseNum);

/* Load coefficient bank for Horizontal Luma */
XScaler_LoadCoeffBank(ScalerInstPtr, &CoeffBank);

/* Horizontal Chroma bank is loaded only if chroma/luma sharing flag
* is not set */
if (!ChromaLumaShareCoeffBank)
XScaler_LoadCoeffBank(ScalerInstPtr, &CoeffBank);

AXI4-Stream Video IP and System Design
UG934 November 16, 2022

www.xilinx.com

44

Send Feedback
Video Subsystem Software Guidelines

/* Vertical coeff banks are loaded only if horizontal/vertical sharing
* flag is not set
*/
if (!HoriVertShareCoeffBank) {

/* Locate coefficients for Vertical scaling */
CoeffBank.CoeffValueBuf = (s16 *)
XScaler_CoefValueLookup(ScalerInHeight,
ScalerOutHeight,
CoeffBank.TapNum,
CoeffBank.PhaseNum);

/* Load coefficient bank for Vertical Luma */
XScaler_LoadCoeffBank(ScalerInstPtr, &CoeffBank);

/* Vertical Chroma coeff bank is loaded only if chroma/luma
* sharing flag is not set
*/
if (!ChromaLumaShareCoeffBank)
XScaler_LoadCoeffBank(ScalerInstPtr, &CoeffBank);
}

/*
* Load phase-offsets into scaler
*/
StartFraction.LumaLeftHori = 0;
StartFraction.LumaTopVert = 0;
StartFraction.ChromaLeftHori = 0;
StartFraction.ChromaTopVert = 0;
XScaler_SetStartFraction(ScalerInstPtr, &StartFraction);

/*
* Set up Aperture.
*/
Aperture.InFirstLine = 0;
Aperture.InLastLine = ScalerInHeight - 1;

Aperture.InFirstPixel = 0;
Aperture.InLastPixel = ScalerInWidth - 1;

Aperture.OutVertSize = ScalerOutHeight;
Aperture.OutHoriSize = ScalerOutWidth;

// Added by Xilinx 2012.12.10
Aperture.SrcVertSize = ScalerInHeight;
Aperture.SrcHoriSize = ScalerInWidth;

XScaler_SetAperture(ScalerInstPtr, &Aperture);

/*
* Set up phases
*/
XScaler_SetPhaseNum(ScalerInstPtr, ScalerInstPtr->Config.MaxPhaseNum,
ScalerInstPtr->Config.MaxPhaseNum);

/*
* Choose active set indexes for both vertical and horizontal directions
*/

AXI4-Stream Video IP and System Design
UG934 November 16, 2022

www.xilinx.com

45

Send Feedback
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
