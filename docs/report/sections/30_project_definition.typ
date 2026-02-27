#import "../shared/macros.typ": *

= Project Definition

In this project, a manipulation pipeline for a camera video stream should be implemented on an FPGA chip using various modifications.
The output of the pipeline should be streamed to a monitor via HDMI in realtime.

The project was completed as group work by Valentin Bumeder, Jan Duchscherer, Justin Löber, and Lukas Roess. 
The report of Justin Löber will be handed as seperate document due to organizational reasons.

== Goal
The goal of this project is to implement a pipeline for modifying a video stream on the FPGA board _Digilent Zybo Z7-10 (Zynq-7010)_@digilent-zybo. 
As the video stream input, a _Pcam 5C (OV5640)_@digilent-pcam camera is used. 
Various modifications should be applicable to the video stream, controlled via the buttons on the board. 
The first modification in the pipeline converts the RGB stream into a grayscale image. 
Building on this, a low-pass filter is implemented to blur image content. 
Finally, edge detection is applied as a minimum requirement. 
As a result of these modifications, the output signal is a black-and-white image showing the detected edges in the video stream. 

After achieving the basic project goal, optional extensions include implementing the detected edges as an overlay on the RGB stream, FAST corner detection, or additional morphological operations.

== Project Reference

The project is based on the _Zybo Z7 Pcam 5C Demo_ project@digilent-zybo-demo. 
This project includes a simple video streaming pipeline on the given hardware using AXI4 video pixel streams. 
The custom-developed modules are integrated into the demo project as IP blocks, thereby modifying the HDMI video output.

