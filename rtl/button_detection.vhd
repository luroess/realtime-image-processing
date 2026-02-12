library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity Button_Detection is
  generic (
    G_CLK_FREQ_HZ         : integer := 50_000_000; -- 50 MHz
    G_BUTTON_DETECTION_MS : integer := 500 -- 500 ms
  );
  port (
    i_clk           : in std_logic;
    i_debounced_btn : in std_logic;
    o_single_click  : out std_logic;
    o_double_click  : out std_logic
  );
end entity;

architecture A_Rtl of Button_Detection is

  constant C_COUNT_MAX : integer := (G_CLK_FREQ_HZ / 1000) * G_BUTTON_DETECTION_MS;

  signal s_counter  : integer range 0 to 2;
  signal s_timer    : integer range 0 to C_COUNT_MAX := 0;
  signal s_btn_prev : std_logic                      := '0';
  -- o_single_click and o_double_click are pulsed high for one clock

begin

  -- TODO: Replace Implementation by State Machine

  -- Button Click Logic: 1 Click o_sig_1, 2 Clicks o_sig_2
  P_REG_BUTTON_LOGIC : process (i_clk)
  begin
    if rising_edge(i_clk) then
      -- default outputs are low (produce a one-clock pulse when asserted)
      o_single_click <= '0';
      o_double_click <= '0';

      -- detect rising edge of debounced button by comparing with previous sample
      if (i_debounced_btn = '1' and s_btn_prev = '0') then
        s_counter <= s_counter + 1;
        s_timer   <= 0;
      else
        if i_debounced_btn = '0' then
          if s_timer = C_COUNT_MAX then
            if s_counter = 1 then
              o_single_click <= '1';
            elsif s_counter = 2 then
              o_double_click <= '1';
            end if;
            s_counter <= 0;
          else
            s_timer <= s_timer + 1;
          end if;
        end if;
      end if;

      -- update previous-sample for next clock
      s_btn_prev <= i_debounced_btn;
    end if;
  end process P_REG_BUTTON_LOGIC;
end architecture A_Rtl;