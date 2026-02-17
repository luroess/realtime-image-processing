library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity AXI_WindowGenerator is
	generic (
		-- Users to add parameters here

		-- User parameters ends
		-- Do not modify the parameters beyond this line


		-- Parameters of Axi Slave Bus Interface s_axis_gray8
		C_s_axis_gray8_TDATA_WIDTH	: integer	:= 32;

		-- Parameters of Axi Master Bus Interface m_axis_window
		C_m_axis_window_TDATA_WIDTH	: integer	:= 32;
		C_m_axis_window_START_COUNT	: integer	:= 32
	);
	port (
		-- Users to add ports here

		-- User ports ends
		-- Do not modify the ports beyond this line


		-- Ports of Axi Slave Bus Interface s_axis_gray8
		s_axis_gray8_aclk	: in std_logic;
		s_axis_gray8_aresetn	: in std_logic;
		s_axis_gray8_tready	: out std_logic;
		s_axis_gray8_tdata	: in std_logic_vector(C_s_axis_gray8_TDATA_WIDTH-1 downto 0);
		s_axis_gray8_tstrb	: in std_logic_vector((C_s_axis_gray8_TDATA_WIDTH/8)-1 downto 0);
		s_axis_gray8_tlast	: in std_logic;
		s_axis_gray8_tvalid	: in std_logic;

		-- Ports of Axi Master Bus Interface m_axis_window
		m_axis_window_aclk	: in std_logic;
		m_axis_window_aresetn	: in std_logic;
		m_axis_window_tvalid	: out std_logic;
		m_axis_window_tdata	: out std_logic_vector(C_m_axis_window_TDATA_WIDTH-1 downto 0);
		m_axis_window_tstrb	: out std_logic_vector((C_m_axis_window_TDATA_WIDTH/8)-1 downto 0);
		m_axis_window_tlast	: out std_logic;
		m_axis_window_tready	: in std_logic
	);
end AXI_WindowGenerator;

architecture arch_imp of AXI_WindowGenerator is

	-- component declaration
	component AXI_WindowGenerator_slave_stream_v1_0_s_axis_gray8 is
		generic (
		C_S_AXIS_TDATA_WIDTH	: integer	:= 32
		);
		port (
		S_AXIS_ACLK	: in std_logic;
		S_AXIS_ARESETN	: in std_logic;
		S_AXIS_TREADY	: out std_logic;
		S_AXIS_TDATA	: in std_logic_vector(C_S_AXIS_TDATA_WIDTH-1 downto 0);
		S_AXIS_TSTRB	: in std_logic_vector((C_S_AXIS_TDATA_WIDTH/8)-1 downto 0);
		S_AXIS_TLAST	: in std_logic;
		S_AXIS_TVALID	: in std_logic
		);
	end component AXI_WindowGenerator_slave_stream_v1_0_s_axis_gray8;

	component AXI_WindowGenerator_master_stream_v1_0_m_axis_window is
		generic (
		C_M_AXIS_TDATA_WIDTH	: integer	:= 32;
		C_M_START_COUNT	: integer	:= 32
		);
		port (
		M_AXIS_ACLK	: in std_logic;
		M_AXIS_ARESETN	: in std_logic;
		M_AXIS_TVALID	: out std_logic;
		M_AXIS_TDATA	: out std_logic_vector(C_M_AXIS_TDATA_WIDTH-1 downto 0);
		M_AXIS_TSTRB	: out std_logic_vector((C_M_AXIS_TDATA_WIDTH/8)-1 downto 0);
		M_AXIS_TLAST	: out std_logic;
		M_AXIS_TREADY	: in std_logic
		);
	end component AXI_WindowGenerator_master_stream_v1_0_m_axis_window;

begin

-- Instantiation of Axi Bus Interface s_axis_gray8
AXI_WindowGenerator_slave_stream_v1_0_s_axis_gray8_inst : AXI_WindowGenerator_slave_stream_v1_0_s_axis_gray8
	generic map (
		C_S_AXIS_TDATA_WIDTH	=> C_s_axis_gray8_TDATA_WIDTH
	)
	port map (
		S_AXIS_ACLK	=> s_axis_gray8_aclk,
		S_AXIS_ARESETN	=> s_axis_gray8_aresetn,
		S_AXIS_TREADY	=> s_axis_gray8_tready,
		S_AXIS_TDATA	=> s_axis_gray8_tdata,
		S_AXIS_TSTRB	=> s_axis_gray8_tstrb,
		S_AXIS_TLAST	=> s_axis_gray8_tlast,
		S_AXIS_TVALID	=> s_axis_gray8_tvalid
	);

-- Instantiation of Axi Bus Interface m_axis_window
AXI_WindowGenerator_master_stream_v1_0_m_axis_window_inst : AXI_WindowGenerator_master_stream_v1_0_m_axis_window
	generic map (
		C_M_AXIS_TDATA_WIDTH	=> C_m_axis_window_TDATA_WIDTH,
		C_M_START_COUNT	=> C_m_axis_window_START_COUNT
	)
	port map (
		M_AXIS_ACLK	=> m_axis_window_aclk,
		M_AXIS_ARESETN	=> m_axis_window_aresetn,
		M_AXIS_TVALID	=> m_axis_window_tvalid,
		M_AXIS_TDATA	=> m_axis_window_tdata,
		M_AXIS_TSTRB	=> m_axis_window_tstrb,
		M_AXIS_TLAST	=> m_axis_window_tlast,
		M_AXIS_TREADY	=> m_axis_window_tready
	);

	-- Add user logic here

	-- User logic ends

end arch_imp;
