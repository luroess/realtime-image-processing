#let ext_link_blue = rgb("#1a5fb4")
#let blink(dest, body) = link(dest)[
  #set text(fill: ext_link_blue)
  #body
]

#let repo_stem = "https://github.com/luroess/realtime-image-processing/blob/master/"

#let repo_link(path, body: none, line: none, line_end: none) = {
  let anchor = if line == none {
    ""
  } else if line_end == none {
    "#L" + str(line)
  } else {
    "#L" + str(line) + "-L" + str(line_end)
  }
  let dest = repo_stem + path + anchor
  if body == none {
    blink(dest, raw(path))
  } else {
    blink(dest, body)
  }
}
