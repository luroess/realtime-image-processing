# Interframe Reinitialization

_Parent: Chapter 3: IP Development Guide_
_Source lines: 7787-7796_

Interframe Reinitialization

Some video IP cores, such as the Image Statistics and Image Characterization, take
thousands of clock cycles to initialize between frames because block RAMs holding
statistical data must be cleared or large sets of metadata must be written to external
memory.

As a general recommendation, video IP cores should re-initialize at the end of the frame,
instead of at the beginning of the frame when the SOF pulse is received.
