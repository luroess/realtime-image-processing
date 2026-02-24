#import "@preview/booktabs:0.0.4": *

#let ext_link_blue = rgb("#1a5fb4")
#let blink(dest, body) = link(dest)[
  #set text(fill: ext_link_blue)
  #body
]

#let repo_base = "https://github.com/luroess/realtime-image-processing"
#let repo_default_branch = "master"

#let repo_link(path, body: none, line: none, line_end: none, branch: none) = {
  let ref = if branch == none { repo_default_branch } else { branch }
  let anchor = if line == none {
    ""
  } else if line_end == none {
    "#L" + str(line)
  } else {
    "#L" + str(line) + "-L" + str(line_end)
  }
  let dest = repo_base + "/blob/" + ref + "/" + path + anchor
  if body == none {
    blink(dest, raw(path))
  } else {
    blink(dest, body)
  }
}

#let component_owner(owner) = {
  block(
    inset: (left: 0pt, right: 0pt, top: 6pt, bottom: 8pt),
    stroke: (bottom: 0.4pt + rgb("#aaaaaa")),
    [
      #text(size: 9pt, fill: rgb("#555555"))[Component owner(s): ]
      #text(size: 9pt, weight: "medium")[#owner]
    ],
  )
}

#let section_kpis(kpis) = {
  let cells = ()
  for kpi in kpis {
    cells.push(
      block(
        inset: 10pt,
        radius: 6pt,
        fill: rgb("#f7f9fc"),
        stroke: 0.5pt + rgb("#c9d3e3"),
        [
          #text(size: 8pt, fill: rgb("#475569"), weight: "medium")[#kpi.at("title")]
          #linebreak()
          #text(size: 13pt, weight: "bold")[#kpi.at("value")]
          #if kpi.at("note") != "" {
            linebreak()
            text(size: 8pt, fill: rgb("#64748b"))[#kpi.at("note")]
          }
        ],
      )
    )
  }
  grid(columns: (1fr,) * kpis.len(), gutter: 8pt, ..cells)
}

#let mono_block(content) = {
  block(
    inset: 9pt,
    radius: 5pt,
    fill: rgb("#f8fafc"),
    stroke: 0.4pt + rgb("#d1d5db"),
    text(font: "DejaVu Sans Mono", size: 8.5pt)[#content],
  )
}

#let academic_table(columns: (), align: auto, ..rows) = {
  let rows_arr = rows.pos()
  let header_row = rows_arr.at(0)
  let body_rows = rows_arr.slice(1)
  table(
    columns: columns,
    align: align,
    inset: (x: 4.5pt, y: 2.4pt),
    toprule(),
    header_row,
    midrule(),
    ..body_rows,
    bottomrule(),
  )
}

#let interface_group_row(
  label,
  fill: luma(240),
  text_fill: rgb("#475569"),
) = {
  table.cell(
    colspan: 4,
    fill: fill,
    inset: (x: 4pt, y: 2pt),
    align: left,
  )[#text(size: 9pt, weight: "bold", fill: text_fill)[#label]]
}

#let interface_table(
  generics: (),
  ports: (),
  columns: (auto, auto, auto, auto),
  align: (left, left, left, left),
  header: ([Name/Group], [Class], [Type/size], [Description]),
  group_fill: luma(240),
  group_text_fill: rgb("#475569"),
  group_sep_stroke: 0.3pt + rgb("#cbd5e1"),
) = {
  let generic_block = (interface_group_row("Generics", fill: group_fill, text_fill: group_text_fill),) + generics
  let port_block = if ports.len() > 0 {
    (table.hline(stroke: group_sep_stroke), interface_group_row("Ports", fill: group_fill, text_fill: group_text_fill),) + ports
  } else {
    ()
  }
  academic_table(
    columns: columns,
    align: align,
    table.header(..header),
    ..(generic_block + port_block),
  )
}

#let academic_grouped_table(
  columns: (),
  align: auto,
  group_header: none,
  sub_header: none,
  cmid_start: none,
  cmid_end: none,
  ..rows,
) = {
  let body_rows = rows.pos()
  if cmid_start == none or cmid_end == none {
    table(
      columns: columns,
      align: align,
      inset: (x: 4.5pt, y: 2.4pt),
      toprule(),
      group_header,
      sub_header,
      midrule(),
      ..body_rows,
      bottomrule(),
    )
  } else {
    table(
      columns: columns,
      align: align,
      inset: (x: 4.5pt, y: 2.4pt),
      toprule(),
      group_header,
      cmidrule(start: cmid_start, end: cmid_end),
      sub_header,
      midrule(),
      ..body_rows,
      bottomrule(),
    )
  }
}
