#import "../shared/macros.typ": *

= Architecture
#component_owner("Valentin Bumeder")

The implemented Video Streaming pipeline contains 5 submodules: 
- `DebouncedClickDetector`: FSM for selection of pipeline mode
- `AXI_RgbToGrayscale`: Modification Layer - RGB to Grayscale
- `AXI_BlurrWindowModule`: Modification Layer - Blurr Filter
- `AXI_SobelWindowModule`: Modification Layer - Sobel Filter
- `FRAME_COMPOSITOR`: Composition of AXI-Streams for overlay generation

#figure(
	image("../figures/architecture.png", width: 100%),
	caption: [System architecture overview.],
) <fig-architecture>

Each module in @fig-architecture will be described in detail in the following sections. 