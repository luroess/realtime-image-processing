library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_debouncing is
end entity;

architecture sim of tb_debouncing is

  -- DUT Signale
  signal clk_tb     : std_logic := '0';
  signal btn_in_tb  : std_logic := '0';
  signal btn_out_tb : std_logic;

  -- Clock Parameter
  constant CLK_PERIOD : time := 20 ns; -- 50 MHz

begin

  ------------------------------------------------------------------
  -- DUT Instanz
  ------------------------------------------------------------------
  DUT : entity work.debouncer
    generic map(
      CLK_FREQ_HZ => 50_000_000,
      DEBOUNCE_MS => 10
    )
    port map
    (
      clk     => clk_tb,
      btn_in  => btn_in_tb,
      btn_out => btn_out_tb
    );

  ------------------------------------------------------------------
  -- Clock Generator
  ------------------------------------------------------------------
  clk_process : process
  begin
    while true loop
      clk_tb <= '0';
      wait for CLK_PERIOD/2;
      clk_tb <= '1';
      wait for CLK_PERIOD/2;
    end loop;
  end process;

  ------------------------------------------------------------------
  -- Stimulus Prozess
  ------------------------------------------------------------------
  stim_proc : process
  begin

    -- Startzustand
    btn_in_tb <= '0';
    wait for 100 ns;

    ------------------------------------------------------------------
    -- Simuliertes Prellen beim Drücken
    ------------------------------------------------------------------
    -- Prellen: 0/1/0/1/0/1
    btn_in_tb <= '1';
    wait for 200 ns;
    btn_in_tb <= '0';
    wait for 150 ns;
    btn_in_tb <= '1';
    wait for 180 ns;
    btn_in_tb <= '0';
    wait for 120 ns;
    btn_in_tb <= '1';
    wait for 160 ns;

    -- Jetzt stabil gedrückt
    btn_in_tb <= '1';
    wait for 20 ms;

    ------------------------------------------------------------------
    -- Stabil gedrückt halten
    ------------------------------------------------------------------
    wait for 10 ms;

    ------------------------------------------------------------------
    -- Prellen beim Loslassen
    ------------------------------------------------------------------
    btn_in_tb <= '0';
    wait for 200 ns;
    btn_in_tb <= '1';
    wait for 150 ns;
    btn_in_tb <= '0';
    wait for 180 ns;
    btn_in_tb <= '1';
    wait for 120 ns;
    btn_in_tb <= '0';
    wait for 160 ns;

    -- Jetzt stabil losgelassen
    btn_in_tb <= '0';
    wait for 20 ms;

    ------------------------------------------------------------------
    -- Simulation beenden
    ------------------------------------------------------------------
    wait for 5 ms;
    assert false report "Simulation beendet (TB)" severity failure;

  end process;

end architecture sim;
