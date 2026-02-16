library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity button_example is
    Port ( 
        clk : in STD_LOGIC;                      -- System clock (125 MHz on Zybo Z7)
        btn : in STD_LOGIC_VECTOR (3 downto 0);  -- 4 buttons
        led : out STD_LOGIC_VECTOR (3 downto 0)  -- 4 LEDs
    );
end button_example;

architecture Behavioral of button_example is
    signal btn_reg : STD_LOGIC_VECTOR(3 downto 0);
begin
    -- Simple synchronizer to avoid metastability
    process(clk)
    begin
        if rising_edge(clk) then
            btn_reg <= btn;
            led <= btn_reg;  -- Copy button states to LEDs
        end if;
    end process;
end Behavioral;