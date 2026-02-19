library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity ShiftRamChain is
  generic (
    -- Delay tap for Sobel-class overlay alignment (in accepted AXI beats).
    G_SOBEL_DELAY      : positive := 1027;
    -- Delay tap for blur+sobel alignment; must be >= G_SOBEL_DELAY.
    G_BLUR_SOBEL_DELAY : positive := 2054
  );
  port (
    -- Common clock domain for all cascaded c_shift_ram stages.
    i_clk                  : in  std_logic;
    -- IMPORTANT: drive with accepted AXI beat (VALID and READY).
    i_ce                   : in  std_logic;
    -- Synchronous clear.
    i_sclr                 : in  std_logic;

    -- 00: no delay, 01: sobel delay, 10: blur+sobel delay
    i_base_delay_stage_sel : in  std_logic_vector(1 downto 0);

    -- Fixed to generated c_shift_ram_0 contract: packed {SOF, EOL, RGB24} on D/Q[25:0].
    i_din                  : in  std_logic_vector(25 downto 0);
    o_dout                 : out std_logic_vector(25 downto 0)
  );
end entity;

architecture A_Rtl of ShiftRamChain is
  constant C_SEL_NONE       : std_logic_vector(1 downto 0) := "00";
  constant C_SEL_SOBEL      : std_logic_vector(1 downto 0) := "01";
  constant C_SEL_BLUR_SOBEL : std_logic_vector(1 downto 0) := "10";

  -- c_shift_ram_0 has 10-bit address depth: max per-stage delay = 1024 beats (A=1023).
  constant C_BLOCK_DELAY : positive := 1024;

  function f_ceil_div(i_a : positive; i_b : positive)
    return positive is
  begin
    return (i_a + i_b - 1) / i_b;
  end function;

  function f_last_chunk_delay(i_total_delay : positive; i_num_chunks : positive; i_block_delay : positive)
    return positive is
    variable v_rem : natural := i_total_delay - ((i_num_chunks - 1) * i_block_delay);
  begin
    if v_rem = 0 then
      return i_block_delay;
    end if;
    return v_rem;
  end function;

  function f_extra_last_chunk_delay(i_extra_delay : natural; i_extra_chunks : natural; i_block_delay : positive)
    return positive is
    variable v_rem : natural;
  begin
    if i_extra_chunks = 0 then
      return 1;
    end if;
    v_rem := i_extra_delay - ((i_extra_chunks - 1) * i_block_delay);
    if v_rem = 0 then
      return i_block_delay;
    end if;
    return v_rem;
  end function;

  function f_chunk_delay(i_index : natural; i_chunks : natural; i_block_delay : positive; i_last_delay : positive)
    return positive is
  begin
    if i_index + 1 < i_chunks then
      return i_block_delay;
    end if;
    return i_last_delay;
  end function;

  -- Split requested delays into full 1024-beat chunks plus one residual chunk.
  constant C_SOBEL_CHUNKS           : positive := f_ceil_div(G_SOBEL_DELAY, C_BLOCK_DELAY);
  constant C_SOBEL_LAST_CHUNK_DELAY : positive := f_last_chunk_delay(G_SOBEL_DELAY, C_SOBEL_CHUNKS, C_BLOCK_DELAY);

  constant C_EXTRA_DELAY : natural := G_BLUR_SOBEL_DELAY - G_SOBEL_DELAY;
  constant C_EXTRA_CHUNKS : natural := (C_EXTRA_DELAY + C_BLOCK_DELAY - 1) / C_BLOCK_DELAY;
  constant C_EXTRA_LAST_CHUNK_DELAY : positive := f_extra_last_chunk_delay(
    i_extra_delay  => C_EXTRA_DELAY,
    i_extra_chunks => C_EXTRA_CHUNKS,
    i_block_delay  => C_BLOCK_DELAY
  );

  type t_word_arr_t is array (natural range <>) of std_logic_vector(25 downto 0);
  signal s_sobel_pipe : t_word_arr_t(0 to C_SOBEL_CHUNKS) := (others => (others => '0'));
  signal s_blur_pipe  : t_word_arr_t(0 to C_EXTRA_CHUNKS) := (others => (others => '0'));
begin
  assert G_BLUR_SOBEL_DELAY >= G_SOBEL_DELAY
    report "ShiftRamChain requires G_BLUR_SOBEL_DELAY >= G_SOBEL_DELAY."
    severity failure;
  -- TODO: Consider asserting that i_base_delay_stage_sel never toggles mid-frame (SOF..EOL) in integration simulations.
  s_sobel_pipe(0) <= i_din;

  G_SOBEL_CHAIN: for i in 0 to C_SOBEL_CHUNKS - 1 generate
    constant C_DELAY_I : positive                     := f_chunk_delay(i, C_SOBEL_CHUNKS, C_BLOCK_DELAY, C_SOBEL_LAST_CHUNK_DELAY);
    constant C_A_I     : std_logic_vector(9 downto 0) := std_logic_vector(to_unsigned(C_DELAY_I - 1, 10));
  begin
    U_SobelChunk: entity work.c_shift_ram_0
      port map (
        A    => C_A_I,
        D    => s_sobel_pipe(i),
        CLK  => i_clk,
        CE   => i_ce,
        SCLR => i_sclr,
        Q    => s_sobel_pipe(i + 1)
      );
  end generate;

  G_NO_EXTRA: if C_EXTRA_CHUNKS = 0 generate
  begin
    s_blur_pipe(0) <= s_sobel_pipe(C_SOBEL_CHUNKS);
  end generate;

  G_EXTRA: if C_EXTRA_CHUNKS > 0 generate
  begin
    s_blur_pipe(0) <= s_sobel_pipe(C_SOBEL_CHUNKS);

    G_EXTRA_CHAIN: for i in 0 to C_EXTRA_CHUNKS - 1 generate
      constant C_DELAY_I : positive                     := f_chunk_delay(i, C_EXTRA_CHUNKS, C_BLOCK_DELAY, C_EXTRA_LAST_CHUNK_DELAY);
      constant C_A_I     : std_logic_vector(9 downto 0) := std_logic_vector(to_unsigned(C_DELAY_I - 1, 10));
    begin
      U_ExtraChunk: entity work.c_shift_ram_0
        port map (
          A    => C_A_I,
          D    => s_blur_pipe(i),
          CLK  => i_clk,
          CE   => i_ce,
          SCLR => i_sclr,
          Q    => s_blur_pipe(i + 1)
        );
    end generate;
  end generate;

  o_dout <= i_din                        when i_base_delay_stage_sel = C_SEL_NONE else
            s_sobel_pipe(C_SOBEL_CHUNKS) when i_base_delay_stage_sel = C_SEL_SOBEL else
            s_blur_pipe(C_EXTRA_CHUNKS)  when i_base_delay_stage_sel = C_SEL_BLUR_SOBEL else
            s_sobel_pipe(C_SOBEL_CHUNKS);
  -- FIXME: Illegal selector values currently fall through to Sobel delay instead of failing fast.
end architecture;
