library ieee;
  use ieee.std_logic_1164.all;

entity AXI_FrameCompositor is
  generic (
    G_COMPONENT_WIDTH : positive                      := 8;
    G_SOBEL_COLOR     : std_logic_vector(23 downto 0) := x"FF0000";
    G_FAST_COLOR      : std_logic_vector(23 downto 0) := x"0000FF"
  );
  port (
    i_aclk                     : in  std_logic;
    i_aresetn                  : in  std_logic;
    i_base_mode                : in  std_logic_vector(1 downto 0);
    i_overlay_mode             : in  std_logic_vector(1 downto 0);

    s_axis_video_rbg888_tvalid : in  std_logic;
    s_axis_video_rbg888_tready : out std_logic;
    s_axis_video_rbg888_tdata  : in  std_logic_vector((3 * G_COMPONENT_WIDTH) - 1 downto 0);
    s_axis_video_rbg888_tuser  : in  std_logic;
    s_axis_video_rbg888_tlast  : in  std_logic;

    s_axis_video_gray8_tvalid  : in  std_logic;
    s_axis_video_gray8_tready  : out std_logic;
    s_axis_video_gray8_tdata   : in  std_logic_vector(G_COMPONENT_WIDTH - 1 downto 0);
    s_axis_video_gray8_tuser   : in  std_logic;
    s_axis_video_gray8_tlast   : in  std_logic;

    s_axis_video_sobel_tvalid  : in  std_logic;
    s_axis_video_sobel_tready  : out std_logic;
    s_axis_video_sobel_tdata   : in  std_logic;
    s_axis_video_sobel_tuser   : in  std_logic;
    s_axis_video_sobel_tlast   : in  std_logic;

    s_axis_video_fast_tvalid   : in  std_logic;
    s_axis_video_fast_tready   : out std_logic;
    s_axis_video_fast_tdata    : in  std_logic;
    s_axis_video_fast_tuser    : in  std_logic;
    s_axis_video_fast_tlast    : in  std_logic;

    m_axis_video_rbg888_tvalid : out std_logic;
    m_axis_video_rbg888_tready : in  std_logic;
    m_axis_video_rbg888_tdata  : out std_logic_vector((3 * G_COMPONENT_WIDTH) - 1 downto 0);
    m_axis_video_rbg888_tuser  : out std_logic;
    m_axis_video_rbg888_tlast  : out std_logic
  );
end entity;

architecture A_Rtl of AXI_FrameCompositor is
  signal s_rgb_valid : std_logic                                              := '0';
  signal s_rgb_data  : std_logic_vector((3 * G_COMPONENT_WIDTH) - 1 downto 0) := (others => '0');
  signal s_rgb_user  : std_logic                                              := '0';
  signal s_rgb_last  : std_logic                                              := '0';

  signal s_gray_valid : std_logic                                        := '0';
  signal s_gray_data  : std_logic_vector(G_COMPONENT_WIDTH - 1 downto 0) := (others => '0');
  signal s_gray_user  : std_logic                                        := '0';
  signal s_gray_last  : std_logic                                        := '0';

  signal s_sobel_valid : std_logic := '0';
  signal s_sobel_data  : std_logic := '0';
  signal s_sobel_user  : std_logic := '0';
  signal s_sobel_last  : std_logic := '0';

  signal s_fast_valid : std_logic := '0';
  signal s_fast_data  : std_logic := '0';
  signal s_fast_user  : std_logic := '0';
  signal s_fast_last  : std_logic := '0';

  signal s_rgb_ready   : std_logic := '0';
  signal s_gray_ready  : std_logic := '0';
  signal s_sobel_ready : std_logic := '0';
  signal s_fast_ready  : std_logic := '0';

  signal s_all_valid : std_logic                                              := '0';
  signal s_pop       : std_logic                                              := '0';
  signal s_out_rgb   : std_logic_vector((3 * G_COMPONENT_WIDTH) - 1 downto 0) := (others => '0');
