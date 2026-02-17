library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity window_generator is
  generic (
    -- bits per pixel
    G_PIXEL_WIDTH : positive := 8;
    -- Size of kernel = ouput window size
    G_KERNEL_SIZE : positive := 3;
    -- Image line width
    G_LINE_WIDTH : natural := 5;
    -- Image row count
    G_ROW : natural := 5
  );
  port (
    i_aclk            : in  std_logic;
    i_aresetn         : in  std_logic;

    -- AXI4-Stream Video Slave (input)
    s_axis_video_tvalid : in  std_logic;
    s_axis_video_tready : out std_logic;
    s_axis_video_tdata  : in  std_logic_vector(G_PIXEL_WIDTH - 1 downto 0);
    s_axis_video_tuser  : in  std_logic; -- SOF
    s_axis_video_tlast  : in  std_logic; -- EOL

    -- AXI4-Stream Video Master (output)
    m_axis_window_tvalid : out std_logic;
    m_axis_window_tready : in  std_logic;
    m_axis_window_tdata  : out std_logic_vector((G_KERNEL_SIZE * G_KERNEL_SIZE * G_PIXEL_WIDTH) - 1 downto 0);
    m_axis_window_tuser  : out std_logic; -- SOF
    m_axis_window_tlast  : out std_logic  -- EOL
  );
end entity;

architecture A_Rtl of window_generator is
  ------------------------------------------------------------------
  -- constants
  ------------------------------------------------------------------
  subtype t_pxl is std_logic_vector(G_PIXEL_WIDTH - 1 downto 0);
  type t_wndw is array (0 to (G_KERNEL_SIZE * G_KERNEL_SIZE) - 1) of t_pxl;
  subtype t_wndw_flat_t is std_logic_vector((G_KERNEL_SIZE * G_KERNEL_SIZE * G_PIXEL_WIDTH) - 1 downto 0);

  constant C_ZERO : t_pxl := (others => '0');
  constant C_BUF_LEN : positive := ((G_KERNEL_SIZE - 1) * G_LINE_WIDTH) + G_KERNEL_SIZE;
  constant C_FILL_MIN : positive := (G_LINE_WIDTH + 1) * ((G_KERNEL_SIZE - 1) / 2);

  ------------------------------------------------------------------
  -- types
  ------------------------------------------------------------------
  type t_line is array (0 to G_LINE_WIDTH-1) of t_pxl;
  type t_buf is array (0 to C_BUF_LEN-1) of t_pxl;

  ------------------------------------------------------------------
  -- signals
  ------------------------------------------------------------------
  -- buffers
  signal buf_reg  : t_buf; -- pixel buffer
  signal sof_reg  : std_logic_vector((C_FILL_MIN-1)+2 downto 0) := (others => '0'); -- control signal buffer (+2 for internal delay s_data -> wndw -> m_data)
  signal eol_reg  : std_logic_vector((C_FILL_MIN-1)+2 downto 0) := (others => '0'); -- control signal buffer (+2 for internal delay s_data -> wndw -> m_data)
  signal rdy_reg  : std_logic := '0';

  -- counters
  signal col_cnt : natural range 0 to G_LINE_WIDTH+1 := 0; -- column counter needed for padding
  signal row_cnt : natural range 0 to G_ROW+1 := 0; -- row counter needed for padding
  signal pxl_cnt : natural range 0 to G_LINE_WIDTH*G_ROW := 0; -- pixel counter needed for initial fill
  signal col_cnt_out : natural range 0 to G_LINE_WIDTH+1 := 0; -- column counter needed for padding
  signal row_cnt_out : natural range 0 to G_ROW+1 := 0; -- row counter needed for padding

  -- window data
  signal wndw : t_wndw;
  -- signal wndw_2d : t_wndw_t := (others => (others => C_ZERO));
  signal wndw_valid : std_logic := '0';

  ------------------------------------------------------------------
  -- functions
  ------------------------------------------------------------------
  -- 1D window array to flat_window (std_logic_vector)
  function f_pack_1d_wndw(i_w : t_wndw)
    return t_wndw_flat_t is
    variable v_flat : t_wndw_flat_t := (others => '0');
  begin
    for i in 0 to G_KERNEL_SIZE*G_KERNEL_SIZE-1 loop
      v_flat((i+1)*G_PIXEL_WIDTH-1 downto i*G_PIXEL_WIDTH) := i_w(i);
    end loop;
    return v_flat;
  end function;

