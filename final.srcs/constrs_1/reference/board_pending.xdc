# DOCUMENTATION TEMPLATE ONLY. Not loaded by simulation/OOC synthesis scripts.
# Do not generate/program a bitstream until the actual board revision is verified.
# Project part: xc7s75fgga484-1. PDF has repeated pins across device sections.
#
# Required before a board build:
# - verified I/O bank voltages and IOSTANDARD
# - LCD panel model, full raster timings and sampling edge
# - camera model, DVP byte order, sync polarity, XCLK and SCCB initialization
# - actual camera/LCD clock generation and clock-capable input pins
# - external input/output delays from device timing specifications
# - common reset wiring and sensor startup sequence
#
# Candidate LCD pins from lecture p.76 (NOT validated for current module):
# lcd_b[0:7] : G22 H18 H19 H20 H21 J19 J20 J21
# lcd_g[0:7] : E22 F18 F19 F20 F21 F22 G20 G21
# lcd_r[0:7] : B20 B21 B22 C20 C22 D20 D21 D22
# panel DCLK: J22, DEN: L18, DISP: K18, VSYNC: K22, HSYNC: K19
# DCLK is an OUTPUT to the panel; card_pet_top.lcd_pclk is an INPUT clock.
# A board wrapper must forward the pixel clock with the verified phase/edge.
#
# Candidate clock pins p.5: G2/T2/T21/G21, but T2 also appears as SEG_SCAN0,
# T21 as AIC_DOUT, G21 as TLCD_G7. Resolve before assigning any package pins.
