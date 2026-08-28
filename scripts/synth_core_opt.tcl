set script_dir [file dirname [info script]]
set project_root [file normalize "$script_dir/.."]
set part "xc7a100tcsg324-1"

read_verilog [glob -nocomplain "$project_root/src/aes/*.v"]
synth_design -top aes_core -part $part -flatten_hierarchy rebuilt -directive AreaOptimized_high
opt_design -directive ExploreArea
report_utilization -file "$project_root/outputs/core_only_util.rpt"
report_timing_summary -file "$project_root/outputs/core_only_timing.rpt"
exit
