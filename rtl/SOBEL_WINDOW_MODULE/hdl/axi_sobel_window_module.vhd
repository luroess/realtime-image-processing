library ieee;
  use ieee.std_logic_1164.all;

entity AXI_SobelWindowModule is
  generic (
    -- Sobel generic
    G_SOBEL_THRESHOLD            : natural  := 150;
    G_SOBEL_MEAN_SHIFT           : natural  := 9;
    G_SOBEL_MEAN_UPDATE_INTERVAL : positive := 1;
    G_SOBEL_THRESHOLD_GAIN_NUM   : positive := 1;
    G_SOBEL_THRESHOLD_GAIN_DEN   : positive := 1;
    G_SOBEL_THRESHOLD_OFFSET     : integer  := 0;

    -- Internal window_generator generics
    G_PIXEL_WIDTH                : positive := 8;
    G_KERNEL_SIZE                : positive := 3;
    G_LINE_WIDTH                 : positive := 1920;
    G_NUM_ROW                    : positive := 1080
  );
  port (
    i_aclk              : in  std_logic;
    i_aresetn           : in  std_logic;
    -- when '1', bypass Sobel and output input gray8 stream
    i_pass_through      : in  std_logic;

    -- AXI4-Stream grayscale input (gray8)
    s_axis_gray8_tvalid : in  std_logic;
    s_axis_gray8_tready : out std_logic;
    s_axis_gray8_tdata  : in  std_logic_vector(G_PIXEL_WIDTH - 1 downto 0);
    s_axis_gray8_tuser  : in  std_logic;
    s_axis_gray8_tlast  : in  std_logic;

    -- AXI4-Stream filtered output (gray8)
    m_axis_gray8_tvalid : out std_logic;
    m_axis_gray8_tready : in  std_logic;
    m_axis_gray8_tdata  : out std_logic_vector(G_PIXEL_WIDTH - 1 downto 0);
    m_axis_gray8_tuser  : out std_logic;
    m_axis_gray8_tlast  : out std_logic
  );
end entity;

architecture A_Rtl of AXI_SobelWindowModule is
  constant C_WINDOW_DATA_WIDTH : positive := G_KERNEL_SIZE * G_KERNEL_SIZE * G_PIXEL_WIDTH;

  signal s_axis_gray8_tvalid_filter : std_logic := '0';
  signal s_axis_gray8_tready_filter : std_logic := '0';

  signal s_wndw_tvalid : std_logic                                          := '0';
  signal s_wndw_tready : std_logic                                          := '0';
  signal s_wndw_tdata  : std_logic_vector(C_WINDOW_DATA_WIDTH - 1 downto 0) := (others => '0');
  signal s_wndw_tuser  : std_logic                                          := '0';
  signal s_wndw_tlast  : std_logic                                          := '0';

  signal s_sobel_tvalid : std_logic                                    := '0';
  signal s_sobel_tdata  : std_logic_vector(G_PIXEL_WIDTH - 1 downto 0) := (others => '0');
  signal s_sobel_tuser  : std_logic                                    := '0';
  signal s_sobel_tlast  : std_logic                                    := '0';
  signal s_axis_gray8_tready_mux : std_logic                           := '0';
  signal s_axis_gray8_accept     : std_logic                           := '0';
begin
  -- AXI_SobelFilter currently requires 3x3 windows with 8-bit grayscale pixels
  assert G_KERNEL_SIZE = 3
    report "AXI_SobelWindowModule with AXI_SobelFilter requires G_KERNEL_SIZE=3."
    severity failure;
  assert G_PIXEL_WIDTH = 8
    report "AXI_SobelWindowModule with AXI_SobelFilter requires G_PIXEL_WIDTH=8."
    severity failure;

  -- In filter mode, keep the hidden filter path live.
  -- In pass-through mode, advance hidden state only on externally accepted beats
  -- so internal warm-up cannot consume unacknowledged input during stalls.
  s_axis_gray8_tvalid_filter <= s_axis_gray8_tvalid when (i_pass_through /= '1') else
                                s_axis_gray8_accept;

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

  U_AxiSobelFilter: entity work.AXI_SobelFilter
    generic map (
      G_PIXEL_WIDTH                => G_PIXEL_WIDTH,
      G_KERNEL_SIZE                => G_KERNEL_SIZE,
      G_SOBEL_THRESHOLD            => G_SOBEL_THRESHOLD,
      G_SOBEL_MEAN_SHIFT           => G_SOBEL_MEAN_SHIFT,
      G_SOBEL_MEAN_UPDATE_INTERVAL => G_SOBEL_MEAN_UPDATE_INTERVAL,
      G_SOBEL_THRESHOLD_GAIN_NUM   => G_SOBEL_THRESHOLD_GAIN_NUM,
      G_SOBEL_THRESHOLD_GAIN_DEN   => G_SOBEL_THRESHOLD_GAIN_DEN,
      G_SOBEL_THRESHOLD_OFFSET     => G_SOBEL_THRESHOLD_OFFSET
    )
    port map (
      i_aclk                => i_aclk,
      i_aresetn             => i_aresetn,
      s_axis_window_tvalid  => s_wndw_tvalid,
      s_axis_window_tready  => s_wndw_tready,
      s_axis_window_tdata   => s_wndw_tdata,
      s_axis_window_tuser   => s_wndw_tuser,
      s_axis_window_tlast   => s_wndw_tlast,
      m_axis_filter8_tvalid => s_sobel_tvalid,
      m_axis_filter8_tready => m_axis_gray8_tready,
      m_axis_filter8_tdata  => s_sobel_tdata,
      m_axis_filter8_tuser  => s_sobel_tuser,
      m_axis_filter8_tlast  => s_sobel_tlast
    );

  -- Top-level AXI4-Stream mux: pass-through or filter output
  s_axis_gray8_tready_mux <= '0'                 when (i_aresetn = '0') else
                             m_axis_gray8_tready when (i_pass_through = '1') else
                             s_axis_gray8_tready_filter;
  s_axis_gray8_tready <= s_axis_gray8_tready_mux;
  s_axis_gray8_accept <= s_axis_gray8_tvalid and s_axis_gray8_tready_mux;

  m_axis_gray8_tvalid <= '0'                 when (i_aresetn = '0') else
                         s_axis_gray8_tvalid when (i_pass_through = '1') else
                         s_sobel_tvalid;
  m_axis_gray8_tdata <= (others => '0')   when (i_aresetn = '0') else
                       s_axis_gray8_tdata when (i_pass_through = '1') and (s_axis_gray8_tvalid = '1') else
                       s_sobel_tdata      when (i_pass_through /= '1') and (s_sobel_tvalid = '1') else
                         (others => '0');
  m_axis_gray8_tuser <= '0'                when (i_aresetn = '0') else
                        s_axis_gray8_tuser when (i_pass_through = '1') and (s_axis_gray8_tvalid = '1') else
                        s_sobel_tuser      when (i_pass_through /= '1') and (s_sobel_tvalid = '1') else
                        '0';
  m_axis_gray8_tlast <= '0'                when (i_aresetn = '0') else
                        s_axis_gray8_tlast when (i_pass_through = '1') and (s_axis_gray8_tvalid = '1') else
                        s_sobel_tlast      when (i_pass_through /= '1') and (s_sobel_tvalid = '1') else
                        '0';
end architecture;
