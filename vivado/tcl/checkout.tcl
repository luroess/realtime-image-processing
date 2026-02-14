# Recreate the Vivado project from canonical repository sources.
# Usage:
#   set argv "-repo-root /abs/path/to/repo"
#   source vivado/tcl/checkout.tcl

proc rt_get_arg {i_flag i_default} {
    set idx [lsearch -exact $::argv $i_flag]
    if {$idx < 0} {
        return $i_default
    }
    set val_idx [expr {$idx + 1}]
    if {$val_idx >= [llength $::argv]} {
        error "Missing value for argument $i_flag"
    }
    return [lindex $::argv $val_idx]
}

set script_dir [file dirname [file normalize [info script]]]
set default_repo_root [file normalize [file join $script_dir .. ..]]
set repo_root [file normalize [rt_get_arg "-repo-root" $default_repo_root]]
set ::rt_repo_root $repo_root

set project_name hw
set project_dir [file normalize [file join $repo_root vivado proj $project_name]]
set project_file [file join $project_dir ${project_name}.xpr]

if {[llength [get_projects -quiet]] > 0} {
    close_project
}

file mkdir $project_dir
create_project $project_name $project_dir -part xc7z010clg400-1 -force

source [file join $repo_root vivado tcl project_info.tcl]
set_project_properties_post_create_project $project_name

# Ensure standard filesets exist.
if {[string equal [get_filesets -quiet sources_1] ""]} {
    create_fileset -srcset sources_1
}
if {[string equal [get_filesets -quiet constrs_1] ""]} {
    create_fileset -constrset constrs_1
}

set src_set [get_filesets sources_1]
set constrs_set [get_filesets constrs_1]

# Configure deterministic IP repository paths.
set ip_repo_paths [list \
    [file normalize [file join $repo_root vivado ip_repo vivado-library]] \
    [file normalize [file join $repo_root vivado src ip_local]] \
]
set_property ip_repo_paths $ip_repo_paths $src_set
update_ip_catalog -rebuild

# Add canonical HDL sources.
foreach pattern [list \
    [file join $repo_root vivado src hdl *.vhd] \
    [file join $repo_root vivado src hdl *.v] \
    [file join $repo_root vivado src hdl *.sv] \
    [file join $repo_root rtl RGB_TO_GRAYSCALE hdl *.vhd] \
    [file join $repo_root rtl RGB_TO_GRAYSCALE hdl *.v] \
    [file join $repo_root rtl RGB_TO_GRAYSCALE hdl *.sv] \
] {
    set files [glob -nocomplain $pattern]
    if {[llength $files] > 0} {
        add_files -quiet -norecurse -fileset $src_set $files
    }
}
update_compile_order -fileset sources_1

# Add constraints.
set xdc_files [glob -nocomplain [file join $repo_root vivado src constraints *.xdc]]
if {[llength $xdc_files] == 0} {
    error "No constraint files found under vivado/src/constraints"
}
add_files -quiet -norecurse -fileset $constrs_set $xdc_files

# Recreate/import block design.
set bd_script [file join $repo_root vivado src bd system.tcl]
if {![file exists $bd_script]} {
    error "Missing block-design script: $bd_script"
}
source $bd_script

# Generate and import wrapper.
set bd_file [lindex [get_files -quiet -all -filter {FILE_TYPE == "Block Designs" && NAME =~ "*system.bd"}] 0]
if {$bd_file eq ""} {
    error "Unable to locate block design file after sourcing $bd_script"
}
set wrapper_file [make_wrapper -files $bd_file -top -force]
import_files -quiet -force -norecurse $wrapper_file
set_property top system_wrapper $src_set
update_compile_order -fileset sources_1

# Configure default runs.
set_project_properties_post_create_runs $project_name
current_run -synthesis [get_runs synth_1]
current_run -implementation [get_runs impl_1]

save_project

puts "INFO: Checkout complete: $project_file"
puts "INFO: Repo root detected as: $repo_root"
puts "INFO: To build and export artifacts run:"
puts "INFO:   set argv \"-tag <artifact_tag> -repo-root $repo_root\""
puts "INFO:   source [file join $repo_root vivado tcl build_export.tcl]"
