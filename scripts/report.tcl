# Vivado post-implementation reporting script
# Usage: vivado -mode batch -source scripts/report.tcl

set script_dir [file dirname [info script]]
set project_root [file normalize "$script_dir/.."]

set dcp_file "$project_root/outputs/post_route.dcp"
if {![file exists $dcp_file]} {
    set dcp_file "$project_root/outputs/post_synth.dcp"
}

if {[file exists $dcp_file]} {
    open_checkpoint $dcp_file
    report_utilization -file "$project_root/outputs/utilization_summary.rpt"
    report_timing_summary -file "$project_root/outputs/timing_summary.rpt"
    report_power -file "$project_root/outputs/power_summary.rpt"
    puts "==> Generated utilization, timing, and power reports in outputs/"
} else {
    puts "==> Error: No checkpoint found in outputs/"
}
