#import "../shared/macros.typ": *

= Component: PICTURE OVERLAY
#component_owner("Valentin Bumeder")

== Overview
The `AxiPictureOverlay` (#repo_link("rtl/PICTURE_OVERLAY/hdl/AxiPictureOverlay.vhd", line: 39, branch: "feature/picture-overlay")) component was implemented as an extension for the pipeline that can be added on the regular RBG AXI4-Stream to create a overlay of a predefined picture in the livestream. 
The component could not be integrated into the final project due to multiple integration issues on the pipeline. Nevertheless the functionality of the entity could confirmed in the testbench  
(#repo_link("testbench/tests/test_axi_picture_overlay.py", line: 1, branch: "feature/picture-overlay")) by generating a output frame (@fig-picture-overlay-output).

== Interface ports and generics
#figure(
  interface_table(
    generics: (
      [`G_PIXEL_WIDTH`],
      [generic],
      [integer],
      [Bits per Pixel configuration.],
      [`G_MASK_W`],
      [generic],
      [integer],
      [Overlay mask width configuration.],
      [`G_MASK_H`],
      [generic],
      [integer],
      [Overlay mask height configuration.],
      [`G_LINE_WIDTH`],
      [generic],
      [integer],
      [Video line width configuration.],
      [`G_NUM_ROW`],
      [generic],
      [integer],
      [Video frame height configuration.],
      [`G_OVERLAY_COLOR`],
      [generic],
      [slv(23)],
      [Overlay color configuration (RGB).],
    ),
    ports: (
      [`i_pass_picture_overlay`],
      [in],
      [1],
      [Passthrough input.],
      [`s_axis_video_rbg888_*`],
      [in/out],
      [AXI4-Stream Video],
      [RGB Input Stream.],
      [`m_axis_video_rbg888_*`],
      [in/out],
      [AXI4-Stream Video],
      [RGB Output Stream.],
    ),
  ),
  caption: [`AxiPictureOverlay` interfaces from (#repo_link("rtl/PICTURE_OVERLAY/hdl/AxiPictureOverlay.vhd", line: 39, branch: "feature/picture-overlay")).],
) <tab-click-if>

== Components
#block(breakable: false)[
The picture overlay consists of multiple components that are shown in the following diagram: 

#figure(
  image("../figures/artifacts/picture_overlay_components.drawio.png", width: 100%),
  caption: [Components overview of `AxiPictureOverlay`.],
) <fig-picture-overlay-components>

As shown in @fig-picture-overlay-components `mask_to_vhdl_rom` tool was implemented to generate the VHDL component `MaskRomPkg` (#repo_link("rtl/PICTURE_OVERLAY/hdl/MaskRomPkg.vhd", line: 39, branch: "feature/picture-overlay")) that contains the overlay mask. 
]

During the synthesis, the overlay mask from `MaskRomPkg` is written into the BRAM of the FPGA-Board by the entity `MaskRom` (#repo_link("rtl/PICTURE_OVERLAY/hdl/MaskRom.vhd", line: 39, branch: "feature/picture-overlay")). The `MaskRom` is a entity of the `AxiPictureOverlay` and reads the mask bit from the BRAM based on a input addr with a one-cycle delay. 

Furthermore, the `AxiPictureOverlay` contains the `PictureOverlayCtrl` (#repo_link("rtl/PICTURE_OVERLAY/hdl/PictureOverlayCtrl.vhd", line: 39, branch: "feature/picture-overlay")) entity, which executes the AXI-Handshake and validates if the current input pixel is in the region of the frame, where the overlay should be applied. It acts as a steering entity for `MaskRom` and `PictureOverlayCore` (#repo_link("rtl/PICTURE_OVERLAY/hdl/PictureOverlayCore.vhd", line: 39, branch: "feature/picture-overlay")). The `PictureOverlayCore` entity simply applies the overlay color to the current pixel, if the passthrough for the picture overlay is inactive, the current pixel is in the overlay region and the overlay mask is active.   


== Testbench

The `AxiPictureOverlay`-Testbench (#repo_link("testbench/tests/test_axi_picture_overlay.py", line: 1, branch: "feature/picture-overlay")) generates a AXI4 Video Stream for one frame that is put into the `AxiPictureOverlay` entity. It executes the following four testcases: 
- test active passthrough
- test if overlay is applied to image
- test that pixels outside the defined region are never replaced
- test start of frame resets by testing with a stream of two back-to-back frames 