library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity Debouncer is
  generic (
    G_CLK_FREQ_HZ : integer := 100_000_000; -- 100 MHz
    G_DEBOUNCE_NS : integer := 10_000_000   -- 10 ms
  );
  port (
    i_rst           : in  std_logic;
    i_clk           : in  std_logic;
    i_btn           : in  std_logic;
    o_btn_debounced : out std_logic
  );
end entity;

architecture A_Rtl of Debouncer is

  constant C_CLK_PERIOD_NS : integer := 1_000_000_000 / G_CLK_FREQ_HZ;
  constant C_COUNT_MAX     : integer := G_DEBOUNCE_NS / C_CLK_PERIOD_NS;

  signal s_sync1, s_sync2 : std_logic                      := '0';
  signal s_stable_btn     : std_logic                      := '0';
  signal s_counter        : integer range 0 to C_COUNT_MAX := 0;

begin

  -- Synchronizer for metastability mitigation
  P_SYNC: process (i_clk)
  begin
    if rising_edge(i_clk) then
      if i_rst = '1' then
        s_sync1 <= '0';
        s_sync2 <= '0';
      else
        s_sync1 <= i_btn;
        s_sync2 <= s_sync1;
      end if;
    end if;
  end process;

  -- Debounce logic: counter-based stability detection
  P_REG_DEBOUNCE: process (i_clk)
  begin
    if rising_edge(i_clk) then
      if i_rst = '1' then
        s_stable_btn <= '0';
        s_counter <= 0;
      else
        if s_sync2 /= s_stable_btn then
          if s_counter < C_COUNT_MAX then
            s_counter <= s_counter + 1;
          end if;
        else
          s_counter <= 0;
        end if;

        if s_counter = C_COUNT_MAX then
          s_stable_btn <= s_sync2;
        end if;
      end if;
    end if;
  end process;

  o_btn_debounced <= s_stable_btn;

end architecture;
