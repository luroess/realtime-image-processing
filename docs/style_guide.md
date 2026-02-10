# VHDL Style Guide

## 1) Naming Convention

Use these prefixes:

- `i_`: input ports (example: `i_clk`, `i_rst_n`, `i_pix_valid`)
- `o_`: output ports (example: `o_pix_data`, `o_done`)
- `s_`: internal signals (example: `s_state`, `s_pix_sum`)
- `v_`: variables (example: `v_count`, `v_next_addr`)
- `P_`: process labels (example: `P_REG_MAIN`, `P_COMB_NEXT`)
- `U_`: instance labels (example: `U_LineBuffer0`, `U_SobelX`)
- `G_`: generics (example: `G_PIXEL_W`, `G_FRAME_W`)
- `C_`: constants (example: `C_SOBEL_X`, `C_ZERO`)
- `*_t`: user-defined types (example: `state_t`, `pixel_t`, `window_t`)

Use these casing rules:

- Entities/components/packages: `PascalCase`
- Architectures: `A_Rtl`, `A_Sim`, `A_Tb`
- Enum literals: `ST_*`
- Active-low nets: `_n` suffix (`i_rst_n`)

## 2) Library / Numeric Rules

- Prefer `ieee.numeric_std.all`
- Avoid `std_logic_arith`, `std_logic_unsigned`, `std_logic_signed`. They are not  ieee std libraries.
- Use explicit `unsigned` / `signed` conversions

## 3) Process Style

- Sequential/register logic: one `P_REG_*` process
- Combinational logic: one `P_COMB_*` process
- FSM: split combinational next-state and sequential state registers

## 4) Minimal Snippets

### Entity + Architecture + Prefixes

```vhd
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity RgbToGray is
  generic (
    G_PIXEL_W : natural := 8
  );
  port (
    i_clk     : in  std_logic;
    i_rst_n   : in  std_logic;
    i_valid   : in  std_logic;
    i_r       : in  std_logic_vector(G_PIXEL_W-1 downto 0);
    i_g       : in  std_logic_vector(G_PIXEL_W-1 downto 0);
    i_b       : in  std_logic_vector(G_PIXEL_W-1 downto 0);
    o_valid   : out std_logic;
    o_gray    : out std_logic_vector(G_PIXEL_W-1 downto 0)
  );
end entity;

architecture A_Rtl of RgbToGray is
  signal s_gray : unsigned(G_PIXEL_W-1 downto 0);
  constant C_ZERO : unsigned(G_PIXEL_W-1 downto 0) := (others => '0');
begin
  s_gray <= C_ZERO when i_valid = '0' else s_gray;
  o_gray  <= std_logic_vector(s_gray);
  o_valid <= i_valid;
end architecture;
```

### Process + Variable Prefix

```vhd
P_REG_ACCUM : process(i_clk)
  variable v_sum : unsigned(9 downto 0);
begin
  if rising_edge(i_clk) then
    if i_rst_n = '0' then
      s_gray <= (others => '0');
    else
      v_sum  := unsigned(i_r) + unsigned(i_g) + unsigned(i_b);
      s_gray <= v_sum(v_sum'high downto 2);
    end if;
  end if;
end process;
```

### FSM Type + States

```vhd
type state_t is (ST_IDLE, ST_RUN, ST_FLUSH);
signal s_state, s_state_n : state_t;

P_REG_FSM : process(i_clk)
begin
  if rising_edge(i_clk) then
    if i_rst_n = '0' then
      s_state <= ST_IDLE;
    else
      s_state <= s_state_n;
    end if;
  end if;
end process;
```

### Instance Labeling

```vhd
U_LineBuffer0 : entity work.LineBuffer
  port map (
    i_clk   => i_clk,
    i_rst_n => i_rst_n,
    i_valid => i_valid,
    o_valid => open
  );
```

### Streaming Port Pattern (recommended)

```vhd
-- Pixel stream handshake + framing
-- i_pix_valid / o_pix_valid
-- i_pix_data  / o_pix_data
-- i_pix_sof   / o_pix_sof   (start of frame)
-- i_pix_eol   / o_pix_eol   (end of line)
```
