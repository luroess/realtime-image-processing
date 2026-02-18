library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

  --============================================================================
  -- E_FastCore
  -- ----------------------------------------------------------------------------
  -- Combinational FAST-N corner candidate evaluator for a 7x7 grayscale window.
  --
  -- Functional summary:
  -- 1) Read center pixel and 16 ring samples (radius 3).
  -- 2) Apply FAST high-speed precheck on ring points {1, 9, 5, 13}.
  -- 3) Evaluate all 16 start positions for a contiguous run of length G_FAST_N.
  -- 4) Produce:
  --    - o_is_candidate: corner candidate flag
  --    - o_score       : strongest bright/dark run score (13-bit saturated)
  --
  -- Notes:
  -- - This block is purely combinational and intended to be wrapped by stream
  --   control logic in AXI_FastFilter.
  -- - Ring indexing and score semantics must stay aligned with the Python
  --   reference model in the testbench.
  --============================================================================

entity E_FastCore is
  generic (
    -- Bit width per grayscale pixel in i_window.
    -- Constrained to 8 by assertion below.
    G_PIXEL_WIDTH    : positive := 8;
    -- Sliding window width/height (KxK).
    -- Constrained to 7 by assertion below.
    G_KERNEL_SIZE    : positive := 7;
    -- FAST threshold t, used as:
    --   bright: ring > center + t
    --   dark  : ring < center - t
    -- Runtime-clamped to <= 255.
    G_FAST_THRESHOLD : natural  := 20;
    -- Required contiguous arc length N in FAST-N.
    -- Constrained to 1..16 by assertion below.
    G_FAST_N         : positive := 9
  );
  port (
    -- Flattened 7x7 grayscale window in row-major order.
    -- Pixel index = row * G_KERNEL_SIZE + col, LSB-packed per pixel.
    i_window       : in  std_logic_vector((G_KERNEL_SIZE * G_KERNEL_SIZE * G_PIXEL_WIDTH) - 1 downto 0);
    -- Corner candidate flag for the center pixel.
    -- '1' if at least one bright or dark contiguous run of length G_FAST_N
    -- exists on the ring.
    o_is_candidate : out std_logic;
    -- Corner score for non-maximum suppression.
    -- Score is max(bright_run_margin_sum, dark_run_margin_sum),
    -- saturated to 13 bits (0..8191).
    o_score        : out std_logic_vector(12 downto 0)
  );
end entity;

