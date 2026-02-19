-- =============================================================================
-- PictureOverlayCtrl
-- =============================================================================
-- Pixel-synchronous address generator for the overlay mask ROM.
--
-- Tracks column and row counters locked to the incoming AXI4-Stream video
-- handshake signals (TUSER = SOF, TLAST = EOL).  Produces a flat ROM address
-- (row * G_MASK_W + col) one clock cycle before the corresponding pixel data
-- is needed at the mux, compensating the one-cycle BRAM read latency.
--
-- Signals
--   i_aclk      : system clock
--   i_aresetn   : active-low synchronous reset
--   i_tvalid    : TVALID from upstream AXI-Stream
--   i_tready    : TREADY from downstream AXI-Stream (backpressure)
--   i_tuser     : TUSER (SOF) from upstream
--   i_tlast     : TLAST (EOL) from upstream
--   o_addr      : ROM address for the *next* pixel (presented one cycle ahead)
--   o_in_region : '1' when the current pixel falls within the mask bounds
--
-- The address and in_region signals are registered; they are valid at the same
-- time as the ROM output (one cycle after the AXI-Stream beat they refer to).
-- The wrapper must delay the data path by one cycle to align them.
-- =============================================================================

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity PictureOverlayCtrl is
  generic (
    -- Mask image width and height in pixels.
    G_MASK_W : positive := 4;
    G_MASK_H : positive := 4;
    -- Full video line width (may be wider than the mask).
    G_LINE_WIDTH : positive := 4;
    -- Full video frame height (may be taller than the mask).
    G_NUM_ROW : positive := 4
  );
  port (
    i_aclk    : in  std_logic;
    i_aresetn : in  std_logic;

    -- AXI-Stream handshake (combinational inputs, not registered internally).
    i_tvalid : in  std_logic;
    i_tready : in  std_logic;
    i_tuser  : in  std_logic; -- SOF
    i_tlast  : in  std_logic; -- EOL

    -- ROM address for the pixel that will emerge from the BRAM one cycle later.
    o_addr      : out unsigned(31 downto 0);
    -- '1' during cycles where the corresponding pixel is inside the mask region.
    o_in_region : out std_logic
  );
end entity PictureOverlayCtrl;

architecture A_Rtl of PictureOverlayCtrl is

  -- Centered top-left origin of the overlay mask inside the full frame.
  -- Assumes G_LINE_WIDTH >= G_MASK_W and G_NUM_ROW >= G_MASK_H.
  constant C_MASK_COL0 : natural := (G_LINE_WIDTH - G_MASK_W) / 2;
  constant C_MASK_ROW0 : natural := (G_NUM_ROW - G_MASK_H) / 2;

  -- s_col_prev / s_row_prev hold the position of the PREVIOUS accepted beat.
  -- On reset they are initialised to the "end of last line of last frame" so
  -- that the combinational next-position logic naturally yields (0, 0) for
  -- the very first beat of the first frame.
  signal s_col_prev : natural range 0 to G_LINE_WIDTH - 1 := G_LINE_WIDTH - 1;
  signal s_row_prev : natural range 0 to G_NUM_ROW - 1    := G_NUM_ROW - 1;

  -- s_eol_prev is '1' when the previous beat was an EOL (tlast).
  -- Used to detect the first pixel of a new line (non-SOF).
  signal s_eol_prev : std_logic := '1';

  -- s_first_beat is '1' before any valid beat has been seen in this frame,
  -- used to correctly handle frames whose first line has no explicit SOF.
  signal s_first_beat : std_logic := '1';

