#import "../shared/macros.typ": *
#import "@preview/algorithmic:1.0.7"
#import algorithmic: algorithm-figure, style-algorithm

= Component: RGB_TO_GRAYSCALE
#component_owner("Jan Duchscherer")

== Overview

RGB_TO_GRAYSCALE is the initial conversion stage that reduces the camera-side RGB24 stream to an 8-bit luminance signal for subsequent window-based filters (blur/Sobel), while still providing an RGB-compatible stream for display and frame buffering. In the active block design, it is placed after Bayer reconstruction. The wrapper is implemented as a synchronized two-consumer AXI4-Stream Video fan-out, so the `gray8` and `rbg888` outputs remain frame- and line-aligned even under asymmetric backpressure.

#figure(
  image("../../figures/ip-cores/AxiRGBToGrayscale.png", width: 55%),
  caption: [AXI_RgbToGrayscale top-level IP-core wrapper view and external stream/control interface.],
) <fig-rgb2gray-vivado>

The component is split into a combinational pixel core `E_RgbToGrayscale` (#repo_link("rtl/RGB_TO_GRAYSCALE/hdl/rgb_to_grayscale.vhd", line: 5)) and an AXI4-Stream video wrapper `AXI_RgbToGrayscale` (#repo_link("rtl/RGB_TO_GRAYSCALE/hdl/axi_rgb_to_grayscale.vhd", line: 4)). The core computes per-pixel luminance `Y`, while the wrapper provides one AXI4-Stream slave input and two master outputs (gray8 and rbg888). A runtime control bit `i_pass_through` selects whether the RGB output forwards the incoming pixel or a grayscale-replicated RGB value.


== Interface ports and generics
The external ports implement AXI4-Stream Video semantics with a single slave input and two master outputs. Following AMD's documentation on AXI4-Stream Video IP and system design, frame boundaries are transported via `TUSER[0]` (`SOF`) and line boundaries via `TLAST` (`EOL`), while payload beats are accepted only on valid handshakes.@UG934 The wrapper has no explicit `ACLKEN`, so acceptance is evaluated on each rising edge of `i_aclk` under `i_aresetn = 1`.

The input payload `s_axis_video_tdata` is treated as 24-bit `R|B|G` (MSB to LSB). This repository uses the name `rbg888` to make the wire-level byte order explicit; consumers that assume conventional RGB24 must therefore interpret the stream as `R|B|G` rather than `R|G|B`.

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

== AXI4-Stream fan-out implementation and synchronization
`AXI_RgbToGrayscale` broadcasts one AXI4-Stream Video slave input into two master outputs that may apply asymmetric backpressure. To preserve pixel-index and `SOF`/`EOL` alignment across both branches, the wrapper acts as a one-beat broadcast buffer. When an input beat is accepted, the wrapper stores `{TDATA, SOF, EOL, i_pass_through}` into a staging slot (`s_pixel_reg`, `s_sof_reg`, `s_eol_reg`, `s_pass_mode_reg`) and holds it stable until both masters have completed a handshake for that beat. Only then can a new input beat be admitted. This behavior is implemented in `P_REG_STREAM` and enforced by a pending-beat flag `s_valid_reg` and per-branch completion flags `s_rgb_sent_reg` / `s_gray_sent_reg` (#repo_link("rtl/RGB_TO_GRAYSCALE/hdl/axi_rgb_to_grayscale.vhd", line: 81)).

While `s_valid_reg = 1`, the staged payload and sidebands remain stable. `SOF`/`EOL` are therefore replicated beat-aligned to both masters, and both outputs observe identical framing positions. Latching `i_pass_through` into `s_pass_mode_reg` makes the RGB output selection beat-stable under stalls. The branch valids `s_rgb_tvalid` and `s_gray_tvalid` stay asserted until their corresponding handshake fires (tracked via `*_sent_reg`), and `TUSER`/`TLAST` are forced low whenever `*_tvalid = 0` to avoid spurious markers. Because `*_tvalid` is derived only from registered state, there is no combinational `TVALID`/`TREADY` loop between the two masters (#repo_link("rtl/RGB_TO_GRAYSCALE/hdl/axi_rgb_to_grayscale.vhd", line: 39)).

For readability, we write `rst_n = i_aresetn`, `valid = s_valid_reg`, `rgb_sent = s_rgb_sent_reg`, `gray_sent = s_gray_sent_reg`, `s_tvalid = s_axis_video_tvalid`, `s_tready = s_axis_video_tready`, `rgb_tready = m_axis_rbg888_tready`, and `gray_tready = m_axis_gray8_tready`. The key ready/valid relations are then:
$ "rgb_tvalid" = "rst_n" and "valid" and (not "rgb_sent") $
$ "gray_tvalid" = "rst_n" and "valid" and (not "gray_sent") $
$ "s_tready" = "rst_n" and ((not "valid") or (("rgb_sent" or "rgb_tready") and ("gray_sent" or "gray_tready"))) $

In the RTL, the `s_tready` predicate is implemented by `s_input_slot_free` and drives `s_axis_video_tready`. If the slot is empty, a new beat can be admitted. If a beat is pending, admission is allowed only when the pending beat is guaranteed to drain to both outputs in the same cycle. This couples input progress to the slowest outstanding branch and guarantees that both outputs advance through the same sequence of accepted pixels.

// #figure(
//   academic_table(
//     columns: (auto, auto, auto),
//     align: (left, left, left),
//     table.header([Internal signal], [Role], [Implementation consequence]),
//     [`s_valid_reg`],
//     [pending beat flag],
//     [Holds one buffered input transaction until both outputs consume it.],
//     [`s_rgb_sent_reg`, `s_gray_sent_reg`],
//     [per-branch completion],
//     [Allow independent output handshakes without dropping sideband alignment.],
//     [`s_input_slot_free`],
//     [admission gate],
//     [Asserts `s_axis_video_tready` only when the slot is empty or fully drainable.],
//     [`s_rgb_tvalid`, `s_gray_tvalid`],
//     [branch TVALID],
//     [Remain high until matching branch handshake occurs.],
//     [`s_sof_reg`, `s_eol_reg`],
//     [framing sidebands],
//     [Replicated to both outputs; guarantees identical SOF/EOL positions.],
//     [`s_pass_mode_reg`],
//     [mode latch],
//     [Prevents intra-beat output mode changes during stalls.],
//   ),
//   caption: [Internal control signals implementing dual-output AXI fan-out in #repo_link("rtl/RGB_TO_GRAYSCALE/hdl/axi_rgb_to_grayscale.vhd", line: 39).],
// ) <tab-rgb2gray-internal>

The complete per-cycle update in `P_REG_STREAM` (including reset, beat latching, and slot release) is summarized by the following acceptance-accurate pseudocode.

#{
  show: style-algorithm.with(
    caption-style: text,
    caption-align: start,
    breakable: true,
  )
  align(center, box(width: 92%, algorithm-figure(
    [Synchronized dual-output AXI4-Stream fan-out update in `P_REG_STREAM`.],
    line-numbers: false,
    {
      import algorithmic: *
      // Suppress explicit block terminators ("end") for report readability.
      let If = If.with(kw3: "")
      let ElseIf = ElseIf.with(kw3: "")
      let Else = Else.with(kw3: "")
      let While = While.with(kw3: "")
      let For = For.with(kw3: "")
      Comment[Combinational handshake and admission]
      Assign[$"rgb_fire"$][$"valid" and (not "rgb_sent") and "rgb_tready"$]
      Assign[$"gray_fire"$][$"valid" and (not "gray_sent") and "gray_tready"$]
      Assign[$"rgb_sent_next"$][$"rgb_sent" or "rgb_fire"$]
      Assign[$"gray_sent_next"$][$"gray_sent" or "gray_fire"$]
      Assign[$"slot_free"$][$(not "valid") or ("rgb_sent_next" and "gray_sent_next")$]
      Assign[$"in_fire"$][$"s_tvalid" and "slot_free"$]
      LineBreak
      Comment[Sequential register update on clock edge]
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
  )))
}

== RGB-to-grayscale core: algorithm and tradeoff
`E_RgbToGrayscale` is purely combinational. It decodes the incoming pixel word as `R|B|G`, computes an 8-bit luminance `Y`, and emits both the scalar luminance (`o_gray8 = Y`) and a grayscale RGB view (`o_rbg888 = {Y,Y,Y}` in `R|B|G` order).

A common luminance-weighted floating-point model is described in OpenCV's color conversion reference.@opencv-color-conversions
$ Y_"float" = 0.299 R + 0.587 G + 0.114 B $

A fixed-point integer approximation suitable for 8-bit hardware is:
$ Y_"fix8" = (77R + 150G + 29B + 128) / 256 $

The implemented RTL uses a shift/add approximation:
$ Y_"rtl" approx (R/4) + (G/2) + (B/4) $

Across the full 8-bit RGB space ($256^3$ colors), the error relative to $Y_"float"$ is $e = Y_"rtl" - Y_"float"$ with mean absolute error $10.30$ LSB, RMSE $12.52$ LSB, and worst-case magnitude $abs(e)_"max" = 36.27$ LSB (at $R = 255$, $G = 255$, $B = 3$).

The approximation is still chosen here because it uses only shifts and adds (no multipliers/DSP blocks), keeps `E_RgbToGrayscale` fully combinational and low-latency, and is sufficient for this pipeline where real-time throughput and relative contrast are prioritized over photometric accuracy.


== Minimal integration waveform: RGB_TO_GRAYSCALE plus FRAME_COMPOSITOR

To validate the correctness of the dual-branch AXIS interface and the resulting per-branch handshake behavior under backpressure and warm-up delays within our image processing branch, a minimal integration test is implemented between `AXI_RgbToGrayscale` and `AXI_FrameCompositor`. The test uses two small 3 #sym.times 2 frames with known pixel values to allow validation of correct synchronization (responsibility of the `AXI_FrameCompositor`).


#figure(
  image("../figures/ghw/axi_rgb2gray_sync.png", width: 95%),
  caption: [GHW snapshot for the 3x2 two-frame RGB2GRAY-to-compositor test, highlighting gray-branch warm-up behavior at each `SOF`.],
) <fig-rgb2gray-sync-ghw>

In @fig-rgb2gray-sync-ghw, the relevant interpretation is handshake-domain based (`TVALID && TREADY`) rather than edge-to-edge toggles of individual signals. The harness keeps split acceptance enabled (`s_split_gray_tready`, `s_split_rgb_tready`) according to FIFO capacity, while the post-compositor feed is blocked during warm-up by `s_comp_block` (#repo_link("testbench/tests/vhdl/axi_rgb2gray_frame_compositor_harness.vhd", line: 150)). This is why upstream branch activity can continue while the compositor-side gray stream temporarily withholds valid transfers.

The expected delay model on the gray branch has two parts. First, a per-frame warm-up budget is configured as `C_GRAY_WARMUP_CYCLES = 3` (#repo_link("testbench/tests/vhdl/axi_rgb2gray_frame_compositor_harness.vhd", line: 35)). The test therefore checks a bounded post-branch `SOF` gap (`3 <= warmup_cycles <= 6`) to account for the explicit hold and cycle-indexing around the `SOF` beat (#repo_link("testbench/tests/test_axi_rgb2gray_frame_compositor_minimal.py", line: 332)). In the latest run, this measured offset was `delta = 5` cycles. Second, once warm-up is released, the post-branch cadence is expected to be one accepted beat per clock for consecutive pixels in each frame (#repo_link("testbench/tests/test_axi_rgb2gray_frame_compositor_minimal.py", line: 337)); this corresponds to an effective one-cycle per-pixel processing interval at steady state.

The brief `TVALID=0` region before the second `SOF` in this test is also expected and originates from the stimulus driver (`await self._source.wait()` followed by idle drive, #repo_link("testbench/drivers/axis_video_source.py", line: 150)), not from gray-branch deadlock. With that context, the observed waveform behavior is consistent with the intended architecture and the assertions embedded in the integration test.
