library ieee;
  use ieee.std_logic_1164.all;

  -- ============================================================================
  -- AXI_FastFilter
  -- ----------------------------------------------------------------------------
  -- AXI4-Stream wrapper around E_FastCore.
  --
  -- Input contract:
  -- - 7x7 grayscale window stream from WINDOW_GENERATOR.
  --
  -- Output contract:
  -- - Binary gray8 mask stream:
  --   255 = FAST candidate, 0 = not a candidate.
  -- - SOF/TUSER and EOL/TLAST are forwarded one-to-one.
  --
  -- Cleaned-up scope:
  -- - Parallel FAST core only.
  -- - No NMS stage.
  -- ============================================================================

entity AXI_FastFilter is
  generic (
    G_PIXEL_WIDTH     : positive := 8;
    G_KERNEL_SIZE     : positive := 7;
    G_LINE_WIDTH      : positive := 1920;
    G_NUM_ROW         : positive := 1080;
    G_FAST_THRESHOLD  : natural  := 20;
    G_FAST_N          : positive := 9;

    -- Kept for compatibility with existing wrapper/target generic maps.
    -- This cleaned implementation supports only:
    -- - G_FAST_ENABLE_NMS = 0
    -- - G_FAST_IMPL = 1
    G_FAST_ENABLE_NMS : natural  := 0;
    G_FAST_IMPL       : positive := 1
  );
  port (
    i_aclk                : in  std_logic;
    i_aresetn             : in  std_logic;

    -- AXI4-Stream input: flattened 7x7 gray window.
    s_axis_window_tvalid  : in  std_logic;
    s_axis_window_tready  : out std_logic;
    s_axis_window_tdata   : in  std_logic_vector((G_KERNEL_SIZE * G_KERNEL_SIZE * G_PIXEL_WIDTH) - 1 downto 0);
    s_axis_window_tuser   : in  std_logic;
    s_axis_window_tlast   : in  std_logic;

    -- AXI4-Stream output: binary gray8 corner mask.
    m_axis_filter8_tvalid : out std_logic;
    m_axis_filter8_tready : in  std_logic;
    m_axis_filter8_tdata  : out std_logic_vector(G_PIXEL_WIDTH - 1 downto 0);
    m_axis_filter8_tuser  : out std_logic;
    m_axis_filter8_tlast  : out std_logic
  );
end entity;

architecture A_Rtl of AXI_FastFilter is
  constant C_CFG_SUPPORTED  : boolean := (G_FAST_ENABLE_NMS = 0) and (G_FAST_IMPL = 1);
  constant C_GEOMETRY_VALID : boolean := (G_LINE_WIDTH >= G_KERNEL_SIZE) and (G_NUM_ROW >= G_KERNEL_SIZE);

  signal s_fast_candidate : std_logic := '0';
begin
  assert G_KERNEL_SIZE = 7
    report "AXI_FastFilter requires G_KERNEL_SIZE=7."
    severity failure;

  assert G_PIXEL_WIDTH = 8
    report "AXI_FastFilter requires G_PIXEL_WIDTH=8."
    severity failure;

  assert G_FAST_ENABLE_NMS = 0
    report "AXI_FastFilter cleaned implementation supports only G_FAST_ENABLE_NMS=0."
    severity failure;

  assert G_FAST_IMPL = 1
    report "AXI_FastFilter cleaned implementation supports only G_FAST_IMPL=1 (parallel)."
    severity failure;

  assert C_GEOMETRY_VALID
    report "AXI_FastFilter requires G_LINE_WIDTH >= G_KERNEL_SIZE and G_NUM_ROW >= G_KERNEL_SIZE."
    severity failure;

  U_FastCore: entity work.E_FastCore
    generic map (
      G_PIXEL_WIDTH    => G_PIXEL_WIDTH,
      G_KERNEL_SIZE    => G_KERNEL_SIZE,
      G_FAST_THRESHOLD => G_FAST_THRESHOLD,
      G_FAST_N         => G_FAST_N
    )
    port map (
      i_window       => s_axis_window_tdata,
      o_is_candidate => s_fast_candidate,
      o_score        => open
    );

  -- This wrapper is combinational around E_FastCore; keep i_aclk consumed so
  -- strict linters do not flag the clock port as unused.
  P_COMB_CLOCK_USE: process (i_aclk) is
  begin
    if rising_edge(i_aclk) then
      null;
    end if;
  end process;

  -- One-to-one AXI stream timing with backpressure from downstream.
  s_axis_window_tready <= '0'                   when (i_aresetn = '0') else
                          m_axis_filter8_tready when (C_CFG_SUPPORTED and C_GEOMETRY_VALID) else
                          '0';

  m_axis_filter8_tvalid <= '0'                  when (i_aresetn = '0') else
                           s_axis_window_tvalid when (C_CFG_SUPPORTED and C_GEOMETRY_VALID) else
                           '0';

  m_axis_filter8_tuser <= '0'                 when (i_aresetn = '0') else
                          s_axis_window_tuser when (C_CFG_SUPPORTED and C_GEOMETRY_VALID) else
                          '0';

  m_axis_filter8_tlast <= '0'                 when (i_aresetn = '0') else
                          s_axis_window_tlast when (C_CFG_SUPPORTED and C_GEOMETRY_VALID) else
                          '0';

  m_axis_filter8_tdata <= (others => '1') when (i_aresetn = '1' and C_CFG_SUPPORTED and C_GEOMETRY_VALID and s_axis_window_tvalid = '1' and s_fast_candidate = '1') else
                           (others => '0');
end architecture;
