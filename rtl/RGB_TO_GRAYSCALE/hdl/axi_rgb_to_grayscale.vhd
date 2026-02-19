library ieee;
  use ieee.std_logic_1164.all;

entity AXI_RgbToGrayscale is
  generic (
    -- Bit-width per color component in the input RBG stream (R, B, G), as well as the output grayscale stream.
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
  signal s_gray8_comb  : std_logic_vector(G_COMPONENT_WIDTH - 1 downto 0)       := (others => '0');
  signal s_rbg888_comb : std_logic_vector((3 * G_COMPONENT_WIDTH) - 1 downto 0) := (others => '0');

  signal s_pixel_reg     : std_logic_vector((3 * G_COMPONENT_WIDTH) - 1 downto 0) := (others => '0');
  signal s_sof_reg       : std_logic                                              := '0';
  signal s_eol_reg       : std_logic                                              := '0';
  signal s_pass_mode_reg : std_logic                                              := '0';
  signal s_valid_reg     : std_logic                                              := '0';
  signal s_rgb_sent_reg  : std_logic                                              := '0';
  signal s_gray_sent_reg : std_logic                                              := '0';

  signal s_rgb_tvalid      : std_logic := '0';
  signal s_gray_tvalid     : std_logic := '0';
  signal s_input_slot_free : std_logic := '0';
begin
  U_RgbToGrayscale: entity work.E_RgbToGrayscale
    generic map (
      G_COMPONENT_WIDTH => G_COMPONENT_WIDTH
    )
    port map (
      i_rgb888 => s_pixel_reg,
      o_gray8  => s_gray8_comb,
      o_rbg888 => s_rbg888_comb
    );

  -- Present one pending beat and let each output acknowledge it independently.
  s_rgb_tvalid <= '1' when (i_aresetn = '1' and s_valid_reg = '1' and s_rgb_sent_reg = '0') else
                  '0';
  s_gray_tvalid <= '1' when (i_aresetn = '1' and s_valid_reg = '1' and s_gray_sent_reg = '0') else
                   '0';

  -- Input can advance when no beat is pending, or when the pending beat is
  -- guaranteed to be fully consumed in this cycle.
  s_input_slot_free <= '1' when (s_valid_reg = '0') else
                       '1' when (((s_rgb_sent_reg = '1') or (m_axis_rbg888_tready = '1')) and ((s_gray_sent_reg = '1') or (m_axis_gray8_tready = '1'))) else
                       '0';

  s_axis_video_tready <= '1' when (i_aresetn = '1' and s_input_slot_free = '1') else
                         '0';

  P_REG_STREAM: process (i_aclk)
    variable v_rgb_fire       : std_logic := '0';
    variable v_gray_fire      : std_logic := '0';
    variable v_rgb_sent_next  : std_logic := '0';
    variable v_gray_sent_next : std_logic := '0';
    variable v_slot_free      : std_logic := '0';
    variable v_in_fire        : std_logic := '0';
  begin
    if rising_edge(i_aclk) then
      if i_aresetn = '0' then
        s_pixel_reg <= (others => '0');
        s_sof_reg <= '0';
        s_eol_reg <= '0';
        s_pass_mode_reg <= '0';
        s_valid_reg <= '0';
        s_rgb_sent_reg <= '0';
        s_gray_sent_reg <= '0';
      else
        v_rgb_fire := '0';
        v_gray_fire := '0';
        if (s_valid_reg = '1') and (s_rgb_sent_reg = '0') and (m_axis_rbg888_tready = '1') then
          v_rgb_fire := '1';
        end if;
        if (s_valid_reg = '1') and (s_gray_sent_reg = '0') and (m_axis_gray8_tready = '1') then
          v_gray_fire := '1';
        end if;

        if (s_rgb_sent_reg = '1') or (v_rgb_fire = '1') then
          v_rgb_sent_next := '1';
        else
          v_rgb_sent_next := '0';
        end if;

        if (s_gray_sent_reg = '1') or (v_gray_fire = '1') then
          v_gray_sent_next := '1';
        else
          v_gray_sent_next := '0';
        end if;

        if (s_valid_reg = '0') or ((v_rgb_sent_next = '1') and (v_gray_sent_next = '1')) then
          v_slot_free := '1';
        else
          v_slot_free := '0';
        end if;

        if (s_axis_video_tvalid = '1') and (v_slot_free = '1') then
          v_in_fire := '1';
        else
          v_in_fire := '0';
        end if;

        if v_in_fire = '1' then
          s_pixel_reg <= s_axis_video_tdata;
          s_sof_reg <= s_axis_video_tuser;
          s_eol_reg <= s_axis_video_tlast;
          s_pass_mode_reg <= i_pass_through;
          s_valid_reg <= '1';
          s_rgb_sent_reg <= '0';
          s_gray_sent_reg <= '0';
        elsif s_valid_reg = '1' then
          if (v_rgb_sent_next = '1') and (v_gray_sent_next = '1') then
            s_valid_reg <= '0';
            s_rgb_sent_reg <= '0';
            s_gray_sent_reg <= '0';
          else
            s_rgb_sent_reg <= v_rgb_sent_next;
            s_gray_sent_reg <= v_gray_sent_next;
          end if;
        end if;
      end if;
    end if;
  end process;

  m_axis_rbg888_tvalid <= s_rgb_tvalid;
  m_axis_gray8_tvalid  <= s_gray_tvalid;

  m_axis_rbg888_tdata <= (others => '0') when s_rgb_tvalid = '0' else
                        s_pixel_reg      when s_pass_mode_reg = '1' else
                        s_rbg888_comb;
  m_axis_rbg888_tuser <= '0' when s_rgb_tvalid = '0' else
                         s_sof_reg;
  m_axis_rbg888_tlast <= '0' when s_rgb_tvalid = '0' else
                         s_eol_reg;

  m_axis_gray8_tdata <= (others => '0') when s_gray_tvalid = '0' else
                       s_gray8_comb;
  m_axis_gray8_tuser <= '0' when s_gray_tvalid = '0' else
                        s_sof_reg;
  m_axis_gray8_tlast <= '0' when s_gray_tvalid = '0' else
                        s_eol_reg;
end architecture;
