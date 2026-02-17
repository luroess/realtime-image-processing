library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity E_FastNms3x3 is
  -- TODO(entity-contract): Document strict local-maximum policy (center must be greater than all neighbors) in the module interface notes for scoreboard parity.
  generic (
    G_SCORE_WIDTH : positive := 13
  );
  port (
    i_score_window : in  std_logic_vector((3 * 3 * G_SCORE_WIDTH) - 1 downto 0);
    o_corner       : out std_logic
  );
end entity;

architecture A_Rtl of E_FastNms3x3 is
  function f_score_at(
    i_window_flat : std_logic_vector;
    i_score_index : natural
  ) return unsigned is
    -- FIXME(bounds-safety): Add index range guarding before slicing so accidental caller misalignment cannot produce silent invalid reads.
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
  P_COMB_NMS: process(i_score_window)
    -- TODO(nms-config): Promote tie-handling behavior to a generic if future variants need >= or deterministic winner selection.
    variable v_center : unsigned(G_SCORE_WIDTH - 1 downto 0);
    variable v_corner : std_logic;
  begin
    -- FIXME(center-index): Keep center index hard-coded to window position 4 only while kernel size remains 3x3; update alongside any kernel change.
    v_center := f_score_at(i_score_window, 4);
    v_corner := '0';

    if v_center /= 0 then
      v_corner := '1';
      for i in 0 to 8 loop
        if i /= 4 then
          if f_score_at(i_score_window, i) >= v_center then
            v_corner := '0';
          end if;
        end if;
      end loop;
    end if;

    -- TODO(output-map): Preserve the final output assignment at process end so waveform inspection has a single handoff point.
    o_corner <= v_corner;
  end process;
end architecture;
