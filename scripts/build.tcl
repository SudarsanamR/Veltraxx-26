## =============================================================================
## Full Implementation Build Script for Nexys A7
## PS06 AES-128 AXI-MM Hardware Accelerator — VELTRAXX '26
## =============================================================================
## Runs: synth_design → opt_design → place_design → phys_opt_design → route_design
## Outputs: utilization, timing, and bitstream reports
## =============================================================================

set script_dir [file dirname [info script]]
set project_root [file normalize "$script_dir/.."]
set part "xc7a100tcsg324-1"

## ─────────────────────────────────────────────────────────────────────────────
## Step 1: Read RTL & Constraints
## ─────────────────────────────────────────────────────────────────────────────
puts "==> Reading RTL..."
read_verilog [glob -nocomplain "$project_root/src/aes/*.v"]
read_verilog [glob -nocomplain "$project_root/src/axi/*.v"]
read_verilog [glob -nocomplain "$project_root/src/top/*.v"]

puts "==> Reading constraints..."
read_xdc "$project_root/constraints/nexys_a7.xdc"

## ─────────────────────────────────────────────────────────────────────────────
## Step 2: Synthesis (AreaOptimized_high)
## ─────────────────────────────────────────────────────────────────────────────
puts "==> Synthesizing aes_axi_top..."
synth_design -top aes_axi_top -part $part -flatten_hierarchy rebuilt -directive AreaOptimized_high

puts "==> Post-Synth Utilization..."
report_utilization -file "$project_root/outputs/post_synth_util.rpt"

## ─────────────────────────────────────────────────────────────────────────────
## Step 3: Logic Optimization (ExploreArea)
## ─────────────────────────────────────────────────────────────────────────────
puts "==> Optimizing logic..."
opt_design -directive ExploreArea

puts "==> Post-Opt Utilization..."
report_utilization -file "$project_root/outputs/post_opt_util.rpt"
report_utilization -hierarchical -file "$project_root/outputs/post_opt_hier_util.rpt"

## ─────────────────────────────────────────────────────────────────────────────
## Step 4: Placement
## ─────────────────────────────────────────────────────────────────────────────
puts "==> Placing design..."
place_design -directive ExtraNetDelay_high

## ─────────────────────────────────────────────────────────────────────────────
## Step 5: Physical Optimization (post-placement)
## ─────────────────────────────────────────────────────────────────────────────
puts "==> Physical optimization..."
phys_opt_design -directive AggressiveExplore

## ─────────────────────────────────────────────────────────────────────────────
## Step 6: Routing
## ─────────────────────────────────────────────────────────────────────────────
puts "==> Routing design..."
route_design -directive Explore

## ─────────────────────────────────────────────────────────────────────────────
## Step 7: Post-Route Reports
## ─────────────────────────────────────────────────────────────────────────────
puts "==> Generating post-route reports..."
report_utilization -file "$project_root/outputs/utilization.rpt"
report_utilization -hierarchical -file "$project_root/outputs/utilization_hier.rpt"
report_timing_summary -file "$project_root/outputs/timing.rpt"
report_power -file "$project_root/outputs/power.rpt"

## ─────────────────────────────────────────────────────────────────────────────
## Step 8: Bitstream Generation
## ─────────────────────────────────────────────────────────────────────────────
puts "==> Generating bitstream..."
write_bitstream -force "$project_root/outputs/aes_axi_top.bit"

puts "============================================"
puts "  BUILD COMPLETE"
puts "============================================"
exit
