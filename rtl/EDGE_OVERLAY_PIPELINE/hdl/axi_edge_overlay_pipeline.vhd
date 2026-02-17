library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity AXI_EdgeOverlayPipeline is
  -- TODO(entity-contract): Define pipeline mode matrix and latency expectations so system-level integration can select output behavior predictably.
  generic (
  G_COMPONENT_WIDTH : positive                      := 8;
  G_PIXEL_WIDTH     : positive                      := 8;
  G_KERNEL_SIZE     : positive                      := 3;
  G_LINE_WIDTH      : positive                      := 512;
  G_NUM_ROW         : positive                      := 512;
  G_FILTER_SELECT   : natural                       := 0;
  G_FAST_THRESHOLD  : natural                       := 20;
  G_FAST_N          : positive                      := 9;
  G_SOBEL_THRESHOLD : natural                       := 200;
    G_EDGE_COLOR      : std_logic_vector(23 downto 0) := x"FF0000";
    G_RGB_FIFO_DEPTH  : positive                      := 2048
  );
  port (
    i_aclk                : in  std_logic;
    i_aresetn             : in  std_logic;
    i_pass_through        : in  std_logic;
    i_overlay_enable      : in  std_logic;

    s_axis_video_tvalid   : in  std_logic;
    s_axis_video_tready   : out std_logic;
    s_axis_video_tdata    : in  std_logic_vector((3 * G_COMPONENT_WIDTH) - 1 downto 0);
    s_axis_video_tuser    : in  std_logic;
    s_axis_video_tlast    : in  std_logic;

    m_axis_video_rbg888_tvalid : out std_logic;
    m_axis_video_rbg888_tready : in  std_logic;
    m_axis_video_rbg888_tdata  : out std_logic_vector((3 * G_COMPONENT_WIDTH) - 1 downto 0);
    m_axis_video_rbg888_tuser  : out std_logic;
    m_axis_video_rbg888_tlast  : out std_logic
  );
end entity;

architecture A_Rtl of AXI_EdgeOverlayPipeline is
  -- FIXME(merger-interface): This top-level path behaves as a mode-limited demultiplexer/compositor; evolve interface to explicit mode select (rgb, gray, rgb+edge, rgb+fast, gray+fast, blur variants).
  subtype t_rgb_t is std_logic_vector((3 * G_COMPONENT_WIDTH) - 1 downto 0);
  type t_rgb_mem_t is array (0 to G_RGB_FIFO_DEPTH - 1) of t_rgb_t;
  type t_sideband_mem_t is array (0 to G_RGB_FIFO_DEPTH - 1) of std_logic;

  constant C_FILTER_SOBEL : natural := 0;
  constant C_FILTER_FAST  : natural := 2;
  constant C_WINDOW_WARMUP_BEATS : natural := ((G_LINE_WIDTH + 1) * ((G_KERNEL_SIZE - 1) / 2)) + 1;
  constant C_FAST_EDGE_COLOR : std_logic_vector(23 downto 0) := x"00FF00";

  signal s_rgb_tvalid : std_logic := '0';
  signal s_rgb_tready : std_logic := '0';
  signal s_rgb_tdata  : t_rgb_t := (others => '0');
  signal s_rgb_tuser  : std_logic := '0';
  signal s_rgb_tlast  : std_logic := '0';

  signal s_gray_tvalid : std_logic := '0';
  signal s_gray_tready : std_logic := '0';
  signal s_gray_tdata  : std_logic_vector(G_PIXEL_WIDTH - 1 downto 0) := (others => '0');
  signal s_gray_tuser  : std_logic := '0';
  signal s_gray_tlast  : std_logic := '0';

  signal s_edge8_tvalid : std_logic := '0';
  signal s_edge8_tready : std_logic := '0';
  signal s_edge8_tdata  : std_logic_vector(G_PIXEL_WIDTH - 1 downto 0) := (others => '0');
  signal s_edge8_tuser  : std_logic := '0';
  signal s_edge8_tlast  : std_logic := '0';
  signal s_edge_bit     : std_logic := '0';

  signal s_fifo_mem_data : t_rgb_mem_t := (others => (others => '0'));
  signal s_fifo_mem_user : t_sideband_mem_t := (others => '0');
  signal s_fifo_mem_last : t_sideband_mem_t := (others => '0');
  signal s_fifo_wr_ptr   : natural range 0 to G_RGB_FIFO_DEPTH - 1 := 0;
  signal s_fifo_rd_ptr   : natural range 0 to G_RGB_FIFO_DEPTH - 1 := 0;
  signal s_fifo_count    : natural range 0 to G_RGB_FIFO_DEPTH := 0;

  signal s_fifo_in_ready : std_logic := '0';
  signal s_fifo_out_valid : std_logic := '0';
  signal s_fifo_out_data : t_rgb_t := (others => '0');
  signal s_fifo_out_user : std_logic := '0';
  signal s_fifo_out_last : std_logic := '0';
  signal s_fifo_write_hs : std_logic := '0';
  signal s_fifo_read_hs : std_logic := '0';
  signal s_overlay_rgb_tready : std_logic := '0';
