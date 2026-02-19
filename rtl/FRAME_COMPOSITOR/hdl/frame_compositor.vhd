library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity FrameCompositor is
  generic (
    -- Per-channel component width for packed RGB bus.
    G_COMPONENT_WIDTH : positive                      := 8;
    -- Overlay colors are provided as packed RGB888 values (wire order follows project convention).
    G_SOBEL_COLOR     : std_logic_vector(23 downto 0) := x"FF0000";
    G_FAST_COLOR      : std_logic_vector(23 downto 0) := x"0000FF"
  );
  port (
    -- Overlay selector: 00=none, 01=FAST color, 10=Sobel color.
    i_overlay_mode : in  std_logic_vector(1 downto 0);
    -- Base RGB pixel to pass through when overlay is inactive.
    i_rgb888       : in  std_logic_vector((3 * G_COMPONENT_WIDTH) - 1 downto 0);
    -- Binary edge flags for Sobel and FAST paths.
    i_sobel_edge   : in  std_logic;
    i_fast_edge    : in  std_logic;
    -- Composited pixel output.
    o_rgb888       : out std_logic_vector((3 * G_COMPONENT_WIDTH) - 1 downto 0)
  );
end entity;

architecture A_Rtl of FrameCompositor is
  constant C_OVERLAY_NONE  : std_logic_vector(1 downto 0) := "00";
  constant C_OVERLAY_FAST  : std_logic_vector(1 downto 0) := "01";
  constant C_OVERLAY_SOBEL : std_logic_vector(1 downto 0) := "10";

  signal s_sobel_color_resized : std_logic_vector((3 * G_COMPONENT_WIDTH) - 1 downto 0);
  signal s_fast_color_resized  : std_logic_vector((3 * G_COMPONENT_WIDTH) - 1 downto 0);
  signal s_overlay_active      : std_logic                                              := '0';
  signal s_overlay_color       : std_logic_vector((3 * G_COMPONENT_WIDTH) - 1 downto 0) := (others => '0');

  -- Expand RGB888 generic colors to the configured component width.
  function f_expand_color(i_color : std_logic_vector(23 downto 0))
    return std_logic_vector is
    variable v_r : unsigned(G_COMPONENT_WIDTH - 1 downto 0);
    variable v_b : unsigned(G_COMPONENT_WIDTH - 1 downto 0);
    variable v_g : unsigned(G_COMPONENT_WIDTH - 1 downto 0);
    variable v_o : std_logic_vector((3 * G_COMPONENT_WIDTH) - 1 downto 0);
  begin
    -- Project stream order on 24-bit RGB buses is R|B|G.
    v_r := resize(unsigned(i_color(23 downto 16)), G_COMPONENT_WIDTH);
    v_b := resize(unsigned(i_color(15 downto 8)), G_COMPONENT_WIDTH);
    v_g := resize(unsigned(i_color(7 downto 0)), G_COMPONENT_WIDTH);
    v_o := std_logic_vector(v_r) & std_logic_vector(v_b) & std_logic_vector(v_g);
    return v_o;
  end function;
begin
  s_sobel_color_resized <= f_expand_color(G_SOBEL_COLOR);
  s_fast_color_resized  <= f_expand_color(G_FAST_COLOR);

  -- Pure combinational overlay selection with base pixel passthrough fallback.
  P_COMB_OVERLAY: process (i_overlay_mode, i_sobel_edge, i_fast_edge, s_sobel_color_resized, s_fast_color_resized)
  begin
    s_overlay_active <= '0';
    s_overlay_color <= (others => '0');

    case i_overlay_mode is
      when C_OVERLAY_SOBEL =>
        if i_sobel_edge = '1' then
          s_overlay_active <= '1';
          s_overlay_color <= s_sobel_color_resized;
        end if;
      when C_OVERLAY_FAST =>
        if i_fast_edge = '1' then
          s_overlay_active <= '1';
          s_overlay_color <= s_fast_color_resized;
        end if;
      when C_OVERLAY_NONE =>
        null;
      when others =>
        null;
    end case;
  end process;

  -- TODO: Add explicit simulation assertion for unsupported i_overlay_mode encodings (others branch).
  o_rgb888 <= s_overlay_color when s_overlay_active = '1' else i_rgb888;
end architecture;
