# Read-only FPGA discovery. Explicitly releases cable before batch process exits.
set root [file normalize [file join [file dirname [info script]] ..]]
if {[catch {
    source [file join $root scripts recover_hardware.tcl]
    report_property -file [file join $root board results hardware_device.rpt] $::usagi_hw_device
    puts "HARDWARE CHECK PASSED"
} message options]} {
    catch {close_hw_target}
    catch {disconnect_hw_server}
    return -options $options $message
}
close_hw_target
disconnect_hw_server
