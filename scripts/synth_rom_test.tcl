set script_dir [file dirname [info script]]
set project_root [file normalize "$script_dir/.."]
set part "xc7a100tcsg324-1"

read_verilog "$project_root/scripts/test_rom_dist.v"
synth_design -top test_rom_dist -part $part -directive AreaOptimized_high
report_utilization -file "$project_root/outputs/test_rom_dist_util.rpt"
exit
