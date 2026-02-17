#!/usr/bin/env tclsh

# Normalize checked-in Vivado Edit-IP .xpr files so they remain portable in Git.
# Usage:
#   tclsh rtl/normalize_local_ip_xpr_paths.tcl

proc read_text {path} {
  set fh [open $path r]
  fconfigure $fh -encoding utf-8 -translation lf
  set text [read $fh]
  close $fh
  return $text
}

proc write_text {path text} {
  set fh [open $path w]
  fconfigure $fh -encoding utf-8 -translation lf
  puts -nonewline $fh $text
  close $fh
}

proc normalize_file {path rules} {
  if {![file exists $path]} {
    error "Missing file: $path"
  }

  set original [read_text $path]
  set text $original
  set total_matches 0

  foreach rule $rules {
    lassign $rule pattern replacement
    set matches [regexp -all -- $pattern $text]
    incr total_matches $matches
    set text [regsub -all -- $pattern $text $replacement]
  }

  if {$text ne $original} {
    write_text $path $text
    puts "Updated $path ($total_matches replacements)"
  } else {
    puts "No changes $path"
  }
}

proc delete_if_exists {path} {
  if {[file exists $path]} {
    file delete -force $path
    puts "Removed $path"
  } else {
    puts "Skip missing $path"
  }
}

proc cleanup_edit_ip_generated_paths {xpr_path} {
  if {![file exists $xpr_path]} {
    error "Missing file: $xpr_path"
  }

  set ip_dir [file dirname $xpr_path]
  set stem [file rootname [file tail $xpr_path]]

  # Keep only the checked-in edit project and source-packaged IP files.
  # These are Vivado-generated working artifacts and can be recreated.
  set generated_suffixes [list \
    ".cache" \
    ".hw" \
    ".ip_user_files" \
    ".sim" \
    ".runs" \
    ".gen" \
  ]

  foreach suffix $generated_suffixes {
    delete_if_exists [file join $ip_dir "${stem}${suffix}"]
  }

  delete_if_exists [file join $ip_dir ".Xil"]
  delete_if_exists [file join $ip_dir "${stem}.jou"]
  delete_if_exists [file join $ip_dir "${stem}.log"]
}

set rtl_dir [file dirname [file normalize [info script]]]

set rgb_xpr [file join $rtl_dir RGB_TO_GRAYSCALE ip edit_AXI_RgbToGrayscale.xpr]
set edge_xpr [file join $rtl_dir EDGE_OVERLAY ip edit_AXI_EdgeOverlay.xpr]

set rgb_rules [list \
  [list {Path="[^"]*edit_AXI_RgbToGrayscale\.xpr"} {Path="$PPRDIR/edit_AXI_RgbToGrayscale.xpr"}] \
  [list {<Option Name="IPRepoPath" Val="\$PPRDIR/\.\./\.\./ip_repo"/>} {<Option Name="IPRepoPath" Val="$PPRDIR/../.."/>}] \
  [list {<File Path="\$PPRDIR/\.\./\.\./ip_repo/component\.xml">} {<File Path="$PPRDIR/../component.xml">}] \
]

set edge_rules [list \
  [list {Path="[^"]*edit_AXI_EdgeOverlay\.xpr"} {Path="$PPRDIR/edit_AXI_EdgeOverlay.xpr"}] \
  [list {<Option Name="IPRepoPath" Val="[^"]*[Ee][Dd][Gg][Ee]_[Oo][Vv][Ee][Rr][Ll][Aa][Yy]"/>} {<Option Name="IPRepoPath" Val="$PPRDIR/.."/>}] \
  [list {<File Path="[^"]*[Ee][Dd][Gg][Ee]_[Oo][Vv][Ee][Rr][Ll][Aa][Yy]/hdl/edge_overlay\.vhd">} {<File Path="$PPRDIR/../hdl/edge_overlay.vhd">}] \
  [list {<File Path="[^"]*[Ee][Dd][Gg][Ee]_[Oo][Vv][Ee][Rr][Ll][Aa][Yy]/hdl/axi_edge_overlay\.vhd">} {<File Path="$PPRDIR/../hdl/axi_edge_overlay.vhd">}] \
]

normalize_file $rgb_xpr $rgb_rules
normalize_file $edge_xpr $edge_rules

cleanup_edit_ip_generated_paths $rgb_xpr
cleanup_edit_ip_generated_paths $edge_xpr

puts "Done."
