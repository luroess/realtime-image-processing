library IEEE;
use IEEE.STD_LOGIC_1164.all;

-- Entity: beschreibt die Schnittstelle (Pins)
entity AND_Gate is
  port (
    A : in std_logic; -- Eingang A
    B : in std_logic; -- Eingang B
    Y : out std_logic -- Ausgang Y
  );
end AND_Gate;

-- Architecture: beschreibt die Logik
architecture Behavioral of AND_Gate is
begin
  Y <= A and B; -- Logikfunktion
end Behavioral;
