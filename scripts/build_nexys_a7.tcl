## =============================================================================
## Nexys A7 Full Implementation & Bitstream Build Script
## PS06 AES-128 AXI-MM Hardware Accelerator — VELTRAXX '26
## =============================================================================

set script_dir [file dirname [info script]]
set project_root [file normalize "$script_dir/.."]
set part "xc7a100tcsg324-1"

puts "==> Reading RTL Sources..."
read_verilog [glob -nocomplain "$project_root/src/aes/*.v"]
read_verilog [glob -nocomplain "$project_root/src/axi/*.v"]
read_verilog [glob -nocomplain "$project_root/src/top/*.v"]

puts "==> Reading Constraints..."
read_xdc "$project_root/constraints/nexys_a7.xdc"

puts "==> Synthesizing Top-Level (nexys_a7_uart_top)..."
synth_design -top nexys_a7_uart_top -part $part -flatten_hierarchy rebuilt -directive AreaOptimized_high

puts "==> Logic Optimization..."
opt_design -directive ExploreArea

puts "==> Placement..."
place_design -directive ExtraPostPlacementOpt

puts "==> Physical Optimization..."
phys_opt_design -directive AggressiveExplore

puts "==> Routing..."
route_design -directive Explore

puts "==> Generating Reports..."
report_utilization -file "$project_root/outputs/nexys_a7_util.rpt"
report_utilization -hierarchical -file "$project_root/outputs/nexys_a7_hier_util.rpt"
report_timing_summary -file "$project_root/outputs/nexys_a7_timing.rpt"
report_power -file "$project_root/outputs/nexys_a7_power.rpt"

puts "==> Generating Bitstream..."
write_bitstream -force "$project_root/outputs/nexys_a7_aes_demo.bit"

puts "================================================================"
puts "  NEXYS A7 AES DEMO BITSTREAM GENERATION COMPLETE!"
puts "  Bitstream Location: outputs/nexys_a7_aes_demo.bit"
puts "================================================================"
exit
