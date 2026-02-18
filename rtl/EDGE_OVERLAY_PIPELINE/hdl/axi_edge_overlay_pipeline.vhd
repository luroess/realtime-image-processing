library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity AXI_EdgeOverlayPipeline is
  generic (
    G_COMPONENT_WIDTH : positive := 8;
    G_PIXEL_WIDTH     : positive := 8;
    G_KERNEL_SIZE     : positive := 3; -- retained for compatibility
    G_LINE_WIDTH      : positive := 512;
    G_NUM_ROW         : positive := 512;
    G_FILTER_SELECT   : natural  := 0; -- retained for compatibility
    G_FAST_THRESHOLD  : natural  := 20;
    G_FAST_N          : positive := 9;
    G_FAST_IMPL       : positive := 1;
    G_SOBEL_THRESHOLD : natural  := 200;
    G_SOBEL_COLOR     : std_logic_vector(23 downto 0) := x"FF0000";
    G_FAST_COLOR      : std_logic_vector(23 downto 0) := x"0000FF";
    G_RGB_FIFO_DEPTH  : positive := 2048
  );
  port (
    i_aclk                : in  std_logic;
    i_aresetn             : in  std_logic;
    i_base_mode           : in  std_logic_vector(1 downto 0);
    i_overlay_mode        : in  std_logic_vector(1 downto 0);

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
  function f_window_warmup(i_line_width : positive; i_kernel_size : positive)
    return natural is
  begin
    return ((i_line_width + 1) * ((i_kernel_size - 1) / 2)) + 1;
  end function;

  subtype t_rgb_t is std_logic_vector((3 * G_COMPONENT_WIDTH) - 1 downto 0);
  type t_rgb_mem_t is array (0 to G_RGB_FIFO_DEPTH - 1) of t_rgb_t;
  type t_bit_mem_t is array (0 to G_RGB_FIFO_DEPTH - 1) of std_logic;
  type t_sideband_mem_t is array (0 to G_RGB_FIFO_DEPTH - 1) of std_logic;

  constant C_SOBEL_KERNEL_SIZE : positive := 3;
  constant C_FAST_KERNEL_SIZE  : positive := 7;
  constant C_SOBEL_WARMUP      : natural := f_window_warmup(G_LINE_WIDTH, C_SOBEL_KERNEL_SIZE);
  constant C_FAST_WARMUP       : natural := f_window_warmup(G_LINE_WIDTH, C_FAST_KERNEL_SIZE) +
                                            f_window_warmup(G_LINE_WIDTH, C_SOBEL_KERNEL_SIZE);

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

  signal s_gray_bcast_valid : std_logic := '0';
  signal s_gray_bcast_data  : std_logic_vector(G_PIXEL_WIDTH - 1 downto 0) := (others => '0');
  signal s_gray_bcast_user  : std_logic := '0';
  signal s_gray_bcast_last  : std_logic := '0';
  signal s_gray_bcast_ready : std_logic := '0';

  signal s_gray_sobel_tvalid : std_logic := '0';
  signal s_gray_sobel_tready : std_logic := '0';
  signal s_gray_sobel_tdata  : std_logic_vector(G_PIXEL_WIDTH - 1 downto 0) := (others => '0');
  signal s_gray_sobel_tuser  : std_logic := '0';
  signal s_gray_sobel_tlast  : std_logic := '0';

  signal s_gray_fast_tvalid : std_logic := '0';
  signal s_gray_fast_tready : std_logic := '0';
  signal s_gray_fast_tdata  : std_logic_vector(G_PIXEL_WIDTH - 1 downto 0) := (others => '0');
  signal s_gray_fast_tuser  : std_logic := '0';
  signal s_gray_fast_tlast  : std_logic := '0';

  signal s_sobel_tvalid : std_logic := '0';
  signal s_sobel_tready : std_logic := '0';
  signal s_sobel_tdata  : std_logic_vector(G_PIXEL_WIDTH - 1 downto 0) := (others => '0');
  signal s_sobel_tuser  : std_logic := '0';
  signal s_sobel_tlast  : std_logic := '0';
  signal s_sobel_bit    : std_logic := '0';

  signal s_fast_tvalid : std_logic := '0';
  signal s_fast_tready : std_logic := '0';
  signal s_fast_tdata  : std_logic_vector(G_PIXEL_WIDTH - 1 downto 0) := (others => '0');
  signal s_fast_tuser  : std_logic := '0';
  signal s_fast_tlast  : std_logic := '0';
  signal s_fast_bit    : std_logic := '0';

  signal s_rgb_fifo_mem_data : t_rgb_mem_t := (others => (others => '0'));
  signal s_rgb_fifo_mem_user : t_sideband_mem_t := (others => '0');
  signal s_rgb_fifo_mem_last : t_sideband_mem_t := (others => '0');
  signal s_rgb_fifo_wr_ptr   : natural range 0 to G_RGB_FIFO_DEPTH - 1 := 0;
  signal s_rgb_fifo_rd_ptr   : natural range 0 to G_RGB_FIFO_DEPTH - 1 := 0;
  signal s_rgb_fifo_count    : natural range 0 to G_RGB_FIFO_DEPTH := 0;

  signal s_rgb_fifo_in_ready : std_logic := '0';
  signal s_rgb_fifo_out_valid : std_logic := '0';
  signal s_rgb_fifo_out_data : t_rgb_t := (others => '0');
  signal s_rgb_fifo_out_user : std_logic := '0';
  signal s_rgb_fifo_out_last : std_logic := '0';
  signal s_rgb_fifo_write_hs : std_logic := '0';
  signal s_rgb_fifo_read_hs  : std_logic := '0';

  signal s_sobel_fifo_mem_data : t_bit_mem_t := (others => '0');
  signal s_sobel_fifo_mem_user : t_sideband_mem_t := (others => '0');
  signal s_sobel_fifo_mem_last : t_sideband_mem_t := (others => '0');
  signal s_sobel_fifo_wr_ptr   : natural range 0 to G_RGB_FIFO_DEPTH - 1 := 0;
  signal s_sobel_fifo_rd_ptr   : natural range 0 to G_RGB_FIFO_DEPTH - 1 := 0;
  signal s_sobel_fifo_count    : natural range 0 to G_RGB_FIFO_DEPTH := 0;

  signal s_sobel_fifo_in_ready : std_logic := '0';
  signal s_sobel_fifo_out_valid : std_logic := '0';
  signal s_sobel_fifo_out_data : std_logic := '0';
  signal s_sobel_fifo_out_user : std_logic := '0';
  signal s_sobel_fifo_out_last : std_logic := '0';
  signal s_sobel_fifo_write_hs : std_logic := '0';
  signal s_sobel_fifo_read_hs  : std_logic := '0';

  signal s_comp_rgb_tready   : std_logic := '0';
  signal s_comp_gray_tready  : std_logic := '0';
  signal s_comp_sobel_tready : std_logic := '0';
  signal s_comp_fast_tready  : std_logic := '0';

  signal s_rgb_fifo_gray8 : std_logic_vector(G_PIXEL_WIDTH - 1 downto 0) := (others => '0');
begin
  assert G_COMPONENT_WIDTH = G_PIXEL_WIDTH
    report "AXI_EdgeOverlayPipeline requires G_COMPONENT_WIDTH = G_PIXEL_WIDTH."
    severity failure;
  assert G_RGB_FIFO_DEPTH > C_FAST_WARMUP
    report "AXI_EdgeOverlayPipeline requires G_RGB_FIFO_DEPTH > FAST warmup beats."
    severity failure;

  U_RgbToGrayscale: entity work.AXI_RgbToGrayscale
    generic map (
      G_COMPONENT_WIDTH => G_COMPONENT_WIDTH
    )
    port map (
      i_aclk               => i_aclk,
      i_aresetn            => i_aresetn,
      i_pass_through       => '1',
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

  -- Gray broadcast to Sobel and FAST branches.
  s_gray_bcast_ready <= '1' when (i_aresetn = '1') and
                                 ((s_gray_bcast_valid = '0') or
                                  (s_gray_sobel_tready = '1' and s_gray_fast_tready = '1')) else
                        '0';
  s_gray_tready <= s_gray_bcast_ready;

  s_gray_sobel_tvalid <= s_gray_bcast_valid;
  s_gray_sobel_tdata  <= s_gray_bcast_data;
  s_gray_sobel_tuser  <= s_gray_bcast_user;
  s_gray_sobel_tlast  <= s_gray_bcast_last;

  s_gray_fast_tvalid <= s_gray_bcast_valid;
  s_gray_fast_tdata  <= s_gray_bcast_data;
  s_gray_fast_tuser  <= s_gray_bcast_user;
  s_gray_fast_tlast  <= s_gray_bcast_last;

  P_GRAY_BROADCAST : process (i_aclk)
  begin
    if rising_edge(i_aclk) then
      if i_aresetn = '0' then
        s_gray_bcast_valid <= '0';
        s_gray_bcast_data  <= (others => '0');
        s_gray_bcast_user  <= '0';
        s_gray_bcast_last  <= '0';
      elsif s_gray_bcast_ready = '1' then
        if s_gray_tvalid = '1' then
          s_gray_bcast_valid <= '1';
          s_gray_bcast_data  <= s_gray_tdata;
          s_gray_bcast_user  <= s_gray_tuser;
          s_gray_bcast_last  <= s_gray_tlast;
        else
          s_gray_bcast_valid <= '0';
          s_gray_bcast_user  <= '0';
          s_gray_bcast_last  <= '0';
        end if;
      end if;
    end if;
  end process;

  U_SobelWrapper: entity work.AXI_FilterWrapper
    generic map (
      G_FILTER_SELECT   => 0,
      G_SOBEL_THRESHOLD => G_SOBEL_THRESHOLD,
      G_FAST_THRESHOLD  => G_FAST_THRESHOLD,
      G_FAST_N          => G_FAST_N,
      G_FAST_IMPL       => G_FAST_IMPL,
      G_PIXEL_WIDTH     => G_PIXEL_WIDTH,
      G_KERNEL_SIZE     => C_SOBEL_KERNEL_SIZE,
      G_LINE_WIDTH      => G_LINE_WIDTH,
      G_NUM_ROW         => G_NUM_ROW
    )
    port map (
      i_aclk                => i_aclk,
      i_aresetn             => i_aresetn,
      s_axis_gray8_tvalid   => s_gray_sobel_tvalid,
      s_axis_gray8_tready   => s_gray_sobel_tready,
      s_axis_gray8_tdata    => s_gray_sobel_tdata,
      s_axis_gray8_tuser    => s_gray_sobel_tuser,
      s_axis_gray8_tlast    => s_gray_sobel_tlast,
      m_axis_filter8_tvalid => s_sobel_tvalid,
      m_axis_filter8_tready => s_sobel_tready,
      m_axis_filter8_tdata  => s_sobel_tdata,
      m_axis_filter8_tuser  => s_sobel_tuser,
      m_axis_filter8_tlast  => s_sobel_tlast
    );

  U_FastWrapper: entity work.AXI_FilterWrapper
    generic map (
      G_FILTER_SELECT   => 2,
      G_SOBEL_THRESHOLD => G_SOBEL_THRESHOLD,
      G_FAST_THRESHOLD  => G_FAST_THRESHOLD,
      G_FAST_N          => G_FAST_N,
      G_FAST_IMPL       => G_FAST_IMPL,
      G_PIXEL_WIDTH     => G_PIXEL_WIDTH,
      G_KERNEL_SIZE     => C_FAST_KERNEL_SIZE,
      G_LINE_WIDTH      => G_LINE_WIDTH,
      G_NUM_ROW         => G_NUM_ROW
    )
    port map (
      i_aclk                => i_aclk,
      i_aresetn             => i_aresetn,
      s_axis_gray8_tvalid   => s_gray_fast_tvalid,
      s_axis_gray8_tready   => s_gray_fast_tready,
      s_axis_gray8_tdata    => s_gray_fast_tdata,
      s_axis_gray8_tuser    => s_gray_fast_tuser,
      s_axis_gray8_tlast    => s_gray_fast_tlast,
      m_axis_filter8_tvalid => s_fast_tvalid,
      m_axis_filter8_tready => s_fast_tready,
      m_axis_filter8_tdata  => s_fast_tdata,
      m_axis_filter8_tuser  => s_fast_tuser,
      m_axis_filter8_tlast  => s_fast_tlast
    );

  s_sobel_bit <= s_sobel_tdata(G_PIXEL_WIDTH - 1);
  s_fast_bit  <= s_fast_tdata(G_PIXEL_WIDTH - 1);

  -- RGB alignment FIFO.
  s_rgb_fifo_in_ready <= '1' when s_rgb_fifo_count < G_RGB_FIFO_DEPTH else '0';
  s_rgb_tready        <= s_rgb_fifo_in_ready;

  s_rgb_fifo_out_valid <= '1' when s_rgb_fifo_count > 0 else '0';
  s_rgb_fifo_out_data  <= (others => '0') when s_rgb_fifo_count = 0 else s_rgb_fifo_mem_data(s_rgb_fifo_rd_ptr);
  s_rgb_fifo_out_user  <= '0' when s_rgb_fifo_count = 0 else s_rgb_fifo_mem_user(s_rgb_fifo_rd_ptr);
  s_rgb_fifo_out_last  <= '0' when s_rgb_fifo_count = 0 else s_rgb_fifo_mem_last(s_rgb_fifo_rd_ptr);

  s_rgb_fifo_write_hs <= s_rgb_tvalid and s_rgb_fifo_in_ready;
  s_rgb_fifo_read_hs  <= s_rgb_fifo_out_valid and s_comp_rgb_tready and s_comp_gray_tready;

  P_RGB_FIFO : process (i_aclk)
  begin
    if rising_edge(i_aclk) then
      if i_aresetn = '0' then
        s_rgb_fifo_wr_ptr <= 0;
        s_rgb_fifo_rd_ptr <= 0;
        s_rgb_fifo_count  <= 0;
      else
        if s_rgb_fifo_write_hs = '1' then
          s_rgb_fifo_mem_data(s_rgb_fifo_wr_ptr) <= s_rgb_tdata;
          s_rgb_fifo_mem_user(s_rgb_fifo_wr_ptr) <= s_rgb_tuser;
          s_rgb_fifo_mem_last(s_rgb_fifo_wr_ptr) <= s_rgb_tlast;
          if s_rgb_fifo_wr_ptr = G_RGB_FIFO_DEPTH - 1 then
            s_rgb_fifo_wr_ptr <= 0;
          else
            s_rgb_fifo_wr_ptr <= s_rgb_fifo_wr_ptr + 1;
          end if;
        end if;

        if s_rgb_fifo_read_hs = '1' then
          if s_rgb_fifo_rd_ptr = G_RGB_FIFO_DEPTH - 1 then
            s_rgb_fifo_rd_ptr <= 0;
          else
            s_rgb_fifo_rd_ptr <= s_rgb_fifo_rd_ptr + 1;
          end if;
        end if;

        if s_rgb_fifo_write_hs = '1' and s_rgb_fifo_read_hs = '0' then
          if s_rgb_fifo_count < G_RGB_FIFO_DEPTH then
            s_rgb_fifo_count <= s_rgb_fifo_count + 1;
          end if;
        elsif s_rgb_fifo_write_hs = '0' and s_rgb_fifo_read_hs = '1' then
          if s_rgb_fifo_count > 0 then
            s_rgb_fifo_count <= s_rgb_fifo_count - 1;
          end if;
        end if;
      end if;
    end if;
  end process;

  -- Sobel alignment FIFO.
  s_sobel_fifo_in_ready <= '1' when s_sobel_fifo_count < G_RGB_FIFO_DEPTH else '0';
  s_sobel_tready        <= s_sobel_fifo_in_ready;

  s_sobel_fifo_out_valid <= '1' when s_sobel_fifo_count > 0 else '0';
  s_sobel_fifo_out_data  <= '0' when s_sobel_fifo_count = 0 else s_sobel_fifo_mem_data(s_sobel_fifo_rd_ptr);
  s_sobel_fifo_out_user  <= '0' when s_sobel_fifo_count = 0 else s_sobel_fifo_mem_user(s_sobel_fifo_rd_ptr);
  s_sobel_fifo_out_last  <= '0' when s_sobel_fifo_count = 0 else s_sobel_fifo_mem_last(s_sobel_fifo_rd_ptr);

  s_sobel_fifo_write_hs <= s_sobel_tvalid and s_sobel_fifo_in_ready;
  s_sobel_fifo_read_hs  <= s_sobel_fifo_out_valid and s_comp_sobel_tready;

  P_SOBEL_FIFO : process (i_aclk)
  begin
    if rising_edge(i_aclk) then
      if i_aresetn = '0' then
        s_sobel_fifo_wr_ptr <= 0;
        s_sobel_fifo_rd_ptr <= 0;
        s_sobel_fifo_count  <= 0;
      else
        if s_sobel_fifo_write_hs = '1' then
          s_sobel_fifo_mem_data(s_sobel_fifo_wr_ptr) <= s_sobel_bit;
          s_sobel_fifo_mem_user(s_sobel_fifo_wr_ptr) <= s_sobel_tuser;
          s_sobel_fifo_mem_last(s_sobel_fifo_wr_ptr) <= s_sobel_tlast;
          if s_sobel_fifo_wr_ptr = G_RGB_FIFO_DEPTH - 1 then
            s_sobel_fifo_wr_ptr <= 0;
          else
            s_sobel_fifo_wr_ptr <= s_sobel_fifo_wr_ptr + 1;
          end if;
        end if;

        if s_sobel_fifo_read_hs = '1' then
          if s_sobel_fifo_rd_ptr = G_RGB_FIFO_DEPTH - 1 then
            s_sobel_fifo_rd_ptr <= 0;
          else
            s_sobel_fifo_rd_ptr <= s_sobel_fifo_rd_ptr + 1;
          end if;
        end if;

        if s_sobel_fifo_write_hs = '1' and s_sobel_fifo_read_hs = '0' then
          if s_sobel_fifo_count < G_RGB_FIFO_DEPTH then
            s_sobel_fifo_count <= s_sobel_fifo_count + 1;
          end if;
        elsif s_sobel_fifo_write_hs = '0' and s_sobel_fifo_read_hs = '1' then
          if s_sobel_fifo_count > 0 then
            s_sobel_fifo_count <= s_sobel_fifo_count - 1;
          end if;
        end if;
      end if;
    end if;
  end process;

  U_RgbToGrayForCompositor: entity work.E_RgbToGrayscale
    generic map (
      G_COMPONENT_WIDTH => G_COMPONENT_WIDTH
    )
    port map (
      i_rgb888 => s_rgb_fifo_out_data,
      o_gray8  => s_rgb_fifo_gray8,
      o_rbg888 => open
    );

  s_fast_tready <= s_comp_fast_tready;

  U_FrameCompositor: entity work.AXI_FrameCompositor
    generic map (
      G_COMPONENT_WIDTH => G_COMPONENT_WIDTH,
      G_SOBEL_COLOR     => G_SOBEL_COLOR,
      G_FAST_COLOR      => G_FAST_COLOR
    )
    port map (
      i_aclk       => i_aclk,
      i_aresetn    => i_aresetn,
      i_base_mode  => i_base_mode,
      i_overlay_mode => i_overlay_mode,

      s_axis_video_rbg888_tvalid => s_rgb_fifo_out_valid,
      s_axis_video_rbg888_tready => s_comp_rgb_tready,
      s_axis_video_rbg888_tdata  => s_rgb_fifo_out_data,
      s_axis_video_rbg888_tuser  => s_rgb_fifo_out_user,
      s_axis_video_rbg888_tlast  => s_rgb_fifo_out_last,

      s_axis_video_gray8_tvalid  => s_rgb_fifo_out_valid,
      s_axis_video_gray8_tready  => s_comp_gray_tready,
      s_axis_video_gray8_tdata   => s_rgb_fifo_gray8,
      s_axis_video_gray8_tuser   => s_rgb_fifo_out_user,
      s_axis_video_gray8_tlast   => s_rgb_fifo_out_last,

      s_axis_video_sobel_tvalid  => s_sobel_fifo_out_valid,
      s_axis_video_sobel_tready  => s_comp_sobel_tready,
      s_axis_video_sobel_tdata   => s_sobel_fifo_out_data,
      s_axis_video_sobel_tuser   => s_sobel_fifo_out_user,
      s_axis_video_sobel_tlast   => s_sobel_fifo_out_last,

      s_axis_video_fast_tvalid   => s_fast_tvalid,
      s_axis_video_fast_tready   => s_comp_fast_tready,
      s_axis_video_fast_tdata    => s_fast_bit,
      s_axis_video_fast_tuser    => s_fast_tuser,
      s_axis_video_fast_tlast    => s_fast_tlast,

      m_axis_video_rbg888_tvalid => m_axis_video_rbg888_tvalid,
      m_axis_video_rbg888_tready => m_axis_video_rbg888_tready,
      m_axis_video_rbg888_tdata  => m_axis_video_rbg888_tdata,
      m_axis_video_rbg888_tuser  => m_axis_video_rbg888_tuser,
      m_axis_video_rbg888_tlast  => m_axis_video_rbg888_tlast
    );

  -- synthesis translate_off
  P_SIM_ASSERT_READY_LOCKSTEP : process (i_aclk)
  begin
    if rising_edge(i_aclk) then
      if i_aresetn = '1' and s_rgb_fifo_out_valid = '1' then
        assert s_comp_rgb_tready = s_comp_gray_tready
          report "AXI_EdgeOverlayPipeline: compositor RGB/GRAY ready diverged."
          severity failure;
      end if;
    end if;
  end process;
  -- synthesis translate_on
end architecture;
