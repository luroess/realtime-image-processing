library ieee;
  use ieee.std_logic_1164.all;

entity AXI_WindowedFilterWrapper is
  generic (
    -- 0: Sobel, 1: Blur placeholder (center-pixel pass-through)
    G_FILTER_SELECT  : natural := 0;

    -- Sobel generic
    G_SOBEL_TRESHOLD : natural := 200;

    -- Internal window_generator generics
    G_PIXEL_WIDTH                : positive := 8;
    G_KERNEL_SIZE                : positive := 3;
    G_LINE_WIDTH                 : positive := 1920;
    G_ROW                        : positive := 1080
  );
  port (
    i_aclk    : in  std_logic;
    i_aresetn : in  std_logic;

    -- AXI4-Stream grayscale input (gray8)
    s_axis_video_tvalid : in  std_logic;
    s_axis_video_tready : out std_logic;
    s_axis_video_tdata  : in  std_logic_vector(G_PIXEL_WIDTH - 1 downto 0);
    s_axis_video_tuser  : in  std_logic;
    s_axis_video_tlast  : in  std_logic;

    -- AXI4-Stream filtered output (gray8)
    m_axis_video_tvalid : out std_logic;
    m_axis_video_tready : in  std_logic;
    m_axis_video_tdata  : out std_logic_vector(G_PIXEL_WIDTH - 1 downto 0);
    m_axis_video_tuser  : out std_logic;
    m_axis_video_tlast  : out std_logic
  );
end entity;

architecture A_Rtl of AXI_WindowedFilterWrapper is
  constant C_FILTER_SOBEL : natural := 0;
  constant C_FILTER_BLUR  : natural := 1;
  constant C_WINDOW_DATA_WIDTH : positive := G_KERNEL_SIZE * G_KERNEL_SIZE * G_PIXEL_WIDTH;
  constant C_CENTER_INDEX      : natural  := (G_KERNEL_SIZE * G_KERNEL_SIZE) / 2;
  constant C_CENTER_LSB        : natural  := C_CENTER_INDEX * G_PIXEL_WIDTH;
  constant C_CENTER_MSB        : natural  := ((C_CENTER_INDEX + 1) * G_PIXEL_WIDTH) - 1;

  -- Unified window stream feeding selected filter
  signal s_wndw_tvalid : std_logic := '0';
  signal s_wndw_tready : std_logic := '0';
  signal s_wndw_tdata  : std_logic_vector(C_WINDOW_DATA_WIDTH - 1 downto 0) := (others => '0');
  signal s_wndw_tuser  : std_logic := '0';
  signal s_wndw_tlast  : std_logic := '0';

  -- Sobel output stream
  signal s_sobel_tvalid : std_logic := '0';
  signal s_sobel_tdata  : std_logic_vector(G_PIXEL_WIDTH - 1 downto 0) := (others => '0');
  signal s_sobel_tuser  : std_logic := '0';
  signal s_sobel_tlast  : std_logic := '0';
begin
  -- AXI_SobelFilter currently requires 3x3 windows with 8-bit grayscale pixels.
  assert G_KERNEL_SIZE = 3
    report "AXI_WindowedFilterWrapper with AXI_SobelFilter requires G_KERNEL_SIZE=3."
    severity failure;
  assert G_PIXEL_WIDTH = 8
    report "AXI_WindowedFilterWrapper with AXI_SobelFilter requires G_PIXEL_WIDTH=8."
    severity failure;

  ---------------------------------------------------------------------------
  -- Internal window generator
  ---------------------------------------------------------------------------
  U_WindowGenerator: entity work.window_generator
    generic map (
      G_PIXEL_WIDTH => G_PIXEL_WIDTH,
      G_KERNEL_SIZE => G_KERNEL_SIZE,
      G_LINE_WIDTH  => G_LINE_WIDTH,
      G_ROW         => G_ROW
    )
    port map (
      i_aclk               => i_aclk,
      i_aresetn            => i_aresetn,
      s_axis_video_tvalid  => s_axis_video_tvalid,
      s_axis_video_tready  => s_axis_video_tready,
      s_axis_video_tdata   => s_axis_video_tdata,
      s_axis_video_tuser   => s_axis_video_tuser,
      s_axis_video_tlast   => s_axis_video_tlast,
      m_axis_window_tvalid => s_wndw_tvalid,
      m_axis_window_tready => s_wndw_tready,
      m_axis_window_tdata  => s_wndw_tdata,
      m_axis_window_tuser  => s_wndw_tuser,
      m_axis_window_tlast  => s_wndw_tlast
    );

  ---------------------------------------------------------------------------
  -- Filter selection
  ---------------------------------------------------------------------------
  G_SobelFilter: if G_FILTER_SELECT = C_FILTER_SOBEL generate
    U_AxiSobelFilter: entity work.AXI_SobelFilter
      generic map (
        G_PIXEL_WIDTH    => G_PIXEL_WIDTH,
        G_KERNEL_SIZE    => G_KERNEL_SIZE,
        G_SOBEL_TRESHOLD => G_SOBEL_TRESHOLD
      )
      port map (
        i_aclk               => i_aclk,
        i_aresetn            => i_aresetn,
        s_axis_video_tvalid  => s_wndw_tvalid,
        s_axis_video_tready  => s_wndw_tready,
        s_axis_video_tdata   => s_wndw_tdata,
        s_axis_video_tuser   => s_wndw_tuser,
        s_axis_video_tlast   => s_wndw_tlast,
        m_axis_window_tvalid => s_sobel_tvalid,
        m_axis_window_tready => m_axis_video_tready,
        m_axis_window_tdata  => s_sobel_tdata,
        m_axis_window_tuser  => s_sobel_tuser,
        m_axis_window_tlast  => s_sobel_tlast
      );

    m_axis_video_tvalid <= s_sobel_tvalid;
    m_axis_video_tdata  <= s_sobel_tdata;
    m_axis_video_tuser  <= s_sobel_tuser;
    m_axis_video_tlast  <= s_sobel_tlast;
  end generate;

  G_BlurPlaceholderFilter: if G_FILTER_SELECT = C_FILTER_BLUR generate
    -- Placeholder path until blur filter module exists
    -- Uses center pixel of the window as pass-through gray output
    s_wndw_tready <= m_axis_video_tready;

    m_axis_video_tvalid <= '0' when (i_aresetn = '0') else s_wndw_tvalid;
    m_axis_video_tdata  <= (others => '0') when (i_aresetn = '0') else s_wndw_tdata(C_CENTER_MSB downto C_CENTER_LSB);
    m_axis_video_tuser  <= '0' when (i_aresetn = '0') else s_wndw_tuser;
    m_axis_video_tlast  <= '0' when (i_aresetn = '0') else s_wndw_tlast;
  end generate;

  G_FilterDefault: if (G_FILTER_SELECT /= C_FILTER_SOBEL) and (G_FILTER_SELECT /= C_FILTER_BLUR) generate
    -- Safe default for unsupported filter selections
    s_wndw_tready <= '0';
    m_axis_video_tvalid <= '0';
    m_axis_video_tdata  <= (others => '0');
    m_axis_video_tuser  <= '0';
    m_axis_video_tlast  <= '0';
  end generate;

end architecture;
