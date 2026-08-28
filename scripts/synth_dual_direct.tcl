set script_dir [file dirname [info script]]
set project_root [file normalize "$script_dir/.."]
set part "xc7a100tcsg324-1"

read_verilog "$project_root/scripts/test_sbox_dual_direct.v"
synth_design -top test_sbox_dual_direct -part $part -directive AreaOptimized_high
report_utilization -file "$project_root/outputs/test_dual_direct_util.rpt"
exit
