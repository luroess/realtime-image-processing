# Project-local entry point for vivado-git integration.
set init_dir [file dirname [info script]]
source [file join $init_dir vivado-git Vivado_init.tcl]
