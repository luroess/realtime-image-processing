#import "../shared/macros.typ": *
#import "@preview/algorithmic:1.0.7"
#import algorithmic: algorithm-figure

= Component: RGB_TO_GRAYSCALE
#component_owner("Jan Duchscherer")

== Overview

The IP core RGB_TO_GRAYSCALE is the initial conversion stage. It reduces the incoming RGB24 pixel stream to an 8-bit luminance (`gray8`) for subsequent image processing modules, while still providing a synchronized RGB stream (`rbg888`) for downstream blocks that require color. In the active block design, it is placed after Bayer reconstruction and gamma correction (provided in the employed demo project by Digilent @digilent-pcam-demo). The wrapper is implemented as a synchronized two-consumer AXI4-Stream Video fan-out, so the `gray8` and `rbg888` outputs remain frame- and line-aligned even under asymmetric backpressure.

#figure(
  image("../../figures/ip-cores/AxiRGBToGrayscale.png", width: 45%),
  caption: [AXI_RgbToGrayscale top-level IP-core wrapper view and external stream/control interface.],
) <fig-rgb2gray-vivado>

The component is split into a combinational pixel core `E_RgbToGrayscale` (#repo_link("rtl/RGB_TO_GRAYSCALE/hdl/rgb_to_grayscale.vhd", line: 5, branch: "feat/rollback")) and an AXI4-Stream video wrapper `AXI_RgbToGrayscale` (#repo_link("rtl/RGB_TO_GRAYSCALE/hdl/axi_rgb_to_grayscale.vhd", line: 4, branch: "feat/rollback")). The core computes per-pixel luminance `Y`, while the wrapper implements the synchronized dual-output AXI4-Stream Video interface.


== Interface ports and generics
Table @tab-rgb2gray-if summarizes the external interface. Payload beats are accepted only on valid handshakes (`TVALID && TREADY`). The input payload `s_axis_video_tdata` consists of 24-bit `R|B|G` (MSB to LSB).

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
      [Selects original RGB forwarding versus gray-replicated RGB.],
      [`s_axis_video_*`],
      [*in* / out],
      [AXI4S Video],
      [Input pixel stream; `TUSER=SOF`, `TLAST=EOL`.],
      [`m_axis_rbg888_*`],
      [*out* / in],
      [AXI4S Video],
      [RGB branch (original color or grayscale-replicated).],
      [`m_axis_gray8_*`],
      [*out* / in],
      [AXI4S Video],
      [Gray8 branch for filter pipeline],
    ),
  ),
  caption: [AXI_RgbToGrayscale interface overview from #repo_link("rtl/RGB_TO_GRAYSCALE/hdl/axi_rgb_to_grayscale.vhd", line: 4, branch: "feat/rollback").],
) <tab-rgb2gray-if>

