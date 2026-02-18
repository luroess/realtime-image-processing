library ieee;
use ieee.std_logic_1164.all;

-- Deprecated legacy AXI wrapper: use FRAME_COMPOSITOR/AXI_FrameCompositor instead.
entity AXI_EdgeOverlay is
  generic (
    G_COMPONENT_WIDTH : positive := 8;
    G_EDGE_COLOR      : std_logic_vector(23 downto 0) := x"FF0000"
  );
  port (
    i_aclk                     : in  std_logic;
    i_aresetn                  : in  std_logic;
    i_overlay_enable           : in  std_logic;

    s_axis_video_rbg888_tvalid : in  std_logic;
    s_axis_video_rbg888_tready : out std_logic;
    s_axis_video_rbg888_tdata  : in  std_logic_vector((3 * G_COMPONENT_WIDTH) - 1 downto 0);
    s_axis_video_rbg888_tuser  : in  std_logic;
    s_axis_video_rbg888_tlast  : in  std_logic;

    s_axis_video_edges_tvalid  : in  std_logic;
    s_axis_video_edges_tready  : out std_logic;
    s_axis_video_edges_tdata   : in  std_logic;
    s_axis_video_edges_tuser   : in  std_logic;
    s_axis_video_edges_tlast   : in  std_logic;

    m_axis_video_rbg888_tvalid : out std_logic;
    m_axis_video_rbg888_tready : in  std_logic;
    m_axis_video_rbg888_tdata  : out std_logic_vector((3 * G_COMPONENT_WIDTH) - 1 downto 0);
    m_axis_video_rbg888_tuser  : out std_logic;
    m_axis_video_rbg888_tlast  : out std_logic
  );
end entity;

architecture A_Rtl of AXI_EdgeOverlay is
  signal s_lockstep_valid : std_logic;
  signal s_overlay_pixel  : std_logic_vector((3 * G_COMPONENT_WIDTH) - 1 downto 0);
begin
  s_lockstep_valid <= s_axis_video_rbg888_tvalid and s_axis_video_edges_tvalid;

  U_EdgeOverlay: entity work.EdgeOverlay
    generic map (
      G_COMPONENT_WIDTH => G_COMPONENT_WIDTH,
      G_EDGE_COLOR      => G_EDGE_COLOR
    )
    port map (
      i_overlay_enable => i_overlay_enable,
      i_edge_detected  => s_axis_video_edges_tdata,
      i_video_rbg888   => s_axis_video_rbg888_tdata,
      o_video_rbg888   => s_overlay_pixel
    );

  s_axis_video_rbg888_tready <= '0' when i_aresetn = '0' else
                                  (m_axis_video_rbg888_tready and s_axis_video_edges_tvalid);
  s_axis_video_edges_tready <= '0' when i_aresetn = '0' else
                                 (m_axis_video_rbg888_tready and s_axis_video_rbg888_tvalid);

  m_axis_video_rbg888_tvalid <= '0' when i_aresetn = '0' else s_lockstep_valid;
  m_axis_video_rbg888_tdata  <= (others => '0') when (i_aresetn = '0' or s_lockstep_valid = '0') else s_overlay_pixel;
  m_axis_video_rbg888_tuser  <= '0' when (i_aresetn = '0' or s_lockstep_valid = '0') else s_axis_video_rbg888_tuser;
  m_axis_video_rbg888_tlast  <= '0' when (i_aresetn = '0' or s_lockstep_valid = '0') else s_axis_video_rbg888_tlast;
end architecture;
