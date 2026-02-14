# Project-wide Vivado configuration for reproducible checkout.
# Vivado version pin: 2025.1

proc set_project_properties_post_create_project {i_project_name} {
    set obj [get_projects $i_project_name]

    set_property part {xc7z010clg400-1} $obj
    set board_part_id {digilentinc.com:zybo-z7-10:part0:1.1}
    if {[llength [get_board_parts -quiet $board_part_id]] > 0} {
        set_property board_part $board_part_id $obj
    } else {
        # Continue with part-only flow if board files are not installed.
        puts "WARNING: Board definition '$board_part_id' not found in this Vivado installation. Continuing with part-only project settings."
    }
    set_property target_language {VHDL} $obj
    set_property simulator_language {Mixed} $obj

    # Keep generated state inside the disposable project workspace.
    set_property ip_cache_permissions {read write} $obj
}

proc set_project_properties_pre_add_repo {i_project_name} {
    # Reserved for project-specific IP catalog settings.
    # Intentionally empty; checkout.tcl sets ip_repo_paths directly.
}

proc set_project_properties_post_create_runs {i_project_name} {
    if {[llength [get_runs -quiet synth_1]] > 0} {
        set_property strategy {Vivado Synthesis Defaults} [get_runs synth_1]
    }

    if {[llength [get_runs -quiet impl_1]] > 0} {
        set_property strategy {Vivado Implementation Defaults} [get_runs impl_1]
        set_property STEPS.WRITE_BITSTREAM.ARGS.BIN_FILE {false} [get_runs impl_1]
    }
}