== AXI4-Stream implementation and synchronization
`AXI_RgbToGrayscale` broadcasts one AXI4-Stream Video slave input into two master outputs that may apply asymmetric backpressure. To preserve pixel-index and `SOF`/`EOL` alignment across both branches, the wrapper buffers exactly one accepted beat `{TDATA, SOF, EOL, i_pass_through}` and holds it stable until both masters have completed a handshake for that beat. This behavior is implemented in `P_REG_STREAM` (#repo_link("rtl/RGB_TO_GRAYSCALE/hdl/axi_rgb_to_grayscale.vhd", line: 81, branch: "feat/rollback")).

`SOF`/`EOL` are beat-aligned to both masters, to enforce identical framing positions. The branch respective valid signals `s_rgb_tvalid` and `s_gray_tvalid` are held until their corresponding handshake fires, and `TUSER`/`TLAST` are forced low whenever `*_tvalid = 0` to avoid spurious markers.

For readability, we write `rst_n = i_aresetn`, `valid = s_valid_reg`, `rgb_sent = s_rgb_sent_reg`, `gray_sent = s_gray_sent_reg`, `s_tvalid = s_axis_video_tvalid`, `s_tready = s_axis_video_tready`, `rgb_tready = m_axis_rbg888_tready`, and `gray_tready = m_axis_gray8_tready`. The key ready/valid relations are then:
$ "rgb_tvalid" = "rst_n" and "valid" and (not "rgb_sent") $
$ "gray_tvalid" = "rst_n" and "valid" and (not "gray_sent") $
$ "s_tready" = "rst_n" and ((not "valid") or (("rgb_sent" or "rgb_tready") and ("gray_sent" or "gray_tready"))) $

In the RTL, the `s_tready` conditional signal is implemented by `s_input_slot_free` and drives `s_axis_video_tready`. It signals input readiness only when the slot is empty or guaranteed to drain to both outputs in the same cycle, coupling input progress to the slowest branch and guaranteeing synchronicity between the two output streams.

The complete per-cycle update in `P_REG_STREAM` is summarized by the following pseudocode.

#{
  show: style-algorithm-compact.with(
    caption-style: text,
    caption-align: start,
    breakable: true,
    width: 84%,
  )
  align(center, box(width: auto, text(size: 10pt, algorithm-figure(
    [Synchronized dual output AXI4S master in `P_REG_STREAM`.],
    line-numbers: false,
    {
      import algorithmic: *
      // Suppress explicit block terminators ("end") for report readability.
      let If = If.with(kw3: "")
      let ElseIf = ElseIf.with(kw3: "")
      let Else = Else.with(kw3: "")
      let While = While.with(kw3: "")
      let For = For.with(kw3: "")
      Comment[Combinational handshake]
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
  ))))
}

== RGB-to-grayscale core: algorithm and tradeoff
`E_RgbToGrayscale` is purely combinational. It decodes the incoming pixel word, computes an 8-bit luminance `Y`, and emits both the scalar luminance (`o_gray8 = Y`) and a grayscale RGB view (`o_rbg888 = {Y,Y,Y}`).

A common luminance-weighted floating-point model is described in OpenCV's color conversion reference @opencv-color-conversions.
$ Y_"fp" = 0.299 R + 0.587 G + 0.114 B $

A fixed-point integer approximation suitable for 8-bit hardware is:
$ Y_"i8" = (77R + 150G + 29B + 128) / 256 $

The implemented RTL uses a shift/add approximation:
$ Y_"rtl" approx (R/4) + (G/2) + (B/4) $

Across the full 8-bit RGB space ($256^3$ colors), the error relative to $Y_"fp"$ is $e = Y_"rtl" - Y_"fp"$. Using exhaustive enumeration (and the actual truncating shifts from the RTL), we obtain a mean absolute error of $10.30$ LSB and a worst-case magnitude $abs(e)_"max" = 36.27$ LSB (at $R = 255$, $G = 255$, $B = 3$).

The approximation is still chosen here because it uses a minimal number of HW primitives, keeps `E_RgbToGrayscale` fully combinational and low-latency, and is sufficient for this pipeline where real-time throughput and relative contrast are prioritized over color accuracy. However, we acknowledge that a fixed-point shift/add approximation would have improved the luminance fidelity without a major resource increase.


== Minimal integration test: RGB_TO_GRAYSCALE plus FRAME_COMPOSITOR

To validate the dual-output AXI4-Stream behavior in a system context, a minimal cocotb test connects `AXI_RgbToGrayscale` to `AXI_FrameCompositor` (@ch-frame-comp). The harness drives `s_axis_video_*` with `AxiVideoStreamSource` and captures `m_axis_video_rbg888_*` with `AxiVideoStreamSink` (#repo_link("testbench/tests/test_axi_rgb2gray_frame_compositor_minimal.py", line: 227, line_end: 242, branch: "feat/rollback")).


#figure(
  image("../figures/ghw/axi_rgb2gray_sync.png", width: 95%),
  caption: [GHW snapshot for the 3x2 two-frame RGB2GRAY-to-compositor test, highlighting gray-branch warm-up behavior at each `SOF`.],
) <fig-rgb2gray-sync-ghw>

During warm-up in @fig-rgb2gray-sync-ghw, we interpret a beat as a successful AXI transfer (`TVALID && TREADY`); stall cycles do not advance the stream. The test measures gray-branch warm-up by comparing the first handshakes on `o_dbg_gray_pre_*` and `o_dbg_gray_post_*`, and it records compositor-side accepted beats (`s_comp_tuser`, `s_comp_tlast`) to check SOF placement and per-pixel progression (#repo_link("testbench/tests/test_axi_rgb2gray_frame_compositor_minimal.py", line: 250, line_end: 294, branch: "feat/rollback")).

The integration test asserts:
- *Warm-up alignment:* `o_dbg_gray_pre_*` accepts without stalling, while `o_dbg_gray_post_*` shows a bounded `3..6` cycle delay at each `SOF` (latest `delta = 5`) (#repo_link("testbench/tests/test_axi_rgb2gray_frame_compositor_minimal.py", line: 324, line_end: 334, branch: "feat/rollback")).
- *Steady-state cadence:* Once warm-up is released, the gray branch transfers consecutive pixels at one accepted beat per clock (#repo_link("testbench/tests/test_axi_rgb2gray_frame_compositor_minimal.py", line: 337, branch: "feat/rollback")).

The brief `TVALID=0` region before the second `SOF` in this test is also expected and originates from the stimulus driver (`await self._source.wait()` followed by idle drive, #repo_link("testbench/drivers/axis_video_source.py", line: 150, branch: "feat/rollback")), not from gray-branch deadlock. With that context, the observed waveform behavior is consistent with the intended architecture and the assertions in the integration test.

== Test coverage: rgb2gray-related cocotb tests

All tests referenced below live on branch `feat/rollback`. The `tb-sim` target mapping is defined in #repo_link("testbench/targets.toml", branch: "feat/rollback").
The RGB2GRAY stage is covered both directly and as part of the full RGB-entry pipeline.

#text(size: 9pt)[
  *UUT: AXI_RgbToGrayscale*
  - #repo_link(
      "testbench/tests/test_axi_rgb_to_grayscale.py",
      body: [`test_axi_rgb_to_grayscale_with_backpressure_three_cycle_breaks`],
      line: 386,
      branch: "feat/rollback",
    ): READY/valid stress + handshake assertions.
  - #repo_link(
      "testbench/tests/test_axi_rgb_to_grayscale.py",
      body: [`test_axi_rgb_to_grayscale_image_file_roundtrip`],
      line: 399,
      branch: "feat/rollback",
    ): image roundtrip + saved artifact.
  - #repo_link(
      "testbench/tests/test_axi_rgb_to_grayscale.py",
      body: [`test_axi_rgb_to_grayscale_passthrough_mode`],
      line: 409,
      branch: "feat/rollback",
    ): `i_pass_through=1` yields bit-exact passthrough.

  *UUT: AXI_RgbToGrayscale + AXI_FrameCompositor (minimal integration)*
  - #repo_link(
      "testbench/tests/test_axi_rgb2gray_frame_compositor_minimal.py",
      body: [`test_axi_rgb2gray_frame_compositor_minimal_3x2_two_frames_with_gray_warmup`],
      line: 207,
      branch: "feat/rollback",
    ): 3x2 two-frame integration into `AXI_FrameCompositor`: bounded gray warm-up + 1-cycle post-warm-up cadence.

]

