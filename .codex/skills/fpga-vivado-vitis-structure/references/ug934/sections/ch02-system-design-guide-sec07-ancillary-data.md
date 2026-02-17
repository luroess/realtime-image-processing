# Ancillary Data

_Parent: Chapter 2: System Design Guide_
_Source lines: 3062-3142_

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
