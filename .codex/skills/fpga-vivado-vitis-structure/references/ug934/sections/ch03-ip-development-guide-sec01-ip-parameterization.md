# IP Parameterization

_Parent: Chapter 3: IP Development Guide_
_Source lines: 6267-6320_

IP Parameterization

General IP configuration parameters are not covered in this specification. However,
commonly used video IP parameters generally are listed in Table 3-1.

Table 3-1:

Standard Video IP Parameters

Parameter Name

Parameter Function

C_HAS_AXI4_LITE 0 or 1 determines whether the core has an AXI4-Lite control interface

C_ACTIVE_ROWS Number of active (non-blank) scan lines per frame

C_ACTIVE_COLS Number of active (non-blank) pixels per scan line

C_MAX_COLS

Maximum number of active (non-blank) pixels per scan line supported by a particular core
instance

Only one video format can be supported in video IP core systems that use an AXI-4
interface without an embedded processor. For this configuration (C_HAS_AXI4_LITE=0),
you can define the supported resolution through generic parameters C_ACTIVE_ROWS and
C_ACTIVE_COLS defined in the core GUI. When C_HAS_AXI4_LITE=0, C_ MAX_COLS
should be equal to C_ACTIVE_COLS.

When an embedded processor is present and the Video core is instantiated with an
AXI4-Lite interface (C_HAS_AXI4_LITE=1), generic parameters C_ACTIVE_ROWS and
C_ACTIVE_COLS assign default values to control registers to define the active resolution.
As an upper bound on the active scanline length supported by the core instance,
C_MAX_COLS is used to define line buffer depths, which have a direct effect on block RAM
footprint. For example, a video core, instantiated to service 720p video (1650 total pixels,
1280 active pixels per line), needs to have C_MAX_COLS set to 1280. This core instance is
not be able to service 1080p video, but works with 720p or any lower resolutions, such as
480p, when the active_size register in the AXI4-Lite control interface is set according to
720p or 480p.

C_MAX_COLS refers to the maximum number of non-blank pixels a core instance must
service. This parameter is often used to allocate block RAMs for line buffers within the core.
For example, a core instance targeting resolutions up to 720p must have this parameter set
to 1280.

AXI4-Stream Video IP and System Design
UG934 November 16, 2022

www.xilinx.com

59

Send Feedback
