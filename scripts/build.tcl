# Vivado Synthesis and Implementation Script (Non-Project Batch Mode)
# Usage: vivado -mode batch -source scripts/build.tcl

set script_dir [file dirname [info script]]
set project_root [file normalize "$script_dir/.."]
set part "xc7a100tcsg324-1"

puts "==> Starting build for part: $part"
puts "==> Project Root: $project_root"

# Read RTL files
read_verilog [glob -nocomplain "$project_root/src/aes/*.v"]
read_verilog [glob -nocomplain "$project_root/src/axi/*.v"]
read_verilog [glob -nocomplain "$project_root/src/top/*.v"]

# Read Constraints
if {[file exists "$project_root/constraints/nexys_a7.xdc"]} {
    read_xdc "$project_root/constraints/nexys_a7.xdc"
}

# Synthesis
synth_design -top aes_axi_top -part $part
write_checkpoint -force "$project_root/outputs/post_synth.dcp"
report_utilization -file "$project_root/outputs/synth_utilization.rpt"
report_timing_summary -file "$project_root/outputs/synth_timing.rpt"

# Implementation
opt_design
place_design
route_design
write_checkpoint -force "$project_root/outputs/post_route.dcp"

# Final Reports
report_utilization -file "$project_root/outputs/route_utilization.rpt"
report_timing_summary -file "$project_root/outputs/route_timing.rpt"

# Generate Bitstream if constraints and pins are fully mapped
# write_bitstream -force "$project_root/outputs/aes_axi_top.bit"

puts "==> Build complete. Check reports in outputs/ directory."