begin

  ------------------------------------------------------------------
  -- Line buffering
  ------------------------------------------------------------------
  process(i_aclk)
    ------------------------------------------------------------------
    -- variables
    ------------------------------------------------------------------
    variable v_col_cnt_out  : natural range 0 to G_LINE_WIDTH+1 := 0; -- column counter
    variable v_row_cnt_out  : natural range 0 to G_ROW+1 := 0; -- row counter
  begin
    if rising_edge(i_aclk) then
      if i_aresetn = '0' then
        -- clear counters
        col_cnt     <= 0;
        row_cnt     <= 0;
        pxl_cnt     <= 0;
        col_cnt_out <= 0;
        row_cnt_out <= 0;
        v_col_cnt_out := 0;
        v_row_cnt_out := 0;
        -- clear registers
        sof_reg     <= (others => '0');
        eol_reg     <= (others => '0');
        rdy_reg     <= '0';
        wndw_valid  <= '0';
        wndw        <= (others => C_ZERO);
        buf_reg     <= (others => C_ZERO);
        -- reset outputs
        s_axis_video_tready   <= '0';
        m_axis_window_tvalid  <= '0';
        m_axis_window_tdata   <= (others => '0');
        m_axis_window_tuser   <= '0';
        m_axis_window_tlast   <= '0';
      else

        -- buffer fill control
        if pxl_cnt <= C_FILL_MIN then -- <= because first pixel is counted as 1, while C_FILL_MIN starts at 0
          -- buffer not filled: keep signalling ready, until buffer completely filled
          s_axis_video_tready <= '1';
          rdy_reg <= '1';
          wndw_valid <= '0';
        else
          -- buffer filled: pass on downstream status
          s_axis_video_tready <= m_axis_window_tready;
          rdy_reg <= m_axis_window_tready;
          wndw_valid <= '1'; -- ? put s_axis_video_tvalid here?
        end if;

        -- AXI Stream handshake occured for input data stream
        if s_axis_video_tvalid = '1' and rdy_reg = '1' then

          -- shift pixels in buffer
          for i in 0 to C_BUF_LEN-2 loop
            buf_reg(i) <= buf_reg(i+1);
          end loop;
          -- append current pixel
          buf_reg(C_BUF_LEN-1) <= s_axis_video_tdata;

          -- shift control signals
          sof_reg <= sof_reg(sof_reg'high-1 downto sof_reg'low) & s_axis_video_tuser; -- shift in current value
          eol_reg <= eol_reg(eol_reg'high-1 downto eol_reg'low) & s_axis_video_tlast; -- shift in current value

          -- increment pixels received
          if pxl_cnt < 2*C_FILL_MIN then -- only use this counter after reset for first fill of buffer until valid output can be produced
            pxl_cnt <= pxl_cnt + 1;
          end if;

          -- handle output counters
          if pxl_cnt > C_FILL_MIN+1 then
            -- EOL
            if eol_reg(eol_reg'high) = '1' then
              col_cnt_out <= 0;
              v_col_cnt_out := 0;
              row_cnt_out <= row_cnt_out + 1;
              v_row_cnt_out := v_row_cnt_out + 1;
            else
              col_cnt_out <= col_cnt_out + 1;
              v_col_cnt_out := v_col_cnt_out + 1;
            end if;
            -- SOF
            if sof_reg(sof_reg'high) = '1' then
              row_cnt_out <= 0;
              v_row_cnt_out := 0;
            end if;
          end if;

          -- counters
          col_cnt <= col_cnt + 1;
          -- reset column on EOL
          if s_axis_video_tlast = '1' then -- EOL
            col_cnt <= 0;
            row_cnt <= row_cnt + 1;
          end if;

          -- Reset row on SOF
          if s_axis_video_tuser = '1' then
            row_cnt <= 0;
            --col_cnt <= 0;
          end if;

        end if; -- end handshake occured

        ------------------------------------------------------------------
        -- 3x3 Window generation with Zero Padding
        -- 1D window:
        -- wndw(0)   wndw(1)   wndw(2)
        -- wndw(3)   wndw(4)   wndw(5)
        -- wndw(6)   wndw(7)   wndw(8)
        ------------------------------------------------------------------

        --default to normal case (no edge pixel)
        wndw(0) <= buf_reg(0);
        wndw(1) <= buf_reg(1);
        wndw(2) <= buf_reg(2);
        wndw(3) <= buf_reg(G_LINE_WIDTH+0);
        wndw(4) <= buf_reg(G_LINE_WIDTH+1); -- pixel that convolution produces result for
        wndw(5) <= buf_reg(G_LINE_WIDTH+2);
        wndw(6) <= buf_reg(2*G_LINE_WIDTH+0);
        wndw(7) <= buf_reg(2*G_LINE_WIDTH+1);
        wndw(8) <= buf_reg(2*G_LINE_WIDTH+2);

        -- edge cases
        -- first and last line
        if v_row_cnt_out < 1 then -- first row in frame
          wndw(0) <= C_ZERO;
          wndw(1) <= C_ZERO;
          wndw(2) <= C_ZERO;
        elsif v_row_cnt_out >= G_ROW-1 then -- last row in frame
          wndw(6) <= C_ZERO;
          wndw(7) <= C_ZERO;
          wndw(8) <= C_ZERO;
        end if;

        -- first and last column
        if v_col_cnt_out < 1 then -- first column in line
          wndw(0) <= C_ZERO;
          wndw(3) <= C_ZERO;
          wndw(6) <= C_ZERO;
        elsif v_col_cnt_out >= G_LINE_WIDTH-1 then -- last column in line
          wndw(2) <= C_ZERO;
          wndw(5) <= C_ZERO;
          wndw(8) <= C_ZERO;
        end if;

        ------------------------------------------------------------------
        -- AXI Stream Master outputs
        ------------------------------------------------------------------
        m_axis_window_tvalid  <= wndw_valid;
        m_axis_window_tdata   <= f_pack_1d_wndw(wndw);
        m_axis_window_tlast   <= eol_reg(eol_reg'high);
        m_axis_window_tuser   <= sof_reg(sof_reg'high);

      end if; -- end rst
    end if; -- end rising edge
  end process;

end architecture;
