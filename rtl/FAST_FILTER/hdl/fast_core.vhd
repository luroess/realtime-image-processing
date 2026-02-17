library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity E_FastCore is
  -- TODO(entity-contract): Document the exact FAST-16 index mapping and score saturation contract in module docs so integration scoreboards can assert identical behavior.
  generic (
    G_PIXEL_WIDTH    : positive := 8;
    G_KERNEL_SIZE    : positive := 7;
    G_FAST_THRESHOLD : natural  := 20;
    G_FAST_N         : positive := 9
  );
  port (
    i_window       : in  std_logic_vector((G_KERNEL_SIZE * G_KERNEL_SIZE * G_PIXEL_WIDTH) - 1 downto 0);
    o_is_candidate : out std_logic;
    o_score        : out std_logic_vector(12 downto 0)
  );
end entity;

architecture A_Rtl of E_FastCore is
  -- TODO(type-cleanup): Move shared FAST/NMS helper types into a package when additional corner detectors are added so this entity stays focused on datapath logic.
  type t_ring_index_t is array (0 to 15) of natural;
  type t_precheck_index_t is array (0 to 3) of natural;
  type t_ring_value_t is array (0 to 15) of integer;
  type state_t is (
    ST_INIT,
    ST_LOAD_RING,
    ST_PRECHECK,
    ST_START_INIT,
    ST_OFFSET_EVAL,
    ST_COMMIT_RUN,
    ST_NEXT_START,
    ST_FINISH,
    ST_DONE
  );

  -- TODO(index-validation): Keep this ring order aligned with the Python reference FAST_RING_OFFSETS and add a cross-check test whenever index order changes.
  -- FAST-16 circle indices for a 7x7 row-major window.
  constant C_RING_INDEX : t_ring_index_t := (
    3, 4, 12, 20, 27, 34, 40, 46,
    45, 44, 36, 28, 21, 14, 8, 2
  );
  -- FIXME(precheck-coupling): Update this precheck table together with f_precheck_required thresholds; mismatched tuning can silently drop true corners.
  -- High-speed test points: 1, 9, 5, 13 (1-based FAST notation).
  constant C_PRECHECK_INDEX : t_precheck_index_t := (0, 8, 4, 12);
  constant C_RING_POINTS : natural := 16;
  constant C_MAX_FSM_STEPS : natural := 400;

  function f_precheck_required(i_fast_n : positive) return natural is
    -- TODO(precheck-coverage): Add simulation assertions for every supported G_FAST_N bin so precheck pruning remains equivalent to golden model expectations.
  begin
    if i_fast_n >= 16 then
      return 4;
    end if;

    if i_fast_n >= 12 then
      return 3;
    end if;

    if i_fast_n >= 8 then
      return 2;
    end if;

    if i_fast_n >= 4 then
      return 1;
    end if;

    return 0;
  end function;

  constant C_PRECHECK_REQUIRED : natural := f_precheck_required(G_FAST_N);

  function f_pixel_at(
      i_window_flat : std_logic_vector;
      i_pixel_index : natural
    ) return integer is
    -- FIXME(bounds-safety): Guard i_pixel_index against out-of-range access before slicing to prevent undefined simulation behavior if caller assumptions drift.
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
  -- FIXME(generic-scope): Mirror these generic constraints in upstream wrappers/tests to fail early during integration, not only at this leaf.
  assert G_KERNEL_SIZE = 7
    report "E_FastCore requires G_KERNEL_SIZE=7."
    severity failure;
  assert G_PIXEL_WIDTH = 8
    report "E_FastCore requires G_PIXEL_WIDTH=8."
    severity failure;
  assert (G_FAST_N >= 1) and (G_FAST_N <= 16)
    report "E_FastCore requires 1 <= G_FAST_N <= 16."
    severity failure;

  P_COMB_FAST: process (i_window)
    -- TODO(fsm-refactor): Split this long combinational FSM into smaller helper procedures after functionality freeze to improve reviewability without altering timing intent.
    variable v_state           : state_t;
    variable v_ring            : t_ring_value_t;
    variable v_center          : integer;
    variable v_threshold       : integer;
    variable v_high_ref        : integer;
    variable v_low_ref         : integer;
    variable v_bright_precheck : natural range 0 to 4;
    variable v_dark_precheck   : natural range 0 to 4;
    variable v_candidate       : boolean;
    variable v_best_score      : integer;
    variable v_bright_run      : boolean;
    variable v_dark_run        : boolean;
    variable v_bright_score    : integer;
    variable v_dark_score      : integer;
    variable v_start_idx       : natural range 0 to C_RING_POINTS - 1;
    variable v_off_idx         : natural range 0 to C_RING_POINTS - 1;
    variable v_ring_idx        : natural range 0 to C_RING_POINTS - 1;
    variable v_value           : integer;
    variable v_is_candidate    : std_logic;
    variable v_score_out       : std_logic_vector(o_score'range);
  begin
    -- TODO(defaulting): Keep all output and control defaults centralized here so any newly added state cannot infer stale values.
    v_state := ST_INIT;
    v_is_candidate := '0';
    v_score_out := (others => '0');

    for i_step in 0 to C_MAX_FSM_STEPS loop
      exit when v_state = ST_DONE;

      case v_state is
        when ST_INIT =>
          -- FIXME(threshold-policy): Clamp policy is one-sided (>255 only); define and enforce full threshold policy in spec so host configuration cannot cause ambiguous behavior.
          v_center := f_pixel_at(i_window, 24);
          v_threshold := integer(G_FAST_THRESHOLD);
          if v_threshold > 255 then
            v_threshold := 255;
          end if;
          v_high_ref := v_center + v_threshold;
          v_low_ref := v_center - v_threshold;

          v_bright_precheck := 0;
          v_dark_precheck := 0;
          v_candidate := false;
          v_best_score := 0;
          v_start_idx := 0;
          v_off_idx := 0;
          v_bright_run := false;
          v_dark_run := false;
          v_bright_score := 0;
          v_dark_score := 0;

          v_state := ST_LOAD_RING;

        when ST_LOAD_RING =>
          -- TODO(ring-load-opt): Evaluate pre-decoding window slices once if synthesis reports this loop as a critical combinational fanout point.
          for i in 0 to C_RING_POINTS - 1 loop
            v_ring(i) := f_pixel_at(i_window, C_RING_INDEX(i));
          end loop;
          v_state := ST_PRECHECK;

        when ST_PRECHECK =>
          -- FIXME(precheck-false-negative): Re-tune precheck gates if field data shows missed corners; this branch is an intentional approximation that can reject valid candidates.
          for i in 0 to 3 loop
            v_value := v_ring(C_PRECHECK_INDEX(i));
            if v_value > v_high_ref then
              v_bright_precheck := v_bright_precheck + 1;
            end if;
            if v_value < v_low_ref then
              v_dark_precheck := v_dark_precheck + 1;
            end if;
          end loop;

          if (v_bright_precheck >= C_PRECHECK_REQUIRED) or (v_dark_precheck >= C_PRECHECK_REQUIRED) then
            v_state := ST_START_INIT;
          else
            v_state := ST_FINISH;
          end if;

        when ST_START_INIT =>
          -- TODO(run-init): Keep run accumulators explicitly reset in this state whenever scoring fields are extended to avoid bleed-through across starts.
          v_bright_run := true;
          v_dark_run := true;
          v_bright_score := 0;
          v_dark_score := 0;
          v_off_idx := 0;
          v_state := ST_OFFSET_EVAL;

        when ST_OFFSET_EVAL =>
          -- TODO(run-eval): Add optional debug counters around this section in simulation builds to localize contiguous-run failures quickly.
          v_ring_idx := (v_start_idx + v_off_idx) mod C_RING_POINTS;
          v_value := v_ring(v_ring_idx);

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

          if v_off_idx = G_FAST_N - 1 then
            v_state := ST_COMMIT_RUN;
          else
            v_off_idx := v_off_idx + 1;
            v_state := ST_OFFSET_EVAL;
          end if;

        when ST_COMMIT_RUN =>
          -- FIXME(score-meaning): Define whether score represents strongest bright/dark evidence or combined evidence; downstream ranking assumptions depend on this choice.
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

          v_state := ST_NEXT_START;

        when ST_NEXT_START =>
          -- TODO(scan-policy): Revisit start-index scan order only with paired scoreboard updates so candidate parity remains deterministic.
          if v_start_idx = C_RING_POINTS - 1 then
            v_state := ST_FINISH;
          else
            v_start_idx := v_start_idx + 1;
            v_state := ST_START_INIT;
          end if;

        when ST_FINISH =>
          -- FIXME(score-sat): Keep score saturation value synchronized with o_score width and testbench golden clipping to avoid truncation mismatches.
          if not v_candidate then
            v_best_score := 0;
            v_is_candidate := '0';
          else
            v_is_candidate := '1';
          end if;

          if v_best_score > 8191 then
            v_best_score := 8191;
          end if;
          v_score_out := std_logic_vector(to_unsigned(v_best_score, o_score'length));

          v_state := ST_DONE;

        when ST_DONE =>
          -- TODO(done-state): Keep ST_DONE side-effect free; any future additions should remain outside the termination guard.
          null;
      end case;
    end loop;

    -- TODO(output-map): Preserve single-point output assignments here so formal/property checks can target one deterministic mapping site.
    o_is_candidate <= v_is_candidate;
    o_score <= v_score_out;
  end process;
end architecture;
