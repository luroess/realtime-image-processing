library ieee;
  use ieee.std_logic_1164.all;

entity DebouncedClickDetector is
  generic (
    G_CLK_FREQ_HZ : integer := 100_000_000;
    G_DEBOUNCE_NS : integer := 10_000_000
  );
  port (
    i_clk                 : in  std_logic;
    i_rst_n               : in  std_logic;
    i_btn                 : in  std_logic_vector(3 downto 0);
    o_btn_debounced       : out std_logic;
    o_base_mode           : out std_logic_vector(1 downto 0);
    o_overlay_mode        : out std_logic_vector(1 downto 0);
    o_pass_grayscale      : out std_logic;
    o_pass_lowpass_filter : out std_logic;
    o_pass_sobel          : out std_logic;
    o_led                 : out std_logic_vector(3 downto 0)
  );
end entity;

architecture A_Rtl of DebouncedClickDetector is
  -- todo use enums for modes as per style_guide.md!
  constant C_BASE_RGB  : std_logic_vector(1 downto 0) := "00";
  constant C_BASE_GRAY : std_logic_vector(1 downto 0) := "01";
  constant C_BASE_ZERO : std_logic_vector(1 downto 0) := "10";

  constant C_OVERLAY_NONE  : std_logic_vector(1 downto 0) := "00";
  constant C_OVERLAY_FAST  : std_logic_vector(1 downto 0) := "01";
  constant C_OVERLAY_SOBEL : std_logic_vector(1 downto 0) := "10";

  signal s_btn_debounced : std_logic_vector(3 downto 0) := (others => '0');
  signal s_btn_prev      : std_logic_vector(3 downto 0) := (others => '0');

  signal s_base_mode    : std_logic_vector(1 downto 0) := C_BASE_RGB;
  signal s_overlay_mode : std_logic_vector(1 downto 0) := C_OVERLAY_NONE;
begin
  G_Debouncer: for i in 0 to 3 generate
    U_Debouncer: entity work.Debouncer
      generic map (
        G_CLK_FREQ_HZ => G_CLK_FREQ_HZ,
        G_DEBOUNCE_NS => G_DEBOUNCE_NS
      )
      port map (
        i_rst_n         => i_rst_n,
        i_clk           => i_clk,
        i_btn           => i_btn(i),
        o_btn_debounced => s_btn_debounced(i)
      );
  end generate;

  P_REG_MODES: process (i_clk)
  begin
    if rising_edge(i_clk) then
      if i_rst_n /= '1' then
        s_btn_prev <= (others => '0');
        s_base_mode <= C_BASE_RGB;
        s_overlay_mode <= C_OVERLAY_NONE;
      else
        -- Button 0: base image cycle RGB -> GRAY -> ZERO -> RGB.
        if s_btn_prev(0) = '0' and s_btn_debounced(0) = '1' then
          case s_base_mode is
            when C_BASE_RGB =>
              s_base_mode <= C_BASE_GRAY;
            when C_BASE_GRAY =>
              s_base_mode <= C_BASE_ZERO;
            when others =>
              s_base_mode <= C_BASE_RGB;
          end case;
        end if;

        -- Button 1: overlay cycle FAST -> SOBEL -> NONE -> FAST.
        if s_btn_prev(1) = '0' and s_btn_debounced(1) = '1' then
          case s_overlay_mode is
            when C_OVERLAY_NONE =>
              s_overlay_mode <= C_OVERLAY_FAST;
            when C_OVERLAY_FAST =>
              s_overlay_mode <= C_OVERLAY_SOBEL;
            when others =>
              s_overlay_mode <= C_OVERLAY_NONE;
          end case;
        end if;

        -- Button 2: force base mode to RGB.
        if s_btn_prev(2) = '0' and s_btn_debounced(2) = '1' then
          s_base_mode <= C_BASE_RGB;
        end if;

        -- Button 3: force overlay mode to NONE.
        if s_btn_prev(3) = '0' and s_btn_debounced(3) = '1' then
          s_overlay_mode <= C_OVERLAY_NONE;
        end if;

        s_btn_prev <= s_btn_debounced;
      end if;
    end if;
  end process;

  o_base_mode    <= s_base_mode;
  o_overlay_mode <= s_overlay_mode;

  -- Compatibility outputs for existing blocks.
  o_btn_debounced       <= '1' when s_btn_debounced /= "0000" else '0';
  o_pass_grayscale      <= '0' when s_base_mode = C_BASE_GRAY else '1';
  o_pass_lowpass_filter <= '1';
  o_pass_sobel          <= '0' when s_overlay_mode = C_OVERLAY_SOBEL else '1';

  -- LEDs expose mode bits directly: [3:2]=overlay, [1:0]=base.
  o_led(1 downto 0) <= s_base_mode;
  o_led(3 downto 2) <= s_overlay_mode;
end architecture;
