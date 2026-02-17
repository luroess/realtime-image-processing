# Propagating SOF and EOL Signals

_Parent: Chapter 3: IP Development Guide_
_Source lines: 7759-7786_

Propagating SOF and EOL Signals

Propagating SOF and EOL Signals

Video processing IP cores either delay or re-generate the SOF and EOL pulses. No
recommendations are given for which method to use when generating output SOF and EOL
pulses. However, for simple pipelined IP cores without line buffers, such as a Color Space
Converter, delay lines matching pipeline latency is recommended. For complex IP with line
buffers, generating SOF and EOL pulses is recommended.

In accordance with AXI4-Stream Signaling Interface, complex video IP can detect a
discrepancy between expected number of active lines (as programmed by timing variables)
and the actual number of EOL pulses received between consecutive SOF pulses.

When SOF is detected early, the output SOF signal should be generated early as well,
meaning the previous frame is not padded to match programmed frame dimensions. When
SOF is detected late, extra lines/pixels from the previous frame should be dropped and the
output SOF signal should be generated according to the programmed values.

In accordance with End of Line Signal, complex video IP can detect a discrepancy between
expected number of active pixels, as programmed by timing variables, and the actual
number of valid pixels received between consecutive EOL pulses.

When EOL is detected early, the output EOL signal should be generated early as well,
meaning the previous frame is not padded to match programmed frame dimensions. When
EOL is detected late, the output EOL signal should be according to programmed values and
extra pixels from the previous line should be dropped.
