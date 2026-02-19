library ieee;
  use ieee.std_logic_1164.all;

entity AXI_Pipeline is
  generic (
    G_CLK_FREQ_HZ                : integer                                                   := 100_000_000;
    G_DEBOUNCE_NS                : integer                                                   := 10_000_000;

    G_PIXEL_WIDTH                : positive                                                  := 8;
    G_LINE_WIDTH                 : positive                                                  := 1920;
    G_NUM_ROW                    : positive                                                  := 1080;

    G_BLURR_KERNEL_SIZE          : positive                                                  := 3;
    G_BLURR_COEFF_WIDTH          : positive                                                  := 8;
    -- Default: 3x3 Gaussian [1 2 1; 2 4 2; 1 2 1], tap0 at LSB.
    G_BLURR_KERNEL_COEFFS        : std_logic_vector(
      (G_BLURR_KERNEL_SIZE * G_BLURR_KERNEL_SIZE * G_BLURR_COEFF_WIDTH) - 1 downto 0) := x"010201020402010201";
    G_BLURR_NORMALIZE_DIVISOR    : positive                                                  := 16;
    G_BLURR_BIAS                 : integer                                                   := 0;

    G_SOBEL_THRESHOLD            : natural                                                   := 150;
    G_SOBEL_MEAN_SHIFT           : natural                                                   := 9;
    G_SOBEL_MEAN_UPDATE_INTERVAL : positive                                                  := 1;
    G_SOBEL_THRESHOLD_GAIN_NUM   : positive                                                  := 1;
    G_SOBEL_THRESHOLD_GAIN_DEN   : positive                                                  := 1;
    G_SOBEL_THRESHOLD_OFFSET     : integer                                                   := 0;
    G_EDGE_COLOR                 : std_logic_vector(23 downto 0)                             := x"FF0000"
  );
  port (
    i_aclk                     : in  std_logic;
    i_aresetn                  : in  std_logic;
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
    o_pass_fast                : out std_logic;
    o_led                      : out std_logic_vector(3 downto 0)
  );
end entity;

architecture A_RtlStruct of AXI_RgbGrayBlurrSobelOverlayPipeline is
  constant C_OVERLAY_NONE  : std_logic_vector(1 downto 0) := "00";
  constant C_OVERLAY_FAST  : std_logic_vector(1 downto 0) := "01";
  constant C_OVERLAY_SOBEL : std_logic_vector(1 downto 0) := "10";

  constant C_DELAY_SEL_NONE       : std_logic_vector(1 downto 0) := "00";
  constant C_DELAY_SEL_SOBEL      : std_logic_vector(1 downto 0) := "01";
  constant C_DELAY_SEL_BLUR_SOBEL : std_logic_vector(1 downto 0) := "10";

  constant C_SOBEL_KERNEL_SIZE : positive := 3;

  signal s_pass_grayscale    : std_logic := '0';
  signal s_pass_blurr_filter : std_logic := '1';
  signal s_pass_sobel        : std_logic := '1';
  signal s_pass_fast         : std_logic := '1';
  signal s_overlay_zeros     : std_logic := '1';

  signal s_fc_overlay_mode    : std_logic_vector(1 downto 0) := C_OVERLAY_NONE;
  signal s_fc_delay_stage_sel : std_logic_vector(1 downto 0) := C_DELAY_SEL_NONE;
  signal s_mode_pass_all      : std_logic                    := '1';
  signal s_mode_blur_only     : std_logic                    := '0';
  signal s_mode_overlay       : std_logic                    := '0';
  signal s_sobel_pass_through : std_logic                    := '1';

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

  signal s_sobel_tvalid    : std_logic                                          := '0';
  signal s_sobel_tready    : std_logic                                          := '0';
  signal s_sobel_tdata     : std_logic_vector(G_PIXEL_WIDTH - 1 downto 0)       := (others => '0');
  signal s_sobel_tuser     : std_logic                                          := '0';
  signal s_sobel_tlast     : std_logic                                          := '0';
  signal s_sobel_rbg_tdata : std_logic_vector((3 * G_PIXEL_WIDTH) - 1 downto 0) := (others => '0');

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

  signal s_overlay_tvalid : std_logic                                          := '0';
  signal s_overlay_tready : std_logic                                          := '0';
  signal s_overlay_tdata  : std_logic_vector((3 * G_PIXEL_WIDTH) - 1 downto 0) := (others => '0');
  signal s_overlay_tuser  : std_logic                                          := '0';
  signal s_overlay_tlast  : std_logic                                          := '0';

  signal s_selected_tvalid : std_logic                                          := '0';
  signal s_selected_tdata  : std_logic_vector((3 * G_PIXEL_WIDTH) - 1 downto 0) := (others => '0');
  signal s_selected_tuser  : std_logic                                          := '0';
  signal s_selected_tlast  : std_logic                                          := '0';
  signal s_output_idle     : boolean                                            := false;
