library ieee;
  use ieee.std_logic_1164.all;

entity AXI_RgbToGrayscale is
  generic (
    -- Bit-width per color component in the input RGB stream (R, G, B), as well as the output grayscale stream.
    G_COMPONENT_WIDTH : positive := 8
  );
  port (
    i_aclk               : in  std_logic;
    i_aresetn            : in  std_logic;
    -- when '1', output unmodified input pixel data instead of grayscale
    i_pass_through       : in  std_logic;

    -- AXI4-Stream Video Slave (input)
    s_axis_video_tvalid  : in  std_logic;
    s_axis_video_tready  : out std_logic;
    s_axis_video_tdata   : in  std_logic_vector((3 * G_COMPONENT_WIDTH) - 1 downto 0);
    s_axis_video_tuser   : in  std_logic; -- SOF
    s_axis_video_tlast   : in  std_logic; -- EOL

    -- AXI4-Stream RGB Master (output)
    -- i_pass_through='1' forwards input RBG, i_pass_through='0'
    m_axis_rbg888_tvalid : out std_logic;
    m_axis_rbg888_tready : in  std_logic;
    m_axis_rbg888_tdata  : out std_logic_vector((3 * G_COMPONENT_WIDTH) - 1 downto 0);
    m_axis_rbg888_tuser  : out std_logic; -- SOF
    m_axis_rbg888_tlast  : out std_logic; -- EOL

    -- AXI4-Stream Grayscale Master (output)
    m_axis_gray8_tvalid  : out std_logic;
    m_axis_gray8_tready  : in  std_logic;
    m_axis_gray8_tdata   : out std_logic_vector(G_COMPONENT_WIDTH - 1 downto 0);
    m_axis_gray8_tuser   : out std_logic; -- SOF
    m_axis_gray8_tlast   : out std_logic  -- EOL
  );
end entity;

architecture A_Rtl of AXI_RgbToGrayscale is
  signal s_gray8                  : std_logic_vector(G_COMPONENT_WIDTH - 1 downto 0);
  signal s_rbg888                 : std_logic_vector((3 * G_COMPONENT_WIDTH) - 1 downto 0);
  signal s_rbg888_tvalid          : std_logic;
  signal s_gray8_tvalid           : std_logic;
  signal s_cond_reset_tvalid_rgb  : boolean := false;
  signal s_cond_reset_tvalid_gray : boolean := false;
begin
  U_RgbToGrayscale: entity work.E_RgbToGrayscale
    generic map (
      G_COMPONENT_WIDTH => G_COMPONENT_WIDTH
    )
    port map (
      i_rgb888 => s_axis_video_tdata,
      o_gray8  => s_gray8,
      o_rbg888 => s_rbg888
    );

  -- Input beat is accepted only when both downstream interfaces are ready.
  s_axis_video_tready <= '0' when (i_aresetn = '0') else
                           (m_axis_rbg888_tready and m_axis_gray8_tready);

  -- Keep RGB valid behavior unchanged for backpressure visibility on this channel.
  s_rbg888_tvalid <= '0' when (i_aresetn = '0') else
                       (s_axis_video_tvalid and m_axis_gray8_tready);
  m_axis_rbg888_tvalid <= s_rbg888_tvalid;

  -- Gate gray valid with RGB ready to avoid consuming duplicated beats while RGB is stalled.
  s_gray8_tvalid <= '0' when (i_aresetn = '0') else
                      (s_axis_video_tvalid and m_axis_rbg888_tready);
  m_axis_gray8_tvalid <= s_gray8_tvalid;

  -- Keep outputs deterministic when idle/reset.
  s_cond_reset_tvalid_rgb  <= (i_aresetn = '0') or (s_rbg888_tvalid = '0');
  s_cond_reset_tvalid_gray <= (i_aresetn = '0') or (s_gray8_tvalid = '0');

  m_axis_rbg888_tdata <= (others => '0')   when s_cond_reset_tvalid_rgb else
                        s_axis_video_tdata when (i_pass_through = '1') else
                        s_rbg888;
  m_axis_rbg888_tuser <= '0' when s_cond_reset_tvalid_rgb else
                         s_axis_video_tuser;
  m_axis_rbg888_tlast <= '0' when s_cond_reset_tvalid_rgb else
                         s_axis_video_tlast;

  m_axis_gray8_tdata <= (others => '0') when s_cond_reset_tvalid_gray else
                       s_gray8;
  m_axis_gray8_tuser <= '0' when s_cond_reset_tvalid_gray else
                        s_axis_video_tuser;
  m_axis_gray8_tlast <= '0' when s_cond_reset_tvalid_gray else
                        s_axis_video_tlast;

  P_REG_CLK: process (i_aclk) is
    variable v_counter : integer := 0;
  begin
    if rising_edge(i_aclk) then
      if i_aresetn = '0' then
        v_counter := 0;
      else
        if v_counter = 10 then
          v_counter := 0;
          s_gray_data(23 downto 16) <= (others => '0');
          s_gray_data(15 downto 8) <= (others => '1');
          s_gray_data(7 downto 0) <= (others => '0');
        else
          s_gray_data <= s_gray_data_in;
          v_counter := v_counter + 1;
        end if;
      end if;
    end if;
  end process;

end architecture;
