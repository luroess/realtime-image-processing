library ieee;
  use ieee.std_logic_1164.all;

entity AXI_FastFilter is
  -- TODO(entity-contract): Document pipeline latency/warm-up expectations for the FAST+NMS chain so upstream scheduling and tests can account for flush beats.
  generic (
    G_PIXEL_WIDTH    : positive := 8;
    G_KERNEL_SIZE    : positive := 7;
    G_LINE_WIDTH     : positive := 1920;
    G_NUM_ROW        : positive := 1080;
    G_FAST_THRESHOLD : natural  := 20;
    G_FAST_N         : positive := 9;
    -- 1: combinational parallel core, 2: sequential multi-cycle core.
    G_FAST_IMPL      : positive := 1
  );
  port (
    i_aclk                : in  std_logic;
    i_aresetn             : in  std_logic;

    -- AXI4-Stream Video Slave (input: 7x7 gray window, flattened)
    s_axis_window_tvalid  : in  std_logic;
    s_axis_window_tready  : out std_logic;
    s_axis_window_tdata   : in  std_logic_vector((G_KERNEL_SIZE * G_KERNEL_SIZE * G_PIXEL_WIDTH) - 1 downto 0);
    s_axis_window_tuser   : in  std_logic;
    s_axis_window_tlast   : in  std_logic;

    -- AXI4-Stream Video Master (output: corner mask gray8)
    m_axis_filter8_tvalid : out std_logic;
    m_axis_filter8_tready : in  std_logic;
    m_axis_filter8_tdata  : out std_logic_vector(G_PIXEL_WIDTH - 1 downto 0);
    m_axis_filter8_tuser  : out std_logic;
    m_axis_filter8_tlast  : out std_logic
  );
end entity;

architecture A_Rtl of AXI_FastFilter is
  -- TODO(signal-ownership): Keep intermediate AXI channels grouped by stage naming (score/nms/output) to simplify future debug instrumentation.
  constant C_SCORE_WIDTH          : positive := 13;
  constant C_NMS_KERNEL_SIZE      : positive := 3;
  constant C_FAST_IMPL_PARALLEL   : positive := 1;
  constant C_FAST_IMPL_SEQUENTIAL : positive := 2;

  signal s_fast_candidate : std_logic                                    := '0';
  signal s_fast_score     : std_logic_vector(C_SCORE_WIDTH - 1 downto 0) := (others => '0');

  signal s_score_tvalid : std_logic                                    := '0';
  signal s_score_tready : std_logic                                    := '0';
  signal s_score_tdata  : std_logic_vector(C_SCORE_WIDTH - 1 downto 0) := (others => '0');
  signal s_score_tuser  : std_logic                                    := '0';
  signal s_score_tlast  : std_logic                                    := '0';

  signal s_nms_wndw_tvalid : std_logic                                                                              := '0';
  signal s_nms_wndw_tready : std_logic                                                                              := '0';
  signal s_nms_wndw_tdata  : std_logic_vector((C_NMS_KERNEL_SIZE * C_NMS_KERNEL_SIZE * C_SCORE_WIDTH) - 1 downto 0) := (others => '0');
  signal s_nms_wndw_tuser  : std_logic                                                                              := '0';
  signal s_nms_wndw_tlast  : std_logic                                                                              := '0';

  signal s_corner : std_logic := '0';
