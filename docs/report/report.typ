#import "shared/macros.typ": repo_link

#set page(
  paper: "a4",
  margin: (x: 1.8cm, y: 1.6cm),
  numbering: "1",
)
#set text(font: "Libertinus Serif", size: 10.3pt)
#set heading(numbering: "1.")
#set par(justify: true)
#set math.equation(numbering: "(1)")
#show bibliography: set text(size: 9pt)

#let project = [Realtime Streaming Image Processing on FPGA]
#let subtitle = [Implementation Report Revision: AXI4-Stream Pipeline, Control FSM, and Verification]
#let team = [Lukas Roess, Valentin Bumeder, Jan Duchscherer, Justin Loeber]

#let resource_rows = csv("data/resource_utilization.csv")
#let share_rows = csv("data/resource_relative_share_vs_system.csv")

#let module_name(module) = {
  if module == "rgb_to_grayscale_axi_ooc" {
    [RGB_TO_GRAYSCALE (AXI OOC)]
  } else if module == "frame_compositor_core_ooc" {
    [FRAME_COMPOSITOR core (OOC)]
  } else if module == "pl_pipeline_ip_ooc" {
    [Integrated pipeline IP (OOC)]
  } else if module == "system_wrapper_placed" {
    [Entire system (placed)]
  } else {
    [#module]
  }
}

#let pct_bar(value, color: rgb("#1f77b4")) = {
  let v = float(value)
  let clamped = calc.min(v, 100.0)
  box(
    width: clamped * 0.06cm,
    height: 0.28cm,
    fill: color,
    stroke: none,
    radius: 1.5pt,
    inset: 0pt,
  )
}

#align(center)[
  #text(size: 18pt, weight: "bold")[#project]
  #v(0.3em)
  #text(size: 11pt)[#subtitle]
  #v(0.9em)
  #team
  #linebreak()
  Embedded Systems, Academic Year 2025-2026
  #linebreak()
  Revision date: 2026-02-22
]

#v(1.1em)

#include "sections/01_abstract.typ"
#include "sections/02_scope_revision.typ"
#include "sections/03_axi_protocol_background.typ"
#include "sections/04_rgb_to_grayscale.typ"
#include "sections/05_click_detector.typ"
#include "sections/06_frame_compositor.typ"
#include "sections/07_simulation_framework.typ"
#include "sections/08_synthesis_results.typ"
#include "sections/09_risks_next_steps.typ"

#bibliography("references.bib", title: [References])
