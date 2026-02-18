# Chapter 4: Tool Support

_Source lines: 7908-7941_

Chapter 4

Tool Support

Core Generator and Vivado Compatibility

For video-IP to show up in the Core Generator and Vivado® repositories, CORE Generator
and/or Vivado GUI files must be present in the core /gui /xgui directories, product guide
documentation must be in PDF format in the /doc directory of the IP, and VHDL or Verilog
simulation models, if present, must reside in the /simulation directory.

The IP is also recommended to include a C model (/lib directory), test-fixtures
(/verification) and hardware validation projects or designs in the /validation
directory.

For more information on designing and delivering IP using Vivado tools, see the Vivado
tools documentation at:

https://www.xilinx.com/cgi-bin/docs/rdoc?v=2022.2;t=vivado+userguides

EDK Compatibility

For native Xilinx® EDK support, video IP must have a peripheral descriptor file (.mpd file),
a user interface file (.mui file), and driver files. The MPD file lists IP parameters and ports,
and identifies clock, reset, and interrupt pins.

AXI4-Stream Video IP and System Design
UG934 November 16, 2022

www.xilinx.com

78

Send Feedback
