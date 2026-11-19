set root [file normalize [file join [file dirname [info script]] ..]]
set action [lindex $argv 0]
if {$action ni {setup build implement simulate}} {error "Choose setup, build, implement, or simulate"}
open_project [file join $root final.xpr]
source [file join $root scripts register_project.tcl]
puts "PROJECT TOP: [get_property top [get_filesets sources_1]]"
puts "REGISTERED SOURCE FILES: [llength [get_files -of_objects [get_filesets sources_1]]]"
puts "REGISTERED CONSTRAINTS: [llength [get_files -of_objects [get_filesets constrs_1]]]"
if {$action eq "simulate"} {
    launch_simulation
    close_sim
} elseif {$action in {build implement}} {
    # Direct in-process implementation avoids the WSH child-run launcher on
    # restricted Windows hosts. Same sources/XDC as normal Vivado project runs.
    close_project
    if {$action eq "implement"} {
        open_checkpoint [file join $root board results board_synth.dcp]
        read_xdc [file join $root final.srcs constrs_1 new hanback_lcd_pet.xdc]
    } else {
        create_project -in_memory -part xc7s75fgga484-1
        foreach folder {common display neuron vision board} {
            foreach src [glob [file join $rtl $folder *.sv]] {read_verilog -sv $src}
        }
        read_xdc [file join $root final.srcs constrs_1 new hanback_lcd_pet.xdc]
        cd [file join $root final.srcs sources_1 rom]
        synth_design -top usagi_board_top -part xc7s75fgga484-1
        write_checkpoint -force [file join $root board results board_synth.dcp]
    }
    opt_design
    place_design
    phys_opt_design
    route_design
    write_checkpoint -force [file join $root board results board_routed.dcp]
    report_timing_summary -file [file join $root board results routed_timing.rpt]
    report_utilization -file [file join $root board results routed_utilization.rpt]
    report_drc -file [file join $root board results routed_drc.rpt]
    foreach delay_type {max min} {
        set worst [get_timing_paths -delay_type $delay_type -max_paths 1]
        if {[llength $worst] && [get_property SLACK $worst]<0} {
            error "Routed $delay_type timing failed"
        }
    }
    report_cdc -file [file join $root board results routed_cdc.rpt]
    write_bitstream -force [file join $root board usagi_camera_pet.bit]
}
close_project
puts "BOARD [string toupper $action] COMPLETE"
