# Propagating Video Timing Information

_Parent: Chapter 2: System Design Guide_
_Source lines: 2179-2231_

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
