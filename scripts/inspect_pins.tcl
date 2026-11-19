set root [file normalize [file join [file dirname [info script]] ..]]
create_project -in_memory -part xc7s75fgga484-1
read_verilog [file join $root scripts pin_probe.v]
synth_design -top pin_probe -part xc7s75fgga484-1
set f [open [file join $root board results package_pins.txt] w]
foreach p {C9 B8 C8 D8 E8 A7 B7 D7 D6 C6 A9 B9 A5 C5 F6 A6 G2 T2} {
    set pin [get_package_pins $p]
    if {[llength $pin]!=1} {puts $f "$p INVALID";continue}
    puts $f "$p [get_property PIN_FUNC $pin] bank=[get_property BANK $pin]"
}
close $f
puts "PIN INSPECTION COMPLETE"
