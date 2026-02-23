#import "../shared/macros.typ": *

= AXI4-Stream Video Protocol Background
The stream contract used by RTL and cocotb scoreboards is:
$ "transfer"_k = "tvalid"_k and "tready"_k $

For AXI4-Stream Video, AMD's documentation on AXI4-Stream Video IP and system design defines project-critical rules for active video beats:@UG934
- `TUSER[0]` marks start-of-frame (`SOF`).
- `TLAST` marks end-of-line (`EOL`).
- While stalled (`TVALID=1`, `TREADY=0`), payload and sidebands remain stable.
- Only active pixels are transferred on the AXI stream.

#figure(
  academic_table(
    columns: (auto, auto, auto),
    align: (left, left, left),
    table.header([Signal/Rule], [Meaning], [Project consequence]),
    [`TUSER[0]`],
    [SOF marker],
    [Control/state latching is performed at frame boundaries.],
    [`TLAST`],
    [EOL marker],
    [Line-level alignment is preserved across RGB and grayscale branches.],
    [`TVALID && TREADY`],
    [Beat acceptance],
    [Delay chains advance only on accepted beats.],
    [stall stability],
    [No payload mutation while blocked],
    [Testbench includes backpressure patterns to detect illegal changes.],
  ),
  caption: [AXI4-Stream video rules applied across this repository.],
) <tab-axi-rules>

Project-specific stream order is consistent across RTL and Python models:
- wire-level RGB24 order is `TDATA[23:0] = R|B|G`,
- Python tuples and scoreboard comparisons use `(R, G, B)` after decode.

Platform context follows Digilent Zybo Z7 and Pcam 5C integration guidance for camera/display infrastructure.@digilent-zybo @digilent-pcam
