-- =============================================================================
-- AxiPictureOverlay
-- =============================================================================
-- AXI4-Stream wrapper that paints a fixed-colour static picture overlay onto a
-- 24-bit RBG888 video stream.
--
-- The overlay mask is stored in a synthesis-time-initialised BRAM (MaskRom).
-- One mask bit is read per pixel beat; '1' replaces the pixel with
-- G_OVERLAY_COLOR, '0' passes it through unchanged.
--
-- Latency pipeline
-- ----------------
-- The BRAM has a synchronous (registered) read port with 1-cycle latency.
-- To compensate, the data path is delayed by one cycle using a single-stage
-- shift register on TDATA/TUSER/TLAST/TVALID.  The TREADY backpressure signal
-- is passed straight through (no FIFO needed because the pipeline stalls the
-- address counter together with the data).
--
--   Cycle  0   : address counter presents addr_N to MaskRom;
--                input beat data_N is latched into the delay register.
--   Cycle  1   : MaskRom outputs mask_bit_N;
--                delay register forwards data_N to the mux.
--                ? mask_bit_N and data_N arrive at PictureOverlayCore together.
--
-- Generics
-- --------
--   G_PIXEL_WIDTH    : bits per colour component (default 8)
--   G_MASK_W         : overlay mask width  in pixels (must match MaskRomPkg)
--   G_MASK_H         : overlay mask height in pixels (must match MaskRomPkg)
--   G_LINE_WIDTH     : full video line width  (>= G_MASK_W)
--   G_NUM_ROW        : full video frame height (>= G_MASK_H)
--   G_OVERLAY_COLOR  : 24-bit replacement colour R|B|G packed (default: green)
-- =============================================================================

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity AxiPictureOverlay is
  generic (
    G_PIXEL_WIDTH   : positive                      := 8;
    G_MASK_W        : positive                      := 4;
    G_MASK_H        : positive                      := 4;
    G_LINE_WIDTH    : positive                      := 4;
    G_NUM_ROW       : positive                      := 4;
    -- Overlay replacement colour, packed R|B|G.  Default: full green.
    G_OVERLAY_COLOR : std_logic_vector(23 downto 0) := x"0000FF"
  );
  port (
    i_aclk    : in  std_logic;
    i_aresetn : in  std_logic;

    -- Runtime pass control: '1' = pure passthrough, '0' enables overlay.
    i_pass_picture_overlay : in  std_logic;

    -- AXI4-Stream video slave (input, RBG888).
    s_axis_video_rbg888_tvalid : in  std_logic;
    s_axis_video_rbg888_tready : out std_logic;
    s_axis_video_rbg888_tdata  : in  std_logic_vector((3 * G_PIXEL_WIDTH) - 1 downto 0);
    s_axis_video_rbg888_tuser  : in  std_logic; -- SOF
    s_axis_video_rbg888_tlast  : in  std_logic; -- EOL

    -- AXI4-Stream video master (output, RBG888).
    m_axis_video_rbg888_tvalid : out std_logic;
    m_axis_video_rbg888_tready : in  std_logic;
    m_axis_video_rbg888_tdata  : out std_logic_vector((3 * G_PIXEL_WIDTH) - 1 downto 0);
    m_axis_video_rbg888_tuser  : out std_logic; -- SOF
    m_axis_video_rbg888_tlast  : out std_logic  -- EOL
  );
end entity AxiPictureOverlay;

architecture A_RtlStruct of AxiPictureOverlay is

  -- -------------------------------------------------------------------------
  -- Internal signals
  -- -------------------------------------------------------------------------

  -- Backpressure: stall when downstream is not ready or during reset.
  signal s_upstream_ready : std_logic;

  -- ROM address and in-region flag from the address controller.
  signal s_rom_addr      : unsigned(31 downto 0);
  signal s_in_region     : std_logic;

  -- Mask bit from the ROM (valid one cycle after s_rom_addr is presented).
  signal s_mask_bit : std_logic := '0';

  -- One-cycle delay pipeline to align data path with BRAM read latency.
  signal s_dly_tdata  : std_logic_vector((3 * G_PIXEL_WIDTH) - 1 downto 0) := (others => '0');
  signal s_dly_tvalid : std_logic := '0';
  signal s_dly_tuser  : std_logic := '0';
  signal s_dly_tlast  : std_logic := '0';
  signal s_dly_in_region : std_logic := '0';

  -- Output of the pixel mux core.
  signal s_mux_data : std_logic_vector((3 * G_PIXEL_WIDTH) - 1 downto 0);

