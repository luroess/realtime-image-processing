# Create a full Vivado project archive zip from the currently open project.
# Usage:
#   set argv "-tag <archive_tag>"
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

if {[llength [get_projects -quiet]] == 0} {
    error "No open project. Open vivado/proj/hw/hw.xpr first or run checkout.tcl"
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