architecture A_Rtl of E_FastCore is
  -- Index table type for ring sample lookup.
  type t_ring_index_t is array (0 to 15) of natural;
  -- Index table type for high-speed precheck points.
  type t_precheck_index_t is array (0 to 3) of natural;
  -- Runtime container for ring sample values.
  type t_ring_value_t is array (0 to 15) of integer;
  -- Internal control states for the bounded combinational FSM.
  type state_t is (
      -- Load threshold/center and initialize accumulators.
      ST_INIT,
      -- Read all 16 ring samples from i_window.
      ST_LOAD_RING,
      -- FAST high-speed precheck.
      ST_PRECHECK,
      -- Reset per-start run accumulators.
      ST_START_INIT,
      -- Evaluate one offset of the current start position.
      ST_OFFSET_EVAL,
      -- Commit run result into candidate/score.
      ST_COMMIT_RUN,
      -- Advance to next start position.
      ST_NEXT_START,
      -- Finalize candidate flag and score output.
      ST_FINISH,
      -- Terminal state.
      ST_DONE
    );

  -- FAST-16 circle indices for a 7x7 row-major window (radius 3), ordered
  -- clockwise from the top pixel.
  constant C_RING_INDEX : t_ring_index_t := (
    3, 4, 12, 20, 27, 34, 40, 46,
    45, 44, 36, 28, 21, 14, 8, 2
  );
  -- High-speed precheck points in 0-based ring indexing:
  -- {1, 9, 5, 13} in FAST literature -> {0, 8, 4, 12} here.
  constant C_PRECHECK_INDEX : t_precheck_index_t := (0, 8, 4, 12);
  -- Number of points on FAST circle.
  constant C_RING_POINTS : natural := 16;
  -- Safety bound for combinational state-iteration loop.
  -- Keeps simulation deterministic even if state logic is modified later.
  constant C_MAX_FSM_STEPS : natural := 400;

  --==========================================================================
  -- f_precheck_required
  -- -------------------------------------------------------------------------
  -- Returns how many of the four high-speed precheck points must pass before
  -- full contiguous-run evaluation is performed.
  --
  -- Input:
  -- - i_fast_n: configured FAST arc length N.
  --
  -- Return:
  -- - required hit count in range 0..4.
  --
  -- Policy:
  -- - N >= 16 -> 4
  -- - N >= 12 -> 3
  -- - N >= 8  -> 2
  -- - N >= 4  -> 1
  -- - else    -> 0
  --==========================================================================
  function f_precheck_required(i_fast_n : positive) return natural is
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

  --==========================================================================
  -- f_pixel_at
  -- -------------------------------------------------------------------------
  -- Extracts one pixel from the flattened i_window vector and returns it as
  -- integer.
  --
  -- Inputs:
  -- - i_window_flat: flattened pixel array.
  -- - i_pixel_index: pixel index in row-major order.
  --
  -- Return:
  -- - pixel value converted from unsigned slice to integer.
  --
  -- Behavior:
  -- - Asserts on out-of-range index to fail fast in simulation.
  --==========================================================================
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
  -- Static guardrails: this implementation is intentionally fixed to FAST on
  -- 8-bit grayscale, 7x7 windows, and ring length 16.
  assert G_KERNEL_SIZE = 7
    report "E_FastCore requires G_KERNEL_SIZE=7."
    severity failure;
  assert G_PIXEL_WIDTH = 8
    report "E_FastCore requires G_PIXEL_WIDTH=8."
    severity failure;
  assert (G_FAST_N >= 1) and (G_FAST_N <= 16)
    report "E_FastCore requires 1 <= G_FAST_N <= 16."
    severity failure;

  --==========================================================================
  -- P_COMB_FAST
  -- -------------------------------------------------------------------------
  -- Bounded combinational state machine that evaluates FAST candidate+score.
  --
  -- Process contract:
  -- - Purely combinational over i_window.
  -- - Output defaults are assigned before evaluation.
  -- - Bounded loop protects against accidental non-terminating state edits.
  --==========================================================================
  P_COMB_FAST: process (i_window)
    -- State machine control variable.
    variable v_state : state_t;
    -- 16 ring sample values around center pixel.
    variable v_ring : t_ring_value_t;
    -- Center pixel and threshold-derived comparison references.
    variable v_center    : integer;
    variable v_threshold : integer;
    variable v_high_ref  : integer;
    variable v_low_ref   : integer;
    -- High-speed precheck hit counters.
    variable v_bright_precheck : natural range 0 to 4;
    variable v_dark_precheck   : natural range 0 to 4;
    -- Candidate and best score accumulators across all starts.
    variable v_candidate  : boolean;
    variable v_best_score : integer;
    -- Per-start contiguous-run status and score.
    variable v_bright_run   : boolean;
    variable v_dark_run     : boolean;
    variable v_bright_score : integer;
    variable v_dark_score   : integer;
    -- Ring traversal indices.
    variable v_start_idx : natural range 0 to C_RING_POINTS - 1;
    variable v_off_idx   : natural range 0 to C_RING_POINTS - 1;
    variable v_ring_idx  : natural range 0 to C_RING_POINTS - 1;
    -- Current ring sample under evaluation.
    variable v_value : integer;
    -- Process-local output staging variables.
    variable v_is_candidate : std_logic;
    variable v_score_out    : std_logic_vector(o_score'range);
  begin
    -- Default outputs for the non-candidate case.
    v_state := ST_INIT;
    v_is_candidate := '0';
    v_score_out := (others => '0');

    for i_step in 0 to C_MAX_FSM_STEPS loop
      exit when v_state = ST_DONE;

      case v_state is
        when ST_INIT =>
          -- Center pixel for 7x7 window is index 24 (row 3, col 3).
          v_center := f_pixel_at(i_window, 24);
          v_threshold := integer(G_FAST_THRESHOLD);
          -- Clamp threshold high-side to 8-bit domain.
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
          -- Materialize all ring samples once for subsequent checks.
          for i in 0 to C_RING_POINTS - 1 loop
            v_ring(i) := f_pixel_at(i_window, C_RING_INDEX(i));
          end loop;
          v_state := ST_PRECHECK;

        when ST_PRECHECK =>
          -- Cheap early rejection before full contiguous-arc evaluation.
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
          -- Initialize one candidate arc starting position.
          v_bright_run := true;
          v_dark_run := true;
          v_bright_score := 0;
          v_dark_score := 0;
          v_off_idx := 0;
          v_state := ST_OFFSET_EVAL;

        when ST_OFFSET_EVAL =>
          -- Evaluate one element in the current contiguous run window.
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
          -- Commit this start position's result into global best score.
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
          -- Scan all 16 start positions to cover wrap-around arcs.
          if v_start_idx = C_RING_POINTS - 1 then
            v_state := ST_FINISH;
          else
            v_start_idx := v_start_idx + 1;
            v_state := ST_START_INIT;
          end if;

        when ST_FINISH =>
          -- Emit final candidate flag and saturate score to 13-bit range.
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
          null;
      end case;
    end loop;

    -- Single-point output assignment for deterministic waveform/debug checks.
    o_is_candidate <= v_is_candidate;
    o_score <= v_score_out;
  end process;
end architecture;

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

--============================================================================
-- E_FastCoreSeq
-- ----------------------------------------------------------------------------
-- Sequential FAST-N evaluator for one 7x7 window at a time.
--
-- Compared to E_FastCore, this variant:
-- - accepts one input window only when idle,
-- - evaluates contiguous arcs across multiple clock cycles,
-- - emits one result beat with preserved sidebands (SOF/EOL).
--
-- This mode is intended for area/fmax trade-off experiments where the AXI
-- wrapper can apply backpressure while a window is under evaluation.
--============================================================================
entity E_FastCoreSeq is
  generic (
    G_PIXEL_WIDTH    : positive := 8;
    G_KERNEL_SIZE    : positive := 7;
    G_FAST_THRESHOLD : natural  := 20;
    G_FAST_N         : positive := 9
  );
  port (
    i_aclk          : in  std_logic;
    i_aresetn       : in  std_logic;

    s_window_tvalid : in  std_logic;
    s_window_tready : out std_logic;
    s_window_tdata  : in  std_logic_vector((G_KERNEL_SIZE * G_KERNEL_SIZE * G_PIXEL_WIDTH) - 1 downto 0);
    s_window_tuser  : in  std_logic;
    s_window_tlast  : in  std_logic;

    m_result_tvalid : out std_logic;
    m_result_tready : in  std_logic;
    m_result_tuser  : out std_logic;
    m_result_tlast  : out std_logic;
    m_is_candidate  : out std_logic;
    m_score         : out std_logic_vector(12 downto 0)
  );
end entity;

architecture A_Rtl of E_FastCoreSeq is
  type t_ring_index_t is array (0 to 15) of natural;
  type t_precheck_index_t is array (0 to 3) of natural;
  type t_ring_value_t is array (0 to 15) of integer range 0 to 255;

  type state_t is (
      ST_IDLE,
      ST_OFFSET_EVAL,
      ST_COMMIT_RUN,
      ST_OUTPUT
    );

  constant C_RING_INDEX : t_ring_index_t := (
    3, 4, 12, 20, 27, 34, 40, 46,
    45, 44, 36, 28, 21, 14, 8, 2
  );
  constant C_PRECHECK_INDEX : t_precheck_index_t := (0, 8, 4, 12);
  constant C_RING_POINTS : natural := 16;

  function f_precheck_required(i_fast_n : positive) return natural is
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
    variable v_lsb : natural;
    variable v_msb : natural;
  begin
    assert i_pixel_index < (i_window_flat'length / G_PIXEL_WIDTH)
      report "E_FastCoreSeq.f_pixel_at index out of range."
      severity failure;
    v_lsb := i_pixel_index * G_PIXEL_WIDTH;
    v_msb := v_lsb + G_PIXEL_WIDTH - 1;
    return to_integer(unsigned(i_window_flat(v_msb downto v_lsb)));
  end function;

  signal s_state : state_t := ST_IDLE;
  signal s_ring : t_ring_value_t := (others => 0);
  signal s_high_ref : integer := 0;
  signal s_low_ref  : integer := 0;

  signal s_start_idx : natural range 0 to C_RING_POINTS - 1 := 0;
  signal s_off_idx   : natural range 0 to C_RING_POINTS - 1 := 0;

  signal s_candidate : std_logic := '0';
  signal s_best_score : integer range 0 to 8191 := 0;

  signal s_bright_run : std_logic := '0';
  signal s_dark_run   : std_logic := '0';
  signal s_bright_score : integer range 0 to 8191 := 0;
  signal s_dark_score   : integer range 0 to 8191 := 0;

  signal s_out_candidate : std_logic := '0';
  signal s_out_score : std_logic_vector(12 downto 0) := (others => '0');
  signal s_out_tuser : std_logic := '0';
  signal s_out_tlast : std_logic := '0';
begin
  assert G_KERNEL_SIZE = 7
    report "E_FastCoreSeq requires G_KERNEL_SIZE=7."
    severity failure;
  assert G_PIXEL_WIDTH = 8
    report "E_FastCoreSeq requires G_PIXEL_WIDTH=8."
    severity failure;
  assert (G_FAST_N >= 1) and (G_FAST_N <= 16)
    report "E_FastCoreSeq requires 1 <= G_FAST_N <= 16."
    severity failure;

  s_window_tready <= '1' when (i_aresetn = '1' and s_state = ST_IDLE) else '0';
  m_result_tvalid <= '1' when (i_aresetn = '1' and s_state = ST_OUTPUT) else '0';
  m_result_tuser <= s_out_tuser;
  m_result_tlast <= s_out_tlast;
  m_is_candidate <= s_out_candidate;
  m_score <= s_out_score;

  P_REG_FAST_SEQ: process (i_aclk)
    variable v_threshold : integer;
    variable v_center : integer;
    variable v_high_ref : integer;
    variable v_low_ref : integer;
    variable v_precheck_value : integer;
    variable v_ring_idx : natural range 0 to C_RING_POINTS - 1;
    variable v_value : integer;
    variable v_bright_precheck : natural range 0 to 4;
    variable v_dark_precheck : natural range 0 to 4;
    variable v_has_candidate : boolean;
    variable v_best_score : integer;
  begin
    if rising_edge(i_aclk) then
      if i_aresetn = '0' then
        s_state <= ST_IDLE;
        s_ring <= (others => 0);
        s_high_ref <= 0;
        s_low_ref <= 0;
        s_start_idx <= 0;
        s_off_idx <= 0;
        s_candidate <= '0';
        s_best_score <= 0;
        s_bright_run <= '0';
        s_dark_run <= '0';
        s_bright_score <= 0;
        s_dark_score <= 0;
        s_out_candidate <= '0';
        s_out_score <= (others => '0');
        s_out_tuser <= '0';
        s_out_tlast <= '0';
      else
        case s_state is
          when ST_IDLE =>
            if s_window_tvalid = '1' then
              s_out_tuser <= s_window_tuser;
              s_out_tlast <= s_window_tlast;

              v_center := f_pixel_at(s_window_tdata, 24);
              v_threshold := integer(G_FAST_THRESHOLD);
              if v_threshold > 255 then
                v_threshold := 255;
              end if;

              v_high_ref := v_center + v_threshold;
              v_low_ref := v_center - v_threshold;
              s_high_ref <= v_high_ref;
              s_low_ref <= v_low_ref;

              for i in 0 to C_RING_POINTS - 1 loop
                s_ring(i) <= f_pixel_at(s_window_tdata, C_RING_INDEX(i));
              end loop;

              v_bright_precheck := 0;
              v_dark_precheck := 0;
              for i in 0 to 3 loop
                v_precheck_value := f_pixel_at(
                  s_window_tdata,
                  C_RING_INDEX(C_PRECHECK_INDEX(i))
                );
                if v_precheck_value > v_high_ref then
                  v_bright_precheck := v_bright_precheck + 1;
                end if;
                if v_precheck_value < v_low_ref then
                  v_dark_precheck := v_dark_precheck + 1;
                end if;
              end loop;

              s_start_idx <= 0;
              s_off_idx <= 0;
              s_candidate <= '0';
              s_best_score <= 0;
              s_bright_run <= '1';
              s_dark_run <= '1';
              s_bright_score <= 0;
              s_dark_score <= 0;

              if (v_bright_precheck >= C_PRECHECK_REQUIRED) or (v_dark_precheck >= C_PRECHECK_REQUIRED) then
                s_state <= ST_OFFSET_EVAL;
              else
                s_out_candidate <= '0';
                s_out_score <= (others => '0');
                s_state <= ST_OUTPUT;
              end if;
            end if;

          when ST_OFFSET_EVAL =>
            v_ring_idx := (s_start_idx + s_off_idx) mod C_RING_POINTS;
            v_value := s_ring(v_ring_idx);

            if (s_bright_run = '1') and (v_value > s_high_ref) then
              s_bright_score <= s_bright_score + (v_value - s_high_ref);
            else
              s_bright_run <= '0';
            end if;

            if (s_dark_run = '1') and (v_value < s_low_ref) then
              s_dark_score <= s_dark_score + (s_low_ref - v_value);
            else
              s_dark_run <= '0';
            end if;

            if s_off_idx = G_FAST_N - 1 then
              s_state <= ST_COMMIT_RUN;
            else
              s_off_idx <= s_off_idx + 1;
            end if;

          when ST_COMMIT_RUN =>
            v_has_candidate := (s_candidate = '1');
            v_best_score := s_best_score;

            if s_bright_run = '1' then
              v_has_candidate := true;
              if s_bright_score > v_best_score then
                v_best_score := s_bright_score;
              end if;
            end if;

            if s_dark_run = '1' then
              v_has_candidate := true;
              if s_dark_score > v_best_score then
                v_best_score := s_dark_score;
              end if;
            end if;

            if v_best_score > 8191 then
              v_best_score := 8191;
            end if;

            if s_start_idx = C_RING_POINTS - 1 then
              if v_has_candidate then
                s_out_candidate <= '1';
                s_out_score <= std_logic_vector(to_unsigned(v_best_score, s_out_score'length));
              else
                s_out_candidate <= '0';
                s_out_score <= (others => '0');
              end if;
              s_state <= ST_OUTPUT;
            else
              if v_has_candidate then
                s_candidate <= '1';
              else
                s_candidate <= '0';
              end if;
              s_best_score <= v_best_score;

              s_start_idx <= s_start_idx + 1;
              s_off_idx <= 0;
              s_bright_run <= '1';
              s_dark_run <= '1';
              s_bright_score <= 0;
              s_dark_score <= 0;
              s_state <= ST_OFFSET_EVAL;
            end if;

          when ST_OUTPUT =>
            if m_result_tready = '1' then
              s_state <= ST_IDLE;
            end if;
        end case;
      end if;
    end if;
  end process;
end architecture;
