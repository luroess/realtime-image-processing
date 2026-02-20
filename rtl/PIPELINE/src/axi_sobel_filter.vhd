library ieee;
  use ieee.std_logic_1164.all;

entity AXI_SobelFilter is
  generic (
    -- Pixel width in bits (default 8-bit grayscale)
    G_PIXEL_WIDTH    : positive := 8;
    -- Used for vector sizing only, Sobel computation is fixed to 3x3
    G_KERNEL_SIZE    : positive := 3;
    -- Threshold in range 0..2040 for 8-bit input
    G_SOBEL_THRESHOLD : natural := 150
  );
  port (
    i_aclk              : in  std_logic;
    i_aresetn           : in  std_logic;

    -- AXI4-Stream Video Slave (input: 3x3 gray window, flattened)
    s_axis_window_tvalid : in  std_logic;
    s_axis_window_tready : out std_logic;
    s_axis_window_tdata  : in  std_logic_vector((G_KERNEL_SIZE * G_KERNEL_SIZE * G_PIXEL_WIDTH) - 1 downto 0);
    s_axis_window_tuser  : in  std_logic; -- SOF passthrough
    s_axis_window_tlast  : in  std_logic; -- EOL passthrough

    -- AXI4-Stream Video Master (output)
    m_axis_filter8_tvalid : out std_logic;
    m_axis_filter8_tready : in  std_logic;
    m_axis_filter8_tdata  : out std_logic_vector(G_PIXEL_WIDTH - 1 downto 0);
    m_axis_filter8_tuser  : out std_logic; -- SOF passthrough
    m_axis_filter8_tlast  : out std_logic  -- EOL passthrough
  );
end entity;

architecture A_Rtl of AXI_SobelFilter is
  signal s_sobel_pixel : std_logic_vector(G_PIXEL_WIDTH - 1 downto 0);
  signal s_tvalid      : std_logic;
begin
  assert G_KERNEL_SIZE = 3
    report "AXI_SobelFilter: fixed Sobel logic requires G_KERNEL_SIZE=3."
    severity failure;

  U_SobelCore: entity work.E_SobelCore
    generic map (
      G_PIXEL_WIDTH    => G_PIXEL_WIDTH,
      G_KERNEL_SIZE    => G_KERNEL_SIZE,
      G_SOBEL_THRESHOLD => G_SOBEL_THRESHOLD
    )
    port map (
      i_window     => s_axis_window_tdata,
      o_edge_pixel => s_sobel_pixel
    );

  -- AXI-stream passthrough timing
  s_axis_window_tready <= '0' when (i_aresetn = '0') else
                         m_axis_filter8_tready;

  s_tvalid <= '0' when (i_aresetn = '0') else
              s_axis_window_tvalid;
  m_axis_filter8_tvalid <= s_tvalid;

  m_axis_filter8_tdata <= (others => '0') when (s_tvalid = '0') else
                         s_sobel_pixel;
  m_axis_filter8_tuser <= '0' when (s_tvalid = '0') else
                         s_axis_window_tuser;
  m_axis_filter8_tlast <= '0' when (s_tvalid = '0') else
                         s_axis_window_tlast;
end architecture;
