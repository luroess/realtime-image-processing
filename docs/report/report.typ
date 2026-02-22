#import "@preview/booktabs:0.0.4": booktabs-default-table-style
#import "shared/macros.typ": *

#set text(lang: "en")
#set math.equation(numbering: "(1)", supplement: [Eq.])
#set par(justify: true)
#set heading(numbering: "1.")
#set page(paper: "a4", margin: (x: 2.1cm, y: 1.9cm), numbering: "1")
#show: booktabs-default-table-style
#show table.cell: set text(size: 8.7pt)
#show table.cell.where(y: 0): set text(weight: "semibold")
#show bibliography: set text(size: 9pt)

#align(center)[
  #text(size: 19pt, weight: "bold")[Realtime Streaming Image Processing on FPGA]
  #linebreak()
  #text(size: 11pt, fill: rgb("#334155"))[
    Implementation Report Revision: AXI4-Stream Pipeline, Control FSM, and Verification
  ]
  #v(6pt)
  #image("../figures/hm-logo.svg", width: 2.8cm)
  #v(6pt)
  #text(size: 10pt)[Lukas Roess, Valentin Bumeder, Jan Duchscherer, Justin Loeber]
  #linebreak()
  #text(size: 9pt, fill: rgb("#64748b"))[Embedded Systems, Academic Year 2025-2026]
  #linebreak()
  #text(size: 9pt, fill: rgb("#64748b"))[Revision date: 2026-02-22]
]

#v(0.8cm)

#include "sections/01_abstract.typ"
#include "sections/02_scope_revision.typ"
#include "sections/03_axi_protocol_background.typ"
#include "sections/04_rgb_to_grayscale.typ"
#include "sections/05_click_detector.typ"
#include "sections/06_frame_compositor.typ"
#include "sections/07_simulation_framework.typ"
#include "sections/08_synthesis_results.typ"
#include "sections/09_risks_next_steps.typ"

#pagebreak()
#bibliography("references.bib", title: [References])
