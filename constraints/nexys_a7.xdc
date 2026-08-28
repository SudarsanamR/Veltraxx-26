## =============================================================================
## Nexys A7 (xc7a100tcsg324-1) Physical Constraints
## PS06 AES-128 AXI-MM Hardware Accelerator — VELTRAXX '26
## =============================================================================

## ─────────────────────────────────────────────────────────────────────────────
## System Clock: 100 MHz Oscillator on pin E3
## ─────────────────────────────────────────────────────────────────────────────
set_property -dict { PACKAGE_PIN E3   IOSTANDARD LVCMOS33 } [get_ports { s_axi_aclk }]
create_clock -period 10.000 -name sys_clk [get_ports { s_axi_aclk }]

## ─────────────────────────────────────────────────────────────────────────────
## Active-Low CPU Reset Button (Active-Low, directly connected to reset_n)
## ─────────────────────────────────────────────────────────────────────────────
set_property -dict { PACKAGE_PIN C12  IOSTANDARD LVCMOS33 } [get_ports { s_axi_aresetn }]

## ─────────────────────────────────────────────────────────────────────────────
## Configuration & Bitstream Settings
## ─────────────────────────────────────────────────────────────────────────────
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
set_property BITSTREAM.CONFIG.CONFIGRATE 33 [current_design]
set_property CONFIG_MODE SPIx4 [current_design]
