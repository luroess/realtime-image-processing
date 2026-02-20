library ieee;
  use ieee.std_logic_1164.all;

entity AXI_RgbGrayBlurrSobelOverlayPipeline is
  generic (
    G_CLK_FREQ_HZ             : integer                                    := 100_000_000;
    G_DEBOUNCE_NS             : integer                                    := 10_000_000;

    G_PIXEL_WIDTH             : positive                                   := 8;
    G_LINE_WIDTH              : positive                                   := 1920;
    G_NUM_ROW                 : positive                                   := 1080;

    G_BLURR_KERNEL_SIZE       : positive                                   := 3;
    G_BLURR_COEFF_WIDTH       : positive                                   := 8;
    -- Default: 3x3 Gaussian [1 2 1; 2 4 2; 1 2 1], tap0 at LSB.
    G_BLURR_KERNEL_COEFFS     : std_logic_vector((3 * 3 * 8) - 1 downto 0) := x"010201020402010201";
    G_BLURR_NORMALIZE_DIVISOR : positive                                   := 16;
    G_BLURR_BIAS              : integer                                    := 0;

    G_SOBEL_THRESHOLD         : natural                                    := 150;
    G_EDGE_COLOR              : std_logic_vector(23 downto 0)              := x"FF0000"
  );
  port (
    i_clk                      : in  std_logic;
    i_rst_n                    : in  std_logic;
    i_btn                      : in  std_logic_vector(3 downto 0);

    -- AXI4-Stream RGB input (R|B|G packed)
    s_axis_video_rbg888_tvalid : in  std_logic;
    s_axis_video_rbg888_tready : out std_logic;
    s_axis_video_rbg888_tdata  : in  std_logic_vector((3 * G_PIXEL_WIDTH) - 1 downto 0);
    s_axis_video_rbg888_tuser  : in  std_logic;
    s_axis_video_rbg888_tlast  : in  std_logic;

    -- AXI4-Stream RGB output (R|B|G packed)
    m_axis_video_rbg888_tvalid : out std_logic;
    m_axis_video_rbg888_tready : in  std_logic;
    m_axis_video_rbg888_tdata  : out std_logic_vector((3 * G_PIXEL_WIDTH) - 1 downto 0);
    m_axis_video_rbg888_tuser  : out std_logic;
    m_axis_video_rbg888_tlast  : out std_logic;

    -- Runtime control/status visibility
    o_btn_debounced            : out std_logic;
    o_pass_grayscale           : out std_logic;
    o_pass_blurr_filter        : out std_logic;
    o_pass_sobel               : out std_logic;
    o_led                      : out std_logic_vector(3 downto 0)
  );
end entity;

