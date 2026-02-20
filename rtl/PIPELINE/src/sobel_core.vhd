library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity E_SobelCore is
  generic (
    -- Pixel width in bits (default 8-bit grayscale)
    G_PIXEL_WIDTH    : positive := 8;
    -- Used for vector sizing onl, Sobel computation is fixed to 3x3
    G_KERNEL_SIZE    : positive := 3;
    -- Threshold in range 0..2040 for 8-bit input
    G_SOBEL_THRESHOLD : natural := 150
  );
  port (
    -- 3x3 grayscale window: 9 bytes packed into 72-bit vector
    -- LSB is p1 and MSB is p9
    -- Visual pixel array:
    -- p1 p2 p3
    -- p4 p5 p6
    -- p7 p8 p9
    i_window     : in  std_logic_vector((G_KERNEL_SIZE * G_KERNEL_SIZE * G_PIXEL_WIDTH) - 1 downto 0);
    o_edge_pixel : out std_logic_vector(G_PIXEL_WIDTH - 1 downto 0)
  );
end entity;

architecture A_RtlComb of E_SobelCore is
  signal s_p1_u : unsigned(G_PIXEL_WIDTH - 1 downto 0);
  signal s_p2_u : unsigned(G_PIXEL_WIDTH - 1 downto 0);
  signal s_p3_u : unsigned(G_PIXEL_WIDTH - 1 downto 0);
  signal s_p4_u : unsigned(G_PIXEL_WIDTH - 1 downto 0);
  signal s_p5_u : unsigned(G_PIXEL_WIDTH - 1 downto 0);
  signal s_p6_u : unsigned(G_PIXEL_WIDTH - 1 downto 0);
  signal s_p7_u : unsigned(G_PIXEL_WIDTH - 1 downto 0);
  signal s_p8_u : unsigned(G_PIXEL_WIDTH - 1 downto 0);
  signal s_p9_u : unsigned(G_PIXEL_WIDTH - 1 downto 0);
begin
  assert G_KERNEL_SIZE = 3
    report "E_SobelCore: fixed Sobel logic requires G_KERNEL_SIZE=3."
    severity failure;

  -- Uses the first 3x3 pixels in row-major order from i_window
  s_p1_u <= unsigned(i_window((1 * G_PIXEL_WIDTH) - 1 downto (0 * G_PIXEL_WIDTH)));
  s_p2_u <= unsigned(i_window((2 * G_PIXEL_WIDTH) - 1 downto (1 * G_PIXEL_WIDTH)));
  s_p3_u <= unsigned(i_window((3 * G_PIXEL_WIDTH) - 1 downto (2 * G_PIXEL_WIDTH)));
  s_p4_u <= unsigned(i_window((4 * G_PIXEL_WIDTH) - 1 downto (3 * G_PIXEL_WIDTH)));
  s_p5_u <= unsigned(i_window((5 * G_PIXEL_WIDTH) - 1 downto (4 * G_PIXEL_WIDTH)));
  s_p6_u <= unsigned(i_window((6 * G_PIXEL_WIDTH) - 1 downto (5 * G_PIXEL_WIDTH)));
  s_p7_u <= unsigned(i_window((7 * G_PIXEL_WIDTH) - 1 downto (6 * G_PIXEL_WIDTH)));
  s_p8_u <= unsigned(i_window((8 * G_PIXEL_WIDTH) - 1 downto (7 * G_PIXEL_WIDTH)));
  s_p9_u <= unsigned(i_window((9 * G_PIXEL_WIDTH) - 1 downto (8 * G_PIXEL_WIDTH)));

  process(s_p1_u, s_p2_u, s_p3_u, s_p4_u, s_p5_u, s_p6_u, s_p7_u, s_p8_u, s_p9_u)
    variable v_gx     : integer;
    variable v_gy     : integer;
    variable v_abs_gx : integer;
    variable v_abs_gy : integer;
    variable v_mag    : integer;
  begin
    -- Sobel kernels:
    -- Gx = [-1  0  1; -2  0  2; -1  0  1]
    -- Gy = [ 1  2  1;  0  0  0; -1 -2 -1]
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

    -- Edge (white)
    if v_mag >= integer(G_SOBEL_THRESHOLD) then
      o_edge_pixel <= (others => '1');
    -- Background (black)
    else
      o_edge_pixel <= (others => '0');
    end if;
  end process;
end architecture;
