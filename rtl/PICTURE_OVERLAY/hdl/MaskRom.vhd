-- =============================================================================
-- MaskRom
-- =============================================================================
-- Synchronous read-only memory holding a 1-bit-per-pixel overlay mask.
-- Contents are initialised at synthesis time from MaskRomPkg.C_MASK_DATA;
-- no runtime writes occur.  Vivado infers Block RAM in read-only mode.
--
-- Ports
--   i_clk  : system clock (rising-edge active)
--   i_addr : pixel address = row * G_MASK_W + col (registered ? 1-cycle latency)
--   o_bit  : mask value for the addressed pixel, valid one cycle after i_addr
--            '1' = overlay active, '0' = transparent
-- =============================================================================

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library work;
  use work.MaskRomPkg.all;

entity MaskRom is
  port (
    -- Clock for synchronous (BRAM-inferred) read.
    i_clk  : in  std_logic;
    -- Read address: row * G_MASK_W + col, presented one cycle before data is needed.
    i_addr : in  unsigned(31 downto 0);
    -- Mask bit output, valid one cycle after i_addr is presented.
    o_bit  : out std_logic
  );
end entity MaskRom;

architecture A_Rtl of MaskRom is

  -- Derive ROM depth directly from the package so dimensions are always consistent.
  constant C_ROM_DEPTH : positive := G_MASK_W * G_MASK_H;

  -- 1-bit-per-word ROM array; initialised from the synthesised package constant.
  type t_rom_t is array (0 to C_ROM_DEPTH - 1) of std_logic;

  -- Unpack the flat std_logic_vector constant into an array so the synthesiser
  -- can map it to Block RAM init data.
  function f_init_rom return t_rom_t is
    variable v_rom : t_rom_t;
  begin
    for i in 0 to C_ROM_DEPTH - 1 loop
      v_rom(i) := C_MASK_DATA(i);
    end loop;
    return v_rom;
  end function;

  signal s_rom : t_rom_t := f_init_rom;

begin

  -- Synchronous read ? one clock cycle latency.
  -- The synthesiser will infer a 1-bit wide Block RAM in read-only mode.
  P_REG_READ : process (i_clk) is
  begin
    if rising_edge(i_clk) then
      if to_integer(i_addr) < C_ROM_DEPTH then
        o_bit <= s_rom(to_integer(i_addr));
      else
        o_bit <= '0';
      end if;
    end if;
  end process P_REG_READ;

end architecture A_Rtl;
