# Lecture PDF pages 5,8,11,15,76. Target xc7s75fgga484-1.
# MAIN_CLOCK1=G2 is ordinary I/O; T2 is the unusable N-side of an MRCC pair.
# Use the fixed G2 wiring and allow ONLY input-to-first-BUFG fabric routing.
# CLOCK SELECT switch MUST be F (50 MHz).
set_property PACKAGE_PIN G2 [get_ports MAIN_CLOCK1]
set_property IOSTANDARD LVCMOS33 [get_ports MAIN_CLOCK1]
create_clock -name main_clock -period 20.000 [get_ports MAIN_CLOCK1]
set_input_jitter main_clock 0.100
set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets -hier -filter {NAME =~ *clocks/reference_unbuffered}]

set_property -dict {PACKAGE_PIN Y6 IOSTANDARD LVCMOS33} [get_ports SW_A]
set_property -dict {PACKAGE_PIN V7 IOSTANDARD LVCMOS33} [get_ports SW_B]
set_property -dict {PACKAGE_PIN AB6 IOSTANDARD LVCMOS33} [get_ports SW_C]
set_property -dict {PACKAGE_PIN W8 IOSTANDARD LVCMOS33} [get_ports SW_H]
set_property -dict {PACKAGE_PIN AB3 IOSTANDARD LVCMOS33} [get_ports {DIPSW[0]}]
set_property -dict {PACKAGE_PIN AB4 IOSTANDARD LVCMOS33} [get_ports {DIPSW[1]}]
set_property -dict {PACKAGE_PIN Y4 IOSTANDARD LVCMOS33} [get_ports {DIPSW[2]}]
set_property -dict {PACKAGE_PIN Y5 IOSTANDARD LVCMOS33} [get_ports {DIPSW[3]}]
set_property -dict {PACKAGE_PIN W5 IOSTANDARD LVCMOS33} [get_ports {DIPSW[4]}]
# Camera manual photographed by user, pp.652-653: OV7670 module.
set_property -dict {PACKAGE_PIN C9 IOSTANDARD LVCMOS33} [get_ports {CAM_D[0]}]
set_property -dict {PACKAGE_PIN B8 IOSTANDARD LVCMOS33} [get_ports {CAM_D[1]}]
set_property -dict {PACKAGE_PIN C8 IOSTANDARD LVCMOS33} [get_ports {CAM_D[2]}]
set_property -dict {PACKAGE_PIN D8 IOSTANDARD LVCMOS33} [get_ports {CAM_D[3]}]
set_property -dict {PACKAGE_PIN E8 IOSTANDARD LVCMOS33} [get_ports {CAM_D[4]}]
set_property -dict {PACKAGE_PIN A7 IOSTANDARD LVCMOS33} [get_ports {CAM_D[5]}]
set_property -dict {PACKAGE_PIN B7 IOSTANDARD LVCMOS33} [get_ports {CAM_D[6]}]
set_property -dict {PACKAGE_PIN D7 IOSTANDARD LVCMOS33} [get_ports {CAM_D[7]}]
set_property -dict {PACKAGE_PIN D6 IOSTANDARD LVCMOS33} [get_ports CAM_HREF]
set_property -dict {PACKAGE_PIN C6 IOSTANDARD LVCMOS33} [get_ports CAM_PCLK]
set_property -dict {PACKAGE_PIN A9 IOSTANDARD LVCMOS33} [get_ports CAM_PWDN]
set_property -dict {PACKAGE_PIN B9 IOSTANDARD LVCMOS33} [get_ports CAM_RESET]
set_property -dict {PACKAGE_PIN A5 IOSTANDARD LVCMOS33} [get_ports CAM_SIOD]
set_property -dict {PACKAGE_PIN C5 IOSTANDARD LVCMOS33} [get_ports CAM_SIOC]
set_property -dict {PACKAGE_PIN F6 IOSTANDARD LVCMOS33} [get_ports CAM_VSYNC]
set_property -dict {PACKAGE_PIN A6 IOSTANDARD LVCMOS33} [get_ports CAM_XCLK]
set_property -dict {DRIVE 8 SLEW SLOW} [get_ports {CAM_XCLK CAM_RESET CAM_PWDN CAM_SIOC CAM_SIOD}]
# CLKRC=1, DBLV bypass: 12.5 MHz. Use 25 MHz for conservative input checks.
# Data/HREF/VSYNC change on the falling PCLK edge (OV7670 DS pp.6-9).
create_clock -name camera_pclk -period 40.000 [get_ports CAM_PCLK]
set_input_delay -clock camera_pclk -clock_fall -max 7.000 [get_ports {CAM_D[*] CAM_HREF CAM_VSYNC}]
set_input_delay -clock camera_pclk -clock_fall -min 0.000 [get_ports {CAM_D[*] CAM_HREF CAM_VSYNC}]
set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets cam_clk_unbuffered]
set_false_path -to [get_ports {CAM_SIOC CAM_RESET CAM_PWDN}]
set_false_path -from [get_ports CAM_SIOD] -to [get_pins -hier -regexp {.*camera_config/bus/sda_sync_reg\[0\]/D}]
set_false_path -to [get_ports CAM_SIOD]
set_property -dict {PACKAGE_PIN U5 IOSTANDARD LVCMOS33} [get_ports {LED[0]}]
set_property -dict {PACKAGE_PIN V1 IOSTANDARD LVCMOS33} [get_ports {LED[1]}]
set_property -dict {PACKAGE_PIN V4 IOSTANDARD LVCMOS33} [get_ports {LED[2]}]
set_property -dict {PACKAGE_PIN V5 IOSTANDARD LVCMOS33} [get_ports {LED[3]}]
set_property -dict {PACKAGE_PIN W1 IOSTANDARD LVCMOS33} [get_ports {LED[4]}]
set_property -dict {PACKAGE_PIN W2 IOSTANDARD LVCMOS33} [get_ports {LED[5]}]
set_property -dict {PACKAGE_PIN W3 IOSTANDARD LVCMOS33} [get_ports {LED[6]}]
set_property -dict {PACKAGE_PIN Y1 IOSTANDARD LVCMOS33} [get_ports {LED[7]}]
set_property -dict {PACKAGE_PIN G22 IOSTANDARD LVCMOS33} [get_ports {TLCD_B[0]}]
set_property -dict {PACKAGE_PIN H18 IOSTANDARD LVCMOS33} [get_ports {TLCD_B[1]}]
set_property -dict {PACKAGE_PIN H19 IOSTANDARD LVCMOS33} [get_ports {TLCD_B[2]}]
set_property -dict {PACKAGE_PIN H20 IOSTANDARD LVCMOS33} [get_ports {TLCD_B[3]}]
set_property -dict {PACKAGE_PIN H21 IOSTANDARD LVCMOS33} [get_ports {TLCD_B[4]}]
set_property -dict {PACKAGE_PIN J19 IOSTANDARD LVCMOS33} [get_ports {TLCD_B[5]}]
set_property -dict {PACKAGE_PIN J20 IOSTANDARD LVCMOS33} [get_ports {TLCD_B[6]}]
set_property -dict {PACKAGE_PIN J21 IOSTANDARD LVCMOS33} [get_ports {TLCD_B[7]}]
set_property -dict {PACKAGE_PIN E22 IOSTANDARD LVCMOS33} [get_ports {TLCD_G[0]}]
set_property -dict {PACKAGE_PIN F18 IOSTANDARD LVCMOS33} [get_ports {TLCD_G[1]}]
set_property -dict {PACKAGE_PIN F19 IOSTANDARD LVCMOS33} [get_ports {TLCD_G[2]}]
set_property -dict {PACKAGE_PIN F20 IOSTANDARD LVCMOS33} [get_ports {TLCD_G[3]}]
set_property -dict {PACKAGE_PIN F21 IOSTANDARD LVCMOS33} [get_ports {TLCD_G[4]}]
set_property -dict {PACKAGE_PIN F22 IOSTANDARD LVCMOS33} [get_ports {TLCD_G[5]}]
set_property -dict {PACKAGE_PIN G20 IOSTANDARD LVCMOS33} [get_ports {TLCD_G[6]}]
set_property -dict {PACKAGE_PIN G21 IOSTANDARD LVCMOS33} [get_ports {TLCD_G[7]}]
set_property -dict {PACKAGE_PIN B20 IOSTANDARD LVCMOS33} [get_ports {TLCD_R[0]}]
set_property -dict {PACKAGE_PIN B21 IOSTANDARD LVCMOS33} [get_ports {TLCD_R[1]}]
set_property -dict {PACKAGE_PIN B22 IOSTANDARD LVCMOS33} [get_ports {TLCD_R[2]}]
set_property -dict {PACKAGE_PIN C20 IOSTANDARD LVCMOS33} [get_ports {TLCD_R[3]}]
set_property -dict {PACKAGE_PIN C22 IOSTANDARD LVCMOS33} [get_ports {TLCD_R[4]}]
set_property -dict {PACKAGE_PIN D20 IOSTANDARD LVCMOS33} [get_ports {TLCD_R[5]}]
set_property -dict {PACKAGE_PIN D21 IOSTANDARD LVCMOS33} [get_ports {TLCD_R[6]}]
set_property -dict {PACKAGE_PIN D22 IOSTANDARD LVCMOS33} [get_ports {TLCD_R[7]}]
set_property -dict {PACKAGE_PIN J22 IOSTANDARD LVCMOS33} [get_ports TLCD_DCLK]
set_property -dict {PACKAGE_PIN L18 IOSTANDARD LVCMOS33} [get_ports TLCD_DEN]
set_property -dict {PACKAGE_PIN K18 IOSTANDARD LVCMOS33} [get_ports TLCD_DISP]
set_property -dict {PACKAGE_PIN K22 IOSTANDARD LVCMOS33} [get_ports TLCD_VSYNC]
set_property -dict {PACKAGE_PIN K19 IOSTANDARD LVCMOS33} [get_ports TLCD_HSYNC]
set_property DRIVE 8 [get_ports {LED[*] TLCD_*}]
set_property SLEW SLOW [get_ports {LED[*] TLCD_*}]
set_property IOB TRUE [get_ports {TLCD_R[*] TLCD_G[*] TLCD_B[*] TLCD_DEN TLCD_HSYNC TLCD_VSYNC}]

