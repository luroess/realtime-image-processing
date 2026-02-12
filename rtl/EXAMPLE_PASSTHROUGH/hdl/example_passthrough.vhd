library ieee;
  use ieee.std_logic_1164.all;

entity example_passthrough is
  port (
    i_clk               : in  std_logic;
    i_rst_n             : in  std_logic;
    s_axis_video_tvalid : in  std_logic;
    s_axis_video_tready : out std_logic;
    s_axis_video_tdata  : in  std_logic_vector(23 downto 0);
    s_axis_video_tlast  : in  std_logic;
    s_axis_video_tuser  : in  std_logic;
    m_axis_video_tvalid : out std_logic;
    m_axis_video_tready : in  std_logic;
    m_axis_video_tdata  : out std_logic_vector(23 downto 0);
    m_axis_video_tlast  : out std_logic;
    m_axis_video_tuser  : out std_logic
  );
end entity;

architecture rtl of example_passthrough is
begin
  -- Keep output buses deterministic in idle cycles:
  -- when input VALID is low, sidebands/data are forced to zero instead of propagating don't-care values.
  -- Treat unknown reset/valid values as idle during simulation startup to prevent U/X propagation.
  <<<<<<< HEAD s_axis_video_tready <= '0' when i_rst_n /= '0'
else
  m_axis_video_tready;
  m_axis_video_tvalid <= '0' when i_rst_n /= '0'
else
  s_axis_video_tvalid;
  m_axis_video_tdata <= (others => '0') when (i_rst_n /= '0') or (s_axis_video_tvalid /= '1')
else
  s_axis_video_tdata;
  m_axis_video_tlast <= '0' when (i_rst_n /= '0') or (s_axis_video_tvalid /= '1')
else
  s_axis_video_tlast;
  m_axis_video_tuser <= '0' when (i_rst_n /= '0') or (s_axis_video_tvalid /= '1')
else
  s_axis_video_tuser;
  = = = = = = = s_axis_video_tready <= '0' when rst /= '0'
else
  m_axis_video_tready;
  m_axis_video_tvalid <= '0' when rst /= '0'
else
  s_axis_video_tvalid;
  m_axis_video_tdata <= (others => '0') when (rst /= '0') or (s_axis_video_tvalid /= '1')
else
  s_axis_video_tdata;
  m_axis_video_tlast <= '0' when (rst /= '0') or (s_axis_video_tvalid /= '1')
else
  s_axis_video_tlast;
  m_axis_video_tuser <= '0' when (rst /= '0') or (s_axis_video_tvalid /= '1')
else
  s_axis_video_tuser;
  >>>>>> > f99c60f(feat(testbench): add cocotbesxt - axi support)
end architecture;
