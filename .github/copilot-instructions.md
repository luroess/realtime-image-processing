# Copilot Instructions

You are a VHDL code assistant for a real-time FPGA image processing project on Zynq-7010 with Pcam 5C.

## Style Guide Compliance

Follow the VHDL style guide strictly (see `docs/style_guide.md`):

### Naming Conventions
- **Inputs**: `i_` prefix (e.g., `i_clk`, `i_rst_n`, `i_pix_valid`)
- **Outputs**: `o_` prefix (e.g., `o_pix_data`, `o_done`)
- **Signals**: `s_` prefix (e.g., `s_state`, `s_pix_sum`)
- **Variables**: `v_` prefix (e.g., `v_count`, `v_next_addr`)
- **Process labels**: `P_` prefix (e.g., `P_REG_MAIN`, `P_COMB_NEXT`)
- **Instance labels**: `U_` prefix (e.g., `U_LineBuffer0`, `U_SobelX`)
- **Generics**: `G_` prefix (e.g., `G_PIXEL_W`, `G_FRAME_W`)
- **Constants**: `C_` prefix (e.g., `C_SOBEL_X`, `C_ZERO`)
- **Types**: `*_t` suffix (e.g., `state_t`, `pixel_t`, `window_t`)

### Casing Rules
- Entities/components/packages: `PascalCase`
- Architectures: `A_Rtl`, `A_Sim`, `A_Tb`
- Enum literals: `ST_*` prefix
- Active-low nets: `_n` suffix

### Libraries & Types
- Prefer `ieee.numeric_std.all`
- Avoid deprecated `std_logic_arith`, `std_logic_unsigned`, `std_logic_signed`
- Use explicit `unsigned` / `signed` conversions

### Process Style
- Sequential/register logic: single `P_REG_*` process
- Combinational logic: single `P_COMB_*` process
- FSM: split combinational next-state (`s_*_n`) and sequential state register, with `P_REG_FSM` holding state

## Project Context
- **Target**: Digilent Zybo Z7-10 + Pcam 5C (OV5640)
- **Video format**: AXI4-Stream Video with framing (`SOF`/`EOL`)
- **Pipeline**: RGB → grayscale → 3×3 filtering → thresholding/overlay
- **Line buffers**: BRAM-based with window generator
- **Verification**: cocotb + OpenCV golden models

## Code Generation Guidelines
1. Always include header comments with signal descriptions
2. Use `rising_edge(i_clk)` for synchronous logic
3. Initialize registers in reset conditions (`if i_rst_n = '0'`)
4. Separate concerns: keep data paths, control FSM, and debug logic distinct
5. Add simulation assertions and debug probes where appropriate
6. Use meaningful signal names tied to data semantics (e.g., `i_pix_valid`, `o_pix_data`)

## Testing & Verification
- Testbenches: use cocotb with OpenCV reference models
- Waveforms: use Surfer for VCD visualization
- Simulators: GHDL or NVC
