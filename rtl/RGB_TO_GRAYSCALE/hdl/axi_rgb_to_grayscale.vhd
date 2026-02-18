library ieee;
use ieee.std_logic_1164.all;

entity AXI_RgbToGrayscale is
  generic (
    G_COMPONENT_WIDTH : positive := 8
  );
  port (
    i_aclk               : in  std_logic;
    i_aresetn            : in  std_logic;
    i_pass_through       : in  std_logic;

    s_axis_video_tvalid  : in  std_logic;
    s_axis_video_tready  : out std_logic;
    s_axis_video_tdata   : in  std_logic_vector((3 * G_COMPONENT_WIDTH) - 1 downto 0);
    s_axis_video_tuser   : in  std_logic;
    s_axis_video_tlast   : in  std_logic;

    m_axis_rbg888_tvalid : out std_logic;
    m_axis_rbg888_tready : in  std_logic;
    m_axis_rbg888_tdata  : out std_logic_vector((3 * G_COMPONENT_WIDTH) - 1 downto 0);
    m_axis_rbg888_tuser  : out std_logic;
    m_axis_rbg888_tlast  : out std_logic;

    m_axis_gray8_tvalid  : out std_logic;
    m_axis_gray8_tready  : in  std_logic;
    m_axis_gray8_tdata   : out std_logic_vector(G_COMPONENT_WIDTH - 1 downto 0);
    m_axis_gray8_tuser   : out std_logic;
    m_axis_gray8_tlast   : out std_logic
  );
end entity;

architecture A_Rtl of AXI_RgbToGrayscale is
  signal s_gray8_comb : std_logic_vector(G_COMPONENT_WIDTH - 1 downto 0);

  signal s_buf_valid : std_logic := '0';
  signal s_buf_rgb   : std_logic_vector((3 * G_COMPONENT_WIDTH) - 1 downto 0) := (others => '0');
  signal s_buf_gray  : std_logic_vector(G_COMPONENT_WIDTH - 1 downto 0) := (others => '0');
  signal s_buf_user  : std_logic := '0';
  signal s_buf_last  : std_logic := '0';

  signal s_buf_ready      : std_logic := '0';
  signal s_lockstep_ready : std_logic := '0';
begin
  -- i_pass_through is intentionally retained for interface compatibility.
  -- RGB output now always forwards original RGB input alongside gray output.
  assert i_pass_through = i_pass_through
    report "i_pass_through is retained for compatibility only."
    severity note;

  U_RgbToGrayscale: entity work.E_RgbToGrayscale
    generic map (
      G_COMPONENT_WIDTH => G_COMPONENT_WIDTH
    )
    port map (
      i_rgb888 => s_axis_video_tdata,
      o_gray8  => s_gray8_comb,
      o_rbg888 => open
    );

  s_lockstep_ready <= '1' when (m_axis_rbg888_tready = '1') and
                               (m_axis_gray8_tready = '1') else
                      '0';

  s_buf_ready <= '1' when (i_aresetn = '1') and
                           ((s_buf_valid = '0') or (s_lockstep_ready = '1')) else
                 '0';

  s_axis_video_tready <= s_buf_ready;

  P_REG_BROADCAST : process (i_aclk)
  begin
    if rising_edge(i_aclk) then
      if i_aresetn = '0' then
        s_buf_valid <= '0';
        s_buf_rgb   <= (others => '0');
        s_buf_gray  <= (others => '0');
        s_buf_user  <= '0';
        s_buf_last  <= '0';
      elsif s_buf_ready = '1' then
        if s_axis_video_tvalid = '1' then
          s_buf_valid <= '1';
          s_buf_rgb   <= s_axis_video_tdata;
          s_buf_gray  <= s_gray8_comb;
          s_buf_user  <= s_axis_video_tuser;
          s_buf_last  <= s_axis_video_tlast;
        else
          s_buf_valid <= '0';
          s_buf_user  <= '0';
          s_buf_last  <= '0';
        end if;
      end if;
    end if;
  end process;

  m_axis_rbg888_tvalid <= s_buf_valid and s_lockstep_ready;
  m_axis_gray8_tvalid  <= s_buf_valid and s_lockstep_ready;

  m_axis_rbg888_tdata <= s_buf_rgb when s_buf_valid = '1' else (others => '0');
  m_axis_rbg888_tuser <= s_buf_user when s_buf_valid = '1' else '0';
  m_axis_rbg888_tlast <= s_buf_last when s_buf_valid = '1' else '0';

  m_axis_gray8_tdata <= s_buf_gray when s_buf_valid = '1' else (others => '0');
  m_axis_gray8_tuser <= s_buf_user when s_buf_valid = '1' else '0';
  m_axis_gray8_tlast <= s_buf_last when s_buf_valid = '1' else '0';
end architecture;
