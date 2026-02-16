library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity debouncer is
  generic (
    CLK_FREQ_HZ : integer := 50_000_000; -- 50 MHz
    DEBOUNCE_MS : integer := 10 -- 10 ms
  );
  port (
    clk     : in std_logic;
    btn_in  : in std_logic;
    btn_out : out std_logic
  );
end entity;

architecture rtl of debouncer is

  constant COUNT_MAX : integer := (CLK_FREQ_HZ / 1000) * DEBOUNCE_MS;

  signal sync1, sync2 : std_logic                    := '0';
  signal btn_last     : std_logic                    := '0';
  signal stable_btn   : std_logic                    := '0';
  signal counter      : integer range 0 to COUNT_MAX := 0;

begin

  -- 1) Synchronizer (Metastability-Schutz)
  process (clk)
  begin
    if rising_edge(clk) then
      sync1 <= btn_in;
      sync2 <= sync1;
    end if;
  end process;

  -- 2) Debounce-Logik
  -- Finite State Machine für verschiedene Inputs (1x Button Druck, 2 x Button Druck)
  process (clk)
  begin
    if rising_edge(clk) then
      if sync2 = btn_last then
        if counter < COUNT_MAX then
          counter <= counter + 1;
        end if;
      else
        counter <= 0;
      end if;

      if counter = COUNT_MAX then
        stable_btn <= sync2;
      end if;

      btn_last <= sync2;
    end if;
  end process;

  btn_out <= stable_btn;

end rtl;
