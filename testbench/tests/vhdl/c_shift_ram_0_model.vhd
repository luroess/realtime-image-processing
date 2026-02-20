library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity c_shift_ram_0 is
  port (
    A    : in  std_logic_vector(9 downto 0);
    D    : in  std_logic_vector(25 downto 0);
    CLK  : in  std_logic;
    CE   : in  std_logic;
    SCLR : in  std_logic;
    Q    : out std_logic_vector(25 downto 0)
  );
end entity;

architecture A_Sim of c_shift_ram_0 is
  type t_mem is array (0 to 1023) of std_logic_vector(25 downto 0);
  signal s_mem : t_mem := (others => (others => '0'));
  signal s_q   : std_logic_vector(25 downto 0) := (others => '0');
begin
  P_REG: process (CLK)
    variable v_idx : natural range 0 to 1023;
  begin
    if rising_edge(CLK) then
      if SCLR = '1' then
        s_mem <= (others => (others => '0'));
        s_q <= (others => '0');
      elsif CE = '1' then
        v_idx := to_integer(unsigned(A));
        s_q <= s_mem(v_idx);
        for i in 1023 downto 1 loop
          s_mem(i) <= s_mem(i - 1);
        end loop;
        s_mem(0) <= D;
      end if;
    end if;
  end process;

  Q <= s_q;
end architecture;
