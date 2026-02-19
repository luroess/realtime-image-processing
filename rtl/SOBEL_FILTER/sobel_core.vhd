library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity E_SobelCore is
  generic (
    -- Pixel width in bits (default 8-bit grayscale)
    G_PIXEL_WIDTH    : positive := 8;
    -- Used for vector sizing onl, Sobel computation is fixed to 3x3
    G_KERNEL_SIZE    : positive := 3;
    -- Initial threshold / running-mean seed.
    G_SOBEL_THRESHOLD : natural := 200;
    -- Running-mean update factor: mean += (mag - mean) / 2^G_MEAN_SHIFT.
    G_MEAN_SHIFT : natural := 4;
    -- Update running mean once every N accepted pixels.
    G_MEAN_UPDATE_INTERVAL : positive := 1;
    -- Adaptive threshold = clamp((mean * NUM / DEN) + OFFSET, MIN..MAX).
    G_THRESHOLD_GAIN_NUM : positive := 1;
    G_THRESHOLD_GAIN_DEN : positive := 1;
    G_THRESHOLD_OFFSET   : integer  := 0;
    G_THRESHOLD_MIN      : natural  := 0;
    G_THRESHOLD_MAX      : natural  := 2040
  );
  port (
    i_aclk         : in  std_logic;
    i_aresetn      : in  std_logic;
    -- Assert when this pixel is consumed (AXIS TVALID and TREADY high).
    i_sample_valid : in  std_logic;
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
  function f_clamp(i_value : integer; i_lo : integer; i_hi : integer) return integer is
  begin
    if i_value < i_lo then
      return i_lo;
    end if;
    if i_value > i_hi then
      return i_hi;
    end if;
    return i_value;
  end function;

  function f_pow2_saturating(i_shift : natural) return integer is
    variable v_value : integer := 1;
  begin
    for i in 1 to i_shift loop
      if v_value > (integer'high / 2) then
        return integer'high;
      end if;
      v_value := v_value * 2;
    end loop;
    return v_value;
  end function;

  constant C_MAG_MAX       : integer := (8 * ((2 ** G_PIXEL_WIDTH) - 1));
  constant C_MEAN_INIT     : integer := f_clamp(integer(G_SOBEL_THRESHOLD), 0, C_MAG_MAX);
  constant C_MEAN_ALPHA_DIV : integer := f_pow2_saturating(G_MEAN_SHIFT);

  signal s_p1_u : unsigned(G_PIXEL_WIDTH - 1 downto 0);
  signal s_p2_u : unsigned(G_PIXEL_WIDTH - 1 downto 0);
  signal s_p3_u : unsigned(G_PIXEL_WIDTH - 1 downto 0);
  signal s_p4_u : unsigned(G_PIXEL_WIDTH - 1 downto 0);
  signal s_p5_u : unsigned(G_PIXEL_WIDTH - 1 downto 0);
  signal s_p6_u : unsigned(G_PIXEL_WIDTH - 1 downto 0);
  signal s_p7_u : unsigned(G_PIXEL_WIDTH - 1 downto 0);
  signal s_p8_u : unsigned(G_PIXEL_WIDTH - 1 downto 0);
  signal s_p9_u : unsigned(G_PIXEL_WIDTH - 1 downto 0);
  signal s_mag          : integer range 0 to C_MAG_MAX := 0;
  signal s_running_mean : integer range 0 to C_MAG_MAX := C_MEAN_INIT;
  signal s_update_counter : natural range 0 to G_MEAN_UPDATE_INTERVAL - 1 := 0;
begin
  assert G_KERNEL_SIZE = 3
    report "E_SobelCore: fixed Sobel logic requires G_KERNEL_SIZE=3."
    severity failure;
  assert G_THRESHOLD_MIN <= G_THRESHOLD_MAX
    report "E_SobelCore: G_THRESHOLD_MIN must be <= G_THRESHOLD_MAX."
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

    v_mag := f_clamp(v_abs_gx + v_abs_gy, 0, C_MAG_MAX);
    s_mag <= v_mag;
  end process;

  process(s_running_mean, s_mag)
    variable v_threshold : integer;
  begin
    v_threshold := ((s_running_mean * integer(G_THRESHOLD_GAIN_NUM)) / integer(G_THRESHOLD_GAIN_DEN))
                   + G_THRESHOLD_OFFSET;
    v_threshold := f_clamp(v_threshold, integer(G_THRESHOLD_MIN), integer(G_THRESHOLD_MAX));
    v_threshold := f_clamp(v_threshold, 0, C_MAG_MAX);

    if s_mag >= v_threshold then
      o_edge_pixel <= (others => '1');
    else
      o_edge_pixel <= (others => '0');
    end if;
  end process;

  P_MEAN_UPDATE : process(i_aclk)
    variable v_delta     : integer;
    variable v_step      : integer;
    variable v_mean_next : integer;
  begin
    if rising_edge(i_aclk) then
      if i_aresetn /= '1' then
        s_running_mean <= C_MEAN_INIT;
        s_update_counter <= 0;
      elsif i_sample_valid = '1' then
        if s_update_counter = (G_MEAN_UPDATE_INTERVAL - 1) then
          s_update_counter <= 0;

          v_delta := s_mag - s_running_mean;
          if C_MEAN_ALPHA_DIV > 1 then
            -- Integer division in VHDL truncates toward zero; keep model behavior explicit
            v_step := v_delta / C_MEAN_ALPHA_DIV;
          else
            v_step := v_delta;
          end if;

          v_mean_next := f_clamp(s_running_mean + v_step, 0, C_MAG_MAX);
          s_running_mean <= v_mean_next;
        else
          s_update_counter <= s_update_counter + 1;
        end if;
      end if;
    end if;
  end process;
end architecture;
