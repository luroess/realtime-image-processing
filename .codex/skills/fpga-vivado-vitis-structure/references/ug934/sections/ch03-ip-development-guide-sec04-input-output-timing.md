# Input/Output Timing

_Parent: Chapter 3: IP Development Guide_
_Source lines: 7241-7355_

Input/Output Timing

VSIZE

HSYNC

0x0000_02EE
VSIZE_F0 = 750
VSIZE_F1 = 0

0x0596_056E
15-0: START = 1390
31-16: END = 1430

0x0000_0465
VSIZE_F0 = 1125
VSIZE_F1 = 0

0x0804_07D8
15-0: START = 2008
31-16: END = 2052

F0_VBLANK_H

0x0000_0000

0x0000_0000

F0_VSYNC_V

0x02DA_02D5
15-0: START = 725
31-16: END = 730

0x0441_043C
15-0: START = 1084
31-16: END = 1089

F0_VSYNC_H

0x0000_0000

0x0000_0000

F1_VBLANK_H

0x0000_0000

0x0000_0000

F1_VSYNC_V

0x0000_0000

0x0000_0000

F1_VSYNC_H

0x0000_0000

0x0000_0000

0x0233_0232
VSIZE_F0 = 562
VSIZE_F1 = 563

0x0804_07D8
15-0: START = 2008
31-16: END = 2052

0x0000_0000
15-0: H_START = 0
31-16: H_END = 0

0x0223_021E
15-0: START = 542
31-16: END = 547

0x0000_0000
15-0: H_START = 0
31-16: H_END = 0

0x0000_0000
15-0: H_START = 0
31-16: H_END = 0

0x0223_021E
15-0: START = 542
31-16: END = 547

0x044C_044C
15-0: H_START = 1100
31-16: H_END = 1100

Input/Output Timing

The recommended design convention for AXI4-Stream component interfaces suggests that
outputs should be registered or driven directly by flip-flops or FIFO/block RAM primitives.
Ideally, inputs are also registered but can be combinatorial. Combinatorial inputs can limit
Fmax so the amount of combinatorial logic present on inputs should be limited.

There must be no combinatorial paths between input and output signals on either master or
slave interfaces. Combinatorial paths between input and output signals are not permitted
across separate AXI4-Stream interfaces. In some cases, outputs driven by combinatorial
logic are a suitable design choice or a reasonable design trade-off, such as when latency is
critical. The IP core data sheet describes AXI4-Stream output signals that are not registered.

AXI4-Stream Video IP and System Design
UG934 November 16, 2022

www.xilinx.com

69

Send Feedback
