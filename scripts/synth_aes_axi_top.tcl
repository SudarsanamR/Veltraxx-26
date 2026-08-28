set script_dir [file dirname [info script]]
set project_root [file normalize "$script_dir/.."]
set part "xc7a100tcsg324-1"

puts "==> Reading RTL..."
read_verilog [glob -nocomplain "$project_root/src/aes/*.v"]
read_verilog [glob -nocomplain "$project_root/src/axi/*.v"]
read_verilog [glob -nocomplain "$project_root/src/top/*.v"]

puts "==> Synthesizing aes_axi_top OOC..."
synth_design -top aes_axi_top -part $part -mode out_of_context -flatten_hierarchy rebuilt -directive AreaOptimized_high

puts "==> Optimizing logic..."
opt_design -directive ExploreArea

puts "==> Placing design..."
create_clock -period 10.000 -name clk [get_ports s_axi_aclk]
place_design -directive ExtraPostPlacementOpt

puts "==> Routing design..."
route_design -directive Explore

puts "==> Post-Implementation Reports..."
report_utilization -file "$project_root/outputs/aes_axi_top_util.rpt"
report_utilization -hierarchical -file "$project_root/outputs/aes_axi_top_hier_util.rpt"
report_timing_summary -file "$project_root/outputs/aes_axi_top_timing.rpt"

puts "==> Build Complete!"
exit