begin
  assert G_BLURR_KERNEL_COEFFS'length = (G_BLURR_KERNEL_SIZE * G_BLURR_KERNEL_SIZE * G_BLURR_COEFF_WIDTH)
    report "AXI_Pipeline: G_BLURR_KERNEL_COEFFS length must equal G_BLURR_KERNEL_SIZE*G_BLURR_KERNEL_SIZE*G_BLURR_COEFF_WIDTH."
    severity failure;

  U_DebouncedClickDetector: entity work.DebouncedClickDetector
    generic map (
      G_CLK_FREQ_HZ => G_CLK_FREQ_HZ,
      G_DEBOUNCE_NS => G_DEBOUNCE_NS
    )
    port map (
      i_clk               => i_aclk,
      i_rst_n             => i_aresetn,
      i_btn               => i_btn,
      o_btn_debounced     => o_btn_debounced,
      o_btn2_debounced    => open,
      o_pass_grayscale    => s_pass_grayscale,
      o_pass_blurr_filter => s_pass_blurr_filter,
      o_pass_sobel        => s_pass_sobel,
      o_pass_fast         => s_pass_fast,
      o_overlay_zeros     => s_overlay_zeros,
      o_led               => o_led
    );

  o_pass_grayscale    <= s_pass_grayscale;
  o_pass_blurr_filter <= s_pass_blurr_filter;
  o_pass_sobel        <= s_pass_sobel;
  o_pass_fast         <= s_pass_fast;

  s_sobel_pass_through <= s_pass_sobel and s_pass_fast;

  s_fc_overlay_mode <= C_OVERLAY_FAST  when (s_pass_fast = '0') else
                       C_OVERLAY_SOBEL when (s_pass_sobel = '0') else
                       C_OVERLAY_NONE;

  -- Select compositor RGB delay tap according to active mask path latency.
  -- SOBEL/FAST overlays consume Sobel mask timing, BLUR+SOBEL needs the
  -- combined blur + sobel delay.
  s_fc_delay_stage_sel <= C_DELAY_SEL_BLUR_SOBEL when (s_pass_blurr_filter = '0' and s_pass_sobel = '0' and s_pass_fast = '1') else
                          C_DELAY_SEL_SOBEL      when (s_fc_overlay_mode /= C_OVERLAY_NONE) else
                          C_DELAY_SEL_NONE;

  s_mode_pass_all <= '1' when (s_pass_blurr_filter = '1' and s_pass_sobel = '1' and s_pass_fast = '1') else
                     '0';
  s_mode_blur_only <= '1' when (s_pass_blurr_filter = '0' and s_pass_sobel = '1' and s_pass_fast = '1') else
                      '0';
  s_mode_overlay <= '1' when s_fc_overlay_mode /= C_OVERLAY_NONE else
                    '0';

  U_AxiRgbToGrayscale: entity work.AXI_RgbToGrayscale
    generic map (
      G_COMPONENT_WIDTH => G_PIXEL_WIDTH
    )
    port map (
      i_aclk               => i_aclk,
      i_aresetn            => i_aresetn,
      i_pass_through       => s_pass_grayscale,
      s_axis_video_tvalid  => s_axis_video_rbg888_tvalid,
      s_axis_video_tready  => s_axis_video_rbg888_tready,
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
      i_aclk                => i_aclk,
      i_aresetn             => i_aresetn,
      i_pass_through        => s_pass_blurr_filter,
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
      G_SOBEL_THRESHOLD            => G_SOBEL_THRESHOLD,
      G_SOBEL_MEAN_SHIFT           => G_SOBEL_MEAN_SHIFT,
      G_SOBEL_MEAN_UPDATE_INTERVAL => G_SOBEL_MEAN_UPDATE_INTERVAL,
      G_SOBEL_THRESHOLD_GAIN_NUM   => G_SOBEL_THRESHOLD_GAIN_NUM,
      G_SOBEL_THRESHOLD_GAIN_DEN   => G_SOBEL_THRESHOLD_GAIN_DEN,
      G_SOBEL_THRESHOLD_OFFSET     => G_SOBEL_THRESHOLD_OFFSET,
      G_PIXEL_WIDTH                => G_PIXEL_WIDTH,
      G_KERNEL_SIZE                => 3,
      G_LINE_WIDTH                 => G_LINE_WIDTH,
      G_NUM_ROW                    => G_NUM_ROW
    )
    port map (
      i_aclk              => i_aclk,
      i_aresetn           => i_aresetn,
      i_pass_through      => s_sobel_pass_through,
      s_axis_gray8_tvalid => s_blurr_tvalid,
      s_axis_gray8_tready => s_blurr_tready,
      s_axis_gray8_tdata  => s_blurr_tdata,
      s_axis_gray8_tuser  => s_blurr_tuser,
      s_axis_gray8_tlast  => s_blurr_tlast,
      m_axis_gray8_tvalid => s_sobel_tvalid,
      m_axis_gray8_tready => s_sobel_tready,
      m_axis_gray8_tdata  => s_sobel_tdata,
      m_axis_gray8_tuser  => s_sobel_tuser,
      m_axis_gray8_tlast  => s_sobel_tlast
    );

  s_fc_rgb_tvalid <= s_rgb_stage_tvalid when s_mode_overlay = '1' else
                     '0';
  s_fc_rgb_tdata <= s_rgb_stage_tdata;
  s_fc_rgb_tuser <= s_rgb_stage_tuser;
  s_fc_rgb_tlast <= s_rgb_stage_tlast;

  s_fc_gray_tvalid <= s_sobel_tvalid when s_mode_overlay = '1' else
                      '0';
  s_fc_gray_tdata <= s_sobel_tdata;
  s_fc_gray_tuser <= s_sobel_tuser;
  s_fc_gray_tlast <= s_sobel_tlast;

  -- Route upstream READY according to selected output path.
  s_rgb_stage_tready <= s_fc_rgb_tready            when s_mode_overlay = '1' else
                        m_axis_video_rbg888_tready when s_mode_pass_all = '1' else
                        '1';
  s_sobel_tready <= s_fc_gray_tready           when s_mode_overlay = '1' else
                    m_axis_video_rbg888_tready when s_mode_blur_only = '1' else
                    '1';

  U_AxiFrameCompositor: entity work.AXI_FrameCompositor
    generic map (
      G_COMPONENT_WIDTH   => G_PIXEL_WIDTH,
      G_SOBEL_COLOR       => G_EDGE_COLOR,
      G_FAST_COLOR        => x"0000FF",
      G_LINE_WIDTH        => G_LINE_WIDTH,
      G_SOBEL_KERNEL_SIZE => C_SOBEL_KERNEL_SIZE,
      G_BLURR_KERNEL_SIZE => G_BLURR_KERNEL_SIZE
    )
    port map (
      i_aclk                     => i_aclk,
      i_aresetn                  => i_aresetn,
      i_overlay_zeros            => s_overlay_zeros,
      i_overlay_mode             => s_fc_overlay_mode,
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
      m_axis_video_rbg888_tvalid => s_overlay_tvalid,
      m_axis_video_rbg888_tready => s_overlay_tready,
      m_axis_video_rbg888_tdata  => s_overlay_tdata,
      m_axis_video_rbg888_tuser  => s_overlay_tuser,
      m_axis_video_rbg888_tlast  => s_overlay_tlast
    );

  s_overlay_tready <= m_axis_video_rbg888_tready when s_mode_overlay = '1' else
                      '1';

  s_sobel_rbg_tdata <= s_sobel_tdata & s_sobel_tdata & s_sobel_tdata;

  s_selected_tvalid <= s_overlay_tvalid when s_mode_overlay = '1' else
                       s_sobel_tvalid   when s_mode_blur_only = '1' else
                       s_rgb_stage_tvalid;
  s_selected_tdata <= s_overlay_tdata   when s_mode_overlay = '1' else
                      s_sobel_rbg_tdata when s_mode_blur_only = '1' else
                      s_rgb_stage_tdata;
  s_selected_tuser <= s_overlay_tuser when s_mode_overlay = '1' else
                      s_sobel_tuser   when s_mode_blur_only = '1' else
                      s_rgb_stage_tuser;
  s_selected_tlast <= s_overlay_tlast when s_mode_overlay = '1' else
                      s_sobel_tlast   when s_mode_blur_only = '1' else
                      s_rgb_stage_tlast;

  m_axis_video_rbg888_tvalid <= '0' when (i_aresetn = '0') else
                                s_selected_tvalid;

  s_output_idle            <= (i_aresetn = '0') or (s_selected_tvalid = '0');
  m_axis_video_rbg888_tdata <= (others => '0') when s_output_idle else
                              s_selected_tdata;
  m_axis_video_rbg888_tuser <= '0' when s_output_idle else
                               s_selected_tuser;
  m_axis_video_rbg888_tlast <= '0' when s_output_idle else
                               s_selected_tlast;
end architecture;
