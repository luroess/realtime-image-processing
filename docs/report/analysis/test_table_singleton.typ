#import "../shared/macros.typ": *

#set text(lang: "en")
#set page(paper: "a4", margin: (x: 1.8cm, y: 1.8cm))
#show table.cell: set text(size: 8.5pt)
#show table.cell.where(y: 0): set text(weight: "semibold")

= Singleton test-table sandbox

The first table mirrors the current approach. The second table uses the promoted shared `academic_test_table` macro with automatic identifier wrap hints.

#let legacy_test_id(content) = text(font: "DejaVu Sans Mono", size: 8.2pt)[#content]

#figure(
  academic_table(
    columns: (1.25fr, 1.25fr, 1.75fr, 3fr),
    align: (left, left, left, left),
    table.header([Target (`targets.toml`)], [Test file], [Test case], [Concise implementation check]),
    table.cell(rowspan: 3)[#legacy_test_id("axi_frame_compositor")], table.cell(rowspan: 3)[#legacy_test_id("test_axi_frame_compositor.py")], [#legacy_test_id("test_axi_frame_compositor_multiframe_") #linebreak() #legacy_test_id("sync_with_gray_delay_and_backpressure")], [Multi-frame AXI handshake correctness under backpressure, including SOF/EOL discipline and payload stability while stalled.],
    [#legacy_test_id("test_axi_frame_compositor_delay_stage_") #linebreak() #legacy_test_id("sweep_with_backpressure")], [Delay-stage sweep verifies Sobel versus Blur+Sobel alignment when gray start delay matches effective tap latency.],
    [#legacy_test_id("test_axi_frame_compositor_binary_mode_") #linebreak() #legacy_test_id("not_blocked_by_rgb")], [Binary mode remains gray-driven and non-blocking even when RGB-source consumption pressure is absent.],
  ),
  caption: [Legacy table style (current section implementation).],
)

#figure(
  academic_test_table(
    target: "axi_frame_compositor",
    test_file: "test_axi_frame_compositor.py",
    cases: (
      academic_test_case(
        name: "test_axi_frame_compositor_multiframe_sync_with_gray_delay_and_backpressure",
        check: [Multi-frame AXI handshake correctness under backpressure, including SOF/EOL discipline and payload stability while stalled.],
      ),
      academic_test_case(
        name: "test_axi_frame_compositor_delay_stage_sweep_with_backpressure",
        check: [Delay-stage sweep verifies Sobel versus Blur+Sobel alignment when gray start delay matches effective tap latency.],
      ),
      academic_test_case(
        name: "test_axi_frame_compositor_binary_mode_not_blocked_by_rgb",
        check: [Binary mode remains gray-driven and non-blocking even when RGB-source consumption pressure is absent.],
      ),
    ),
  ),
  caption: [Final shared macro (`academic_test_table`) with automatic identifier wrapping and grouped case input.],
)
