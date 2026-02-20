library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity FrameCompositor is
  generic (
    -- Per-channel component width for packed RGB bus.
    G_COMPONENT_WIDTH : positive                      := 8;
    -- Overlay color provided as packed RGB888 value (project wire order R|B|G).
    G_EDGE_COLOR      : std_logic_vector(23 downto 0) := x"FF0000"
  );
  port (
    -- Base RGB pixel to pass through when edge mask is inactive.
    i_rgb888    : in  std_logic_vector((3 * G_COMPONENT_WIDTH) - 1 downto 0);
    -- Edge mask by Sobel/Sobel+Blur processing path.
    i_edge_mask : in  std_logic;
    -- Composited pixel output.
    o_rgb888    : out std_logic_vector((3 * G_COMPONENT_WIDTH) - 1 downto 0)
  );
end entity;

architecture A_Rtl of FrameCompositor is
  signal s_edge_color_resized : std_logic_vector((3 * G_COMPONENT_WIDTH) - 1 downto 0);

  -- Expand packed RGB888 generic color to current component width.
  -- i_color layout is interpreted as R[23:16] | B[15:8] | G[7:0] to match
  -- project stream order on 24-bit "rbg" buses.
  function f_expand_color(i_color : std_logic_vector(23 downto 0))
    return std_logic_vector is
    variable v_r : unsigned(G_COMPONENT_WIDTH - 1 downto 0);
    variable v_b : unsigned(G_COMPONENT_WIDTH - 1 downto 0);
    variable v_g : unsigned(G_COMPONENT_WIDTH - 1 downto 0);
    variable v_o : std_logic_vector((3 * G_COMPONENT_WIDTH) - 1 downto 0);
  begin
    v_r := resize(unsigned(i_color(23 downto 16)), G_COMPONENT_WIDTH);
    v_b := resize(unsigned(i_color(15 downto 8)), G_COMPONENT_WIDTH);
    v_g := resize(unsigned(i_color(7 downto 0)), G_COMPONENT_WIDTH);
    v_o := std_logic_vector(v_r) & std_logic_vector(v_b) & std_logic_vector(v_g);
    return v_o;
  end function;
begin
  s_edge_color_resized <= f_expand_color(G_EDGE_COLOR);

  o_rgb888 <= s_edge_color_resized when i_edge_mask = '1' else
              i_rgb888;
end architecture;
