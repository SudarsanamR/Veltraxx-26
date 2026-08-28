set script_dir [file dirname [info script]]
set project_root [file normalize "$script_dir/.."]
set part "xc7a100tcsg324-1"

read_verilog "/tmp/canright_sbox.v"
synth_design -top bSbox -part $part -directive AreaOptimized_high
report_utilization -file "$project_root/outputs/test_canright_util.rpt"
exit
