library ieee;
  use ieee.std_logic_1164.all;

entity AXI_FrameCompositor is
  generic (
    -- 8-bit components are required by the current c_shift_ram payload mapping.
    G_COMPONENT_WIDTH           : positive                      := 8;
    -- Overlay color used for Sobel mask hits.
    G_EDGE_COLOR                : std_logic_vector(23 downto 0) := x"FF0000";
    -- Stream geometry used to derive stage delays in beat domain.
    G_LINE_WIDTH                : positive                      := 1280;
    -- Odd kernel sizes used by sobel and blur stages in the active pipeline.
    G_SOBEL_KERNEL_SIZE         : positive                      := 3;
    G_BLUR_KERNEL_SIZE          : positive                      := 3;
    -- 0 => use the auto-derived stage delays from line width + kernel sizes.
    G_SOBEL_DELAY_OVERRIDE      : natural                       := 0;
    G_BLUR_SOBEL_DELAY_OVERRIDE : natural                       := 0
  );
  port (
    -- Global AXI clock/reset domain.
    i_aclk                     : in  std_logic;
    i_aresetn                  : in  std_logic;
    -- Overlay control: force binary-only output.
    i_overlay_zeros            : in  std_logic;
    -- Selects which delay tap aligns the RGB base with the gray mask timing.
    i_base_delay_stage_sel     : in  std_logic_vector(1 downto 0);

    -- s_axis_video_rbg888: AXI4-Stream Video from RGB2GRAY, color RBG if o_pass_grayscale='1', else gray8 replicated.
    s_axis_video_rbg888_tvalid : in  std_logic;
    s_axis_video_rbg888_tready : out std_logic;
    s_axis_video_rbg888_tdata  : in  std_logic_vector((3 * G_COMPONENT_WIDTH) - 1 downto 0);
    s_axis_video_rbg888_tuser  : in  std_logic;
    s_axis_video_rbg888_tlast  : in  std_logic;

    -- s_axis_video_gray8_* : AXI4-Stream Video processed gray stream (timing reference + edge mask).
    s_axis_video_gray8_tvalid  : in  std_logic;
    s_axis_video_gray8_tready  : out std_logic;
    s_axis_video_gray8_tdata   : in  std_logic_vector(G_COMPONENT_WIDTH - 1 downto 0);
    s_axis_video_gray8_tuser   : in  std_logic;
    s_axis_video_gray8_tlast   : in  std_logic;

    -- m_axis_video_rbg888_* : AXI4-Stream Video output stream (composited RGB24 + gray-timed SOF/EOL).
    m_axis_video_rbg888_tvalid : out std_logic;
    m_axis_video_rbg888_tready : in  std_logic;
    m_axis_video_rbg888_tdata  : out std_logic_vector((3 * G_COMPONENT_WIDTH) - 1 downto 0);
    m_axis_video_rbg888_tuser  : out std_logic;
    m_axis_video_rbg888_tlast  : out std_logic
  );
end entity;

