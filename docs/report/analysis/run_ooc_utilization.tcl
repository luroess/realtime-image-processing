set repo_root [file normalize [file join [pwd] "."]]
set part "xc7z010clg400-1"

proc run_ooc_util {name top src_list out_dir part} {
  file mkdir $out_dir
  create_project -force $name $out_dir -part $part

  foreach src $src_list {
    read_vhdl $src
  }

  synth_design -top $top -part $part -mode out_of_context
  report_utilization -file [file join $out_dir "${name}_utilization_synth.rpt"]
  report_timing_summary -file [file join $out_dir "${name}_timing_synth.rpt"]
  close_project
}

set rgb_src [list \
  [file join $repo_root "rtl" "RGB_TO_GRAYSCALE" "hdl" "rgb_to_grayscale.vhd"] \
  [file join $repo_root "rtl" "RGB_TO_GRAYSCALE" "hdl" "axi_rgb_to_grayscale.vhd"] \
]

set frame_src [list \
  [file join $repo_root "rtl" "FRAME_COMPOSITOR" "hdl" "frame_compositor.vhd"] \
]

run_ooc_util "rgb_to_grayscale_ooc" "AXI_RgbToGrayscale" $rgb_src \
  [file join $repo_root "docs" "report" "data" "vivado_ooc" "rgb_to_grayscale"] $part

run_ooc_util "frame_compositor_core_ooc" "FrameCompositor" $frame_src \
  [file join $repo_root "docs" "report" "data" "vivado_ooc" "frame_compositor_core"] $part

exit
