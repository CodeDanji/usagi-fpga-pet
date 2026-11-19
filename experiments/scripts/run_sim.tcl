# vivado -mode batch -source experiments/scripts/run_sim.tcl -tclargs card|display|conditioning
set root [file normalize [file join [file dirname [info script]] ..]]
if {[llength $argv] != 1 || [lindex $argv 0] ni {card display conditioning board camera}} {
    error "Select card, display, or conditioning"
}
set which [lindex $argv 0]
set build [file join $root build sim_$which]
file mkdir $build
create_project -force sim_$which $build -part xc7s75fgga484-1
set src [file join $root .. final.srcs sources_1 rtl]
set sources [glob [file join $src common *.sv] [file join $src vision *.sv] \
                  [file join $src display *.sv] [file join $src neuron *.sv] [file join $src board *.sv]]
add_files -norecurse $sources
add_files -norecurse [file join $root .. final.srcs sources_1 rom usagi_128x128.mem]
if {$which eq "conditioning"} {
    if {![file exists [file join $root results stimulus.mem]]} {
        error "Run model/reference.py first to generate stimulus.mem"
    }
    add_files -norecurse [file join $root .. final.srcs sources_1 rom conditioning_stimulus.mem]
    set tb tb_conditioning
} elseif {$which eq "camera"} {set tb tb_camera} elseif {$which eq "card"} {set tb tb_card_path} elseif {$which eq "board"} {
    add_files -norecurse [file join $root .. final.srcs sources_1 rom conditioning_stimulus.mem]
    set tb tb_board
} else {set tb tb_display}
add_files -fileset sim_1 -norecurse [file join $root .. final.srcs sim_1 new $tb.sv]
set_property top $tb [get_filesets sim_1]
set_property xsim.simulate.runtime all [get_filesets sim_1]
update_compile_order -fileset sources_1
launch_simulation
close_sim
set simdir [file join $build sim_$which.sim sim_1 behav xsim]
foreach name {conditioning_rtl.csv display_neutral.ppm display_happy.ppm} {
    if {[file exists [file join $simdir $name]]} {
        file copy -force [file join $simdir $name] [file join $root results $name]
    }
}
puts "Simulation output: $simdir"
close_project
