library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

  -- ============================================================================
  -- E_FastCore
  -- ----------------------------------------------------------------------------
  -- FAST-N corner candidate evaluator for one 7x7 grayscale window.
  --
  -- Behavior:
  -- - Samples the 16-pixel FAST ring (radius 3 around center).
  -- - Performs full contiguous arc test for length G_FAST_N.
  -- - Emits candidate flag and 13-bit score.
  --
  -- Notes:
  -- - This block is purely combinational.
  -- - Output score is the maximum bright/dark arc margin sum.
  -- ============================================================================

entity E_FastCore is
  generic (
    -- Pixel width in bits. This implementation requires 8-bit gray.
    G_PIXEL_WIDTH          : positive := 8;
    -- Window side length. This implementation requires a 7x7 window.
    G_KERNEL_SIZE          : positive := 7;
    -- FAST threshold t.
    G_FAST_THRESHOLD       : natural  := 20;
    -- FAST arc length N (contiguous samples on a 16-sample ring).
    G_FAST_N               : positive := 9
  );
  port (
    -- Flattened 7x7 window in row-major order, one gray pixel per slice.
    i_window       : in  std_logic_vector((G_KERNEL_SIZE * G_KERNEL_SIZE * G_PIXEL_WIDTH) - 1 downto 0);
    -- Corner candidate flag for the center pixel.
    o_is_candidate : out std_logic;
    -- Corner score for downstream ranking (13-bit unsigned).
    o_score        : out std_logic_vector(12 downto 0)
  );
end entity;

architecture A_Rtl of E_FastCore is
  -- Ring lookup index type for 16 FAST ring taps.
  type t_ring_index_t is array (0 to 15) of natural;
  -- Runtime ring sample storage.
  type t_ring_value_t is array (0 to 15) of integer;

  -- FAST ring sample positions for a 7x7 row-major window.
  constant C_RING_INDEX : t_ring_index_t := (
    3, 4, 12, 20, 27, 34, 40, 46,
    45, 44, 36, 28, 21, 14, 8, 2
  );

  constant C_RING_POINTS      : natural := 16;
  constant C_SCORE_MAX        : natural := 8191;

  -- --------------------------------------------------------------------------
  -- f_pixel_at
  -- --------------------------------------------------------------------------
  -- Extracts one pixel from the flattened input window.
  --
  -- Inputs:
  -- - i_window_flat: flattened window vector.
  -- - i_pixel_index: row-major pixel index.
  --
  -- Return:
  -- - Pixel value as integer.
  --
  -- Behavior:
  -- - Asserts on out-of-range index.
  -- --------------------------------------------------------------------------
  function f_pixel_at(
      i_window_flat : std_logic_vector;
      i_pixel_index : natural
    ) return integer is
    variable v_lsb : natural;
    variable v_msb : natural;
  begin
    assert i_pixel_index < (i_window_flat'length / G_PIXEL_WIDTH)
      report "E_FastCore.f_pixel_at index out of range."
      severity failure;

    v_lsb := i_pixel_index * G_PIXEL_WIDTH;
    v_msb := v_lsb + G_PIXEL_WIDTH - 1;
    return to_integer(unsigned(i_window_flat(v_msb downto v_lsb)));
  end function;

begin
  assert G_KERNEL_SIZE = 7
    report "E_FastCore requires G_KERNEL_SIZE=7."
    severity failure;

  assert G_PIXEL_WIDTH = 8
    report "E_FastCore requires G_PIXEL_WIDTH=8."
    severity failure;

  assert (G_FAST_N >= 1) and (G_FAST_N <= 16)
    report "E_FastCore requires 1 <= G_FAST_N <= 16."
    severity failure;

  -- Main combinational FAST evaluation.
  P_COMB_FAST: process (i_window)
    variable v_ring : t_ring_value_t;

    variable v_center    : integer;
    variable v_threshold : integer;
    variable v_high_ref  : integer;
    variable v_low_ref   : integer;

    variable v_candidate  : boolean;
    variable v_best_score : integer;

    variable v_bright_run    : boolean;
    variable v_dark_run      : boolean;
    variable v_bright_score  : integer;
    variable v_dark_score    : integer;

    variable v_idx   : natural range 0 to C_RING_POINTS - 1;
    variable v_value : integer;
  begin
    -- Load ring samples once for the whole evaluation.
    for i in 0 to C_RING_POINTS - 1 loop
      v_ring(i) := f_pixel_at(i_window, C_RING_INDEX(i));
    end loop;

    v_center := f_pixel_at(i_window, 24);

    v_threshold := integer(G_FAST_THRESHOLD);
    if v_threshold > 255 then
      v_threshold := 255;
    end if;

    v_high_ref := v_center + v_threshold;
    v_low_ref := v_center - v_threshold;

    v_candidate := false;
    v_best_score := 0;

    -- Full contiguous arc evaluation over all 16 start positions.
    for i_start in 0 to C_RING_POINTS - 1 loop
      v_bright_run := true;
      v_dark_run := true;
      v_bright_score := 0;
      v_dark_score := 0;

      for i_off in 0 to G_FAST_N - 1 loop
        v_idx := (i_start + i_off) mod C_RING_POINTS;
        v_value := v_ring(v_idx);

        if v_value > v_high_ref then
          v_bright_score := v_bright_score + (v_value - v_high_ref);
        else
          v_bright_run := false;
        end if;

        if v_value < v_low_ref then
          v_dark_score := v_dark_score + (v_low_ref - v_value);
        else
          v_dark_run := false;
        end if;
      end loop;

      if v_bright_run then
        v_candidate := true;
        if v_bright_score > v_best_score then
          v_best_score := v_bright_score;
        end if;
      end if;

      if v_dark_run then
        v_candidate := true;
        if v_dark_score > v_best_score then
          v_best_score := v_dark_score;
        end if;
      end if;
    end loop;

    if v_candidate then
      if v_best_score > integer(C_SCORE_MAX) then
        v_best_score := integer(C_SCORE_MAX);
      end if;
      o_is_candidate <= '1';
      o_score <= std_logic_vector(to_unsigned(v_best_score, o_score'length));
    else
      o_is_candidate <= '0';
      o_score <= (others => '0');
    end if;
  end process;
end architecture;
