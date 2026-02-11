library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity Tb_Button_Detection is
end entity;

architecture A_Tb of Tb_Button_Detection is

  -- DUT Signals
  signal s_clk              : std_logic := '0';
  signal s_debounced_btn_in : std_logic := '0';
  signal s_single_click_out : std_logic;
  signal s_double_click_out : std_logic;

  -- Clock Parameter
  constant C_CLK_PERIOD : time := 20 ns; -- 50 MHz

begin

  ------------------------------------------------------------------
  -- DUT Instance
  ------------------------------------------------------------------
  U_DUT : entity work.Button_Detection
    generic map(
      G_CLK_FREQ_HZ         => 50_000_000,
      G_BUTTON_DETECTION_MS => 5
    )
    port map
    (
      i_clk           => s_clk,
      i_debounced_btn => s_debounced_btn_in,
      o_single_click  => s_single_click_out,
      o_double_click  => s_double_click_out
    );

  ------------------------------------------------------------------
  -- Clock Generator
  ------------------------------------------------------------------
  P_CLK : process
  begin
    while true loop
      s_clk <= '0';
      wait for C_CLK_PERIOD/2;
      s_clk <= '1';
      wait for C_CLK_PERIOD/2;
    end loop;
  end process P_CLK;

  ------------------------------------------------------------------
  -- Stimulus Process
  ------------------------------------------------------------------
  P_STIM : process
  begin

    -- Initial state
    s_debounced_btn_in <= '0';
    wait for 100 ns;

    ------------------------------------------------------------------
    -- Simulated Single Click
    ------------------------------------------------------------------
    -- 
    s_debounced_btn_in <= '1';
    wait for 40 ns;

    s_debounced_btn_in <= '0';
    wait for 6 ms;

    ------------------------------------------------------------------
    -- Simulated Double Click
    ------------------------------------------------------------------
    s_debounced_btn_in <= '1';
    wait for 40 ns;

    s_debounced_btn_in <= '0';
    wait for 40 ns;

    s_debounced_btn_in <= '1';
    wait for 40 ns;

    s_debounced_btn_in <= '0';
    wait for 6 ms;

    ------------------------------------------------------------------
    -- End simulation (Note: Severity failure is only used to stop execution of the simulation. )
    ------------------------------------------------------------------
    assert false report "Simulation completed" severity failure;

  end process P_STIM;

end architecture A_Tb;
