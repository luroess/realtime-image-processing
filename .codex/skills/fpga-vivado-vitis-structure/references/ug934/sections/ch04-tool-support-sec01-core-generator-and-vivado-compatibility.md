# Core Generator and Vivado Compatibility

_Parent: Chapter 4: Tool Support_
_Source lines: 7912-7927_

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
