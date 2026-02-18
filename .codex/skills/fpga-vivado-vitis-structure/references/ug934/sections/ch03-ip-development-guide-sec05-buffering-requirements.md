# Buffering Requirements

_Parent: Chapter 3: IP Development Guide_
_Source lines: 7356-7535_

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