begin
  -- FIXME(generic-guard): Keep FIFO-depth guard synchronized with warm-up formula and testbench assumptions to prevent hidden underflow misalignment.
  assert G_COMPONENT_WIDTH = G_PIXEL_WIDTH
    report "AXI_EdgeOverlayPipeline requires G_COMPONENT_WIDTH = G_PIXEL_WIDTH."
    severity failure;
  assert G_RGB_FIFO_DEPTH > C_WINDOW_WARMUP_BEATS
    report "AXI_EdgeOverlayPipeline requires G_RGB_FIFO_DEPTH > window warm-up beats."
    severity failure;

  U_RgbToGrayscale: entity work.AXI_RgbToGrayscale
    -- TODO(stage-contract): Reconfirm passthrough/grayscale semantics here when introducing selectable merger modes so downstream expectation logic remains consistent.
    generic map (
      G_COMPONENT_WIDTH => G_COMPONENT_WIDTH
    )
    port map (
      i_aclk               => i_aclk,
      i_aresetn            => i_aresetn,
      i_pass_through       => i_pass_through,
      s_axis_video_tvalid  => s_axis_video_tvalid,
      s_axis_video_tready  => s_axis_video_tready,
      s_axis_video_tdata   => s_axis_video_tdata,
      s_axis_video_tuser   => s_axis_video_tuser,
      s_axis_video_tlast   => s_axis_video_tlast,
      m_axis_rbg888_tvalid => s_rgb_tvalid,
      m_axis_rbg888_tready => s_rgb_tready,
      m_axis_rbg888_tdata  => s_rgb_tdata,
      m_axis_rbg888_tuser  => s_rgb_tuser,
      m_axis_rbg888_tlast  => s_rgb_tlast,
      m_axis_gray8_tvalid  => s_gray_tvalid,
      m_axis_gray8_tready  => s_gray_tready,
      m_axis_gray8_tdata   => s_gray_tdata,
      m_axis_gray8_tuser   => s_gray_tuser,
      m_axis_gray8_tlast   => s_gray_tlast
    );

  U_FilterWrapper: entity work.AXI_FilterWrapper
    -- FIXME(filter-select): Replace fixed Sobel selection with mode-controlled dispatch when FAST/blur overlays are promoted to first-class runtime options.
    generic map (
      G_FILTER_SELECT   => G_FILTER_SELECT,
      G_SOBEL_THRESHOLD => G_SOBEL_THRESHOLD,
      G_FAST_THRESHOLD  => G_FAST_THRESHOLD,
      G_FAST_N          => G_FAST_N,
      G_PIXEL_WIDTH     => G_PIXEL_WIDTH,
      G_KERNEL_SIZE     => G_KERNEL_SIZE,
      G_LINE_WIDTH      => G_LINE_WIDTH,
      G_NUM_ROW         => G_NUM_ROW
    )
    port map (
      i_aclk               => i_aclk,
      i_aresetn            => i_aresetn,
      s_axis_gray8_tvalid  => s_gray_tvalid,
      s_axis_gray8_tready  => s_gray_tready,
      s_axis_gray8_tdata   => s_gray_tdata,
      s_axis_gray8_tuser   => s_gray_tuser,
      s_axis_gray8_tlast   => s_gray_tlast,
      m_axis_filter8_tvalid => s_edge8_tvalid,
      m_axis_filter8_tready => s_edge8_tready,
      m_axis_filter8_tdata  => s_edge8_tdata,
      m_axis_filter8_tuser  => s_edge8_tuser,
      m_axis_filter8_tlast  => s_edge8_tlast
    );

  -- TODO(edge-encoding): Keep edge-bit extraction policy explicit so alternative filter outputs can map to overlay predicates without ambiguity.
  s_edge_bit <= s_edge8_tdata(G_PIXEL_WIDTH - 1);

  G_EdgeOverlaySobel: if G_FILTER_SELECT /= C_FILTER_FAST generate
    U_EdgeOverlay: entity work.AXI_EdgeOverlay
      -- FIXME(compositor-path): Generalize this single compositor instance into a selectable merger fabric before adding gray/fast/blur output combinations.
      generic map (
        G_COMPONENT_WIDTH => G_COMPONENT_WIDTH,
        G_EDGE_COLOR      => G_EDGE_COLOR
      )
      port map (
        i_aclk                     => i_aclk,
        i_aresetn                  => i_aresetn,
        i_overlay_enable           => i_overlay_enable,
        s_axis_video_rbg888_tvalid => s_fifo_out_valid,
        s_axis_video_rbg888_tready => s_overlay_rgb_tready,
        s_axis_video_rbg888_tdata  => s_fifo_out_data,
        s_axis_video_rbg888_tuser  => s_fifo_out_user,
        s_axis_video_rbg888_tlast  => s_fifo_out_last,
        s_axis_video_edges_tvalid  => s_edge8_tvalid,
        s_axis_video_edges_tready  => s_edge8_tready,
        s_axis_video_edges_tdata   => s_edge_bit,
        s_axis_video_edges_tuser   => s_edge8_tuser,
        s_axis_video_edges_tlast   => s_edge8_tlast,
        m_axis_video_rbg888_tvalid => m_axis_video_rbg888_tvalid,
        m_axis_video_rbg888_tready => m_axis_video_rbg888_tready,
        m_axis_video_rbg888_tdata  => m_axis_video_rbg888_tdata,
        m_axis_video_rbg888_tuser  => m_axis_video_rbg888_tuser,
        m_axis_video_rbg888_tlast  => m_axis_video_rbg888_tlast
      );
  end generate;

  G_EdgeOverlayFast: if G_FILTER_SELECT = C_FILTER_FAST generate
    U_EdgeOverlayFast: entity work.AXI_EdgeOverlay
      -- FIXME(compositor-path): Keep FAST overlays visually distinct from Sobel overlays while preserving shared lockstep behavior.
      generic map (
        G_COMPONENT_WIDTH => G_COMPONENT_WIDTH,
        G_EDGE_COLOR      => C_FAST_EDGE_COLOR
      )
      port map (
        i_aclk                     => i_aclk,
        i_aresetn                  => i_aresetn,
        i_overlay_enable           => i_overlay_enable,
        s_axis_video_rbg888_tvalid => s_fifo_out_valid,
        s_axis_video_rbg888_tready => s_overlay_rgb_tready,
        s_axis_video_rbg888_tdata  => s_fifo_out_data,
        s_axis_video_rbg888_tuser  => s_fifo_out_user,
        s_axis_video_rbg888_tlast  => s_fifo_out_last,
        s_axis_video_edges_tvalid  => s_edge8_tvalid,
        s_axis_video_edges_tready  => s_edge8_tready,
        s_axis_video_edges_tdata   => s_edge_bit,
        s_axis_video_edges_tuser   => s_edge8_tuser,
        s_axis_video_edges_tlast   => s_edge8_tlast,
        m_axis_video_rbg888_tvalid => m_axis_video_rbg888_tvalid,
        m_axis_video_rbg888_tready => m_axis_video_rbg888_tready,
        m_axis_video_rbg888_tdata  => m_axis_video_rbg888_tdata,
        m_axis_video_rbg888_tuser  => m_axis_video_rbg888_tuser,
        m_axis_video_rbg888_tlast  => m_axis_video_rbg888_tlast
      );
  end generate;

  -- TODO(fifo-handshake): Preserve explicit FIFO handshake combinational logic here to keep throughput analysis and backpressure debugging straightforward.
  s_fifo_in_ready <= '1' when s_fifo_count < G_RGB_FIFO_DEPTH else '0';
  s_rgb_tready    <= s_fifo_in_ready;

  -- FIXME(fifo-alignment): Validate FIFO dequeue alignment whenever overlay consumer timing changes; drift here will desynchronize RGB payload from edge metadata.
  s_fifo_out_valid <= '1' when s_fifo_count > 0 else '0';
  s_fifo_out_data <= (others => '0') when s_fifo_count = 0 else
                     s_fifo_mem_data(s_fifo_rd_ptr);
  s_fifo_out_user <= '0' when s_fifo_count = 0 else
                     s_fifo_mem_user(s_fifo_rd_ptr);
  s_fifo_out_last <= '0' when s_fifo_count = 0 else
                     s_fifo_mem_last(s_fifo_rd_ptr);

  -- TODO(handshake-flags): Keep write/read handshake flags centralized so occupancy updates remain single-source and auditable.
  s_fifo_write_hs <= s_rgb_tvalid and s_fifo_in_ready;
  s_fifo_read_hs  <= s_fifo_out_valid and s_overlay_rgb_tready;

  P_RGB_FIFO: process (i_aclk)
    -- FIXME(fifo-robustness): Add simulation-time overflow/underflow assertions if runtime mode switching is introduced to catch pointer/count divergence early.
  begin
    if rising_edge(i_aclk) then
      if i_aresetn = '0' then
        s_fifo_wr_ptr <= 0;
        s_fifo_rd_ptr <= 0;
        s_fifo_count  <= 0;
      else
        -- synthesis translate_off
        if (s_fifo_write_hs = '1') and (s_fifo_read_hs = '0') and (s_fifo_count = G_RGB_FIFO_DEPTH) then
          assert false
            report "AXI_EdgeOverlayPipeline FIFO overflow attempt: write handshake while FIFO is full."
            severity failure;
        end if;
        if (s_fifo_write_hs = '0') and (s_fifo_read_hs = '1') and (s_fifo_count = 0) then
          assert false
            report "AXI_EdgeOverlayPipeline FIFO underflow attempt: read handshake while FIFO is empty."
            severity failure;
        end if;
        -- synthesis translate_on

        if s_fifo_write_hs = '1' then
          s_fifo_mem_data(s_fifo_wr_ptr) <= s_rgb_tdata;
          s_fifo_mem_user(s_fifo_wr_ptr) <= s_rgb_tuser;
          s_fifo_mem_last(s_fifo_wr_ptr) <= s_rgb_tlast;
          if s_fifo_wr_ptr = G_RGB_FIFO_DEPTH - 1 then
            s_fifo_wr_ptr <= 0;
          else
            s_fifo_wr_ptr <= s_fifo_wr_ptr + 1;
          end if;
        end if;

        if s_fifo_read_hs = '1' then
          if s_fifo_rd_ptr = G_RGB_FIFO_DEPTH - 1 then
            s_fifo_rd_ptr <= 0;
          else
            s_fifo_rd_ptr <= s_fifo_rd_ptr + 1;
          end if;
        end if;

        if s_fifo_write_hs = '1' and s_fifo_read_hs = '0' then
          if s_fifo_count < G_RGB_FIFO_DEPTH then
            s_fifo_count <= s_fifo_count + 1;
          end if;
        elsif s_fifo_write_hs = '0' and s_fifo_read_hs = '1' then
          if s_fifo_count > 0 then
            s_fifo_count <= s_fifo_count - 1;
          end if;
        end if;
      end if;
    end if;
  end process;
end architecture;
