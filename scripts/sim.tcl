# Vivado simulation automation script
# Usage: vivado -mode batch -source scripts/sim.tcl -tclargs <top_testbench>

set script_dir [file dirname [info script]]
set project_root [file normalize "$script_dir/.."]

set tb_name "tb_aes_axi_top"
if { $argc > 0 } {
    set tb_name [lindex $argv 0]
}

puts "==> Running simulation for: $tb_name"
puts "==> Project Root: $project_root"

# Create in-memory project
create_project -in_memory -part xc7a100tcsg324-1

# Add RTL source files
add_files [glob -nocomplain "$project_root/src/aes/*.v"]
add_files [glob -nocomplain "$project_root/src/axi/*.v"]
add_files [glob -nocomplain "$project_root/src/top/*.v"]

# Add Simulation files
add_files -fileset sim_1 [glob -nocomplain "$project_root/tb/*.v"]

# Set top simulation module
set_property top $tb_name [get_filesets sim_1]

# Launch simulation
launch_simulation -simset sim_1 -mode behavioral
run all
close_sim
