set repo_root [file normalize [file join [pwd] "."]]

set dcp_path [file join $repo_root \
  "vivado" "Zybo-Z7-10-Pcam-5C-hw.xpr" "hw" "hw.runs" \
  "system_AXI_RgbGrayBlurrSobe_0_0_synth_1" "system_AXI_RgbGrayBlurrSobe_0_0.dcp"]

set out_dir [file join $repo_root "docs" "report" "data" "vivado_ooc" "pipeline_ip"]
file mkdir $out_dir

open_checkpoint $dcp_path
report_utilization -file [file join $out_dir "pipeline_ip_utilization_synth.rpt"]
report_utilization -hierarchical -hierarchical_depth 2 \
  -file [file join $out_dir "pipeline_ip_hier_utilization_synth.rpt"]
close_design

exit
