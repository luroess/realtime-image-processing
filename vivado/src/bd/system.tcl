# Transitional block-design bootstrap script.
#
# This repository expects this file to eventually be the direct output of:
#   write_bd_tcl -force -include_layout vivado/src/bd/system.tcl
#
# Vivado is not available in this environment, so this script currently imports
# a migration snapshot BD from vivado/migration/system.bd.

set script_dir [file dirname [file normalize [info script]]]
set repo_root [file normalize [file join $script_dir .. ..]]
set migration_bd [file normalize [file join $repo_root migration system.bd]]

if {![file exists $migration_bd]} {
    error "Missing migration BD snapshot: $migration_bd"
}

puts "INFO: Importing migration BD snapshot: $migration_bd"

# Add the snapshot BD to sources_1 if not already present.
set bd_candidates [get_files -quiet -all -filter {FILE_TYPE == "Block Designs" && NAME =~ "*system.bd"}]
if {[llength $bd_candidates] == 0} {
    add_files -norecurse -fileset sources_1 $migration_bd
    set bd_candidates [get_files -quiet -all -filter {FILE_TYPE == "Block Designs" && NAME =~ "*system.bd"}]
}

if {[llength $bd_candidates] == 0} {
    error "Unable to locate system.bd after import"
}

set bd_file [lindex $bd_candidates 0]
open_bd_design $bd_file
validate_bd_design
save_bd_design

puts "INFO: Loaded block design from migration snapshot."
puts "INFO: Replace vivado/src/bd/system.tcl with write_bd_tcl output when Vivado is available."
