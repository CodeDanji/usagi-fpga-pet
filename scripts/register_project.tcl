# Run this in the currently open final project's Tcl Console to refresh Sources.
# Also used by project.tcl for batch setup. Paths stay relative in final.xpr.
set root [file normalize [file join [file dirname [info script]] ..]]
if {[llength [get_projects -quiet]]==0} {open_project [file join $root final.xpr]}
if {[get_property PART [current_project]] ne "xc7s75fgga484-1"} {
    error "Wrong project part; open final.xpr (xc7s75fgga484-1) first"
}
if {[file normalize [get_property DIRECTORY [current_project]]] ne $root} {
    error "Open this workspace's final.xpr before registering sources"
}
set rtl [file join $root final.srcs sources_1 rtl]
foreach folder {common display neuron vision board} {
    foreach src [glob [file join $rtl $folder *.sv]] {
        if {[llength [get_files -quiet $src]]==0} {add_files -norecurse -fileset sources_1 $src}
    }
}
foreach src [glob [file join $root final.srcs sources_1 rom *.mem]] {
    if {[llength [get_files -quiet $src]]==0} {add_files -norecurse -fileset sources_1 $src}
}
set_property file_type SystemVerilog [get_files *.sv]
set_property top usagi_board_top [get_filesets sources_1]
set_property top_auto_set 0 [get_filesets sources_1]
set_property target_language Verilog [current_project]
set_property simulator_language Mixed [current_project]
set xdc [file join $root final.srcs constrs_1 new hanback_lcd_pet.xdc]
if {[llength [get_files -quiet $xdc]]==0} {add_files -norecurse -fileset constrs_1 $xdc}
foreach {fileset top} {sim_1 tb_board sim_card tb_card_path sim_display tb_display sim_conditioning tb_conditioning sim_camera tb_camera} {
    if {[llength [get_filesets -quiet $fileset]]==0} {create_fileset -simset $fileset}
    set src [file join $root final.srcs sim_1 new $top.sv]
    if {[llength [get_files -quiet -of_objects [get_filesets $fileset] $src]]==0} {
        add_files -norecurse -fileset $fileset $src
    }
    set_property top $top [get_filesets $fileset]
    set_property xsim.simulate.runtime all [get_filesets $fileset]
}
current_fileset -simset [get_filesets sim_1]
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1
puts "Sources registered: top=usagi_board_top; camera/LCD constraints; 5 simulation filesets"