begin
  s_all_valid <= s_rgb_valid and s_gray_valid and s_sobel_valid and s_fast_valid;
  s_pop       <= '1' when (i_aresetn = '1') and (m_axis_video_rbg888_tready = '1') and (s_all_valid = '1') else
                 '0';

  s_rgb_ready   <= '1' when (i_aresetn = '1') and ((s_rgb_valid = '0') or (s_pop = '1')) else '0';
  s_gray_ready  <= '1' when (i_aresetn = '1') and ((s_gray_valid = '0') or (s_pop = '1')) else '0';
  s_sobel_ready <= '1' when (i_aresetn = '1') and ((s_sobel_valid = '0') or (s_pop = '1')) else '0';
  s_fast_ready  <= '1' when (i_aresetn = '1') and ((s_fast_valid = '0') or (s_pop = '1')) else '0';

  s_axis_video_rbg888_tready <= s_rgb_ready;
  s_axis_video_gray8_tready  <= s_gray_ready;
  s_axis_video_sobel_tready  <= s_sobel_ready;
  s_axis_video_fast_tready   <= s_fast_ready;

  P_REG_INPUT_STAGE: process (i_aclk)
  begin
    if rising_edge(i_aclk) then
      if i_aresetn = '0' then
        s_rgb_valid <= '0';
        s_gray_valid <= '0';
        s_sobel_valid <= '0';
        s_fast_valid <= '0';

        s_rgb_data <= (others => '0');
        s_gray_data <= (others => '0');
        s_sobel_data <= '0';
        s_fast_data <= '0';

        s_rgb_user <= '0';
        s_gray_user <= '0';
        s_sobel_user <= '0';
        s_fast_user <= '0';

        s_rgb_last <= '0';
        s_gray_last <= '0';
        s_sobel_last <= '0';
        s_fast_last <= '0';
      else
        if s_rgb_ready = '1' then
          if s_axis_video_rbg888_tvalid = '1' then
            s_rgb_valid <= '1';
            s_rgb_data <= s_axis_video_rbg888_tdata;
            s_rgb_user <= s_axis_video_rbg888_tuser;
            s_rgb_last <= s_axis_video_rbg888_tlast;
          else
            s_rgb_valid <= '0';
            s_rgb_user <= '0';
            s_rgb_last <= '0';
          end if;
        end if;

        if s_gray_ready = '1' then
          if s_axis_video_gray8_tvalid = '1' then
            s_gray_valid <= '1';
            s_gray_data <= s_axis_video_gray8_tdata;
            s_gray_user <= s_axis_video_gray8_tuser;
            s_gray_last <= s_axis_video_gray8_tlast;
          else
            s_gray_valid <= '0';
            s_gray_user <= '0';
            s_gray_last <= '0';
          end if;
        end if;

        if s_sobel_ready = '1' then
          if s_axis_video_sobel_tvalid = '1' then
            s_sobel_valid <= '1';
            s_sobel_data <= s_axis_video_sobel_tdata;
            s_sobel_user <= s_axis_video_sobel_tuser;
            s_sobel_last <= s_axis_video_sobel_tlast;
          else
            s_sobel_valid <= '0';
            s_sobel_user <= '0';
            s_sobel_last <= '0';
          end if;
        end if;

        if s_fast_ready = '1' then
          if s_axis_video_fast_tvalid = '1' then
            s_fast_valid <= '1';
            s_fast_data <= s_axis_video_fast_tdata;
            s_fast_user <= s_axis_video_fast_tuser;
            s_fast_last <= s_axis_video_fast_tlast;
          else
            s_fast_valid <= '0';
            s_fast_user <= '0';
            s_fast_last <= '0';
          end if;
        end if;
      end if;
    end if;
  end process;

  U_FrameCompositor: entity work.FrameCompositor
    generic map (
      G_COMPONENT_WIDTH => G_COMPONENT_WIDTH,
      G_SOBEL_COLOR     => G_SOBEL_COLOR,
      G_FAST_COLOR      => G_FAST_COLOR
    )
    port map (
      i_base_mode    => i_base_mode,
      i_overlay_mode => i_overlay_mode,
      i_rgb888       => s_rgb_data,
      i_gray8        => s_gray_data,
      i_sobel_edge   => s_sobel_data,
      i_fast_edge    => s_fast_data,
      o_rgb888       => s_out_rgb
    );

  m_axis_video_rbg888_tvalid <= '0' when i_aresetn = '0' else s_all_valid;
  m_axis_video_rbg888_tdata  <= s_out_rgb when (i_aresetn = '1' and s_all_valid = '1') else (others => '0');
  m_axis_video_rbg888_tuser  <= s_rgb_user when (i_aresetn = '1' and s_all_valid = '1') else '0';
  m_axis_video_rbg888_tlast  <= s_rgb_last when (i_aresetn = '1' and s_all_valid = '1') else '0';
end architecture;
