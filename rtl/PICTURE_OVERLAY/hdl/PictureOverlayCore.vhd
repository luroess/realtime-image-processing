-- =============================================================================
-- PictureOverlayCore
-- =============================================================================
-- Combinational mux that replaces a video pixel with a fixed overlay colour
-- whenever the corresponding mask bit is active.
--
-- Mirrors the pattern of EdgeOverlay.vhd but works from a BRAM-sourced
-- per-pixel mask bit instead of a live edge-detection signal.
--
-- Ports
--   i_pass_picture_overlay : runtime gate ('1' = pure passthrough)
--   i_mask_bit          : 1-bit mask value from MaskRom for the current pixel
--   i_in_region         : '1' when the pixel falls inside the mask bounds
--   i_video_rbg888      : RBG888 input pixel from the video stream
--   i_overlay_color_rbg : replacement colour to paint when mask='1'
--   o_video_rbg888      : RBG888 output pixel (replaced or passthrough)
-- =============================================================================

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity PictureOverlayCore is
  generic (
    G_COMPONENT_WIDTH  : positive                      := 8;
    -- Default overlay colour: full green in R|B|G packing = R=00 B=00 G=FF.
    G_OVERLAY_COLOR    : std_logic_vector(23 downto 0) := x"0000FF"
  );
  port (
    -- Runtime control: '1' = full passthrough, '0' = overlay active.
    i_pass_picture_overlay : in  std_logic;
    -- Mask bit sourced from MaskRom (already aligned to the pixel beat).
    i_mask_bit          : in  std_logic;
    -- '1' when the current pixel is within the mask image bounds.
    i_in_region         : in  std_logic;
    -- Input video pixel (R|B|G packed, 24-bit for 8-bit components).
    i_video_rbg888      : in  std_logic_vector((3 * G_COMPONENT_WIDTH) - 1 downto 0);
    -- Output video pixel.
    o_video_rbg888      : out std_logic_vector((3 * G_COMPONENT_WIDTH) - 1 downto 0)
  );
end entity PictureOverlayCore;

architecture A_Rtl of PictureOverlayCore is

  signal s_overlay_color_resized : std_logic_vector((3 * G_COMPONENT_WIDTH) - 1 downto 0);

begin

  -- Resize the generic colour to match the actual component width.
  s_overlay_color_resized <=
    std_logic_vector(resize(unsigned(G_OVERLAY_COLOR), s_overlay_color_resized'length));

  -- Replace pixel with overlay colour only when:
  --   ? passthrough is disabled globally, AND
  --   ? the pixel is within the mask image bounds, AND
  --   ? the mask bit for this pixel is '1' (active).
  o_video_rbg888 <=
    s_overlay_color_resized
      when (i_pass_picture_overlay = '0') and (i_in_region = '1') and (i_mask_bit = '0')
    else i_video_rbg888;

end architecture A_Rtl;
