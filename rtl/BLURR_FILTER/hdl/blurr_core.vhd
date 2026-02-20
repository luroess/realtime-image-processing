library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity E_BlurrCore is
  generic (
    -- Pixel width in bits (default 8-bit grayscale)
    G_PIXEL_WIDTH : positive := 8;
    -- Window/kernel side length (K)
    G_KERNEL_SIZE : positive := 3;
    -- Signed coefficient width in bits
    G_COEFF_WIDTH : positive := 8;
    -- Packed signed coefficients in row-major order, tap0 at LSB.
    -- Default: 3x3 Gaussian [1 2 1; 2 4 2; 1 2 1]
    G_KERNEL_COEFFS : std_logic_vector(71 downto 0) := x"010201020402010201";
    -- Post-accumulation normalization divisor (must be >=1)
    G_NORMALIZE_DIVISOR : positive := 16;
    -- Optional bias added before normalization
    G_BIAS : integer := 0
  );
  port (
    -- KxK grayscale window: K*K pixels packed row-major, tap0 at LSB.
    i_window      : in  std_logic_vector((G_KERNEL_SIZE * G_KERNEL_SIZE * G_PIXEL_WIDTH) - 1 downto 0);
    o_blurr_pixel : out std_logic_vector(G_PIXEL_WIDTH - 1 downto 0)
  );
end entity;

architecture A_RtlComb of E_BlurrCore is
  constant C_NUM_TAPS  : positive := G_KERNEL_SIZE * G_KERNEL_SIZE;
  constant C_MAX_PIXEL : integer  := (2 ** G_PIXEL_WIDTH) - 1;

  function f_coeff_at(i_idx : natural) return integer is
    constant C_LSB : natural := i_idx * G_COEFF_WIDTH;
    constant C_MSB : natural := ((i_idx + 1) * G_COEFF_WIDTH) - 1;
  begin
    return to_integer(signed(G_KERNEL_COEFFS(C_MSB downto C_LSB)));
  end function;
begin
  assert G_KERNEL_SIZE > 0
    report "E_BlurrCore: G_KERNEL_SIZE must be > 0."
    severity failure;
  assert G_KERNEL_COEFFS'length = (G_KERNEL_SIZE * G_KERNEL_SIZE * G_COEFF_WIDTH)
    report "E_BlurrCore: G_KERNEL_COEFFS length must equal G_KERNEL_SIZE*G_KERNEL_SIZE*G_COEFF_WIDTH."
    severity failure;

  process(i_window)
    variable v_sum   : integer;
    variable v_pixel : integer;
    variable v_coeff : integer;
    variable v_norm  : integer;
    variable v_div   : integer;
    variable v_clip  : integer;
  begin
    v_sum := G_BIAS;

    for i in 0 to C_NUM_TAPS - 1 loop
      v_pixel := to_integer(unsigned(i_window(((i + 1) * G_PIXEL_WIDTH) - 1 downto (i * G_PIXEL_WIDTH))));
      v_coeff := f_coeff_at(i);
      v_sum := v_sum + (v_pixel * v_coeff);
    end loop;

    v_norm := v_sum;
    v_div := integer(G_NORMALIZE_DIVISOR);
    if v_div > 1 then
      -- Integer rounding to nearest value before clipping.
      if v_norm >= 0 then
        v_norm := (v_norm + (v_div / 2)) / v_div;
      else
        v_norm := (v_norm - (v_div / 2)) / v_div;
      end if;
    end if;

    if v_norm < 0 then
      v_clip := 0;
    elsif v_norm > C_MAX_PIXEL then
      v_clip := C_MAX_PIXEL;
    else
      v_clip := v_norm;
    end if;

    o_blurr_pixel <= std_logic_vector(to_unsigned(v_clip, G_PIXEL_WIDTH));
  end process;
end architecture;
