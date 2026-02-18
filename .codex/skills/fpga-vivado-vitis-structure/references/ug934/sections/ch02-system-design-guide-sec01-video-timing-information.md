# Video Timing Information

_Parent: Chapter 2: System Design Guide_
_Source lines: 2107-2178_

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
