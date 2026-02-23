#import "../shared/macros.typ": *
#import "@preview/algorithmic:1.0.7"
#import algorithmic: algorithm-figure, style-algorithm

= Component: RGB_TO_GRAYSCALE
#component_owner("Jan Duchscherer")

#grid(
  columns: (1.15fr, 1fr),
  gutter: 14pt,
  [
    `AXI_RgbToGrayscale` (#repo_link("rtl/RGB_TO_GRAYSCALE/hdl/axi_rgb_to_grayscale.vhd", line: 4)) wraps the grayscale core `E_RgbToGrayscale` (#repo_link("rtl/RGB_TO_GRAYSCALE/hdl/rgb_to_grayscale.vhd", line: 5)) and emits two synchronized output branches: a grayscale stream (`gray8`) and an RGB stream (`rbg888`) that can either forward the original pixel or replicate grayscale data, depending on the control signal `i_pass_through`.
  ],
  [

    #figure(
      image("../../figures/ip-cores/AxiRGBToGrayscale.png", width: 100%),
      caption: [AXI_RgbToGrayscale top-level IP-core wrapper view and external stream/control interface.],
    ) <fig-rgb2gray-vivado>
  ],
)

== Interface ports and generics
The external ports implement AXI4-Stream Video semantics with a single slave input and two master outputs. Following AMD's documentation on AXI4-Stream Video IP and system design, frame boundaries are transported via `TUSER[0]` (`SOF`) and line boundaries via `TLAST` (`EOL`), while payload beats are accepted only on valid handshakes @UG934. The wrapper has no explicit `ACLKEN`, so acceptance is evaluated on each rising edge of `i_aclk` under `i_aresetn = 1`.

`s_axis_video_tdata` is treated as 24-bit `R|B|G`, and the wrapper publishes two synchronized views of the same accepted beat: `m_axis_rbg888_*` for RGB-compatible downstream consumers and `m_axis_gray8_*` for gray-plane processing stages.

#figure(
  interface_table(
    generics: (
      [`G_COMPONENT_WIDTH`],
      [positive],
      [default `8`],
      [Per-channel component width.],
    ),
    ports: (
      [`i_aclk`, `i_aresetn`],
      [in],
      [1],
      [Clock/reset for AXI stream logic.],
      [`i_pass_through`],
      [in],
      [1],
      [Selects original RGB forwarding versus grayscale-replicated RGB.],
      [`s_axis_video_*`],
      [*in* / out],
      [AXI4S Video],
      [Input pixel stream; `TUSER=SOF`, `TLAST=EOL`, payload order `R|B|G`.],
      [`m_axis_rbg888_*`],
      [*out* / in],
      [AXI4S Video],
      [RGB branch (legacy RTL name `rbg888`); forwards source RGB or grayscale-replicated RGB.],
      [`m_axis_gray8_*`],
      [*out* / in],
      [AXI4S Video],
      [Gray8 branch for filter pipeline; keeps SOF/EOL aligned with RGB branch.],
    ),
  ),
  caption: [AXI_RgbToGrayscale interface overview from #repo_link("rtl/RGB_TO_GRAYSCALE/hdl/axi_rgb_to_grayscale.vhd", line: 4).],
) <tab-rgb2gray-if>

