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

#align(center)[
  #text(size: 19pt, weight: "bold")[Realtime Streaming Image Processing on FPGA]
  #linebreak()
  #text(size: 11pt, fill: rgb("#334155"))[
    Implementation Report: AXI4-Stream Pipeline, Verification, and Team Contributions
  ]
  #v(6pt)
  #image("figures/hm-logo.svg", width: 2.8cm)
  #v(6pt)
  #text(size: 10pt)[Lukas Roess, Valentin Bumeder, Jan Duchscherer, Justin Loeber]
  #linebreak()
  #text(size: 9pt, fill: rgb("#64748b"))[Embedded Systems, Academic Year 2025-2026]
]

#v(0.8cm)

#include "sections/00_abstract.typ"
#include "sections/01_intro_scope.typ"
#include "sections/02_system_architecture.typ"
#include "sections/03_verification_framework.typ"
#include "sections/04_component_rgb2gray.typ"
#include "sections/05_component_window_sobel_wrapper.typ"
#include "sections/06_component_edge_overlay_and_control.typ"
#include "sections/07_results_and_metrics.typ"
#include "sections/08_team_contributions.typ"
#include "sections/09_fast_theoretical_zybo.typ"
#include "sections/09_risks_limitations_future.typ"
#include "sections/10_conclusion.typ"

#pagebreak()
#bibliography("references.bib", title: [References])
