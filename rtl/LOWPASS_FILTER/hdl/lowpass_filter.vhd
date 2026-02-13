library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity LowpassFilter is
  generic (
    G_PIXEL_WIDTH : integer := 8
  );
  port (
    clk   : in std_logic;
    rst_n : in std_logic;

    -- AXI SLAVE
    s_axis_lowpass_tvalid : in std_logic;
    s_axis_lowpass_tready : out std_logic;
    s_axis_lowpass_tdata  : in std_logic_vector (9 * G_PIXEL_WIDTH - 1 downto 0);
    s_axis_lowpass_tlast  : in std_logic;
    s_axis_lowpass_tuser  : in std_logic;

    -- AXI MASTER
    m_axis_lowpass_tready : in std_logic;
    m_axis_lowpass_tvalid : out std_logic;
    m_axis_lowpass_tdata  : out std_logic_vector (G_PIXEL_WIDTH - 1 downto 0);
    m_axis_lowpass_tlast  : out std_logic;
    m_axis_lowpass_tuser  : out std_logic
  );
end entity;

architecture A_Rtl of LowpassFilter is
  type t_state is (IDLE, FILTER_OUTPUT);

  signal r_state : t_state := IDLE;

  signal r_m_tvalid : std_logic                                    := '0';
  signal r_m_tdata  : std_logic_vector(G_PIXEL_WIDTH - 1 downto 0) := (others => '0');
  signal r_m_tlast  : std_logic                                    := '0';
  signal r_m_tuser  : std_logic                                    := '0';

  function f_lowpass_avg_3x3(
    i_window : std_logic_vector(9 * G_PIXEL_WIDTH - 1 downto 0)
  ) return std_logic_vector is
    variable v_sum   : integer := 0;
    variable v_pixel : unsigned(G_PIXEL_WIDTH - 1 downto 0);
    variable v_avg   : integer := 0;
  begin
    v_sum := 0;
    for i in 0 to 8 loop
      v_pixel := unsigned(i_window((i + 1) * G_PIXEL_WIDTH - 1 downto i * G_PIXEL_WIDTH));
      v_sum   := v_sum + to_integer(v_pixel);
    end loop;

    v_avg := v_sum / 9;
    return std_logic_vector(to_unsigned(v_avg, G_PIXEL_WIDTH));
  end function;

begin
  s_axis_lowpass_tready <= '1' when (rst_n = '1') and (r_state = IDLE) else
    '0';

  m_axis_lowpass_tvalid <= r_m_tvalid;
  m_axis_lowpass_tdata  <= r_m_tdata;
  m_axis_lowpass_tlast  <= r_m_tlast;
  m_axis_lowpass_tuser  <= r_m_tuser;

  p_fsm : process (clk)
  begin
    if rising_edge(clk) then
      if rst_n = '0' then
        r_state    <= IDLE;
        r_m_tvalid <= '0';
        r_m_tdata  <= (others => '0');
        r_m_tlast  <= '0';
        r_m_tuser  <= '0';
      else
        case r_state is
          when IDLE =>
            r_m_tvalid <= '0';

            if s_axis_lowpass_tvalid = '1' then
              r_m_tdata  <= f_lowpass_avg_3x3(s_axis_lowpass_tdata);
              r_m_tlast  <= s_axis_lowpass_tlast;
              r_m_tuser  <= s_axis_lowpass_tuser;
              r_m_tvalid <= '1';
              r_state    <= FILTER_OUTPUT;
            end if;

          when FILTER_OUTPUT =>
            if (r_m_tvalid = '1') and (m_axis_lowpass_tready = '1') then
              r_m_tvalid <= '0';
              r_state    <= IDLE;
            end if;

        end case;
      end if;
    end if;
  end process;
end architecture A_Rtl;