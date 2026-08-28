set script_dir [file dirname [info script]]
set project_root [file normalize "$script_dir/.."]
set part "xc7a100tcsg324-1"

puts "==> Reading RTL..."
read_verilog [glob -nocomplain "$project_root/src/aes/*.v"]
read_verilog [glob -nocomplain "$project_root/src/axi/*.v"]
read_verilog [glob -nocomplain "$project_root/src/top/*.v"]

puts "==> Synthesizing with AreaOptimized_high..."
synth_design -top aes_axi_top -part $part -flatten_hierarchy rebuilt -directive AreaOptimized_high

puts "==> Post-synth utilization..."
report_utilization -file "$project_root/outputs/test_area_synth.rpt"

puts "==> Running opt_design with ExploreArea..."
opt_design -directive ExploreArea

puts "==> Post-opt utilization..."
report_utilization -file "$project_root/outputs/test_area_opt.rpt"
exit
