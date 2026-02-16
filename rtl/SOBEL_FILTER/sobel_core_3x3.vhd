library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity E_SobelCore3x3 is
  generic (
    -- Threshold in range 0..2040 for 8-bit input
    G_SOBEL_TRESHOLD : natural := 200
  );
  port (
    -- 3x3 grayscale window: 9 bytes packed into 72-bit vector
    -- LSB is p1 and MSB is p9
    -- Visual pixel array:
    -- p1 p2 p3
    -- p4 p5 p6
    -- p7 p8 p9
    -- (p1 in bits 7:0 and p9 in bits 71:64)
    i_window     : in  std_logic_vector(71 downto 0);
    o_edge_pixel : out std_logic_vector(7 downto 0)
  );
end entity;

architecture A_RtlComb of E_SobelCore3x3 is
  signal s_p1_u : unsigned(7 downto 0);
  signal s_p2_u : unsigned(7 downto 0);
  signal s_p3_u : unsigned(7 downto 0);
  signal s_p4_u : unsigned(7 downto 0);
  signal s_p5_u : unsigned(7 downto 0);
  signal s_p6_u : unsigned(7 downto 0);
  signal s_p7_u : unsigned(7 downto 0);
  signal s_p8_u : unsigned(7 downto 0);
  signal s_p9_u : unsigned(7 downto 0);
begin
  s_p1_u <= unsigned(i_window(7 downto 0));
  s_p2_u <= unsigned(i_window(15 downto 8));
  s_p3_u <= unsigned(i_window(23 downto 16));
  s_p4_u <= unsigned(i_window(31 downto 24));
  s_p5_u <= unsigned(i_window(39 downto 32));
  s_p6_u <= unsigned(i_window(47 downto 40));
  s_p7_u <= unsigned(i_window(55 downto 48));
  s_p8_u <= unsigned(i_window(63 downto 56));
  s_p9_u <= unsigned(i_window(71 downto 64));

  process(s_p1_u, s_p2_u, s_p3_u, s_p4_u, s_p5_u, s_p6_u, s_p7_u, s_p8_u, s_p9_u)
    variable v_gx     : integer range -1020 to 1020;
    variable v_gy     : integer range -1020 to 1020;
    variable v_abs_gx : integer range 0 to 1020;
    variable v_abs_gy : integer range 0 to 1020;
    variable v_mag    : integer range 0 to 2040;
  begin
    -- Sobel kernels:
    -- Gx = [-1  0  1; -2  0  2; -1  0  1]
    -- Gy = [ 1  2  1;  0  0  0; -1 -2 -1]

    -- Calculate Sobel gradients x & y
    v_gx := (to_integer(s_p3_u) + (2 * to_integer(s_p6_u)) + to_integer(s_p9_u))
            - (to_integer(s_p1_u) + (2 * to_integer(s_p4_u)) + to_integer(s_p7_u));
    v_gy := (to_integer(s_p1_u) + (2 * to_integer(s_p2_u)) + to_integer(s_p3_u))
            - (to_integer(s_p7_u) + (2 * to_integer(s_p8_u)) + to_integer(s_p9_u));

    if v_gx < 0 then
      v_abs_gx := -v_gx;
    else
      v_abs_gx := v_gx;
    end if;

    if v_gy < 0 then
      v_abs_gy := -v_gy;
    else
      v_abs_gy := v_gy;
    end if;

    v_mag := v_abs_gx + v_abs_gy;

    -- Edge
    if v_mag >= G_SOBEL_TRESHOLD then
      o_edge_pixel <= (others => '1'); -- White
    -- Background
    else
      o_edge_pixel <= (others => '0'); -- Black
    end if;
  end process;
end architecture;