== AXI interface implementation details
The wrapper implements a one-beat staging slot (`s_pixel_reg`, `s_sof_reg`, `s_eol_reg`, `s_pass_mode_reg`) that is updated in `P_REG_STREAM` only when `s_axis_video_tvalid = 1` and the slot is free (#repo_link("rtl/RGB_TO_GRAYSCALE/hdl/axi_rgb_to_grayscale.vhd", line: 91)). This design decouples input admission from output backpressure and avoids combinational `TVALID`/`TREADY` loops between the two output branches.

Input admission is controlled by `s_input_slot_free`, and therefore by `s_axis_video_tready`, which is asserted only when no beat is pending or when the pending beat is guaranteed to drain to both outputs in the current cycle (#repo_link("rtl/RGB_TO_GRAYSCALE/hdl/axi_rgb_to_grayscale.vhd", line: 76)). Completion is tracked independently through `s_rgb_sent_reg` and `s_gray_sent_reg`; `m_axis_rbg888_tvalid` and `m_axis_gray8_tvalid` remain asserted until branch-local handshake, while `SOF` and `EOL` are replicated from the same stored beat to preserve framing alignment under asymmetric backpressure (#repo_link("rtl/RGB_TO_GRAYSCALE/hdl/axi_rgb_to_grayscale.vhd", line: 64)). `i_pass_through` is sampled with the beat and held in `s_pass_mode_reg`, so output mode is beat-stable during stalls.

#figure(
  academic_table(
    columns: (auto, auto, auto),
    align: (left, left, left),
    table.header([Internal signal], [Role], [Implementation consequence]),
    [`s_valid_reg`],
    [pending beat flag],
    [Holds one buffered input transaction until both outputs consume it.],
    [`s_rgb_sent_reg`, `s_gray_sent_reg`],
    [per-branch completion],
    [Allow independent output handshakes without dropping sideband alignment.],
    [`s_input_slot_free`],
    [admission gate],
    [Asserts `s_axis_video_tready` only when the slot is empty or fully drainable.],
    [`s_rgb_tvalid`, `s_gray_tvalid`],
    [branch TVALID],
    [Remain high until matching branch handshake occurs.],
    [`s_sof_reg`, `s_eol_reg`],
    [framing sidebands],
    [Replicated to both outputs; guarantees identical SOF/EOL positions.],
    [`s_pass_mode_reg`],
    [mode latch],
    [Prevents intra-beat output mode changes during stalls.],
  ),
  caption: [Internal control signals implementing dual-output AXI fan-out in #repo_link("rtl/RGB_TO_GRAYSCALE/hdl/axi_rgb_to_grayscale.vhd", line: 39).],
) <tab-rgb2gray-internal>

== AXI transition logic
The per-cycle control equations are equivalent to the update logic in `P_REG_STREAM` (#repo_link("rtl/RGB_TO_GRAYSCALE/hdl/axi_rgb_to_grayscale.vhd", line: 81)). Let `valid`, `rgb_sent`, and `gray_sent` denote the registered pending-beat state, and let `rgb_tready`, `gray_tready`, and `s_tvalid` denote current-cycle handshake inputs.

Branch-local handshakes are generated from pending-slot state and branch readiness:
$ "rgb_fire"_k = "valid"_k and (not "rgb_sent"_k) and "rgb_tready"_k $
$ "gray_fire"_k = "valid"_k and (not "gray_sent"_k) and "gray_tready"_k $

The completion state then accumulates accepted transfers on each branch:
$ "rgb_sent_next"_k = "rgb_sent"_k or "rgb_fire"_k $
$ "gray_sent_next"_k = "gray_sent"_k or "gray_fire"_k $

Input admission follows from slot availability and reset gating:
$ "slot_free"_k = (not "valid"_k) or ("rgb_sent_next"_k and "gray_sent_next"_k) $
$ "s_tready"_k = "rst_n"_k and "slot_free"_k $
$ "in_fire"_k = "s_tvalid"_k and "slot_free"_k $

At each rising edge, reset clears the slot and completion flags. Otherwise, `in_fire = 1` latches pixel data, sidebands, and pass-through mode into the slot. If no new beat is admitted and both branches have completed, the slot is cleared. In all other valid-slot cases, branch completion flags are updated to `rgb_sent_next` and `gray_sent_next`. The following compact control block summarizes this sequential priority.

#{
  show: style-algorithm.with(
    caption-style: text,
    caption-align: start,
    breakable: true,
  )
  algorithm-figure(
    [Sequential register-update priority in `P_REG_STREAM`.],
    line-numbers: false,
    {
      import algorithmic: *
      If($not "rst_n"$, {
        Assign[$"valid"$][$0$]
        Assign[$"rgb_sent"$][$0$]
        Assign[$"gray_sent"$][$0$]
      })
      ElseIf($"in_fire"$, {
        Comment[latch tdata, tuser, tlast, i_pass_through]
        Assign[$"valid"$][$1$]
        Assign[$"rgb_sent"$][$0$]
        Assign[$"gray_sent"$][$0$]
      })
      ElseIf($"valid" and "rgb_sent_next" and "gray_sent_next"$, {
        Assign[$"valid"$][$0$]
        Assign[$"rgb_sent"$][$0$]
        Assign[$"gray_sent"$][$0$]
      })
      ElseIf($"valid"$, {
        Assign[$"rgb_sent"$][$"rgb_sent_next"$]
        Assign[$"gray_sent"$][$"gray_sent_next"$]
      })
    },
  )
}

== Conversion formulas and implementation tradeoff
A common luminance-weighted floating-point model is described in OpenCV's color conversion reference.@opencv-color-conversions
$ Y_"float" = 0.299 R + 0.587 G + 0.114 B $

A fixed-point integer approximation suitable for 8-bit hardware is:
$ Y_"fix8" = (77R + 150G + 29B + 128) / 256 $

The implemented RTL uses a shift/add approximation:
$ Y_"rtl" approx (R/4) + (G/2) + (B/4) $

Across the full 8-bit RGB space ($256^3$ colors), the error relative to $Y_"float"$ is $e = Y_"rtl" - Y_"float"$ with mean absolute error $10.30$ LSB, RMSE $12.52$ LSB, and worst-case magnitude $abs(e)_"max" = 36.27$ LSB (at $R = 255$, $G = 255$, $B = 3$).

The approximation is still chosen here because it uses only shifts and adds (no multipliers/DSP blocks), keeps `E_RgbToGrayscale` fully combinational and low-latency, and is sufficient for this pipeline where real-time throughput and relative contrast are prioritized over photometric accuracy.

== Typical transaction sequence
#figure(
  image("../figures/generated/seq_rgb_to_grayscale_transaction.png", width: 92%),
  caption: [Typical dual-branch transaction for AXI_RgbToGrayscale under optional RGB-branch backpressure.],
) <fig-rgb2gray-seq>

== Minimal integration waveform: RGB_TO_GRAYSCALE plus FRAME_COMPOSITOR

To validate the correctness of the dual-branch AXIS interface and the resulting per-branch handshake behavior under backpressure and warm-up delays within our image processing branch, a minimal integration test is implemented between `AXI_RgbToGrayscale` and `AXI_FrameCompositor`. The test uses two small 3 #sym.times 2 frames with known pixel values to allow validation of correct synchronization (responsibility of the `AXI_FrameCompositor`).


#figure(
  image("../figures/ghw/axi_rgb2gray_sync.png", width: 95%),
  caption: [GHW snapshot for the 3x2 two-frame RGB2GRAY-to-compositor test, highlighting gray-branch warm-up behavior at each `SOF`.],
) <fig-rgb2gray-sync-ghw>

