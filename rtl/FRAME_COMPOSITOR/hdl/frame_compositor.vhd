library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity FrameCompositor is
  generic (
    G_COMPONENT_WIDTH : positive := 8;
    G_SOBEL_COLOR     : std_logic_vector(23 downto 0) := x"FF0000";
    G_FAST_COLOR      : std_logic_vector(23 downto 0) := x"0000FF"
  );
  port (
    i_base_mode    : in  std_logic_vector(1 downto 0);
    i_overlay_mode : in  std_logic_vector(1 downto 0);
    i_rgb888       : in  std_logic_vector((3 * G_COMPONENT_WIDTH) - 1 downto 0);
    i_gray8        : in  std_logic_vector(G_COMPONENT_WIDTH - 1 downto 0);
    i_sobel_edge   : in  std_logic;
    i_fast_edge    : in  std_logic;
    o_rgb888       : out std_logic_vector((3 * G_COMPONENT_WIDTH) - 1 downto 0)
  );
end entity;

architecture A_Rtl of FrameCompositor is
  constant C_BASE_RGB  : std_logic_vector(1 downto 0) := "00";
  constant C_BASE_GRAY : std_logic_vector(1 downto 0) := "01";

  constant C_OVERLAY_NONE  : std_logic_vector(1 downto 0) := "00";
  constant C_OVERLAY_FAST  : std_logic_vector(1 downto 0) := "01";
  constant C_OVERLAY_SOBEL : std_logic_vector(1 downto 0) := "10";

  signal s_gray_rgb            : std_logic_vector((3 * G_COMPONENT_WIDTH) - 1 downto 0);
  signal s_base_rgb            : std_logic_vector((3 * G_COMPONENT_WIDTH) - 1 downto 0);
  signal s_sobel_color_resized : std_logic_vector((3 * G_COMPONENT_WIDTH) - 1 downto 0);
  signal s_fast_color_resized  : std_logic_vector((3 * G_COMPONENT_WIDTH) - 1 downto 0);
  signal s_overlay_active      : std_logic := '0';
  signal s_overlay_color       : std_logic_vector((3 * G_COMPONENT_WIDTH) - 1 downto 0) := (others => '0');
begin
  s_gray_rgb <= i_gray8 & i_gray8 & i_gray8;

  s_sobel_color_resized <= std_logic_vector(
    resize(unsigned(G_SOBEL_COLOR), s_sobel_color_resized'length)
  );
  s_fast_color_resized <= std_logic_vector(
    resize(unsigned(G_FAST_COLOR), s_fast_color_resized'length)
  );

  P_COMB_BASE : process (i_base_mode, i_rgb888, s_gray_rgb)
  begin
    case i_base_mode is
      when C_BASE_RGB =>
        s_base_rgb <= i_rgb888;
      when C_BASE_GRAY =>
        s_base_rgb <= s_gray_rgb;
      when others =>
        s_base_rgb <= (others => '0');
    end case;
  end process;

  P_COMB_OVERLAY : process (
    i_overlay_mode,
    i_sobel_edge,
    i_fast_edge,
    s_sobel_color_resized,
    s_fast_color_resized
  )
  begin
    s_overlay_active <= '0';
    s_overlay_color  <= (others => '0');

    case i_overlay_mode is
      when C_OVERLAY_SOBEL =>
        if i_sobel_edge = '1' then
          s_overlay_active <= '1';
          s_overlay_color  <= s_sobel_color_resized;
        end if;
      when C_OVERLAY_FAST =>
        if i_fast_edge = '1' then
          s_overlay_active <= '1';
          s_overlay_color  <= s_fast_color_resized;
        end if;
      when C_OVERLAY_NONE =>
        null;
      when others =>
        null;
    end case;
  end process;

  o_rgb888 <= s_overlay_color when s_overlay_active = '1' else s_base_rgb;
end architecture;
