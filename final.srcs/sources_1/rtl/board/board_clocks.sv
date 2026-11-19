// Board CLOCK SELECT = F (50 MHz), MAIN_CLOCK1 on ordinary I/O G2.
// Fixed lecture-board wiring requires a fabric segment to the first BUFG.
// MMCM VCO=1000 MHz: /30 = 33.333 MHz LCD; /40 = 25 MHz neuron/UI.
module board_clocks(
    input wire clock_50,reset,
    output wire pixel_clk,core_clk,locked
);
    wire feedback,feedback_buffer,pixel_unbuffered,core_unbuffered;
    wire reference_unbuffered,reference_global;
    IBUF reference_input(.I(clock_50),.O(reference_unbuffered));
    BUFG reference_buf(.I(reference_unbuffered),.O(reference_global));
    MMCME2_BASE #(
        .BANDWIDTH("OPTIMIZED"),.CLKIN1_PERIOD(20.0),
        .CLKFBOUT_MULT_F(20.0),.DIVCLK_DIVIDE(1),
        .CLKOUT0_DIVIDE_F(30.0),.CLKOUT1_DIVIDE(40),.STARTUP_WAIT("FALSE")
    ) mmcm (
        .CLKIN1(reference_global),.RST(reset),.PWRDWN(1'b0),
        .CLKFBIN(feedback_buffer),.CLKFBOUT(feedback),.CLKFBOUTB(),
        .CLKOUT0(pixel_unbuffered),.CLKOUT0B(),.CLKOUT1(core_unbuffered),.CLKOUT1B(),
        .CLKOUT2(),.CLKOUT2B(),.CLKOUT3(),.CLKOUT3B(),.CLKOUT4(),.CLKOUT5(),.CLKOUT6(),
        .LOCKED(locked)
    );
    BUFG fb_buf(.I(feedback),.O(feedback_buffer));
    BUFG pixel_buf(.I(pixel_unbuffered),.O(pixel_clk));
    BUFG core_buf(.I(core_unbuffered),.O(core_clk));
endmodule