architecture A_Rtl of AXI_FrameCompositor is
  constant C_DELAY_SEL_NONE       : std_logic_vector(1 downto 0) := "00";
  constant C_DELAY_SEL_SOBEL      : std_logic_vector(1 downto 0) := "01";
  constant C_DELAY_SEL_BLUR_SOBEL : std_logic_vector(1 downto 0) := "10";
  constant C_DELAY_SEL_RESERVED   : std_logic_vector(1 downto 0) := "11";

  constant C_GRAY_ZERO       : std_logic_vector(G_COMPONENT_WIDTH - 1 downto 0) := (others => '0');
  constant C_BASE_WORD_WIDTH : positive                                         := (3 * G_COMPONENT_WIDTH) + 2;
  constant C_BLOCK_DELAY     : positive                                         := 1024;

  -- Helper used to determine how many 1024-beat storage chunks are required
  -- for a requested aggregate delay.
  function f_ceil_div(i_a : positive; i_b : positive) return positive is
  begin
    return (i_a + i_b - 1) / i_b;
  end function;

  -- Beat-domain warm-up delay for an odd KxK windowing stage.
  function f_stage_delay(i_line_width : positive; i_kernel_size : positive) return positive is
  begin
    return (i_line_width + 1) * ((i_kernel_size - 1) / 2);
  end function;

  -- Select explicit override when present, otherwise use the auto-derived delay.
  function f_resolve_delay(i_override : natural; i_auto : positive) return positive is
  begin
    if i_override > 0 then
      return i_override;
    end if;
    return i_auto;
  end function;

  -- Max helper for sizing the validity conveyor to the deepest selected tap.
  function f_max(i_a : positive; i_b : positive) return positive is
  begin
    if i_a >= i_b then
      return i_a;
    end if;
    return i_b;
  end function;

  -- Auto-derived stage delays from configured line width and kernel sizes.
  constant C_SOBEL_DELAY_AUTO      : positive := f_stage_delay(G_LINE_WIDTH, G_SOBEL_KERNEL_SIZE);
  constant C_BLUR_DELAY_AUTO       : positive := f_stage_delay(G_LINE_WIDTH, G_BLUR_KERNEL_SIZE);
  constant C_BLUR_SOBEL_DELAY_AUTO : positive := C_SOBEL_DELAY_AUTO + C_BLUR_DELAY_AUTO;

  -- Resolved delay taps used by ShiftRamChain.
  constant C_SOBEL_DELAY      : positive := f_resolve_delay(G_SOBEL_DELAY_OVERRIDE, C_SOBEL_DELAY_AUTO);
  constant C_BLUR_SOBEL_DELAY : positive := f_resolve_delay(G_BLUR_SOBEL_DELAY_OVERRIDE, C_BLUR_SOBEL_DELAY_AUTO);

  -- Number of cascaded 1024-beat c_shift_ram chunks for each requested tap.
  constant C_SOBEL_CHUNKS : positive := f_ceil_div(C_SOBEL_DELAY, C_BLOCK_DELAY);
  -- Additional beats needed to extend sobel tap to blur+sobel tap.
  constant C_EXTRA_DELAY : natural := C_BLUR_SOBEL_DELAY - C_SOBEL_DELAY;
  -- Extra c_shift_ram chunks required for the blur extension segment.
  constant C_EXTRA_CHUNKS : natural := (C_EXTRA_DELAY + C_BLOCK_DELAY - 1) / C_BLOCK_DELAY;
  -- Total cascaded chunks from RGB input to blur+sobel delay tap.
  constant C_TOTAL_CHUNKS : positive := C_SOBEL_CHUNKS + C_EXTRA_CHUNKS;

  -- The generated c_shift_ram_0 introduces one extra cycle per cascaded stage
  -- beyond the first stage (Register Last Bit enabled).
  constant C_SOBEL_DELAY_EFFECTIVE      : positive := C_SOBEL_DELAY + (C_SOBEL_CHUNKS - 1);
  constant C_BLUR_SOBEL_DELAY_EFFECTIVE : positive := C_BLUR_SOBEL_DELAY + (C_TOTAL_CHUNKS - 1);
  constant C_MAX_DELAY_EFFECTIVE        : positive := f_max(C_SOBEL_DELAY_EFFECTIVE, C_BLUR_SOBEL_DELAY_EFFECTIVE);

  -- Control-derived mode helper: merge path consumes delayed RGB base.
  signal s_need_rgb : std_logic := '0';
  -- Internal gray-stream READY used for local handshake checks (avoid reading OUT port).
  signal s_axis_video_gray8_tready_i : std_logic := '0';
  -- Output-valid gate: gray reference valid and required RGB tap prefilled.
  signal s_required_valid : std_logic := '0';
  -- Decoded mask bit from gray stream and binary RGB replacement payload.
  signal s_mask_edge  : std_logic                                              := '0';
  signal s_binary_rgb : std_logic_vector((3 * G_COMPONENT_WIDTH) - 1 downto 0) := (others => '0');
  -- FrameCompositor mixed RGB output and backpressure-propagated base READY.
  signal s_out_rgb            : std_logic_vector((3 * G_COMPONENT_WIDTH) - 1 downto 0) := (others => '0');
  signal s_axis_rbg888_tready : std_logic                                              := '0';

  -- Packed RGB input beat ({SOF,EOL,RGB24}) and delayed tap word.
  signal s_base_word_in      : std_logic_vector(25 downto 0) := (others => '0');
  signal s_base_word_delayed : std_logic_vector(25 downto 0) := (others => '0');
  -- Unpacked delayed base components used by overlay composer.
  signal s_base_delayed_rgb : std_logic_vector((3 * G_COMPONENT_WIDTH) - 1 downto 0) := (others => '0');
  signal s_base_delayed_sof : std_logic                                              := '0';
  signal s_base_delayed_eol : std_logic                                              := '0';
  -- Accepted base beat pulse driving delay RAM clock-enable.
  signal s_base_accept : std_logic := '0';
  -- Explicit reset helper to satisfy strict simulator static-expression rules.
  signal s_sclr : std_logic := '0';

  -- Beat-domain validity conveyor and selected delayed tap-valid bit.
  signal s_base_valid_pipe    : std_logic_vector(C_MAX_DELAY_EFFECTIVE downto 0) := (others => '0');
  signal s_base_delayed_valid : std_logic                                        := '0';
  -- Indicates merge path can consume in lockstep without underrunning delayed base.
  signal s_prefill_done : std_logic := '0';
  -- Prevent selector warnings from flooding logs while selector stays invalid.
  signal s_invalid_sel_warned : std_logic := '0';
  -- Simulation-only guard for unlatched runtime control toggles.
  signal s_midframe_ctrl_warned : std_logic                    := '0';
  signal s_overlay_zeros_sof    : std_logic                    := '1';
  signal s_delay_sel_sof        : std_logic_vector(1 downto 0) := C_DELAY_SEL_NONE;
