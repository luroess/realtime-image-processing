#import "@preview/supercharged-hm:0.1.2": hm-template
#import "@preview/booktabs:0.0.4": booktabs-default-table-style
#import "shared/macros.typ": *

#show: hm-template(
  [
    #set math.equation(numbering: "(1)", supplement: [Eq.])
    #show: booktabs-default-table-style
    #show table.cell: set text(size: 8.7pt)
    #show table.cell.where(y: 0): set text(weight: "semibold")
    #set page(
      header: context {
        set text(10pt)
        grid(
          columns: (1fr, auto),
          align(left)[
            HW/SW Co-Design
          ],
          align(right)[
            #set image(height: 25pt)
            #image("../figures/hm-logo.svg")
          ],
        )
        line(length: 100%, stroke: 1pt + rgb("#1f2937"))
      },
    )
    #set page(
      footer: context {
        set text(9pt)
        grid(
          columns: (1fr, auto),
          align(left)[Jan Duchscherer, Lukas Röß, Valentin Bumeder],
          align(right)[
            #counter(page).display("1 / 1", both: true)
          ],
        )
      },
    )

    #include "sections/01_intro.typ"
    #include "sections/04_rgb_to_grayscale.typ"
    #include "sections/05_a_debouncer.typ"
    #include "sections/05_click_detector.typ"
    #include "sections/20_blur_filter.typ"
    #include "sections/21_sobel_filter.typ"
    #include "sections/22_sobel-blur_window_module.typ"
    #include "sections/06_frame_compositor.typ"
    #include "sections/23_pipeline.typ"
    #include "sections/30_picture_overlay.typ"
    #include "sections/07_simulation_framework.typ"
    #include "sections/31_vivado_integration.typ"
    #include "sections/08_synthesis_results.typ"
    #include "sections/09_conclusion.typ"
  ],
  title: [Realtime Streaming Image Processing on FPGA],
  subtitle: [Module Report: AXI4-Stream Pipeline, Control FSM, Image Overlay, Verification & Simulation, Synthesis Results],
  top-remark: [],
  doc-type: [HW/SW Co-Design],
  authors: [Jan Duchscherer, Lukas Röß, Valentin Bumeder],
  date: datetime(year: 2026, month: 2, day: 22),
  language: "en",
  font: "CMU Serif",
  show-table-of-contents: true,
  toc-depth: 2,
  bibliography: bibliography("references.bib"),
  appendix: [
    #include "sections/10_appendix.typ"
  ],
)
