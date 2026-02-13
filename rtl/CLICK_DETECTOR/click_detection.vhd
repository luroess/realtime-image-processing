library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity ClickDetector is
  generic (
    G_CLK_FREQ_HZ    : integer := 100_000_000; -- 100 MHz
    G_CLICK_TIMER_MS : integer := 10 -- TODO: 0,5s, change to 10ms for testing
  );
  port (
    i_clk           : in std_logic;
    i_rst           : in std_logic;
    i_btn_debounced : in std_logic;
    o_single_click  : out std_logic := '1'; -- default mode
    o_double_click  : out std_logic;
    o_triple_click  : out std_logic
  );
end entity;

architecture A_Rtl of ClickDetector is

  constant C_COUNT_MAX : integer := (G_CLK_FREQ_HZ / 1000) * G_CLICK_TIMER_MS;

  -- 1. Define States
  type state_t is (ST_IDLE, ST_BTN_PRESSED, ST_BTN_RELEASED);
  signal s_current_state : state_t := ST_IDLE;

  -- Internal Registers
  signal s_counter  : integer range 0 to 3           := 0;
  signal s_timer    : integer range 0 to C_COUNT_MAX := 0;
  signal s_btn_prev : std_logic                      := '0';

  -- Edge detection wire
  signal s_btn_rising_edge : std_logic := '0';

begin

  P_STATE_MACHINE : process (i_clk)
  begin

    if i_rst = '1' then
      s_current_state   <= ST_IDLE;
      s_counter         <= 0;
      s_timer           <= 0;
      s_btn_prev        <= '0';
      s_btn_rising_edge <= '0';
      o_single_click    <= '1';
      o_double_click    <= '0';
      o_triple_click    <= '0';
    else
      if rising_edge(i_clk) then
        if i_btn_debounced = '1' and s_btn_prev = '0' then
          s_btn_rising_edge <= '1';
        else
          s_btn_rising_edge <= '0';
        end if;

        s_btn_prev <= i_btn_debounced;

        case s_current_state is
          when ST_IDLE =>
            if s_btn_rising_edge = '1' then
              s_current_state <= ST_BTN_PRESSED;
            end if;

          when ST_BTN_PRESSED =>
            if i_btn_debounced = '0' then
              if s_counter < 3 then
                s_counter <= s_counter + 1;
              end if;
              s_timer         <= 1;
              s_current_state <= ST_BTN_RELEASED;
            end if;

          when ST_BTN_RELEASED =>
            if s_btn_rising_edge = '1' then
              s_current_state <= ST_BTN_PRESSED;
            elsif s_timer = C_COUNT_MAX then
              if s_counter = 1 then
                o_single_click <= '1';
                o_double_click <= '0';
                o_triple_click <= '0';
              elsif s_counter = 2 then
                o_single_click <= '1';
                o_double_click <= '1';
                o_triple_click <= '0';
              elsif s_counter = 3 then
                o_single_click <= '1';
                o_double_click <= '1';
                o_triple_click <= '1';
              end if;
              s_current_state <= ST_IDLE;
              s_counter       <= 0;
            else
              s_timer <= s_timer + 1;
            end if;
          when others =>
            s_current_state <= ST_IDLE;
        end case;
      end if;
    end if;

  end process P_STATE_MACHINE;

end A_Rtl;