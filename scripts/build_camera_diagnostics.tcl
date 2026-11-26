# Isolated build: never opens/saves final.xpr or overwrites the proven GUI BIT.
set root [file normalize [file join [file dirname [info script]] ..]]
set out [file join $root board vision_lab]
file mkdir $out
create_project -in_memory -part xc7s75fgga484-1
set_property XPM_LIBRARIES {XPM_CDC XPM_MEMORY XPM_FIFO} [current_project]
foreach folder {common display neuron vision board} {
    foreach src [glob [file join $root final.srcs sources_1 rtl $folder *.sv]] {read_verilog -sv $src}
}
read_xdc [file join $root final.srcs constrs_1 new hanback_lcd_pet.xdc]
cd [file join $root final.srcs sources_1 rom]
synth_design -top usagi_board_top -part xc7s75fgga484-1
opt_design
place_design
phys_opt_design
route_design
report_timing_summary -file [file join $out timing.rpt]
report_utilization -file [file join $out utilization.rpt]
report_drc -file [file join $out drc.rpt]
foreach delay_type {max min} {
    set worst [get_timing_paths -delay_type $delay_type -max_paths 1]
    if {[llength $worst] && [get_property SLACK $worst]<0} {error "Diagnostic $delay_type timing failed"}
}
write_bitstream -force [file join $out usagi_vision_lab.bit]
puts "CAMERA DIAGNOSTICS BUILD COMPLETE"
close_project
