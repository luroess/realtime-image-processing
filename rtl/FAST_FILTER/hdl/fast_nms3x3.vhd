library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

--============================================================================
-- E_FastNms3x3
-- ----------------------------------------------------------------------------
-- 3x3 non-maximum suppression stage for FAST score maps.
--
-- Functional summary:
-- - Input is a flattened 3x3 window of FAST scores (center + 8 neighbors).
-- - Output o_corner is asserted only when:
--   1) center score is non-zero, and
--   2) center score is strictly greater than every neighbor.
--
-- This strict '>' policy suppresses ties intentionally.
--============================================================================
entity E_FastNms3x3 is
  generic (
    -- Bit width of each score element in i_score_window.
    G_SCORE_WIDTH : positive := 13
  );
  port (
    -- Flattened 3x3 score window in row-major order.
    -- Index mapping: 0..8 with center at index 4.
    i_score_window : in  std_logic_vector((3 * 3 * G_SCORE_WIDTH) - 1 downto 0);
    -- Binary corner mask output: '1' for strict local maxima, else '0'.
    o_corner       : out std_logic
  );
end entity;

architecture A_Rtl of E_FastNms3x3 is

  --==========================================================================
  -- f_score_at
  -- -------------------------------------------------------------------------
  -- Extract one score value from flattened 3x3 score window.
  --
  -- Inputs:
  -- - i_window_flat: flattened score vector (row-major).
  -- - i_score_index: score index in range 0..8.
  --
  -- Return:
  -- - score slice as unsigned(G_SCORE_WIDTH-1 downto 0).
  --
  -- Behavior:
  -- - Asserts when i_score_index is out of range.
  --==========================================================================
  function f_score_at(
      i_window_flat : std_logic_vector;
      i_score_index : natural
    ) return unsigned is
    variable v_lsb : natural;
    variable v_msb : natural;
  begin
    assert i_score_index < (i_window_flat'length / G_SCORE_WIDTH)
      report "E_FastNms3x3.f_score_at index out of range."
      severity failure;
    v_lsb := i_score_index * G_SCORE_WIDTH;
    v_msb := v_lsb + G_SCORE_WIDTH - 1;
    return unsigned(i_window_flat(v_msb downto v_lsb));
  end function;

begin

  --==========================================================================
  -- P_COMB_NMS
  -- -------------------------------------------------------------------------
  -- Combinational strict-NMS decision for one 3x3 neighborhood.
  --==========================================================================
  P_COMB_NMS: process (i_score_window)
    -- Center score at index 4 and staged output flag.
    variable v_center : unsigned(G_SCORE_WIDTH - 1 downto 0);
    variable v_corner : std_logic;
  begin
    -- Row-major center index for 3x3 window.
    v_center := f_score_at(i_score_window, 4);
    v_corner := '0';

    if v_center /= 0 then
      -- Tentatively accept center, then invalidate on any >= neighbor.
      v_corner := '1';
      for i in 0 to 8 loop
        if i /= 4 then
          if f_score_at(i_score_window, i) >= v_center then
            v_corner := '0';
          end if;
        end if;
      end loop;
    end if;

    -- Single-point output assignment for deterministic debug traces.
    o_corner <= v_corner;
  end process;

end architecture;
