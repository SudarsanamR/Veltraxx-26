## =============================================================================
## Digilent Nexys A7 FPGA Bitstream Flasher Script
## PS06 AES-128 AXI-MM Hardware Accelerator — VELTRAXX '26
## =============================================================================

set script_dir [file dirname [info script]]
set bitfile [file normalize "$script_dir/../outputs/nexys_a7_aes_demo.bit"]

if {![file exists $bitfile]} {
    puts "Error: Bitstream file $bitfile not found!"
    exit 1
}

puts "==> Connecting to Hardware Manager..."
open_hw_manager
connect_hw_server -allow_non_jtag
open_hw_target

set device [lindex [get_hw_devices xc7a100t_0] 0]
if {$device == ""} {
    set device [lindex [get_hw_devices] 0]
}

puts "==> Programming device $device with $bitfile..."
set_property PROGRAM.FILE $bitfile $device
program_hw_devices $device

puts "================================================================"
puts "  NEXYS A7 FPGA PROGRAMMED SUCCESSFULLY!"
puts "  Your AES Hardware Accelerator is LIVE and ready for demo!"
puts "================================================================"
close_hw_target
disconnect_hw_server
close_hw_manager
exit
