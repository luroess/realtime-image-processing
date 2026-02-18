# Reset Requirements

_Parent: Chapter 2: System Design Guide_
_Source lines: 2232-2285_

Reset Requirements

Reset Requirements

Hardware Reset

Each AXI interface must be designed to accommodate entering or exiting a reset on a
different (preceding or subsequent) cycle than the interface to which it is connected.
Specifically, an IP core must not rely on another connected IP being reset simultaneously
during the same cycle. Video IP should be designed so that any reset of the AXI4-Stream
interfaces re-initializes the IP to reduce disruption on the output video stream.

Although Xilinx® IP can generally have multiple AXI interfaces connected to isolated
interconnection networks to support the localized reset of some interfaces, it is not
recommended. As a practical system design guideline, the reset source(s) should be held
active internally for some minimum number of cycles (of the slowest clock in the system) to
ensure that all IP is properly reinitialized and all AXI interfaces go into the quiescent state
prior to releasing the reset. If internal extension of the reset pulse is not throughble, video
IP data sheets specify the required reset pulse-width, if greater than one cycle.

As stated in the Xilinx AXI Reference Guide guidelines, it is recommended that all AXI
interfaces in a system be globally reset together. When resetting multiple video cores in a
system, all interfaces must be reset before any interface comes out of reset. Video IP should
accept and drop (not propogate) valid samples until the SOF signal is received.

AXI4-Stream interfaces must deassert their VALID and READY outputs while in reset. This
does not need to commence immediately upon sampling the reset input active, but in time
to allow the network of connected IP to reach a quiescent reset state prior to the
deassertion of reset at any IP. This allows for arbitrary (but reasonable) internal pipe-lining
of reset inputs, including resynchronization to a different clock domain, if necessary.

Software Reset

When resetting multiple video cores within a system, all interfaces must be reset before any
interface comes out of reset. When reset is performed in the software (which
asserts/deasserts software reset flags sequentially), the IP cores should be reset from the
output towards the input. The software reset pin of video IP closest to the system output
should be asserted first. Subsequent cores near the signal source should then be reset.
Software reset pins should be deasserted in the same sequence.

If permitted by the application, provide a soft software reset option (SSR) for the video IP,
where reset is synchronized with video frame boundaries. If sufficient time is available
between video frames, (for example, a vertical blanking period is present), a soft reset after
the predicted end-of-frame can facilitate the reset of individual cores without negatively
impacting system performance.

AXI4-Stream Video IP and System Design
UG934 November 16, 2022

www.xilinx.com

18

Send Feedback