begin

  -- =========================================================================
  -- Backpressure
  -- =========================================================================
  -- TREADY flows straight back to the upstream; we only gate it during reset.
  s_upstream_ready           <= '0' when i_aresetn = '0' else m_axis_video_rbg888_tready;
  s_axis_video_rbg888_tready <= s_upstream_ready;

  -- =========================================================================
  -- U_PictureOverlayCtrl : pixel address generator
  -- =========================================================================
  U_PictureOverlayCtrl : entity work.PictureOverlayCtrl
    generic map (
      G_MASK_W     => G_MASK_W,
      G_MASK_H     => G_MASK_H,
      G_LINE_WIDTH => G_LINE_WIDTH,
      G_NUM_ROW    => G_NUM_ROW
    )
    port map (
      i_aclk    => i_aclk,
      i_aresetn => i_aresetn,
      i_tvalid  => s_axis_video_rbg888_tvalid,
      i_tready  => s_upstream_ready,
      i_tuser   => s_axis_video_rbg888_tuser,
      i_tlast   => s_axis_video_rbg888_tlast,
      o_addr      => s_rom_addr,
      o_in_region => s_in_region
    );

  -- =========================================================================
  -- U_MaskRom : 1-bit-per-pixel BRAM ROM
  -- Dimensions come from MaskRomPkg constants; no generics needed.
  -- =========================================================================
  U_MaskRom : entity work.MaskRom
    port map (
      i_clk  => i_aclk,
      i_addr => s_rom_addr,
      o_bit  => s_mask_bit
    );

  -- =========================================================================
  -- P_REG_DELAY : one-cycle data-path delay to absorb BRAM read latency
  -- =========================================================================
  -- The address controller drives s_rom_addr combinationally from the current
  -- counter values; MaskRom delivers s_mask_bit one cycle later.  We latch the
  -- AXI-Stream sideband signals here on the same beat the counter presents the
  -- address, so that s_dly_* and s_mask_bit emerge from the BRAM together.
  --
  -- The enable condition is (tvalid AND tready) ? the same condition that
  -- advances the pixel counter ? so data and in_region always stay aligned.
  P_REG_DELAY : process (i_aclk) is
  begin
    if rising_edge(i_aclk) then
      if i_aresetn = '0' then
        s_dly_tdata     <= (others => '0');
        s_dly_tvalid    <= '0';
        s_dly_tuser     <= '0';
        s_dly_tlast     <= '0';
        s_dly_in_region <= '0';
      else
        -- Always update tvalid so the output can de-assert when input goes idle.
        s_dly_tvalid <= s_axis_video_rbg888_tvalid and s_upstream_ready;
        -- Only latch data/sideband when a pixel beat is actually accepted.
        if s_axis_video_rbg888_tvalid = '1' and s_upstream_ready = '1' then
          s_dly_tdata     <= s_axis_video_rbg888_tdata;
          s_dly_tuser     <= s_axis_video_rbg888_tuser;
          s_dly_tlast     <= s_axis_video_rbg888_tlast;
          s_dly_in_region <= s_in_region;
        end if;
      end if;
    end if;
  end process P_REG_DELAY;

  -- =========================================================================
  -- U_PictureOverlayCore : combinational pixel mux
  -- =========================================================================
  U_PictureOverlayCore : entity work.PictureOverlayCore
    generic map (
      G_COMPONENT_WIDTH => G_PIXEL_WIDTH,
      G_OVERLAY_COLOR   => G_OVERLAY_COLOR
    )
    port map (
      i_pass_picture_overlay => i_pass_picture_overlay,
      i_mask_bit             => s_mask_bit,
      i_in_region            => s_dly_in_region,
      i_video_rbg888         => s_dly_tdata,
      o_video_rbg888         => s_mux_data
    );

  -- =========================================================================
  -- Output assignments
  -- =========================================================================
  m_axis_video_rbg888_tvalid <= '0'         when i_aresetn = '0' else s_dly_tvalid;
  m_axis_video_rbg888_tdata  <= (others => '0') when (i_aresetn = '0') or (s_dly_tvalid = '0')
                                 else s_mux_data;
  m_axis_video_rbg888_tuser  <= '0'         when (i_aresetn = '0') or (s_dly_tvalid = '0')
                                 else s_dly_tuser;
  m_axis_video_rbg888_tlast  <= '0'         when (i_aresetn = '0') or (s_dly_tvalid = '0')
                                 else s_dly_tlast;

end architecture A_RtlStruct;
