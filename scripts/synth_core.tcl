# Early Synthesis & Logic Optimization Check for aes_core
set script_dir [file dirname [info script]]
set project_root [file normalize "$script_dir/.."]
set part "xc7a100tcsg324-1"

puts "==> Reading AES RTL..."
read_verilog [glob -nocomplain "$project_root/src/aes/*.v"]

puts "==> Synthesizing aes_core for $part..."
synth_design -top aes_core -part $part -flatten_hierarchy rebuilt -directive AreaOptimized_high

puts "==> Running opt_design..."
opt_design -directive ExploreArea

puts "==> Generating Post-Opt Utilization Report..."
report_utilization -file "$project_root/outputs/core_opt_utilization.rpt"

puts "==> Generating Timing Report..."
report_timing_summary -file "$project_root/outputs/core_opt_timing.rpt"

puts "==> Optimization & Synthesis Complete!"
