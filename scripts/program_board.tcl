# Optional MANUAL action: source this in Vivado Tcl Console with powered board
# connected through JTAG. This programs volatile FPGA configuration, not flash.
set root [file normalize [file join [file dirname [info script]] ..]]
set bitfile [file join $root board usagi_camera_pet.bit]
if {![file exists $bitfile]} {error "Build the board bitstream first"}
source [file join $root scripts recover_hardware.tcl]
set target $::usagi_hw_device
current_hw_device $target
set_property PROGRAM.FILE $bitfile $target
program_hw_devices $target
refresh_hw_device -update_hw_probes false $target
puts "Programmed Usagi camera/LCD/learning experiment (volatile JTAG configuration)."
