library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity E_RgbToGrayscale is
  generic (
    -- Bit-width per color component (R, G, B).
    G_COMPONENT_WIDTH : positive := 8
  );
  port (
    -- Input pixel encoded as R | B | G, MSB to LSB.
    i_rgb888 : in  std_logic_vector((3 * G_COMPONENT_WIDTH) - 1 downto 0);
    -- Grayscale output with component width.
    o_gray8  : out std_logic_vector(G_COMPONENT_WIDTH - 1 downto 0);
    -- RGB grayscale output (R=G=B=Y) with RBG width.
    o_rbg888 : out std_logic_vector((3 * G_COMPONENT_WIDTH) - 1 downto 0)
  );
end entity;

architecture A_RtlComb of E_RgbToGrayscale is
  constant C_RGB_WIDTH : positive := 3 * G_COMPONENT_WIDTH;
  constant C_R_MSB     : natural  := C_RGB_WIDTH - 1;
  constant C_R_LSB     : natural  := 2 * G_COMPONENT_WIDTH;
  constant C_B_MSB     : natural  := (2 * G_COMPONENT_WIDTH) - 1;
  constant C_B_LSB     : natural  := G_COMPONENT_WIDTH;
  constant C_G_MSB     : natural  := G_COMPONENT_WIDTH - 1;
  constant C_G_LSB     : natural  := 0;

  signal s_r_u    : unsigned(G_COMPONENT_WIDTH - 1 downto 0);
  signal s_g_u    : unsigned(G_COMPONENT_WIDTH - 1 downto 0);
  signal s_b_u    : unsigned(G_COMPONENT_WIDTH - 1 downto 0);
  signal s_gray_u : unsigned(G_COMPONENT_WIDTH - 1 downto 0);
begin
  s_r_u <= unsigned(i_rgb888(C_R_MSB downto C_R_LSB));
  s_g_u <= unsigned(i_rgb888(C_G_MSB downto C_G_LSB));
  s_b_u <= unsigned(i_rgb888(C_B_MSB downto C_B_LSB));

  -- Shift-and-add grayscale approximation:
  -- Y ~= (R/4) + (G/2) + (B/4)
  s_gray_u <= shift_right(s_r_u, 2) + shift_right(s_g_u, 1) + shift_right(s_b_u, 2);

  o_gray8  <= std_logic_vector(s_gray_u);
  o_rbg888 <= std_logic_vector(s_gray_u) & std_logic_vector(s_gray_u) & std_logic_vector(s_gray_u);

end architecture;