architecture A_RtlStruct of AXI_RgbGrayBlurrSobelOverlayPipeline is
  constant C_DELAY_SEL_NONE       : std_logic_vector(1 downto 0) := "00";
  constant C_DELAY_SEL_SOBEL      : std_logic_vector(1 downto 0) := "01";
  constant C_DELAY_SEL_BLUR_SOBEL : std_logic_vector(1 downto 0) := "10";

  signal s_pass_grayscale    : std_logic := '0';
  signal s_pass_blurr_filter : std_logic := '1';
  signal s_pass_sobel        : std_logic := '1';
  signal s_overlay_zeros     : std_logic := '1';

  -- Frame-latched controls captured on accepted input SOF.
  signal s_pass_grayscale_l    : std_logic := '0';
  signal s_pass_blurr_filter_l : std_logic := '1';
  signal s_pass_sobel_l        : std_logic := '1';
  signal s_overlay_zeros_l     : std_logic := '1';
  signal s_input_sof_accept    : std_logic := '0';
  signal s_input_tready        : std_logic := '0';

  signal s_gray_tvalid : std_logic                                    := '0';
  signal s_gray_tready : std_logic                                    := '0';
  signal s_gray_tdata  : std_logic_vector(G_PIXEL_WIDTH - 1 downto 0) := (others => '0');
  signal s_gray_tuser  : std_logic                                    := '0';
  signal s_gray_tlast  : std_logic                                    := '0';

  signal s_rgb_stage_tvalid : std_logic                                          := '0';
  signal s_rgb_stage_tready : std_logic                                          := '0';
  signal s_rgb_stage_tdata  : std_logic_vector((3 * G_PIXEL_WIDTH) - 1 downto 0) := (others => '0');
  signal s_rgb_stage_tuser  : std_logic                                          := '0';
  signal s_rgb_stage_tlast  : std_logic                                          := '0';

  signal s_blurr_tvalid : std_logic                                    := '0';
  signal s_blurr_tready : std_logic                                    := '0';
  signal s_blurr_tdata  : std_logic_vector(G_PIXEL_WIDTH - 1 downto 0) := (others => '0');
  signal s_blurr_tuser  : std_logic                                    := '0';
  signal s_blurr_tlast  : std_logic                                    := '0';

  signal s_sobel_tvalid : std_logic                                          := '0';
  signal s_sobel_tready : std_logic                                          := '0';
  signal s_sobel_tdata  : std_logic_vector((3 * G_PIXEL_WIDTH) - 1 downto 0) := (others => '0');
  signal s_sobel_tuser  : std_logic                                          := '0';
  signal s_sobel_tlast  : std_logic                                          := '0';

  -- AXI_FrameCompositor channels:
  --   s_fc_rgb_*  = base RGB stream,
  --   s_fc_gray_* = timing/mask stream (Sobel in overlay modes, zero-mask from RGB timing in pass-all mode).
  signal s_fc_rgb_tvalid : std_logic                                          := '0';
  signal s_fc_rgb_tready : std_logic                                          := '0';
  signal s_fc_rgb_tdata  : std_logic_vector((3 * G_PIXEL_WIDTH) - 1 downto 0) := (others => '0');
  signal s_fc_rgb_tuser  : std_logic                                          := '0';
  signal s_fc_rgb_tlast  : std_logic                                          := '0';

  signal s_fc_gray_tvalid : std_logic                                    := '0';
  signal s_fc_gray_tready : std_logic                                    := '0';
  signal s_fc_gray_tdata  : std_logic_vector(G_PIXEL_WIDTH - 1 downto 0) := (others => '0');
  signal s_fc_gray_tuser  : std_logic                                    := '0';
  signal s_fc_gray_tlast  : std_logic                                    := '0';

  signal s_fc_delay_stage_sel : std_logic_vector(1 downto 0) := C_DELAY_SEL_NONE;
  signal s_mode_overlay       : std_logic                    := '0';

  signal s_compositor_tvalid : std_logic                                          := '0';
  signal s_compositor_tdata  : std_logic_vector((3 * G_PIXEL_WIDTH) - 1 downto 0) := (others => '0');
  signal s_compositor_tuser  : std_logic                                          := '0';
  signal s_compositor_tlast  : std_logic                                          := '0';
