# Out-of-context resource/clock feasibility; no board pin or bitstream claims.
# vivado -mode batch -source experiments/scripts/synthesize.tcl -tclargs card|conditioning
set root [file normalize [file join [file dirname [info script]] ..]]
if {[llength $argv]!=1 || [lindex $argv 0] ni {card conditioning}} {
    error "Select card or conditioning"
}
set which [lindex $argv 0]
set build [file join $root build synth_$which]
file mkdir $build
create_project -in_memory -part xc7s75fgga484-1
set rtl [file join $root .. final.srcs sources_1 rtl]
foreach src [glob [file join $rtl common *.sv] [file join $rtl vision *.sv] \
                  [file join $rtl display *.sv] [file join $rtl neuron *.sv]] {
    read_verilog -sv $src
}
# $readmemh resolves relative to the working directory during synthesis.
cd [file join $root .. final.srcs sources_1 rom]
if {$which eq "card"} {
    # Real capture path must survive synthesis; synthetic-only input could hide defects.
    synth_design -top card_pet_top -part xc7s75fgga484-1 -mode out_of_context -generic SYNTHETIC=0
    create_clock -name camera -period 41.667 [get_ports cam_pclk]
    create_clock -name lcd -period 30.000 [get_ports lcd_pclk]
    # Bundled-data crossing: synchronize controls; constrain held payload delay.
    set req_d [get_pins -hier -regexp {.*mailbox/req_sync_reg\[0\]/D}]
    set ack_d [get_pins -hier -regexp {.*mailbox/ack_sync_reg\[0\]/D}]
    if {[llength $req_d]!=1 || [llength $ack_d]!=1} {error "CDC control endpoints not found"}
    set_false_path -to $req_d
    set_false_path -to $ack_d
    set_max_delay -datapath_only 25 -from [get_cells -hier -filter {NAME =~ *mailbox/held_reg*}] \
        -to [get_cells -hier -filter {NAME =~ *mailbox/dst_data_reg*}]
} else {
    synth_design -top conditioning_top -part xc7s75fgga484-1 -mode out_of_context
    # 50 MHz one-step combinational update missed timing (WNS -9.028 ns).
    # Model needs only 4 kHz updates; use a 25 MHz core, 6250 cycles/step.
    create_clock -name core -period 40.000 [get_ports clk]
}
report_utilization -file [file join $root results ${which}_utilization.rpt]
report_timing_summary -file [file join $root results ${which}_synth_timing.rpt]
write_checkpoint -force [file join $build ${which}_synth.dcp]
puts "Out-of-context synthesis completed; timing is pre-route only."
