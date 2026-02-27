#import "../shared/macros.typ": *

= Architecture
#component_owner("Valentin Bumeder")

The implemented system extends Digilent's camera-to-HDMI reference path with a custom AXI4-Stream processing pipeline @digilent-pcam-demo. The architecture separates runtime control, pixel processing, and final composition, while preserving a single streaming contract from input to output.

#figure(
  image("../figures/architecture.png", width: 100%),
  caption: [System architecture and data/control partitioning.],
) <fig-architecture>

At system level, two design rules shape the implementation. First, all pixel modules follow the AXI4-Stream Video handshake and framing model (`TVALID/TREADY`, `TUSER=SOF`, `TLAST=EOL`). Second, runtime mode changes are applied at frame boundaries to avoid visual tearing inside active video.

== Functional decomposition
The architecture is organized into six functional blocks. Runtime control is handled by `DebouncedClickDetector` and `ClickDetector`, which debounce user input and generate stable mode signals. Color conversion and branch generation are handled by `AXI_RgbToGrayscale`, which provides a processing branch in grayscale and a synchronized base branch for later composition.

The filtering path is formed by `AXI_BlurrWindowModule` and `AXI_SobelWindowModule`. Each wrapper is a combined stage: it contains both window formation and the corresponding filter operation. In other words, these modules are not only transport wrappers; they realize `window + filter` as one processing block.

The window-generation method is delegated to the separate report by Justin Löber. That separate report explains the sliding-window derivation. The present report covers the integrated wrapper behavior in which window generation and filtering are coupled.

The final merge stage is `AXI_FrameCompositor`, which aligns delayed base data with processed edge timing and generates either a normal, an overlay or a binary edge view. The complete system integration is provided by `AXI_RgbGrayBlurrSobelOverlayPipeline`, which combines all blocks into one frame-consistent AXI4-Stream chain.

== Dataflow and mode concept
The pixel stream follows a branch-and-merge structure. After grayscale conversion, the processing branch can pass through unchanged, apply Sobel, or apply Blur followed by Sobel. In parallel, the base branch remains available for visual context. The compositor merges both branches after delay alignment, so edge information is positioned on the correct output pixels.

Control is orthogonal to pixel transport. One control partition selects the active processing stage, and a second partition selects the base image representation (RGB, gray, or zeros for binary mask view). This orthogonality allows mode variation without changing the external stream interface.

Because window-based stages introduce warm-up latency at frame start, the architecture aligns branches in accepted-beat space before composition. This keeps overlay quality stable across all supported runtime modes.

The following chapters analyze these subsystems in detail, covering control logic, grayscale conversion, Blur/Sobel processing, window wrappers, frame composition, and full pipeline integration.
