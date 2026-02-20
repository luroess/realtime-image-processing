library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity window_generator is
  generic (
    -- bits per pixel
    G_PIXEL_WIDTH : positive := 8;
    -- Size of kernel = output window size
    G_KERNEL_SIZE : positive := 3;
    -- Image line width
    G_LINE_WIDTH : natural := 5;
    -- Image row count
    G_NUM_ROW : natural := 5;
    -- Type of padding for out-of-bounds pixels (zero padding or replication)
    G_EDGE_PADDING : natural := 0 -- '0' for zero padding, '1' for replicate edge
  );
  port (
    i_aclk            : in  std_logic;
    i_aresetn         : in  std_logic;

    -- AXI4-Stream Video Slave (input)
    s_axis_gray8_tvalid : in  std_logic;
    s_axis_gray8_tready : out std_logic;
    s_axis_gray8_tdata  : in  std_logic_vector(G_PIXEL_WIDTH - 1 downto 0);
    s_axis_gray8_tuser  : in  std_logic; -- SOF
    s_axis_gray8_tlast  : in  std_logic; -- EOL

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
  constant C_OFFSET : natural := 0;
  constant C_BUF_LEN : positive := ((G_KERNEL_SIZE - 1) * G_LINE_WIDTH) + G_KERNEL_SIZE + C_OFFSET;
  constant C_CENTER_PXL_IDX : positive := (G_LINE_WIDTH + 1) * ((G_KERNEL_SIZE - 1) / 2); -- 6 for 3x3 kernel and line width of 5
  constant C_FILL_MIN : positive := C_BUF_LEN - C_CENTER_PXL_IDX; -- 7 for 3x3 kernel and line width of 5

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
  signal sof_reg  : std_logic_vector((C_FILL_MIN-1)+C_OFFSET downto 0) := (others => '0'); -- control signal buffer aligned to output payload timing
  signal eol_reg  : std_logic_vector((C_FILL_MIN-1)+C_OFFSET downto 0) := (others => '0'); -- control signal buffer aligned to output payload timing

  -- counters
  signal col_cnt : natural range 0 to G_LINE_WIDTH+1 := 0; -- column counter needed for padding
  signal row_cnt : natural range 0 to G_NUM_ROW+1 := 0; -- row counter needed for padding
  signal pxl_cnt : natural range 0 to G_LINE_WIDTH*G_NUM_ROW := 0; -- pixel counter needed for initial fill
  signal col_cnt_out : natural range 0 to G_LINE_WIDTH+1 := 0; -- column counter needed for padding
  signal row_cnt_out : natural range 0 to G_NUM_ROW+1 := 0; -- row counter needed for padding

  -- output registers
  signal m_axis_window_tvalid_reg : std_logic := '0';
  signal m_axis_window_tuser_reg  : std_logic := '0';
  signal m_axis_window_tlast_reg  : std_logic := '0';

  ------------------------------------------------------------------
  -- functions
  ------------------------------------------------------------------

  -- 1D window array to flat_window (std_logic_vector)
  --   Packs a 1D window array of G_KERNEL_SIZE*G_KERNEL_SIZE pixels into a single
  --   std_logic_vector for the AXI Stream master output interface.
  --   i_w : t_wndw         -> 1D window array of G_KERNEL_SIZE*G_KERNEL_SIZE pixels
  --   return t_wndw_flat_t -> flat std_logic_vector of G_KERNEL_SIZE*G_KERNEL_SIZE*G_PIXEL_WIDTH bits representing the window pixels
  function f_pack_1d_wndw(i_w : t_wndw) return t_wndw_flat_t is
    -- returned variable
    variable v_flat : t_wndw_flat_t := (others => '0');
  begin
    for i in 0 to G_KERNEL_SIZE*G_KERNEL_SIZE-1 loop
      v_flat((i+1)*G_PIXEL_WIDTH-1 downto i*G_PIXEL_WIDTH) := i_w(i);
    end loop;
    return v_flat;
  end function;

  -- buffer to 1D window array
  --   Extracts a G_KERNEL_SIZE x G_KERNEL_SIZE pixel window from the line buffer
  --   around the current pixel position, applying padding for out-of-bounds access
  --   (zero padding or edge replication as configured by G_EDGE_PADDING).
  --   i_buf : t_buf     -> multi-line pixel buffer storing recent image rows
  --   i_col : natural   -> current pixel column index in the frame
  --   i_row : natural   -> current pixel row index in the frame
  --   return t_wndw     -> 1D window array of G_KERNEL_SIZE*G_KERNEL_SIZE pixels
  function f_wndw_from_buffer(i_buf : t_buf; i_col : natural; i_row : natural) return t_wndw is
    constant C_MAX_PAD : natural := ((G_KERNEL_SIZE - 1) / 2); -- max padding needed for odd kernel sizes (e.g. 1 for 3x3, 2 for 5x5)
    -- returned variable
    variable v_wndw : t_wndw := (others => C_ZERO);
    -- indexing helpers
    variable v_1d_wndw_idx : natural := 0;
    variable v_buf_idx : natural := 0;
    variable v_replicate_offset_r : natural range 0 to C_MAX_PAD := 0;
    variable v_replicate_offset_c : natural range 0 to C_MAX_PAD := 0;
    -- edge helpers
    variable v_out_top : std_logic := '0';
    variable v_out_bottom : std_logic := '0';
    variable v_out_left : std_logic := '0';
    variable v_out_right : std_logic := '0';
  begin
    ------------------------------------------------------------------
    -- Window generation with Zero Padding
    -- E.g. 3x3 1D window:
    -- wndw(0)   wndw(1)   wndw(2)
    -- wndw(3)   wndw(4)   wndw(5)
    -- wndw(6)   wndw(7)   wndw(8)
    ------------------------------------------------------------------
    for r in 0 to G_KERNEL_SIZE-1 loop
      for c in 0 to G_KERNEL_SIZE-1 loop
        v_1d_wndw_idx := (r * G_KERNEL_SIZE) + c;
        v_buf_idx := (r * G_LINE_WIDTH) + c;

        if (i_row < C_MAX_PAD and r < C_MAX_PAD) then
          v_out_top := '1'; -- out of img bounds to the top
        else
          v_out_top := '0';
        end if;

        if (i_row >= G_NUM_ROW-C_MAX_PAD and r >= G_KERNEL_SIZE-C_MAX_PAD) then
          v_out_bottom := '1'; -- out of img bounds to the bottom
        else
          v_out_bottom := '0';
        end if;

        if (i_col < C_MAX_PAD and c < C_MAX_PAD) then
          v_out_left := '1'; -- out of img bounds to the left
        else
          v_out_left := '0';
        end if;

        if (i_col >= G_LINE_WIDTH-C_MAX_PAD and c >= G_KERNEL_SIZE-C_MAX_PAD) then
          v_out_right := '1'; -- out of img bounds to the right
        else
          v_out_right := '0';
        end if;

        -- set window pixel value
        v_wndw(v_1d_wndw_idx) := i_buf(v_buf_idx); -- normal image pixel behavior

        if G_EDGE_PADDING = 1 then
          -- Replicate edge pixels for out-of-bounds pixels
          v_replicate_offset_r := abs(C_MAX_PAD - r);
          v_replicate_offset_c := abs(C_MAX_PAD - c);
          if (v_out_top = '1' and v_out_bottom = '0' and v_out_left = '0' and v_out_right = '0') then
            -- Only TOP out of range
            v_wndw(v_1d_wndw_idx) := i_buf(v_buf_idx + (v_replicate_offset_r * G_LINE_WIDTH)); -- replicate from row below
          elsif (v_out_top = '0' and v_out_bottom = '1' and v_out_left = '0' and v_out_right = '0') then
            -- Only BOTTOM out of range
            v_wndw(v_1d_wndw_idx) := i_buf(v_buf_idx - (v_replicate_offset_r * G_LINE_WIDTH)); -- replicate from row above
          elsif (v_out_top = '0' and v_out_bottom = '0' and v_out_left = '1' and v_out_right = '0') then
            -- Only LEFT out of range
            v_wndw(v_1d_wndw_idx) := i_buf(v_buf_idx + v_replicate_offset_c); -- replicate from column to the right
          elsif (v_out_top = '0' and v_out_bottom = '0' and v_out_left = '0' and v_out_right = '1') then
            -- Only RIGHT out of range
            v_wndw(v_1d_wndw_idx) := i_buf(v_buf_idx - v_replicate_offset_c); -- replicate from column to the left
          elsif (v_out_top = '1' and v_out_bottom = '0' and v_out_left = '1' and v_out_right = '0') then
            -- TOP and LEFT out of range
            v_wndw(v_1d_wndw_idx) := i_buf(v_buf_idx + ((v_replicate_offset_r * G_LINE_WIDTH) + v_replicate_offset_c)); -- replicate from pixel diagonally down-right
          elsif (v_out_top = '1' and v_out_bottom = '0' and v_out_left = '0' and v_out_right = '1') then
            -- TOP and RIGHT out of range
            v_wndw(v_1d_wndw_idx) := i_buf(v_buf_idx + ((v_replicate_offset_r * G_LINE_WIDTH) - v_replicate_offset_c)); -- replicate from pixel diagonally down-left
          elsif (v_out_top = '0' and v_out_bottom = '1' and v_out_left = '1' and v_out_right = '0') then
            -- BOTTOM and LEFT out of range
            v_wndw(v_1d_wndw_idx) := i_buf(v_buf_idx - ((v_replicate_offset_r * G_LINE_WIDTH) - v_replicate_offset_c)); -- replicate from pixel diagonally up-right
          elsif (v_out_top = '0' and v_out_bottom = '1' and v_out_left = '0' and v_out_right = '1') then
            -- BOTTOM and RIGHT out of range
            v_wndw(v_1d_wndw_idx) := i_buf(v_buf_idx - ((v_replicate_offset_r * G_LINE_WIDTH) + v_replicate_offset_c)); -- replicate from pixel diagonally up-left
          end if;
        elsif G_EDGE_PADDING = 0 then
          -- zero padding for out-of-bounds pixels
          if (v_out_left = '1') then -- out of img bounds to the left
            v_wndw(v_1d_wndw_idx) := C_ZERO;
          end if;
          if (v_out_right = '1') then -- out of img bounds to the right
            v_wndw(v_1d_wndw_idx) := C_ZERO;
          end if;
          if (v_out_top = '1') then -- out of img bounds to the top
            v_wndw(v_1d_wndw_idx) := C_ZERO;
          end if;
          if (v_out_bottom = '1') then -- out of img bounds to the bottom
            v_wndw(v_1d_wndw_idx) := C_ZERO;
          end if;
        end if;

      end loop;
    end loop;
    return v_wndw;
  end function;

begin

  assert (G_KERNEL_SIZE mod 2 = 1) report "Currently only odd window/kernel sizes are supported" severity failure;

  m_axis_window_tvalid <= m_axis_window_tvalid_reg;
  m_axis_window_tuser  <= m_axis_window_tuser_reg;
  m_axis_window_tlast  <= m_axis_window_tlast_reg;

  -- Expose input READY combinationally so upstream and internal handshake
  -- observe the same value in the same cycle.
  s_axis_gray8_tready <= '0' when i_aresetn = '0' else
                         '1' when pxl_cnt < C_FILL_MIN else
                         m_axis_window_tready;

  ------------------------------------------------------------------
  -- Line buffering
  ------------------------------------------------------------------
  P_WNDW_GEN_REG : process(i_aclk)
    ------------------------------------------------------------------
    -- variables
    ------------------------------------------------------------------
    variable v_in_ready     : std_logic := '0';
    variable v_in_hs        : std_logic := '0';
    variable v_buf_now      : t_buf;
    variable v_wndw_now     : t_wndw;
    variable v_col_out_next : natural range 0 to G_LINE_WIDTH+1;
    variable v_row_out_next : natural range 0 to G_NUM_ROW+1;
  begin
    if rising_edge(i_aclk) then
      if i_aresetn = '0' then
        -- clear counters
        col_cnt     <= 0;
        row_cnt     <= 0;
        pxl_cnt     <= 0;
        col_cnt_out <= 0;
        row_cnt_out <= 0;
        -- clear registers
        sof_reg     <= (others => '0');
        eol_reg     <= (others => '0');
        buf_reg     <= (others => C_ZERO);
        -- reset outputs
        m_axis_window_tvalid_reg  <= '0';
        m_axis_window_tdata   <= (others => '0');
        m_axis_window_tuser_reg   <= '0';
        m_axis_window_tlast_reg   <= '0';
      else
        v_buf_now := buf_reg;
        v_in_hs := '0';

        -- buffer fill control
        if pxl_cnt < C_FILL_MIN then -- warm-up: wait until taps for first output window are available
          -- buffer not filled: keep signalling ready, until buffer completely filled
          v_in_ready := '1';
        else
          -- buffer filled: pass on downstream status
          v_in_ready := m_axis_window_tready;
        end if;
        -- AXI Stream handshake occured for input data stream
        if s_axis_gray8_tvalid = '1' and v_in_ready = '1' then
          v_in_hs := '1';

          -- shift pixels in buffer
          for i in 0 to C_BUF_LEN-2 loop
            v_buf_now(i) := v_buf_now(i+1);
          end loop;
          -- append current pixel
          v_buf_now(C_BUF_LEN-1) := s_axis_gray8_tdata;
          buf_reg <= v_buf_now;

          -- shift control signals
          sof_reg <= sof_reg(sof_reg'high-1 downto sof_reg'low) & s_axis_gray8_tuser; -- shift in current value
          eol_reg <= eol_reg(eol_reg'high-1 downto eol_reg'low) & s_axis_gray8_tlast; -- shift in current value

          -- increment pixels received
          if pxl_cnt < 2*C_FILL_MIN then -- only use this counter after reset for first fill of buffer until valid output can be produced
            pxl_cnt <= pxl_cnt + 1;
          end if;

          -- counters
          if col_cnt < G_LINE_WIDTH+1 then
            col_cnt <= col_cnt + 1;
          end if;
          -- reset column on EOL
          if s_axis_gray8_tlast = '1' then -- EOL
            col_cnt <= 0;
            if row_cnt < G_NUM_ROW+1 then
              row_cnt <= row_cnt + 1;
            end if;
          end if;

          -- Reset row on SOF
          if s_axis_gray8_tuser = '1' then
            row_cnt <= 0;
            --col_cnt <= 0;
          end if;

        end if; -- end handshake occured

        ------------------------------------------------------------------
        -- AXI Stream Master coordinate tracking
        ------------------------------------------------------------------
        -- Derive coordinates for the next emitted output beat from the
        -- currently accepted output beat.
        v_col_out_next := col_cnt_out;
        v_row_out_next := row_cnt_out;

        if m_axis_window_tvalid_reg = '1' and m_axis_window_tready = '1' then
          if m_axis_window_tuser_reg = '1' then
            v_row_out_next := 0;
            v_col_out_next := 0;
          end if;

          if m_axis_window_tlast_reg = '1' then
            v_col_out_next := 0;
            if v_row_out_next < G_NUM_ROW+1 then
              v_row_out_next := v_row_out_next + 1;
            end if;
          else
            if v_col_out_next < G_LINE_WIDTH+1 then
              v_col_out_next := v_col_out_next + 1;
            end if;
          end if;
        end if;

        ------------------------------------------------------------------
        -- 3x3 Window generation with Zero Padding
        -- 1D window:
        -- wndw(0)   wndw(1)   wndw(2)
        -- wndw(3)   wndw(4)   wndw(5)
        -- wndw(6)   wndw(7)   wndw(8)
        ------------------------------------------------------------------

        v_wndw_now := f_wndw_from_buffer(buf_reg, v_col_out_next, v_row_out_next);

        ------------------------------------------------------------------
        -- AXI Stream Master outputs
        ------------------------------------------------------------------
        col_cnt_out <= v_col_out_next;
        row_cnt_out <= v_row_out_next;

        -- Hold payload stable while stalled (VALID=1, READY=0).
        if m_axis_window_tready = '1' or m_axis_window_tvalid_reg = '0' then
          if v_in_hs = '1' and pxl_cnt >= C_FILL_MIN then
            m_axis_window_tvalid_reg  <= '1';
            m_axis_window_tdata   <= f_pack_1d_wndw(v_wndw_now);
            m_axis_window_tlast_reg   <= eol_reg(eol_reg'high);
            m_axis_window_tuser_reg   <= sof_reg(sof_reg'high);
          else
            m_axis_window_tvalid_reg  <= '0';
          end if;
        end if;

      end if; -- end rst
    end if; -- end rising edge
  end process;

end architecture;
