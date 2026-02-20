library ieee;
  use ieee.std_logic_1164.all;

entity AXI_FastWindowModule is
  generic (
    -- FAST filter generics
    G_FAST_THRESHOLD       : natural  := 20;
    G_FAST_N               : positive := 9;

    -- Internal window_generator generics
    G_PIXEL_WIDTH          : positive := 8;
    G_KERNEL_SIZE          : positive := 7;
    G_LINE_WIDTH           : positive := 1920;
    G_NUM_ROW              : positive := 1080
  );
  port (
    i_aclk                : in  std_logic;
    i_aresetn             : in  std_logic;
    -- when '1', bypass FAST and output input gray8 stream
    i_pass_through        : in  std_logic;

    -- AXI4-Stream grayscale input (gray8)
    s_axis_gray8_tvalid   : in  std_logic;
    s_axis_gray8_tready   : out std_logic;
    s_axis_gray8_tdata    : in  std_logic_vector(G_PIXEL_WIDTH - 1 downto 0);
    s_axis_gray8_tuser    : in  std_logic;
    s_axis_gray8_tlast    : in  std_logic;

    -- AXI4-Stream filtered output (gray8)
    m_axis_filter8_tvalid : out std_logic;
    m_axis_filter8_tready : in  std_logic;
    m_axis_filter8_tdata  : out std_logic_vector(G_PIXEL_WIDTH - 1 downto 0);
    m_axis_filter8_tuser  : out std_logic;
    m_axis_filter8_tlast  : out std_logic
  );
end entity;

architecture A_Rtl of AXI_FastWindowModule is
  constant C_WINDOW_DATA_WIDTH : positive := G_KERNEL_SIZE * G_KERNEL_SIZE * G_PIXEL_WIDTH;

  signal s_axis_gray8_tvalid_filter : std_logic := '0';
  signal s_axis_gray8_tready_filter : std_logic := '0';

  signal s_wndw_tvalid : std_logic                                          := '0';
  signal s_wndw_tready : std_logic                                          := '0';
  signal s_wndw_tdata  : std_logic_vector(C_WINDOW_DATA_WIDTH - 1 downto 0) := (others => '0');
  signal s_wndw_tuser  : std_logic                                          := '0';
  signal s_wndw_tlast  : std_logic                                          := '0';

  signal s_fast_tvalid : std_logic                                    := '0';
  signal s_fast_tdata  : std_logic_vector(G_PIXEL_WIDTH - 1 downto 0) := (others => '0');
  signal s_fast_tuser  : std_logic                                    := '0';
  signal s_fast_tlast  : std_logic                                    := '0';
begin
  -- AXI_FastFilter currently requires 7x7 windows with 8-bit grayscale pixels.
  assert G_KERNEL_SIZE = 7
    report "AXI_FastWindowModule with AXI_FastFilter requires G_KERNEL_SIZE=7."
    severity failure;
  assert G_PIXEL_WIDTH = 8
    report "AXI_FastWindowModule with AXI_FastFilter requires G_PIXEL_WIDTH=8."
    severity failure;

  -- Always feed the window generator / filter pipeline so internal state
  -- stays aligned with the live input stream, independent of pass-through.
  s_axis_gray8_tvalid_filter <= s_axis_gray8_tvalid;

  U_WindowGenerator: entity work.window_generator
    generic map (
      G_PIXEL_WIDTH => G_PIXEL_WIDTH,
      G_KERNEL_SIZE => G_KERNEL_SIZE,
      G_LINE_WIDTH  => G_LINE_WIDTH,
      G_NUM_ROW     => G_NUM_ROW
    )
    port map (
      i_aclk               => i_aclk,
      i_aresetn            => i_aresetn,
      s_axis_gray8_tvalid  => s_axis_gray8_tvalid_filter,
      s_axis_gray8_tready  => s_axis_gray8_tready_filter,
      s_axis_gray8_tdata   => s_axis_gray8_tdata,
      s_axis_gray8_tuser   => s_axis_gray8_tuser,
      s_axis_gray8_tlast   => s_axis_gray8_tlast,
      m_axis_window_tvalid => s_wndw_tvalid,
      m_axis_window_tready => s_wndw_tready,
      m_axis_window_tdata  => s_wndw_tdata,
      m_axis_window_tuser  => s_wndw_tuser,
      m_axis_window_tlast  => s_wndw_tlast
    );

  U_AxiFastFilter: entity work.AXI_FastFilter
    generic map (
      G_PIXEL_WIDTH          => G_PIXEL_WIDTH,
      G_KERNEL_SIZE          => G_KERNEL_SIZE,
      G_LINE_WIDTH           => G_LINE_WIDTH,
      G_NUM_ROW              => G_NUM_ROW,
      G_FAST_THRESHOLD       => G_FAST_THRESHOLD,
      G_FAST_N               => G_FAST_N,
      G_FAST_ENABLE_NMS      => 0,
      G_FAST_IMPL            => 1
    )
    port map (
      i_aclk                => i_aclk,
      i_aresetn             => i_aresetn,
      s_axis_window_tvalid  => s_wndw_tvalid,
      s_axis_window_tready  => s_wndw_tready,
      s_axis_window_tdata   => s_wndw_tdata,
      s_axis_window_tuser   => s_wndw_tuser,
      s_axis_window_tlast   => s_wndw_tlast,
      m_axis_filter8_tvalid => s_fast_tvalid,
      m_axis_filter8_tready => m_axis_filter8_tready,
      m_axis_filter8_tdata  => s_fast_tdata,
      m_axis_filter8_tuser  => s_fast_tuser,
      m_axis_filter8_tlast  => s_fast_tlast
    );

  -- Top-level AXI4-Stream mux: pass-through or FAST output.
  s_axis_gray8_tready <= '0'                   when (i_aresetn = '0') else
                         m_axis_filter8_tready when (i_pass_through = '1') else
                         s_axis_gray8_tready_filter;

  m_axis_filter8_tvalid <= '0'                 when (i_aresetn = '0') else
                           s_axis_gray8_tvalid when (i_pass_through = '1') else
                           s_fast_tvalid;
  m_axis_filter8_tdata <= (others => '0')    when (i_aresetn = '0') else
                         s_axis_gray8_tdata  when (i_pass_through = '1') and (s_axis_gray8_tvalid = '1') else
                         s_fast_tdata        when (i_pass_through /= '1') and (s_fast_tvalid = '1') else
                         (others => '0');
  m_axis_filter8_tuser <= '0'                 when (i_aresetn = '0') else
                         s_axis_gray8_tuser  when (i_pass_through = '1') and (s_axis_gray8_tvalid = '1') else
                         s_fast_tuser        when (i_pass_through /= '1') and (s_fast_tvalid = '1') else
                         '0';
  m_axis_filter8_tlast <= '0'                 when (i_aresetn = '0') else
                         s_axis_gray8_tlast  when (i_pass_through = '1') and (s_axis_gray8_tvalid = '1') else
                         s_fast_tlast        when (i_pass_through /= '1') and (s_fast_tvalid = '1') else
                         '0';
end architecture;
