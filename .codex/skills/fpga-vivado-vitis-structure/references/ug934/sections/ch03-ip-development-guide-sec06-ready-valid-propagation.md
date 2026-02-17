# READY – VALID Propagation

_Parent: Chapter 3: IP Development Guide_
_Source lines: 7536-7647_

READY – VALID Propagation

X-Ref Target - Figure 3-4

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

X22113-121018

Figure 3-4: Processing Bubble Example

1. Core A and Core B ran out of valid samples.

Figure 3-4 presents an example scenario when processing cores A and B run out of valid
samples mid-frame, so when the output interface asserts its ready output to start a new line,
samples must be retrieved from external memory and must be processed by Core A and
Core B, causing significant delay, which can break the sync - data alignment at the output
interface.

To avoid processing bubbles, cores should not assert the VALID signal on the output
interfaces until internal FIFOs are almost full and keep VALID asserted until output FIFOs
and internal pipeline stages are empty.

The READY output should be driven in a greedy fashion; asserted unless all pipeline stages
are full, internal FIFOs are almost full, and the master interface READY is sampled low, as
described in READY – VALID Propagation, or internal pipelines need to be flushed as
described in Flushing Pipelined Cores. This behavior ensures processing efficiency and
proper flushing of pipelines and processing systems at line and frame ends.

READY – VALID Propagation

For very simple IP cores, propagating VALID from master to slave and propagating READY
from slave to master seems straight-forward. However, when the IP core has pipeline
registers and/or FIFOs, the internal state of pipelines and FIFOs must be factored in to the
READY/VALID output assignments. See Buffer Management for more information.

As stated in Input/Output Timing, the READY output on the slave interface and VALID
output on the master interface must be registered. This requirement inserts a propagation
delay of at least one clock cycle between the deasserted READY signal on the IP core slave
interface input and the master interface READY output. The logic controlling these outputs,
as well as the latching in of new pixels from the slave interface to internal FIFOs or pipeline
registers, must consider the scenario when all internal buffers (pipeline registers and FIFOs)
are full, the downstream slave interface just deasserted READY, but the upstream master
interface sends one more pixel due to the core master interface READY signal lagging
behind the slave interface.

AXI4-Stream Video IP and System Design
UG934 November 16, 2022

www.xilinx.com

72

Send Feedback
