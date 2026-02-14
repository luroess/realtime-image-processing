# Build bitstream and export handoff artifacts.
# Usage:
#   set argv "-tag <artifact_tag> -repo-root /abs/path/to/repo"
#   source vivado/tcl/build_export.tcl

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
if {[info exists ::rt_repo_root]} {
    set repo_root $::rt_repo_root
}

if {[llength [get_projects -quiet]] == 0} {
    set auto_project_file [file join $repo_root vivado proj hw hw.xpr]
    if {![file exists $auto_project_file]} {
        error "No open project and no project found at $auto_project_file. Run checkout.tcl first."
    }
    open_project $auto_project_file
}

set project_name [get_property NAME [current_project]]
set project_dir [get_property DIRECTORY [current_project]]
set repo_root [file normalize [file join $project_dir .. .. ..]]

set default_tag [clock format [clock seconds] -format "%Y%m%d-%H%M%S"]
set tag [rt_get_arg "-tag" $default_tag]
set out_dir [file normalize [file join $repo_root vivado artifacts handoff $tag]]
file mkdir $out_dir

puts "INFO: Launching implementation through write_bitstream"
launch_runs impl_1 -to_step write_bitstream
wait_on_run impl_1

set run_dir [file normalize [file join $project_dir ${project_name}.runs impl_1]]
set bit_files [glob -nocomplain [file join $run_dir *.bit]]
set ltx_files [glob -nocomplain [file join $run_dir *.ltx]]
set dcp_files [glob -nocomplain [file join $run_dir *.dcp]]

if {[llength $bit_files] == 0} {
    error "Bitstream not found in $run_dir"
}

foreach f $bit_files {
    file copy -force $f $out_dir
}
foreach f $ltx_files {
    file copy -force $f $out_dir
}
foreach f $dcp_files {
    file copy -force $f $out_dir
}

set xsa_file [file join $out_dir system_wrapper.xsa]
write_hw_platform -fixed -include_bit -force -file $xsa_file

puts "INFO: Export complete: $out_dir"