# Forwarded clock, falling-edge receiver; PDF p.75 specifies setup/hold 8 ns.
create_generated_clock -name lcd_forward -source [get_pins pixel_clock_forward/C] \
    -divide_by 1 [get_ports TLCD_DCLK]
set lcd_data [get_ports {TLCD_R[*] TLCD_G[*] TLCD_B[*] TLCD_DEN TLCD_HSYNC TLCD_VSYNC}]
set_output_delay -clock lcd_forward -clock_fall -max 8.000 $lcd_data
set_output_delay -clock lcd_forward -clock_fall -min -8.000 $lcd_data

# Asynchronous physical controls: only first metastability stage is excepted.
set_false_path -from [get_ports {SW_A SW_B SW_C DIPSW[*]}] \
    -to [get_pins -hier -regexp {.*input_meta_reg\[[0-7]\]/D}]
set_false_path -from [get_ports SW_H]
set_false_path -to [get_ports {LED[*] TLCD_DISP}]

# Bundled-data mailbox: hold payload until acknowledgement; constrain transfer.
set_false_path -to [get_pins -hier -regexp {.*ui_mailbox/(req_sync|ack_sync)_reg\[0\]/D}]
set_max_delay -datapath_only 25.0 \
    -from [get_cells -hier -filter {NAME =~ *ui_mailbox/held_reg*}] \
    -to [get_cells -hier -filter {NAME =~ *ui_mailbox/dst_data_reg*}]

# Additional CDC: sensor readiness, camera report and preview ownership handshake.
set_false_path -to [get_pins -hier -regexp {.*camera/config_sync_reg\[0\]/D}]
set_false_path -to [get_pins -hier -regexp {.*camera/camera_mailbox/(req_sync|ack_sync)_reg\[0\]/D}]
set_max_delay -datapath_only 25.0 \
    -from [get_cells -hier -filter {NAME =~ *camera/camera_mailbox/held_reg*}] \
    -to [get_cells -hier -filter {NAME =~ *camera/camera_mailbox/dst_data_reg*}]
set_false_path -to [get_pins -hier -regexp {.*camera/preview_(ack|req)_sync_reg\[0\]/D}]
set_max_delay -datapath_only 25.0 -from [get_cells -hier -filter {NAME =~ *camera/published_bank_reg}] \
    -to [get_cells -hier -filter {NAME =~ *camera/read_bank_reg}]

# Volatile JTAG configuration only. No configuration flash operation here.
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]
