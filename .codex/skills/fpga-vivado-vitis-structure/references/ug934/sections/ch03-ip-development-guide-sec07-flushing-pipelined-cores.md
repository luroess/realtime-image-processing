# Flushing Pipelined Cores

_Parent: Chapter 3: IP Development Guide_
_Source lines: 7648-7758_

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
