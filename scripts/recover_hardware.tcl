# Run in the SAME Vivado GUI that is using the board. Does not program FPGA.
# Rebuilds stale server/target/device objects after USB/power/server changes.
if {![info exists ::usagi_cable_serial]} {set ::usagi_cable_serial "13724327082d01"}
proc usagi_reconnect_hardware {} {
    open_hw_manager
    foreach server [get_hw_servers -quiet] {
        if {[string match *localhost:3121 $server] || [string match *127.0.0.1:3121 $server]} {
            current_hw_server $server
            foreach target [get_hw_targets -quiet] {
                if {[string match *$::usagi_cable_serial $target]} {catch {close_hw_target $target}}
            }
            catch {disconnect_hw_server $server}
        }
    }
    connect_hw_server -url localhost:3121
    set targets [get_hw_targets -quiet *$::usagi_cable_serial]
    if {[llength $targets]!=1} {
        error "Cable $::usagi_cable_serial not available. Check board power/JTAG USB; available targets: [get_hw_targets -quiet]"
    }
    set target [lindex $targets 0]
    current_hw_target $target
    # Use only a frequency explicitly advertised by this cable. A lock cannot
    # be fixed by clock changes; a supported lower rate helps marginal links.
    set rates {}
    catch {set rates [list_property_value PARAM.FREQUENCY $target]}
    set chosen 0
    foreach rate $rates {
        if {[string is integer -strict $rate] && $rate>0 && $rate<=1000000 && $rate>$chosen} {set chosen $rate}
    }
    if {$chosen>0} {set_property PARAM.FREQUENCY $chosen $target}
    if {[catch {open_hw_target $target} message options]} {
        error "Cannot open JTAG cable. Close competing Hardware Manager/Vitis sessions or restart local hw_server, then retry. Original: $message"
    }
    set devices [get_hw_devices -quiet -filter {PART =~ xc7s75*}]
    if {[llength $devices]!=1} {error "Expected one XC7S75 on cable $::usagi_cable_serial; got [get_hw_devices -quiet]"}
    set device [lindex $devices 0]
    current_hw_device $device
    # This bitstream contains no ILA/VIO. Do not attach stale .ltx/probe data.
    foreach property {PROBES.FILE FULL_PROBES.FILE} {
        if {[lsearch -exact [list_property $device] $property]>=0} {set_property $property {} $device}
    }
    refresh_hw_device -update_hw_probes false $device
    puts "USAGI HARDWARE READY: $device; cable=$::usagi_cable_serial"
    return $device
}
set ::usagi_hw_device [usagi_reconnect_hardware]
