library ieee;
  use ieee.std_logic_1164.all;

entity AXI_BlurrFilter is
  generic (
    -- Pixel width in bits (default 8-bit grayscale)
    G_PIXEL_WIDTH : positive := 8;
    -- Window/kernel side length (K)
    G_KERNEL_SIZE : positive := 3;
    -- Signed coefficient width in bits
    G_COEFF_WIDTH : positive := 8;
    -- Packed signed coefficients in row-major order, tap0 at LSB
    -- Default: 3x3 Gaussian [1 2 1; 2 4 2; 1 2 1]
    G_KERNEL_COEFFS : std_logic_vector((G_KERNEL_SIZE * G_KERNEL_SIZE * G_COEFF_WIDTH) - 1 downto 0) := x"010201020402010201";
    -- Post-accumulation normalization divisor (must be >=1)
    G_NORMALIZE_DIVISOR : positive := 16;
    -- Optional bias added before normalization
    G_BIAS : integer := 0
  );
  port (
    i_aclk               : in  std_logic;
    i_aresetn            : in  std_logic;

    -- AXI4-Stream Video Slave (input: KxK gray window, flattened)
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

architecture A_Rtl of AXI_BlurrFilter is
  signal s_blurr_pixel : std_logic_vector(G_PIXEL_WIDTH - 1 downto 0);
  signal s_tvalid      : std_logic;
begin
  assert G_KERNEL_COEFFS'length = (G_KERNEL_SIZE * G_KERNEL_SIZE * G_COEFF_WIDTH)
    report "AXI_BlurrFilter: G_KERNEL_COEFFS length must equal G_KERNEL_SIZE*G_KERNEL_SIZE*G_COEFF_WIDTH."
    severity failure;

  U_BlurrCore: entity work.E_BlurrCore
    generic map (
      G_PIXEL_WIDTH       => G_PIXEL_WIDTH,
      G_KERNEL_SIZE       => G_KERNEL_SIZE,
      G_COEFF_WIDTH       => G_COEFF_WIDTH,
      G_KERNEL_COEFFS     => G_KERNEL_COEFFS,
      G_NORMALIZE_DIVISOR => G_NORMALIZE_DIVISOR,
      G_BIAS              => G_BIAS
    )
    port map (
      i_window      => s_axis_window_tdata,
      o_blurr_pixel => s_blurr_pixel
    );

  -- AXI-stream passthrough timing
  s_axis_window_tready <= '0' when (i_aresetn = '0') else
                         m_axis_filter8_tready;

  s_tvalid <= '0' when (i_aresetn = '0') else
              s_axis_window_tvalid;
  m_axis_filter8_tvalid <= s_tvalid;

  m_axis_filter8_tdata <= (others => '0') when (s_tvalid = '0') else
                         s_blurr_pixel;
  m_axis_filter8_tuser <= '0' when (s_tvalid = '0') else
                         s_axis_window_tuser;
  m_axis_filter8_tlast <= '0' when (s_tvalid = '0') else
                         s_axis_window_tlast;
end architecture;
