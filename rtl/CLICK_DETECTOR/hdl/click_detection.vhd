library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity ClickDetector is
  port (
    i_clk                 : in std_logic;
    i_rst_n               : in std_logic;
    i_btn_debounced       : in std_logic;
    o_pass_grayscale      : out std_logic;
    o_pass_blurr_filter : out std_logic;
    o_pass_sobel          : out std_logic;
    o_led                 : out std_logic_vector(3 downto 0)  -- 4 LEDs
  );
end entity;

architecture A_Rtl of ClickDetector is

  -- State type and state registers
  type state_t is (ST_PASSTHROUGH, ST_GRAYSCALE, ST_BLURR, ST_SOBEL);
  signal s_current_state : state_t := ST_PASSTHROUGH;
  signal s_next_state    : state_t := ST_PASSTHROUGH;

  -- Button edge detection register
  signal s_btn_prev : std_logic := '0';

begin

  P_REG_FSM : process (i_clk)
  begin
    if rising_edge(i_clk) then
      if i_rst_n /= '1' then
        s_current_state <= ST_PASSTHROUGH;
        s_btn_prev      <= '0';
      else
        s_btn_prev      <= i_btn_debounced;
        s_current_state <= s_next_state;
      end if;
    end if;
  end process;

  P_COMB_FSM : process (s_current_state, s_btn_prev, i_btn_debounced)
  begin
    s_next_state <= s_current_state;

    o_pass_grayscale      <= '1';
    o_pass_blurr_filter <= '1';
    o_pass_sobel          <= '1';
    o_led(0) <= '1';
    o_led(1) <= '0';
    o_led(2) <= '0';
    o_led(3) <= '0';

    case s_current_state is
      when ST_PASSTHROUGH =>
        if i_btn_debounced = '1' and s_btn_prev = '0' then
          s_next_state <= ST_GRAYSCALE;
        end if;

      when ST_GRAYSCALE =>
        o_pass_grayscale <= '0';
        o_led(1) <= '1';
        if i_btn_debounced = '1' and s_btn_prev = '0' then
          s_next_state <= ST_BLURR;
        end if;

      when ST_BLURR =>
        o_pass_grayscale      <= '0';
        o_pass_blurr_filter <= '0';
        o_led(1) <= '1';
        o_led(2) <= '1';
        if i_btn_debounced = '1' and s_btn_prev = '0' then
          s_next_state <= ST_SOBEL;
        end if;

      when ST_SOBEL =>
        o_pass_grayscale      <= '0';
        o_pass_blurr_filter <= '0';
        o_pass_sobel          <= '0';
        o_led(1) <= '1';
        o_led(2) <= '1';
        o_led(3) <= '1';
        if i_btn_debounced = '1' and s_btn_prev = '0' then
          s_next_state <= ST_PASSTHROUGH;
        end if;
    end case;
  end process P_COMB_FSM;
end architecture;