Used test harness components (Python):
- Source: #repo_link("testbench/drivers/axis_video_source.py", body: [`AxiVideoStreamSource`], line: 22, branch: "feat/rollback")
- Sink: #repo_link("testbench/monitors/axis_video_sink.py", body: [`AxiVideoStreamSink`], line: 14, branch: "feat/rollback")
- Reset/pause helpers: #repo_link("testbench/common/reset.py", body: [`apply_reset`], line: 8, branch: "feat/rollback"), #repo_link("testbench/common/pause.py", body: [`drive_sink_pause`], line: 17, branch: "feat/rollback"), #repo_link("testbench/common/pause.py", body: [`repeating_pause`], line: 35, branch: "feat/rollback")
- Image model / checking: #repo_link("testbench/models/image_model.py", body: [`Image`], line: 13, branch: "feat/rollback"), #repo_link("testbench/verification/scoreboard.py", body: [`Scoreboard`], line: 10, branch: "feat/rollback")

RTL components exercised in these tests:
- RGB2GRAY core/wrapper: #repo_link("rtl/RGB_TO_GRAYSCALE/hdl/rgb_to_grayscale.vhd", line: 5, branch: "feat/rollback"), #repo_link("rtl/RGB_TO_GRAYSCALE/hdl/axi_rgb_to_grayscale.vhd", line: 4, branch: "feat/rollback")
- Downstream integration: #repo_link("rtl/FRAME_COMPOSITOR/hdl/axi_frame_compositor.vhd", line: 4, branch: "feat/rollback"), #repo_link("rtl/PIPELINE/hdl/axi_rgb_gray_blurr_sobel_overlay_pipeline.vhd", line: 4, branch: "feat/rollback")
