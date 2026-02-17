library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity AXI_EdgeOverlay is
  generic (
    -- Pixel component width (typically 8 for R,G,B bytes).
    G_COMPONENT_WIDTH : positive                      := 8;
    -- Overlay replacement color, packed as 24-bit R|B|G payload.
    G_EDGE_COLOR      : std_logic_vector(23 downto 0) := x"FF0000"
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

    -- AXI4-Stream binary edge mask input
    s_axis_video_edges_tvalid  : in  std_logic;
    s_axis_video_edges_tready  : out std_logic;
    s_axis_video_edges_tdata   : in  std_logic;
    s_axis_video_edges_tuser   : in  std_logic; -- SOF
    s_axis_video_edges_tlast   : in  std_logic; -- EOL

    -- AXI4-Stream RGB output to AXI_VDMA
    m_axis_video_rbg888_tvalid : out std_logic;
    m_axis_video_rbg888_tready : in  std_logic;
    m_axis_video_rbg888_tdata  : out std_logic_vector((3 * G_COMPONENT_WIDTH) - 1 downto 0);
    m_axis_video_rbg888_tuser  : out std_logic; -- SOF
    m_axis_video_rbg888_tlast  : out std_logic  -- EOL
  );
end entity;

architecture A_Rtl of AXI_EdgeOverlay is
  -- Combined lockstep valid from both source channels.
  signal s_lockstep_valid : std_logic;
  -- Edge-lane verdict for the current beat.
  signal s_edge_detected : std_logic;
  -- Composed RGB payload from edge overlay core.
  signal s_overlay_pixel : std_logic_vector((3 * G_COMPONENT_WIDTH) - 1 downto 0);
  -- Output gating flag for reset/idle deterministic outputs.
  signal s_output_idle : boolean := false;
  -- synthesis translate_off
  signal s_lockstep_wait_ctr : natural range 0 to 1023 := 0;
  -- synthesis translate_on
begin
  s_lockstep_valid <= s_axis_video_rbg888_tvalid and s_axis_video_edges_tvalid;
  s_edge_detected  <= '1' when s_axis_video_edges_tdata = '1' else '0';

  U_EdgeOverlay: entity work.EdgeOverlay
    generic map (
      G_COMPONENT_WIDTH => G_COMPONENT_WIDTH,
      G_EDGE_COLOR      => G_EDGE_COLOR
    )
    port map (
      i_overlay_enable => i_overlay_enable,
      i_edge_detected  => s_edge_detected,
      i_video_rbg888   => s_axis_video_rbg888_tdata,
      o_video_rbg888   => s_overlay_pixel
    );

  -- Dual-input lockstep handshake.
  s_axis_video_rbg888_tready <= '0' when (i_aresetn = '0') else
                                  (m_axis_video_rbg888_tready and s_axis_video_edges_tvalid);
  s_axis_video_edges_tready <= '0' when (i_aresetn = '0') else
                                 (m_axis_video_rbg888_tready and s_axis_video_rbg888_tvalid);
  m_axis_video_rbg888_tvalid <= '0' when (i_aresetn = '0') else
                                s_lockstep_valid;

  s_output_idle <= (i_aresetn = '0') or (s_lockstep_valid = '0');

  -- Keep output deterministic when idle/reset.
  m_axis_video_rbg888_tdata <= (others => '0') when s_output_idle else
                              s_overlay_pixel;
  m_axis_video_rbg888_tuser <= '0' when s_output_idle else
                               s_axis_video_rbg888_tuser;
  m_axis_video_rbg888_tlast <= '0' when s_output_idle else
                               s_axis_video_rbg888_tlast;

  -- synthesis translate_off
  P_SIM_ASSERT_STREAM_ALIGNMENT: process (i_aclk)
  begin
    if rising_edge(i_aclk) then
      if i_aresetn = '1' and s_lockstep_valid = '1' then
        assert s_axis_video_rbg888_tuser = s_axis_video_edges_tuser
          report "AxiEdgeOverlay: SOF mismatch between RGB and edge streams."
          severity failure;
        assert s_axis_video_rbg888_tlast = s_axis_video_edges_tlast
          report "AxiEdgeOverlay: EOL mismatch between RGB and edge streams."
          severity failure;
      end if;
    end if;
  end process;
  -- synthesis translate_on

  -- synthesis translate_off
  P_SIM_ASSERT_LOCKSTEP_PROGRESS: process (i_aclk)
  begin
    if rising_edge(i_aclk) then
      if i_aresetn = '0' then
        s_lockstep_wait_ctr <= 0;
      elsif m_axis_video_rbg888_tready = '1'
        and ((s_axis_video_rbg888_tvalid = '1' and s_axis_video_edges_tvalid = '0')
          or (s_axis_video_rbg888_tvalid = '0' and s_axis_video_edges_tvalid = '1')) then
        if s_lockstep_wait_ctr < 1023 then
          s_lockstep_wait_ctr <= s_lockstep_wait_ctr + 1;
        end if;
        assert s_lockstep_wait_ctr < 256
          report "AxiEdgeOverlay: prolonged one-sided valid observed; possible lockstep deadlock."
          severity failure;
      else
        s_lockstep_wait_ctr <= 0;
      end if;
    end if;
  end process;
  -- synthesis translate_on
end architecture;
