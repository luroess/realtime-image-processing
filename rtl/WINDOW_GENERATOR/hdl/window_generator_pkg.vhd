library ieee;
use ieee.std_logic_1164.all;

package window_generator_pkg is

  -- Pixel width constant
  constant C_PXL_WIDTH : natural := 24;
  constant C_KERNEL_WIDTH : natural := 3;

  -- Pixel data type
  subtype t_pxl is std_logic_vector(C_PXL_WIDTH-1 downto 0);

  -- Window data type
  type t_wndw is array (0 to (C_KERNEL_WIDTH*C_KERNEL_WIDTH)-1) of t_pxl;

end package window_generator_pkg;

package body window_generator_pkg is
end package body window_generator_pkg;
