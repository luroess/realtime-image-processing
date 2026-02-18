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

proc regex_escape {text} {
  set escaped $text
  regsub -all {[][(){}.^$*+?\\|]} $escaped {\\&} escaped
  return $escaped
}

proc find_xpr_files {root_dir} {
  set results [list]

  foreach entry [glob -nocomplain -directory $root_dir *] {
    if {[file isdirectory $entry]} {
      set nested [find_xpr_files $entry]
      if {[llength $nested] > 0} {
        set results [concat $results $nested]
      }
    } elseif {[string equal -nocase [file extension $entry] ".xpr"]} {
      lappend results $entry
    }
  }

  return $results
}

proc build_xpr_rules {xpr_path} {
  set xpr_name [file tail $xpr_path]
  set xpr_name_pattern [regex_escape $xpr_name]

  return [list \
    [list [format {Path="[^"]*%s"} $xpr_name_pattern] [format {Path="$PPRDIR/%s"} $xpr_name]] \
  ]
}

set rtl_dir [file dirname [file normalize [info script]]]

set xpr_files [find_xpr_files $rtl_dir]
if {[llength $xpr_files] == 0} {
  error "No .xpr files found under $rtl_dir"
}

foreach xpr_path $xpr_files {
  set rules [build_xpr_rules $xpr_path]
  normalize_file $xpr_path $rules
  cleanup_edit_ip_generated_paths $xpr_path
}

puts "Done."