begin
  assert C_BASE_WORD_WIDTH = 26
    report "AXI_FrameCompositor requires 26-bit base packing (TUSER/TLAST/RGB24) for c_shift_ram_0."
    severity failure;
  assert G_COMPONENT_WIDTH = 8
    report "AXI_FrameCompositor with c_shift_ram_0 integration currently requires G_COMPONENT_WIDTH=8."
    severity failure;
  assert (G_SOBEL_KERNEL_SIZE mod 2) = 1 and G_SOBEL_KERNEL_SIZE >= 3
    report "AXI_FrameCompositor requires odd G_SOBEL_KERNEL_SIZE >= 3 for delay derivation."
    severity failure;
  assert (G_BLUR_KERNEL_SIZE mod 2) = 1 and G_BLUR_KERNEL_SIZE >= 3
    report "AXI_FrameCompositor requires odd G_BLUR_KERNEL_SIZE >= 3 for delay derivation."
    severity failure;
  assert C_BLUR_SOBEL_DELAY >= C_SOBEL_DELAY
    report "AXI_FrameCompositor requires blur+sobel delay >= sobel delay."
    severity failure;

  s_sclr <= not i_aresetn;

  U_ShiftRamChain: entity work.ShiftRamChain
    generic map (
      G_SOBEL_DELAY      => C_SOBEL_DELAY,
      G_BLUR_SOBEL_DELAY => C_BLUR_SOBEL_DELAY
    )
    port map (
      i_clk                  => i_aclk,
      i_ce                   => s_base_accept,
      i_sclr                 => s_sclr,
      i_base_delay_stage_sel => i_base_delay_stage_sel,
      i_din                  => s_base_word_in,
      o_dout                 => s_base_word_delayed
    );

  U_FrameCompositor: entity work.FrameCompositor
    generic map (
      G_COMPONENT_WIDTH => G_COMPONENT_WIDTH,
      G_EDGE_COLOR      => G_EDGE_COLOR
    )
    port map (
      i_rgb888    => s_base_delayed_rgb,
      i_edge_mask => s_mask_edge,
      o_rgb888    => s_out_rgb
    );

  -- Merge path needs RGB only when binary-only mode is off.
  s_need_rgb <= '1' when i_overlay_zeros = '0' else
                '0';

  -- ShiftRamChain is intentionally reset-only (i_sclr <- not i_aresetn). Frame
  -- boundaries are handled through validity/SOF alignment, not per-frame RAM clear.
  P_ASSERT_CTRL_STABLE_WITHIN_FRAME: process (i_aclk)
  begin
    if rising_edge(i_aclk) then
      if i_aresetn = '0' then
        s_midframe_ctrl_warned <= '0';
        s_overlay_zeros_sof <= '1';
        s_delay_sel_sof <= C_DELAY_SEL_NONE;
      elsif (s_axis_video_gray8_tvalid = '1') and (s_axis_video_gray8_tready_i = '1') then
        if s_axis_video_gray8_tuser = '1' then
          -- SOF defines the legal control-change boundary.
          s_overlay_zeros_sof <= i_overlay_zeros;
          s_delay_sel_sof <= i_base_delay_stage_sel;
          s_midframe_ctrl_warned <= '0';
        elsif (
            (i_overlay_zeros /= s_overlay_zeros_sof) or (i_base_delay_stage_sel /= s_delay_sel_sof)
          ) then
          if s_midframe_ctrl_warned = '0' then
            assert false
              report "AXI_FrameCompositor: control input changed mid-frame; latch controls at input SOF to avoid mode tearing or prefill deadlock."
              severity warning;
            s_midframe_ctrl_warned <= '1';
          end if;
        end if;
      end if;
    end if;
  end process;

  -- Pack SOF/EOL + RGB24 to match the fixed 26-bit c_shift_ram_0 contract.
  s_base_word_in             <= s_axis_video_rbg888_tuser & s_axis_video_rbg888_tlast & s_axis_video_rbg888_tdata;
  s_base_accept              <= s_axis_video_rbg888_tvalid and s_axis_rbg888_tready;
  s_axis_video_rbg888_tready <= s_axis_rbg888_tready;

  s_base_delayed_sof <= s_base_word_delayed(25);
  s_base_delayed_eol <= s_base_word_delayed(24);
  s_base_delayed_rgb <= s_base_word_delayed(23 downto 0);

  -- Tracks delayed-base validity at each potential delay tap.
  -- This is a beat-domain validity conveyor clocked only on accepted RGB beats
  -- (s_base_accept), so tap-valid tracks data movement through ShiftRamChain.
  P_REG_BASE_VALID_DELAY: process (i_aclk)
  begin
    if rising_edge(i_aclk) then
      if i_aresetn = '0' then
        s_base_valid_pipe <= (others => '0');
      elsif s_base_accept = '1' then
        if (s_axis_video_rbg888_tuser = '1') and (s_base_delayed_valid = '0') then
          -- If the selected tap is not yet valid at accepted SOF, start a fresh
          -- prefill window for this frame.
          s_base_valid_pipe(0) <= '1';
          for i in 1 to C_MAX_DELAY_EFFECTIVE loop
            s_base_valid_pipe(i) <= '0';
          end loop;
        else
          -- Mark newly accepted input as valid at stage 0, then advance prior
          -- validity through every delayed stage.
          s_base_valid_pipe(0) <= '1';
          for i in 1 to C_MAX_DELAY_EFFECTIVE loop
            s_base_valid_pipe(i) <= s_base_valid_pipe(i - 1);
          end loop;
        end if;
      end if;
    end if;
  end process;

  -- Select validity tap matching currently selected delay stage.
  -- Reserved selector "11" aliases to Sobel tap.
  s_base_delayed_valid <= s_base_valid_pipe(C_SOBEL_DELAY_EFFECTIVE)      when i_base_delay_stage_sel = C_DELAY_SEL_SOBEL else
                          s_base_valid_pipe(C_BLUR_SOBEL_DELAY_EFFECTIVE) when i_base_delay_stage_sel = C_DELAY_SEL_BLUR_SOBEL else
                          s_base_valid_pipe(C_SOBEL_DELAY_EFFECTIVE)      when i_base_delay_stage_sel = C_DELAY_SEL_RESERVED else
                          s_axis_video_rbg888_tvalid                      when i_base_delay_stage_sel = C_DELAY_SEL_NONE else
                          s_axis_video_rbg888_tvalid;

  P_ASSERT_VALID_DELAY_SEL: process (i_aclk)
  begin
    if rising_edge(i_aclk) then
      if i_aresetn = '0' then
        s_invalid_sel_warned <= '0';
      elsif (s_axis_video_gray8_tvalid = '1') and (s_axis_video_gray8_tready_i = '1') then
        if i_base_delay_stage_sel = C_DELAY_SEL_RESERVED then
          if s_invalid_sel_warned = '0' then
            assert false
              report "AXI_FrameCompositor: i_base_delay_stage_sel=11 is reserved; falling back to Sobel delay tap."
              severity warning;
            s_invalid_sel_warned <= '1';
          end if;
        elsif not (
            (i_base_delay_stage_sel = C_DELAY_SEL_NONE) or (i_base_delay_stage_sel = C_DELAY_SEL_SOBEL) or (i_base_delay_stage_sel = C_DELAY_SEL_BLUR_SOBEL)
          ) then
          if s_invalid_sel_warned = '0' then
            assert false
              report "AXI_FrameCompositor: i_base_delay_stage_sel has unsupported encoding; falling back to bypass semantics."
              severity warning;
            s_invalid_sel_warned <= '1';
          end if;
        else
          s_invalid_sel_warned <= '0';
        end if;
      end if;
    end if;
  end process;

  -- Merge mode can start only once delayed-base tap has valid data.
  s_prefill_done <= '1' when (s_need_rgb = '0') or (s_base_delayed_valid = '1') else
                    '0';

  -- Gray stream drives output timing.
  -- Keep READY high while gray TVALID='0' so upstream pipelines can prefill
  -- RGB delay RAM without combinational tready deadlock.
  s_axis_video_gray8_tready_i <= '0'                        when i_aresetn = '0' else
                                 m_axis_video_rbg888_tready when s_need_rgb = '0' else
                                 '1'                        when s_axis_video_gray8_tvalid = '0' else
                                   (m_axis_video_rbg888_tready and s_prefill_done);
  s_axis_video_gray8_tready <= s_axis_video_gray8_tready_i;

  -- In binary-only mode (s_need_rgb='0'), always drain RGB input so upstream
  -- forked producers cannot deadlock while gray path is warming up.
  -- In merge mode, prefill base delay RAM first. After prefill, consume base
  -- in lockstep with gray output acceptance.
  -- Once prefill is done, stop advancing RGB while gray is idle so SOF/EOL
  -- remain aligned at the selected delay tap.
  s_axis_rbg888_tready <= '0' when i_aresetn = '0' else
                          '1' when s_need_rgb = '0' else
                          '1' when s_prefill_done = '0' else
                            (m_axis_video_rbg888_tready and s_axis_video_gray8_tvalid);

  s_required_valid <= s_axis_video_gray8_tvalid and (s_base_delayed_valid or (not s_need_rgb));

  -- Non-zero grayscale values mark foreground/edge mask pixels.
  s_mask_edge <= '1' when s_axis_video_gray8_tdata /= C_GRAY_ZERO else
                 '0';
  s_binary_rgb <= (others => '1') when s_mask_edge = '1' else
                   (others => '0');

  -- Output sideband timing follows the gray reference stream when a valid merged/binary pixel is emitted.
  m_axis_video_rbg888_tvalid <= '0' when i_aresetn = '0' else s_required_valid;
  m_axis_video_rbg888_tdata  <= s_binary_rgb when (i_aresetn = '1' and s_required_valid = '1' and i_overlay_zeros = '1') else
                                s_out_rgb    when (i_aresetn = '1' and s_required_valid = '1') else
                                  (others => '0');
  m_axis_video_rbg888_tuser <= s_axis_video_gray8_tuser when (i_aresetn = '1' and s_required_valid = '1') else
                               '0';
  m_axis_video_rbg888_tlast <= s_axis_video_gray8_tlast when (i_aresetn = '1' and s_required_valid = '1') else
                               '0';

  -- Simulation guard:
  -- while merge mode emits accepted output beats, delayed-base SOF/EOL must
  -- align exactly with gray reference SOF/EOL used for output sidebands.
  P_ASSERT_ALIGN: process (i_aclk)
  begin
    if rising_edge(i_aclk) then
      if i_aresetn = '1' then
        if (s_need_rgb = '1') and (s_required_valid = '1') and (m_axis_video_rbg888_tready = '1') then
          assert s_axis_video_gray8_tuser = s_base_delayed_sof
            report "AXI_FrameCompositor: SOF mismatch between gray and delayed RGB streams while RGB base mode is active."
            severity warning;
          assert s_axis_video_gray8_tlast = s_base_delayed_eol
            report "AXI_FrameCompositor: EOL mismatch between gray and delayed RGB streams while RGB base mode is active."
            severity warning;
        end if;
      end if;
    end if;
  end process;
end architecture;