begin
  -- FIXME(generic-constraints): Mirror these hard constraints in higher-level wrappers and target metadata to fail fast before simulation/elaboration.
  assert G_KERNEL_SIZE = 7
    report "AXI_FastFilter requires G_KERNEL_SIZE=7."
    severity failure;
  assert G_PIXEL_WIDTH = 8
    report "AXI_FastFilter requires G_PIXEL_WIDTH=8."
    severity failure;
  assert (G_FAST_IMPL = C_FAST_IMPL_PARALLEL) or
         (G_FAST_IMPL = C_FAST_IMPL_SEQUENTIAL)
    report "AXI_FastFilter requires G_FAST_IMPL in {1,2}."
    severity failure;

  G_FastImplParallel: if G_FAST_IMPL = C_FAST_IMPL_PARALLEL generate
    U_FastCore: entity work.E_FastCore
    -- TODO(core-parity): Re-validate this mapping whenever FAST generics change to keep hardware and software golden parameters synchronized.
    generic map (
      G_PIXEL_WIDTH    => G_PIXEL_WIDTH,
      G_KERNEL_SIZE    => G_KERNEL_SIZE,
      G_FAST_THRESHOLD => G_FAST_THRESHOLD,
      G_FAST_N         => G_FAST_N
    ) port map (
      i_window       => s_axis_window_tdata,
      o_is_candidate => s_fast_candidate,
      o_score        => s_fast_score
    );

    -- FIXME(input-handshake): Re-check ready propagation under reset-deassert timing; incorrect gating can drop the first post-reset window beat.
    s_axis_window_tready <= '0' when i_aresetn = '0' else s_score_tready;

    -- TODO(score-stream): Keep score sideband forwarding strictly lockstep with input window stream to preserve SOF/EOL alignment.
    s_score_tvalid <= '0' when i_aresetn = '0' else s_axis_window_tvalid;
    s_score_tuser  <= '0' when i_aresetn = '0' else s_axis_window_tuser;
    s_score_tlast  <= '0' when i_aresetn = '0' else s_axis_window_tlast;
  end generate;

  G_FastImplSequential: if G_FAST_IMPL = C_FAST_IMPL_SEQUENTIAL generate
    U_FastCoreSeq: entity work.E_FastCoreSeq
    generic map (
      G_PIXEL_WIDTH    => G_PIXEL_WIDTH,
      G_KERNEL_SIZE    => G_KERNEL_SIZE,
      G_FAST_THRESHOLD => G_FAST_THRESHOLD,
      G_FAST_N         => G_FAST_N
    ) port map (
      i_aclk          => i_aclk,
      i_aresetn       => i_aresetn,
      s_window_tvalid => s_axis_window_tvalid,
      s_window_tready => s_axis_window_tready,
      s_window_tdata  => s_axis_window_tdata,
      s_window_tuser  => s_axis_window_tuser,
      s_window_tlast  => s_axis_window_tlast,
      m_result_tvalid => s_score_tvalid,
      m_result_tready => s_score_tready,
      m_result_tuser  => s_score_tuser,
      m_result_tlast  => s_score_tlast,
      m_is_candidate  => s_fast_candidate,
      m_score         => s_fast_score
    );
  end generate;

  s_score_tdata  <= s_fast_score when s_fast_candidate = '1' else
                      (others => '0');

  U_ScoreWindowGenerator: entity work.window_generator
  -- TODO(nms-windowing): If NMS kernel size changes, update this instance and paired test flush/warmup calculations in the same change.
  generic map (
    G_PIXEL_WIDTH => C_SCORE_WIDTH,
    G_KERNEL_SIZE => C_NMS_KERNEL_SIZE,
    G_LINE_WIDTH  => G_LINE_WIDTH,
    G_NUM_ROW     => G_NUM_ROW
  ) port map (
    i_aclk               => i_aclk,
    i_aresetn            => i_aresetn,
    s_axis_gray8_tvalid  => s_score_tvalid,
    s_axis_gray8_tready  => s_score_tready,
    s_axis_gray8_tdata   => s_score_tdata,
    s_axis_gray8_tuser   => s_score_tuser,
    s_axis_gray8_tlast   => s_score_tlast,
    m_axis_window_tvalid => s_nms_wndw_tvalid,
    m_axis_window_tready => s_nms_wndw_tready,
    m_axis_window_tdata  => s_nms_wndw_tdata,
    m_axis_window_tuser  => s_nms_wndw_tuser,
    m_axis_window_tlast  => s_nms_wndw_tlast
  );

  U_FastNms3x3: entity work.E_FastNms3x3
  -- FIXME(nms-coupling): Keep score width and non-zero corner policy aligned with E_FastNms3x3 and software reference to prevent ranking drift.
  generic map (
    G_SCORE_WIDTH => C_SCORE_WIDTH
  ) port map (
    i_score_window => s_nms_wndw_tdata,
    o_corner       => s_corner
  );

  -- TODO(output-backpressure): Preserve single backpressure control path here so READY behavior remains analyzable under stress tests.
  s_nms_wndw_tready <= '0' when i_aresetn = '0' else m_axis_filter8_tready;

  -- FIXME(output-encoding): Keep corner mask encoding contract (all-ones corner, all-zeros non-corner) documented and shared with integration consumers.
  m_axis_filter8_tvalid <= '0' when i_aresetn = '0' else s_nms_wndw_tvalid;
  m_axis_filter8_tuser  <= '0' when i_aresetn = '0' else s_nms_wndw_tuser;
  m_axis_filter8_tlast  <= '0' when i_aresetn = '0' else s_nms_wndw_tlast;
  m_axis_filter8_tdata  <= (others => '1') when (i_aresetn = '1' and s_nms_wndw_tvalid = '1' and s_corner = '1') else
                            (others => '0');
end architecture;
