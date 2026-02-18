library ieee;
  use ieee.std_logic_1164.all;

entity AXI_EdgeOverlay is
  generic (
    -- Pixel component width (typically 8 for R,G,B bytes).
    G_COMPONENT_WIDTH : positive                                         := 8;
    -- Overlay replacement color, packed as R|B|G payload (default: full red).
    G_EDGE_COLOR  : std_logic_vector((3 * G_COMPONENT_WIDTH) - 1 downto 0) :=
                    ((3 * G_COMPONENT_WIDTH) - 1 downto (2 * G_COMPONENT_WIDTH) => '1',
                     others => '0')
  );
  port (
    -- AXI4-Stream clock and lockstep reset.
    i_aclk                     : in  std_logic;
    -- Active-low reset for deterministic IDLE outputs and protocol gates.
    i_aresetn                  : in  std_logic;
    -- Runtime control: 1 = overlay enabled, 0 = passthrough.
    i_overlay_enable           : in  std_logic;

    -- AXI4-Stream RGB input from AXI_RgbToGrayscale
    s_axis_video_rbg888_tvalid : in  std_logic;
    s_axis_video_rbg888_tready : out std_logic;
    s_axis_video_rbg888_tdata  : in  std_logic_vector((3 * G_COMPONENT_WIDTH) - 1 downto 0);
    s_axis_video_rbg888_tuser  : in  std_logic; -- SOF
    s_axis_video_rbg888_tlast  : in  std_logic; -- EOL

    -- AXI4-Stream edge input -- Sobel output stream / passthrough
    -- Non-zero payload is treated as edge detected.
    s_axis_rbg888_tvalid  : in  std_logic;
    s_axis_rbg888_tready  : out std_logic;
    s_axis_rbg888_tdata   : in  std_logic_vector((3 * G_COMPONENT_WIDTH) - 1 downto 0);
    s_axis_rbg888_tuser   : in  std_logic; -- SOF
    s_axis_rbg888_tlast   : in  std_logic; -- EOL

    -- AXI4-Stream RGB output to AXI_VDMA
    m_axis_video_rbg888_tvalid : out std_logic;
    m_axis_video_rbg888_tready : in  std_logic;
    m_axis_video_rbg888_tdata  : out std_logic_vector((3 * G_COMPONENT_WIDTH) - 1 downto 0);
    m_axis_video_rbg888_tuser  : out std_logic; -- SOF
    m_axis_video_rbg888_tlast  : out std_logic  -- EOL
  );
end entity;

architecture A_Rtl of AXI_EdgeOverlay is
  -- Output gating flag for reset/idle deterministic outputs.
  signal s_output_idle : boolean := false;
begin
  -- Temporary behavior: bypass overlay/masking and forward Sobel pixels.
  -- TODO: Re-enable edge masking only after adding frame-alignment architecture
  -- between base-stream and edge-mask
  s_axis_video_rbg888_tready <= '0' when (i_aresetn = '0') else
                                  m_axis_video_rbg888_tready;
  -- Keep edge-stream advancement aligned with base-stream handshake, even in bypass.
  s_axis_rbg888_tready <= '0' when (i_aresetn = '0') else
                         (m_axis_video_rbg888_tready and s_axis_video_rbg888_tvalid);
  m_axis_video_rbg888_tvalid <= '0' when (i_aresetn = '0') else
                                s_axis_video_rbg888_tvalid;

  s_output_idle <= (i_aresetn = '0') or (s_axis_video_rbg888_tvalid = '0');

  -- Keep output deterministic when idle/reset.
  m_axis_video_rbg888_tdata <= (others => '0') when s_output_idle else
                              s_axis_video_rbg888_tdata;
  m_axis_video_rbg888_tuser <= '0' when s_output_idle else
                               s_axis_video_rbg888_tuser;
  m_axis_video_rbg888_tlast <= '0' when s_output_idle else
                               s_axis_video_rbg888_tlast;
end architecture;