In @fig-rgb2gray-sync-ghw, the relevant interpretation is handshake-domain based (`TVALID && TREADY`) rather than edge-to-edge toggles of individual signals. The harness keeps split acceptance enabled (`s_split_gray_tready`, `s_split_rgb_tready`) according to FIFO capacity, while the post-compositor feed is blocked during warm-up by `s_comp_block` (#repo_link("testbench/tests/vhdl/axi_rgb2gray_frame_compositor_harness.vhd", line: 150)). This is why upstream branch activity can continue while the compositor-side gray stream temporarily withholds valid transfers.

The expected delay model on the gray branch has two parts. First, a per-frame warm-up budget is configured as `C_GRAY_WARMUP_CYCLES = 3` (#repo_link("testbench/tests/vhdl/axi_rgb2gray_frame_compositor_harness.vhd", line: 35)). The test therefore checks a bounded post-branch `SOF` gap (`3 <= warmup_cycles <= 6`) to account for the explicit hold and cycle-indexing around the `SOF` beat (#repo_link("testbench/tests/test_axi_rgb2gray_frame_compositor_minimal.py", line: 332)). In the latest run, this measured offset was `delta = 5` cycles. Second, once warm-up is released, the post-branch cadence is expected to be one accepted beat per clock for consecutive pixels in each frame (#repo_link("testbench/tests/test_axi_rgb2gray_frame_compositor_minimal.py", line: 337)); this corresponds to an effective one-cycle per-pixel processing interval at steady state.

The brief `TVALID=0` region before the second `SOF` in this test is also expected and originates from the stimulus driver (`await self._source.wait()` followed by idle drive, #repo_link("testbench/drivers/axis_video_source.py", line: 150)), not from gray-branch deadlock. With that context, the observed waveform behavior is consistent with the intended architecture and the assertions embedded in the integration test.
