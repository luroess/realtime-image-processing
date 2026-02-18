library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity ClickDetector is
  port (
    i_clk               : in  std_logic;
    i_rst_n             : in  std_logic;
    i_btn_debounced     : in  std_logic;                   -- BTN1: processing state FSM
    i_btn2_debounced    : in  std_logic;                   -- BTN2: base image state FSM
    o_pass_grayscale    : out std_logic;
    o_pass_blurr_filter : out std_logic;
    o_pass_sobel        : out std_logic;
    o_pass_fast         : out std_logic;
    o_base_mode         : out std_logic_vector(1 downto 0);
    o_led               : out std_logic_vector(3 downto 0) -- 4 LEDs
  );
end entity;

architecture A_Rtl of ClickDetector is

  -- BTN1 processing state machine
  type state_t is (ST_PASS_ALL, ST_BLUR, ST_SOBEL, ST_BLUR_SOBEL, ST_FAST);
  signal s_current_state : state_t := ST_PASS_ALL;
  signal s_next_state    : state_t := ST_PASS_ALL;

  -- BTN2 base-image state machine
  type base_state_t is (ST_BRAM_RGB, ST_BRAM_GRAY, ST_ZEROS);
  signal s_base_current_state : base_state_t := ST_ZEROS;
  signal s_base_next_state    : base_state_t := ST_ZEROS;

  -- Button edge detection registers
  signal s_btn1_prev : std_logic := '0';
  signal s_btn2_prev : std_logic := '0';

begin

  P_REG_FSM: process (i_clk)
  begin
    if rising_edge(i_clk) then
      if i_rst_n /= '1' then
        s_current_state <= ST_PASS_ALL;
        s_base_current_state <= ST_ZEROS;
        s_btn1_prev <= '0';
        s_btn2_prev <= '0';
      else
        s_btn1_prev <= i_btn_debounced;
        s_btn2_prev <= i_btn2_debounced;
        s_current_state <= s_next_state;
        s_base_current_state <= s_base_next_state;
      end if;
    end if;
  end process;

  P_COMB_FSM: process (s_current_state, s_btn1_prev, i_btn_debounced)
  begin
    s_next_state <= s_current_state;

    -- Processing chain is RGB->GRAY->BLUR->SOBEL/FAST.
    -- Base grayscale stage stays enabled in all BTN1 states.
    o_pass_grayscale <= '0';
    o_pass_blurr_filter <= '1';
    o_pass_sobel <= '1';
    o_pass_fast <= '1';
    o_led(0) <= '1';
    o_led(1) <= '0';
    o_led(2) <= '0';
    o_led(3) <= '0';

    case s_current_state is
      when ST_PASS_ALL =>
        if i_btn_debounced = '1' and s_btn1_prev = '0' then
          s_next_state <= ST_BLUR;
        end if;

      when ST_BLUR =>
        o_pass_blurr_filter <= '0';
        o_led(1) <= '1';
        if i_btn_debounced = '1' and s_btn1_prev = '0' then
          s_next_state <= ST_SOBEL;
        end if;

      when ST_SOBEL =>
        o_pass_sobel <= '0';
        o_led(1) <= '1';
        o_led(3) <= '1';
        if i_btn_debounced = '1' and s_btn1_prev = '0' then
          s_next_state <= ST_BLUR_SOBEL;
        end if;

      when ST_BLUR_SOBEL =>
        o_pass_blurr_filter <= '0';
        o_pass_sobel <= '0';
        o_led(1) <= '1';
        o_led(2) <= '1';
        o_led(3) <= '1';
        if i_btn_debounced = '1' and s_btn1_prev = '0' then
          s_next_state <= ST_FAST;
        end if;

      when ST_FAST =>
        o_pass_fast <= '0';
        o_led(1) <= '1';
        o_led(2) <= '1';
        if i_btn_debounced = '1' and s_btn1_prev = '0' then
          s_next_state <= ST_PASS_ALL;
        end if;
    end case;
  end process;

  P_COMB_BASE_FSM: process (s_base_current_state, s_btn2_prev, i_btn2_debounced, s_current_state)
  begin
    s_base_next_state <= s_base_current_state;
    o_base_mode <= "00";

    -- For ST_PASS_ALL and ST_BLUR the base image is not used.
    -- Keep base mode fixed to ZEROS as requested.
    if (s_current_state = ST_PASS_ALL) or (s_current_state = ST_BLUR) then
      s_base_next_state <= ST_ZEROS;
      o_base_mode <= "00";
    else
      case s_base_current_state is
        when ST_BRAM_RGB =>
          o_base_mode <= "01";
          if i_btn2_debounced = '1' and s_btn2_prev = '0' then
            s_base_next_state <= ST_BRAM_GRAY;
          end if;
        when ST_BRAM_GRAY =>
          o_base_mode <= "10";
          if i_btn2_debounced = '1' and s_btn2_prev = '0' then
            s_base_next_state <= ST_ZEROS;
          end if;
        when ST_ZEROS =>
          o_base_mode <= "00";
          if i_btn2_debounced = '1' and s_btn2_prev = '0' then
            s_base_next_state <= ST_BRAM_RGB;
          end if;
      end case;
    end if;
  end process;
end architecture;
