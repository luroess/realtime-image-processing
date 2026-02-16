library IEEE;
use IEEE.STD_LOGIC_1164.all;

-- Testbench hat KEINE Ports!
entity tb_and_gate is
end tb_and_gate;

architecture Behavioral of tb_and_gate is

  -- Komponentendeklaration (Device Under Test = DUT)
  component AND_Gate
    port (
      A : in std_logic;
      B : in std_logic;
      Y : out std_logic
    );
  end component;

  -- interne Signale
  signal A_tb : std_logic := '0';
  signal B_tb : std_logic := '0';
  signal Y_tb : std_logic;

begin

  -- DUT Instanz
  DUT : AND_Gate
  port map
  (
    A => A_tb,
    B => B_tb,
    Y => Y_tb
  );

  -- Stimulus-Prozess (Testsignale)
  stim_proc : process
  begin
    -- Test 1: 0 AND 0
    A_tb <= '0';
    B_tb <= '0';
    wait for 10 ns;

    -- Test 2: 0 AND 1
    A_tb <= '0';
    B_tb <= '1';
    wait for 10 ns;

    -- Test 3: 1 AND 0
    A_tb <= '1';
    B_tb <= '0';
    wait for 10 ns;

    -- Test 4: 1 AND 1
    A_tb <= '1';
    B_tb <= '1';
    wait for 10 ns;

    -- Simulation stoppen
    wait;
  end process;

end Behavioral;
