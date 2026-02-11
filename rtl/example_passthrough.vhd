library ieee;
use ieee.std_logic_1164.all;

entity example_passthrough is
    port (
        clk           : in  std_logic;
        rst           : in  std_logic;
        s_axis_tvalid : in  std_logic;
        s_axis_tready : out std_logic;
        s_axis_tdata  : in  std_logic_vector(7 downto 0);
        s_axis_tlast  : in  std_logic;
        s_axis_tuser  : in  std_logic;
        m_axis_tvalid : out std_logic;
        m_axis_tready : in  std_logic;
        m_axis_tdata  : out std_logic_vector(7 downto 0);
        m_axis_tlast  : out std_logic;
        m_axis_tuser  : out std_logic
    );
end entity example_passthrough;

architecture rtl of example_passthrough is
begin
    -- Pure passthrough for testbench framework check
    s_axis_tready <= '0' when rst = '1' else m_axis_tready;
    m_axis_tvalid <= '0' when rst = '1' else s_axis_tvalid;
    m_axis_tdata  <= (others => '0') when rst = '1' else s_axis_tdata;
    m_axis_tlast  <= '0' when rst = '1' else s_axis_tlast;
    m_axis_tuser  <= '0' when rst = '1' else s_axis_tuser;
end architecture rtl;
