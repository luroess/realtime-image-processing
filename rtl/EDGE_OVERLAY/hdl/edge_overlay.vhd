library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Deprecated legacy compositor: use FRAME_COMPOSITOR instead.
entity EdgeOverlay is
  generic (
    G_COMPONENT_WIDTH : positive := 8;
    G_EDGE_COLOR      : std_logic_vector(23 downto 0) := x"FF0000"
  );
  port (
    i_overlay_enable : in  std_logic;
    i_edge_detected  : in  std_logic;
    i_video_rbg888   : in  std_logic_vector((3 * G_COMPONENT_WIDTH) - 1 downto 0);
    o_video_rbg888   : out std_logic_vector((3 * G_COMPONENT_WIDTH) - 1 downto 0)
  );
end entity;

architecture A_Rtl of EdgeOverlay is
  signal s_edge_color_resized : std_logic_vector((3 * G_COMPONENT_WIDTH) - 1 downto 0);
begin
  s_edge_color_resized <= std_logic_vector(
    resize(unsigned(G_EDGE_COLOR), s_edge_color_resized'length)
  );

  o_video_rbg888 <= s_edge_color_resized when (i_overlay_enable = '1') and (i_edge_detected = '1') else
                    i_video_rbg888;
end architecture;
