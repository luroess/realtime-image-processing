# Create a full Vivado project archive zip from the currently open project.
# Usage:
#   set argv "-tag <archive_tag> -repo-root /abs/path/to/repo"
#   source vivado/tcl/archive_full_project.tcl

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

set project_dir [get_property DIRECTORY [current_project]]
set repo_root [file normalize [file join $project_dir .. .. ..]]
set default_tag [clock format [clock seconds] -format "%Y%m%d-%H%M%S"]
set tag [rt_get_arg "-tag" $default_tag]

set out_dir [file normalize [file join $repo_root vivado artifacts archive]]
file mkdir $out_dir
set zip_path [file join $out_dir ${tag}.zip]

puts "INFO: Archiving full project to $zip_path"
archive_project -force -include_local_ip_cache $zip_path
puts "INFO: Archive complete: $zip_path"
