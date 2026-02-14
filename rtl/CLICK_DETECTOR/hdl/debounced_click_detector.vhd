library ieee;
  use ieee.std_logic_1164.all;

  -- TODO(@ValentinBumeder): Please write a testbench for this module.

entity DebouncedClickDetector is
  generic (
    G_CLK_FREQ_HZ    : integer := 100_000_000; -- 100 MHz
    G_DEBOUNCE_NS    : integer := 10_000_000;  -- 10 ms
    G_CLICK_TIMER_NS : integer := 500_000_000  -- 0.5 s
  );
  port (
    i_clk           : in  std_logic;
    i_rst           : in  std_logic;
    i_btn           : in  std_logic;
    o_btn_debounced : out std_logic;
    o_single_click  : out std_logic;
    o_double_click  : out std_logic;
    o_triple_click  : out std_logic
  );
end entity;

architecture A_RtlStruct of DebouncedClickDetector is

  signal s_btn_debounced : std_logic := '0';

begin

  U_Debouncer: entity work.Debouncer(A_Rtl) generic map (
    G_CLK_FREQ_HZ => G_CLK_FREQ_HZ,
    G_DEBOUNCE_NS => G_DEBOUNCE_NS
  ) port map (
    i_rst           => i_rst,
    i_clk           => i_clk,
    i_btn           => i_btn,
    o_btn_debounced => s_btn_debounced
  );

  U_ClickDetector: entity work.ClickDetector(A_Rtl) generic map (
    G_CLK_FREQ_HZ    => G_CLK_FREQ_HZ,
    G_CLICK_TIMER_NS => G_CLICK_TIMER_NS
  ) port map (
    i_clk           => i_clk,
    i_rst           => i_rst,
    i_btn_debounced => s_btn_debounced,
    o_single_click  => o_single_click,
    o_double_click  => o_double_click,
    o_triple_click  => o_triple_click
  );

  o_btn_debounced <= s_btn_debounced;

end architecture;
