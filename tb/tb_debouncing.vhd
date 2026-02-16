library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity Tb_Debouncing is
end entity;

architecture A_Tb of Tb_Debouncing is

  -- DUT Signals
  signal s_clk     : std_logic := '0';
  signal s_btn_in  : std_logic := '0';
  signal s_btn_out : std_logic;

  -- Clock Parameter
  constant C_CLK_PERIOD : time := 20 ns; -- 50 MHz

begin

  ------------------------------------------------------------------
  -- DUT Instance
  ------------------------------------------------------------------
  U_DUT : entity work.Debouncer
    generic map(
      G_CLK_FREQ_HZ => 50_000_000,
      G_DEBOUNCE_MS => 10
    )
    port map
    (
      i_clk           => s_clk,
      i_btn           => s_btn_in,
      o_btn_debounced => s_btn_out
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
    s_btn_in <= '0';
    wait for 100 ns;

    ------------------------------------------------------------------
    -- Simulated bouncing during press
    ------------------------------------------------------------------
    -- Bounce pattern: 0/1/0/1/0/1
    s_btn_in <= '1';
    wait for 200 ns;
    s_btn_in <= '0';
    wait for 150 ns;
    s_btn_in <= '1';
    wait for 180 ns;
    s_btn_in <= '0';
    wait for 120 ns;
    s_btn_in <= '1';
    wait for 160 ns;

    -- Now stable pressed
    s_btn_in <= '1';
    wait for 20 ms;

    ------------------------------------------------------------------
    -- Keep stable pressed
    ------------------------------------------------------------------
    wait for 10 ms;

    ------------------------------------------------------------------
    -- Bouncing during release
    ------------------------------------------------------------------
    s_btn_in <= '0';
    wait for 200 ns;
    s_btn_in <= '1';
    wait for 150 ns;
    s_btn_in <= '0';
    wait for 180 ns;
    s_btn_in <= '1';
    wait for 120 ns;
    s_btn_in <= '0';
    wait for 160 ns;

    -- Now stable released
    s_btn_in <= '0';
    wait for 20 ms;

    ------------------------------------------------------------------
    -- End simulation (Note: Severity failure is only used to stop execution of the simulation. )
    ------------------------------------------------------------------
    wait for 5 ms;
    assert false report "Simulation completed" severity failure;

  end process P_STIM;

end architecture A_Tb;
