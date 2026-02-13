library ieee;
  use ieee.std_logic_1164.all;

entity AXI_RgbToGrayscale is
  generic (
    -- Bit-width per color component in the input RGB stream.
    G_COMPONENT_WIDTH : positive := 8;
    -- Output data width:
    -- - G_COMPONENT_WIDTH => mono gray
    -- - 3*G_COMPONENT_WIDTH => GrayRGB (R=G=B=Y)
    G_OUTPUT_WIDTH    : positive := 24
  );
  port (
    i_aclk              : in  std_logic;
    i_aresetn           : in  std_logic;
    -- when '1', output unmodified input pixel data instead of grayscale (for testing/debugging)
    i_pass_through      : in  std_logic;

    -- AXI4-Stream Video Slave (input)
    s_axis_video_tvalid : in  std_logic;
    s_axis_video_tready : out std_logic;
    s_axis_video_tdata  : in  std_logic_vector((3 * G_COMPONENT_WIDTH) - 1 downto 0);
    s_axis_video_tuser  : in  std_logic; -- SOF
    s_axis_video_tlast  : in  std_logic; -- EOL

    -- AXI4-Stream Video Master (output)
    m_axis_video_tvalid : out std_logic;
    m_axis_video_tready : in  std_logic;
    m_axis_video_tdata  : out std_logic_vector(G_OUTPUT_WIDTH - 1 downto 0);
    m_axis_video_tuser  : out std_logic; -- SOF
    m_axis_video_tlast  : out std_logic  -- EOL
  );
end entity;

architecture A_Rtl of AXI_RgbToGrayscale is
  constant C_RGB_WIDTH : positive := 3 * G_COMPONENT_WIDTH;
  signal s_gray_data : std_logic_vector(G_OUTPUT_WIDTH - 1 downto 0);
  signal s_out_data  : std_logic_vector(G_OUTPUT_WIDTH - 1 downto 0);
begin
  U_RgbToGrayscale: entity work.RgbToGrayscale
    generic map (
      G_COMPONENT_WIDTH => G_COMPONENT_WIDTH,
      G_OUTPUT_WIDTH    => G_OUTPUT_WIDTH
    )
    port map (
      i_rgb888 => s_axis_video_tdata,
      o_gray8  => open,
      o_data   => s_gray_data
    );

  -- Output selection:
  -- * RGB-width mode: runtime switch between passthrough and grayscale.
  -- * Mono-width mode: grayscale only.
  G_RGB_OUTPUT: if G_OUTPUT_WIDTH = C_RGB_WIDTH generate
    s_out_data <= s_axis_video_tdata when i_pass_through = '1' else s_gray_data;
  end generate;

  G_MONO_OUTPUT: if G_OUTPUT_WIDTH = G_COMPONENT_WIDTH generate
    s_out_data <= s_gray_data;
  end generate;

  G_FALLBACK_OUTPUT: if (G_OUTPUT_WIDTH /= C_RGB_WIDTH) and (G_OUTPUT_WIDTH /= G_COMPONENT_WIDTH) generate
    s_out_data <= s_gray_data;
  end generate;

  -- Transparent AXI4-Stream handshake and sideband forwarding.
  -- Data path is transformed by U_RgbToGrayscale.
  s_axis_video_tready <= '0' when i_aresetn /= '1' else m_axis_video_tready;
  m_axis_video_tvalid <= '0' when i_aresetn /= '1' else s_axis_video_tvalid;

  -- Keep outputs deterministic when idle/reset.
  m_axis_video_tdata <= (others => '0') when (i_aresetn /= '1') or (s_axis_video_tvalid /= '1') else
                       s_out_data;
  m_axis_video_tuser <= '0' when (i_aresetn /= '1') or (s_axis_video_tvalid /= '1') else
                        s_axis_video_tuser;
  m_axis_video_tlast <= '0' when (i_aresetn /= '1') or (s_axis_video_tvalid /= '1') else
                        s_axis_video_tlast;
end architecture;