begin
  assert G_BLURR_KERNEL_COEFFS'length = (G_BLURR_KERNEL_SIZE * G_BLURR_KERNEL_SIZE * G_BLURR_COEFF_WIDTH)
    report "AXI_RgbGrayBlurrSobelOverlayPipeline: G_BLURR_KERNEL_COEFFS length must equal G_BLURR_KERNEL_SIZE*G_BLURR_KERNEL_SIZE*G_BLURR_COEFF_WIDTH."
    severity failure;

  U_DebouncedClickDetector: entity work.DebouncedClickDetector
    generic map (
      G_CLK_FREQ_HZ => G_CLK_FREQ_HZ,
      G_DEBOUNCE_NS => G_DEBOUNCE_NS
    )
    port map (
      i_clk               => i_clk,
      i_rst_n             => i_rst_n,
      i_btn               => i_btn,
      o_btn_debounced     => o_btn_debounced,
      o_btn2_debounced    => open,
      o_pass_grayscale    => s_pass_grayscale,
      o_pass_blurr_filter => s_pass_blurr_filter,
      o_pass_sobel        => s_pass_sobel,
      o_overlay_zeros     => s_overlay_zeros,
      o_led               => o_led
    );

  o_pass_grayscale    <= s_pass_grayscale;
  o_pass_blurr_filter <= s_pass_blurr_filter;
  o_pass_sobel        <= s_pass_sobel;

  -- Capture point for frame-level control updates.
  s_input_sof_accept <= s_axis_video_rbg888_tvalid and s_input_tready and s_axis_video_rbg888_tuser;

  P_REG_FRAME_CTRL_LATCH: process (i_clk)
  begin
    if rising_edge(i_clk) then
      if i_rst_n = '0' then
        s_pass_grayscale_l <= '0';
        s_pass_blurr_filter_l <= '1';
        s_pass_sobel_l <= '1';
        s_overlay_zeros_l <= '1';
      elsif s_input_sof_accept = '1' then
        s_pass_grayscale_l <= s_pass_grayscale;
        s_pass_blurr_filter_l <= s_pass_blurr_filter;
        s_pass_sobel_l <= s_pass_sobel;
        s_overlay_zeros_l <= s_overlay_zeros;
      end if;
    end if;
  end process;

  -- Sobel-active modes consume real edge mask data from Sobel output.
  s_mode_overlay <= '1' when s_pass_sobel_l = '0' else
                    '0';

  -- Select compositor RGB delay tap according to active processing latency.
  s_fc_delay_stage_sel <= C_DELAY_SEL_BLUR_SOBEL when (s_mode_overlay = '1' and s_pass_blurr_filter_l = '0') else
                          C_DELAY_SEL_SOBEL      when (s_mode_overlay = '1') else
                          C_DELAY_SEL_NONE;

  U_AxiRgbToGrayscale: entity work.AXI_RgbToGrayscale
    generic map (
      G_COMPONENT_WIDTH => G_PIXEL_WIDTH
    )
    port map (
      i_aclk               => i_clk,
      i_aresetn            => i_rst_n,
      i_pass_through       => s_pass_grayscale_l,
      s_axis_video_tvalid  => s_axis_video_rbg888_tvalid,
      s_axis_video_tready  => s_input_tready,
      s_axis_video_tdata   => s_axis_video_rbg888_tdata,
      s_axis_video_tuser   => s_axis_video_rbg888_tuser,
      s_axis_video_tlast   => s_axis_video_rbg888_tlast,
      m_axis_rbg888_tvalid => s_rgb_stage_tvalid,
      m_axis_rbg888_tready => s_rgb_stage_tready,
      m_axis_rbg888_tdata  => s_rgb_stage_tdata,
      m_axis_rbg888_tuser  => s_rgb_stage_tuser,
      m_axis_rbg888_tlast  => s_rgb_stage_tlast,
      m_axis_gray8_tvalid  => s_gray_tvalid,
      m_axis_gray8_tready  => s_gray_tready,
      m_axis_gray8_tdata   => s_gray_tdata,
      m_axis_gray8_tuser   => s_gray_tuser,
      m_axis_gray8_tlast   => s_gray_tlast
    );

  s_axis_video_rbg888_tready <= s_input_tready;

  U_AxiBlurrWindowModule: entity work.AXI_BlurrWindowModule
    generic map (
      G_PIXEL_WIDTH       => G_PIXEL_WIDTH,
      G_KERNEL_SIZE       => G_BLURR_KERNEL_SIZE,
      G_LINE_WIDTH        => G_LINE_WIDTH,
      G_NUM_ROW           => G_NUM_ROW,
      G_COEFF_WIDTH       => G_BLURR_COEFF_WIDTH,
      G_KERNEL_COEFFS     => G_BLURR_KERNEL_COEFFS,
      G_NORMALIZE_DIVISOR => G_BLURR_NORMALIZE_DIVISOR,
      G_BIAS              => G_BLURR_BIAS
    )
    port map (
      i_aclk                => i_clk,
      i_aresetn             => i_rst_n,
      i_pass_through        => s_pass_blurr_filter_l,
      s_axis_gray8_tvalid   => s_gray_tvalid,
      s_axis_gray8_tready   => s_gray_tready,
      s_axis_gray8_tdata    => s_gray_tdata,
      s_axis_gray8_tuser    => s_gray_tuser,
      s_axis_gray8_tlast    => s_gray_tlast,
      m_axis_filter8_tvalid => s_blurr_tvalid,
      m_axis_filter8_tready => s_blurr_tready,
      m_axis_filter8_tdata  => s_blurr_tdata,
      m_axis_filter8_tuser  => s_blurr_tuser,
      m_axis_filter8_tlast  => s_blurr_tlast
    );

  U_AxiSobelWindowModule: entity work.AXI_SobelWindowModule
    generic map (
      G_SOBEL_THRESHOLD => G_SOBEL_THRESHOLD,
      G_PIXEL_WIDTH     => G_PIXEL_WIDTH,
      G_KERNEL_SIZE     => 3,
      G_LINE_WIDTH      => G_LINE_WIDTH,
      G_NUM_ROW         => G_NUM_ROW
    )
    port map (
      i_aclk               => i_clk,
      i_aresetn            => i_rst_n,
      i_pass_through       => s_pass_sobel_l,
      s_axis_gray8_tvalid  => s_blurr_tvalid,
      s_axis_gray8_tready  => s_blurr_tready,
      s_axis_gray8_tdata   => s_blurr_tdata,
      s_axis_gray8_tuser   => s_blurr_tuser,
      s_axis_gray8_tlast   => s_blurr_tlast,
      m_axis_rbg888_tvalid => s_sobel_tvalid,
      m_axis_rbg888_tready => s_sobel_tready,
      m_axis_rbg888_tdata  => s_sobel_tdata,
      m_axis_rbg888_tuser  => s_sobel_tuser,
      m_axis_rbg888_tlast  => s_sobel_tlast
    );

  -- Base RGB stream always feeds compositor.
  s_fc_rgb_tvalid <= s_rgb_stage_tvalid;
  s_fc_rgb_tdata  <= s_rgb_stage_tdata;
  s_fc_rgb_tuser  <= s_rgb_stage_tuser;
  s_fc_rgb_tlast  <= s_rgb_stage_tlast;

  -- Sobel path always provides compositor timing. In pass-all mode, force a
  -- zero mask to bypass edge coloring while preserving AXI beat cadence.
  s_fc_gray_tvalid <= s_sobel_tvalid;
  s_fc_gray_tdata  <= s_sobel_tdata(G_PIXEL_WIDTH - 1 downto 0) when s_mode_overlay = '1' else
                        (others => '0');
  s_fc_gray_tuser <= s_sobel_tuser;
  s_fc_gray_tlast <= s_sobel_tlast;

  -- READY propagation follows compositor ownership of the final output path.
  s_rgb_stage_tready <= s_fc_rgb_tready;
  s_sobel_tready     <= s_fc_gray_tready;

  U_AxiFrameCompositor: entity work.AXI_FrameCompositor
    generic map (
      G_COMPONENT_WIDTH   => G_PIXEL_WIDTH,
      G_EDGE_COLOR        => G_EDGE_COLOR,
      G_LINE_WIDTH        => G_LINE_WIDTH,
      G_SOBEL_KERNEL_SIZE => 3,
      G_BLUR_KERNEL_SIZE  => G_BLURR_KERNEL_SIZE
    )
    port map (
      i_aclk                     => i_clk,
      i_aresetn                  => i_rst_n,
      i_overlay_zeros            => s_overlay_zeros_l,
      i_base_delay_stage_sel     => s_fc_delay_stage_sel,
      s_axis_video_rbg888_tvalid => s_fc_rgb_tvalid,
      s_axis_video_rbg888_tready => s_fc_rgb_tready,
      s_axis_video_rbg888_tdata  => s_fc_rgb_tdata,
      s_axis_video_rbg888_tuser  => s_fc_rgb_tuser,
      s_axis_video_rbg888_tlast  => s_fc_rgb_tlast,
      s_axis_video_gray8_tvalid  => s_fc_gray_tvalid,
      s_axis_video_gray8_tready  => s_fc_gray_tready,
      s_axis_video_gray8_tdata   => s_fc_gray_tdata,
      s_axis_video_gray8_tuser   => s_fc_gray_tuser,
      s_axis_video_gray8_tlast   => s_fc_gray_tlast,
      m_axis_video_rbg888_tvalid => s_compositor_tvalid,
      m_axis_video_rbg888_tready => m_axis_video_rbg888_tready,
      m_axis_video_rbg888_tdata  => s_compositor_tdata,
      m_axis_video_rbg888_tuser  => s_compositor_tuser,
      m_axis_video_rbg888_tlast  => s_compositor_tlast
    );

  m_axis_video_rbg888_tvalid <= '0' when (i_rst_n = '0') else
                                s_compositor_tvalid;
  m_axis_video_rbg888_tdata <= (others => '0') when (i_rst_n = '0') else
                              s_compositor_tdata;
  m_axis_video_rbg888_tuser <= '0' when (i_rst_n = '0') else
                               s_compositor_tuser;
  m_axis_video_rbg888_tlast <= '0' when (i_rst_n = '0') else
                               s_compositor_tlast;
end architecture;
