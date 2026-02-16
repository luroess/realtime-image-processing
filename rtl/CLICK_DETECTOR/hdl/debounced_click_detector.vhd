library ieee;
  use ieee.std_logic_1164.all;

entity DebouncedClickDetector is
  generic (
    G_CLK_FREQ_HZ    : integer := 100_000_000; -- 100 MHz
    G_DEBOUNCE_NS    : integer := 10_000_000  -- 10 ms
  );
  port (
    i_clk           : in  std_logic;
    i_rst_n           : in  std_logic;
    i_btn           : in  std_logic;
    o_btn_debounced : out std_logic;
    o_pass_grayscale  : out std_logic;
    o_pass_lowpass_filter  : out std_logic;
    o_pass_sobel  : out std_logic
  );
end entity;

architecture A_RtlStruct of DebouncedClickDetector is

  signal s_btn_debounced : std_logic := '0';

begin

  U_Debouncer: entity work.Debouncer(A_Rtl) generic map (
    G_CLK_FREQ_HZ => G_CLK_FREQ_HZ,
    G_DEBOUNCE_NS => G_DEBOUNCE_NS
  ) port map (
    i_rst_n           => i_rst_n,
    i_clk           => i_clk,
    i_btn           => i_btn,
    o_btn_debounced => s_btn_debounced
  );

  U_ClickDetector: entity work.ClickDetector(A_Rtl) port map (
    i_clk           => i_clk,
    i_rst_n           => i_rst_n,
    i_btn_debounced => s_btn_debounced,
    o_pass_grayscale => o_pass_grayscale,
    o_pass_lowpass_filter  => o_pass_lowpass_filter,
    o_pass_sobel  => o_pass_sobel
  );

  o_btn_debounced <= s_btn_debounced;

end architecture;
