# OpenSTA script for the tiny example.
# This follows the style of upstream OpenSTA examples:
#   read_liberty -> read_verilog -> link_design -> read_sdc -> report_checks

set top tiny

# The Makefile runs OpenSTA with PDK_ROOT=/pdk when mounted.
if {![info exists ::env(PDK_ROOT)]} {
  puts "Error: PDK_ROOT is not set (expected via Docker mount)."
  exit 1
}

# Liberty selection: use the typical-corner Sky130A HD library.
set lib "$::env(PDK_ROOT)/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib"
if {![file exists $lib]} {
  puts "Error: Sky130 liberty not found: $lib"
  puts "Hint: run 'make pdk-sky130' in the example directory first."
  exit 1
}
set netlist "/work/scratch/${top}_netlist.v"
set sdc "/work/${top}.sdc"

read_liberty $lib
read_verilog $netlist
link_design $top

if {![file exists $sdc]} {
  puts "Error: SDC not found: $sdc"
  exit 1
}
read_sdc $sdc

check_setup

puts "\n=== Worst setup paths ==="
report_checks -path_delay max -fields {slew cap input_pins} -digits 3

puts "\n=== Worst hold paths ==="
report_checks -path_delay min -fields {slew cap input_pins} -digits 3

puts "\n=== Summary ==="
report_tns
report_wns
