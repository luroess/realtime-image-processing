library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity LowpassFilter is
  generic (
    G_PIXEL_WIDTH : integer := 8
  );
  port (
    i_aclk   : in std_logic;
    i_aresetn : in std_logic;

    i_pass_through : in std_logic;

    -- AXI SLAVE
    s_axis_window_tvalid : in std_logic;
    s_axis_window_tready : out std_logic;
    s_axis_window_tdata  : in std_logic_vector (9 * G_PIXEL_WIDTH - 1 downto 0);
    s_axis_window_tlast  : in std_logic; --EOF
    s_axis_window_tuser  : in std_logic; -- SOF

    -- AXI MASTER
    m_axis_video_tready : in std_logic; -- TODO: Align naming!
    m_axis_video_tvalid : out std_logic;
    m_axis_video_tdata  : out std_logic_vector (G_PIXEL_WIDTH - 1 downto 0);
    m_axis_video_tlast  : out std_logic;
    m_axis_video_tuser  : out std_logic
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
  -- Single-cycle combinational path: accept upstream data only when
  -- downstream is ready, and assert master valid directly from slave valid.
  s_axis_window_tready <= m_axis_video_tready and i_aresetn;
  m_axis_video_tvalid  <= s_axis_window_tvalid and i_aresetn;

  m_axis_video_tdata <= f_lowpass_avg_3x3(s_axis_window_tdata)
                        when s_axis_window_tvalid = '1'
                        else (others => '0');
  m_axis_video_tlast <= s_axis_window_tlast
                        when s_axis_window_tvalid = '1'
                        else '0';
  m_axis_video_tuser <= s_axis_window_tuser
                        when s_axis_window_tvalid = '1'
                        else '0';

end architecture A_Rtl;