begin

  -- Parameter sanity checks.
  assert G_LINE_WIDTH >= G_MASK_W
    report "PictureOverlayCtrl: G_LINE_WIDTH must be >= G_MASK_W"
    severity failure;
  assert G_NUM_ROW >= G_MASK_H
    report "PictureOverlayCtrl: G_NUM_ROW must be >= G_MASK_H"
    severity failure;

  -- -------------------------------------------------------------------------
  -- P_COMB_NEXT : derive current beat's (col, row) and drive ROM outputs.
  --
  -- Latency contract
  -- ----------------
  -- o_addr and o_in_region are combinational from the registered previous-beat
  -- state.  They are VALID during the current beat (tvalid & tready).
  -- The BRAM sees o_addr and delivers the mask bit one cycle later.
  -- AxiPictureOverlay latches tdata/tuser/tlast in P_REG_DELAY on the same
  -- beat, producing s_dly_* one cycle later ? aligned with s_mask_bit.
  -- -------------------------------------------------------------------------
  P_COMB_NEXT : process (
    s_col_prev, s_row_prev, s_eol_prev, s_first_beat,
    i_tvalid, i_tready, i_tuser, i_tlast
  ) is
    variable v_col : natural range 0 to G_LINE_WIDTH - 1;
    variable v_row : natural range 0 to G_NUM_ROW - 1;
  begin
    if i_tvalid = '1' and i_tready = '1' then
      if i_tuser = '1' then
        -- SOF: always pixel (0, 0).
        v_col := 0;
        v_row := 0;
      elsif s_eol_prev = '1' or s_first_beat = '1' then
        -- First pixel of a new line (not SOF): col=0, row advances.
        v_col := 0;
        if s_row_prev < G_NUM_ROW - 1 then
          v_row := s_row_prev + 1;
        else
          v_row := s_row_prev;
        end if;
      else
        -- Mid-line: advance column.
        if s_col_prev < G_LINE_WIDTH - 1 then
          v_col := s_col_prev + 1;
        else
          v_col := s_col_prev;
        end if;
        v_row := s_row_prev;
      end if;
    else
      -- No handshake: hold previous position for ROM (address doesn't matter,
      -- in_region driven '0' so any stale output is masked anyway).
      v_col := s_col_prev;
      v_row := s_row_prev;
    end if;

    if (v_col >= C_MASK_COL0) and (v_col < (C_MASK_COL0 + G_MASK_W))
      and (v_row >= C_MASK_ROW0) and (v_row < (C_MASK_ROW0 + G_MASK_H)) then
      o_addr      <= to_unsigned(
        (v_row - C_MASK_ROW0) * G_MASK_W + (v_col - C_MASK_COL0),
        32
      );
      o_in_region <= '1' when (i_tvalid = '1' and i_tready = '1') else '0';
    else
      o_addr      <= (others => '0');
      o_in_region <= '0';
    end if;
  end process P_COMB_NEXT;

  -- -------------------------------------------------------------------------
  -- P_REG_COORD : register the current beat's position for the next cycle.
  -- -------------------------------------------------------------------------
  P_REG_COORD : process (i_aclk) is
    variable v_col : natural range 0 to G_LINE_WIDTH - 1;
    variable v_row : natural range 0 to G_NUM_ROW - 1;
  begin
    if rising_edge(i_aclk) then
      if i_aresetn = '0' then
        s_col_prev  <= G_LINE_WIDTH - 1;
        s_row_prev  <= G_NUM_ROW - 1;
        s_eol_prev  <= '1';
        s_first_beat <= '1';
      elsif i_tvalid = '1' and i_tready = '1' then
        s_first_beat <= '0';
        s_eol_prev   <= i_tlast;
        if i_tuser = '1' then
          s_col_prev <= 0;
          s_row_prev <= 0;
        elsif s_eol_prev = '1' or s_first_beat = '1' then
          s_col_prev <= 0;
          if s_row_prev < G_NUM_ROW - 1 then
            s_row_prev <= s_row_prev + 1;
          end if;
        else
          if s_col_prev < G_LINE_WIDTH - 1 then
            s_col_prev <= s_col_prev + 1;
          end if;
        end if;
      end if;
    end if;
  end process P_REG_COORD;

end architecture A_Rtl;
