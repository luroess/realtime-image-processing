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
  signal s_gray_data         : std_logic_vector(G_OUTPUT_WIDTH - 1 downto 0);
  signal s_cond_reset_tvalid : std_logic := '0';
begin
  U_RgbToGrayscale: entity work.E_RgbToGrayscale
    generic map (
      G_COMPONENT_WIDTH => G_COMPONENT_WIDTH,
      G_OUTPUT_WIDTH    => G_OUTPUT_WIDTH
    )
    port map (
      i_rgb888 => s_axis_video_tdata,
      o_gray8  => open,
      o_data   => s_gray_data
    );

  -- Transparent AXI4-Stream handshake and sideband forwarding.
  -- Data path is transformed by U_RgbToGrayscale.
  s_axis_video_tready <= '0' when i_aresetn /= '1' else m_axis_video_tready;
  m_axis_video_tvalid <= '0' when i_aresetn /= '1' else s_axis_video_tvalid;

  -- Keep outputs deterministic when idle/reset.
  s_cond_reset_tvalid <= (i_aresetn /= '1') or (s_axis_video_tvalid /= '1');
  m_axis_video_tdata  <= (others => '0') when s_cond_reset_tvalid else
                        s_gray_data;
  m_axis_video_tuser <= '0' when s_cond_reset_tvalid else
                        s_axis_video_tuser;
  m_axis_video_tlast <= '0' when s_cond_reset_tvalid else
                        s_axis_video_tlast;

end architecture;
