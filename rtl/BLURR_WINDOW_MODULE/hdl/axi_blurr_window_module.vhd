library ieee;
  use ieee.std_logic_1164.all;

entity AXI_BlurrWindowModule is
  generic (
    -- Internal window_generator generics
    G_PIXEL_WIDTH : positive := 8;
    G_KERNEL_SIZE : positive := 3;
    G_LINE_WIDTH  : positive := 1920;
    G_NUM_ROW     : positive := 1080;

    -- Blurr filter generics
    G_COEFF_WIDTH       : positive := 8;
    -- Default: 3x3 Gaussian [1 2 1; 2 4 2; 1 2 1], tap0 at LSB
    G_KERNEL_COEFFS     : std_logic_vector(71 downto 0) := x"010201020402010201";
    G_NORMALIZE_DIVISOR : positive := 16;
    G_BIAS              : integer := 0
  );
  port (
    i_aclk         : in  std_logic;
    i_aresetn      : in  std_logic;
    -- when '1', output unmodified input pixel data instead of blurr output
    i_pass_through : in  std_logic;

    -- AXI4-Stream grayscale input (gray8)
    s_axis_gray8_tvalid : in  std_logic;
    s_axis_gray8_tready : out std_logic;
    s_axis_gray8_tdata  : in  std_logic_vector(G_PIXEL_WIDTH - 1 downto 0);
    s_axis_gray8_tuser  : in  std_logic;
    s_axis_gray8_tlast  : in  std_logic;

    -- AXI4-Stream filtered output (gray8)
    m_axis_filter8_tvalid : out std_logic;
    m_axis_filter8_tready : in  std_logic;
    m_axis_filter8_tdata  : out std_logic_vector(G_PIXEL_WIDTH - 1 downto 0);
    m_axis_filter8_tuser  : out std_logic;
    m_axis_filter8_tlast  : out std_logic
  );
end entity;

architecture A_Rtl of AXI_BlurrWindowModule is
  constant C_WINDOW_DATA_WIDTH : positive := G_KERNEL_SIZE * G_KERNEL_SIZE * G_PIXEL_WIDTH;

  signal s_axis_gray8_tready_sel : std_logic := '0';
  signal s_axis_gray8_tvalid_filter : std_logic := '0';
  signal s_axis_gray8_tready_filter : std_logic := '0';

  signal s_wndw_tvalid : std_logic := '0';
  signal s_wndw_tready : std_logic := '0';
  signal s_wndw_tdata  : std_logic_vector(C_WINDOW_DATA_WIDTH - 1 downto 0) := (others => '0');
  signal s_wndw_tuser  : std_logic := '0';
  signal s_wndw_tlast  : std_logic := '0';

  signal s_blurr_tvalid : std_logic := '0';
  signal s_blurr_tdata  : std_logic_vector(G_PIXEL_WIDTH - 1 downto 0) := (others => '0');
  signal s_blurr_tuser  : std_logic := '0';
  signal s_blurr_tlast  : std_logic := '0';
begin
  assert G_KERNEL_COEFFS'length = (G_KERNEL_SIZE * G_KERNEL_SIZE * G_COEFF_WIDTH)
    report "AXI_BlurrWindowModule: G_KERNEL_COEFFS length must equal G_KERNEL_SIZE*G_KERNEL_SIZE*G_COEFF_WIDTH."
    severity failure;

  -- In pass-through mode, keep the hidden filter path quiescent.
  -- This avoids consuming internal warm-up beats while output is bypassed.
  s_axis_gray8_tready_sel <= '0' when (i_aresetn = '0') else
                             m_axis_filter8_tready when (i_pass_through = '1') else
                             s_axis_gray8_tready_filter;
  s_axis_gray8_tready <= s_axis_gray8_tready_sel;

  s_axis_gray8_tvalid_filter <= '0' when (i_pass_through = '1') else s_axis_gray8_tvalid;

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

  U_AxiBlurrFilter: entity work.AXI_BlurrFilter
    generic map (
      G_PIXEL_WIDTH       => G_PIXEL_WIDTH,
      G_KERNEL_SIZE       => G_KERNEL_SIZE,
      G_COEFF_WIDTH       => G_COEFF_WIDTH,
      G_KERNEL_COEFFS     => G_KERNEL_COEFFS,
      G_NORMALIZE_DIVISOR => G_NORMALIZE_DIVISOR,
      G_BIAS              => G_BIAS
    )
    port map (
      i_aclk               => i_aclk,
      i_aresetn            => i_aresetn,
      s_axis_window_tvalid => s_wndw_tvalid,
      s_axis_window_tready => s_wndw_tready,
      s_axis_window_tdata  => s_wndw_tdata,
      s_axis_window_tuser  => s_wndw_tuser,
      s_axis_window_tlast  => s_wndw_tlast,
      m_axis_filter8_tvalid => s_blurr_tvalid,
      m_axis_filter8_tready => m_axis_filter8_tready,
      m_axis_filter8_tdata  => s_blurr_tdata,
      m_axis_filter8_tuser  => s_blurr_tuser,
      m_axis_filter8_tlast  => s_blurr_tlast
    );

  -- Top-level AXI4-Stream mux: pass-through or filter output
  m_axis_filter8_tvalid <= '0' when (i_aresetn = '0') else
                           s_axis_gray8_tvalid when (i_pass_through = '1') else
                           s_blurr_tvalid;
  m_axis_filter8_tdata <= (others => '0') when (i_aresetn = '0') else
                          s_axis_gray8_tdata when (i_pass_through = '1') and (s_axis_gray8_tvalid = '1') else
                          s_blurr_tdata when (i_pass_through /= '1') and (s_blurr_tvalid = '1') else
                          (others => '0');
  m_axis_filter8_tuser <= '0' when (i_aresetn = '0') else
                          s_axis_gray8_tuser when (i_pass_through = '1') and (s_axis_gray8_tvalid = '1') else
                          s_blurr_tuser when (i_pass_through /= '1') and (s_blurr_tvalid = '1') else
                          '0';
  m_axis_filter8_tlast <= '0' when (i_aresetn = '0') else
                          s_axis_gray8_tlast when (i_pass_through = '1') and (s_axis_gray8_tvalid = '1') else
                          s_blurr_tlast when (i_pass_through /= '1') and (s_blurr_tvalid = '1') else
                          '0';
end architecture;
