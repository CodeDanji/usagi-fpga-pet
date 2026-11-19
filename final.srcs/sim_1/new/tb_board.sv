`timescale 1ns/1ps
module tb_board;
    reg MAIN_CLOCK1=0;
    always #10 MAIN_CLOCK1=~MAIN_CLOCK1;
    reg SW_A=0,SW_B=0,SW_C=0,SW_H=1;
    reg [4:0] DIPSW=0;
    reg [7:0] CAM_D=0;
    reg CAM_PCLK=0,CAM_HREF=0,CAM_VSYNC=0;
    always #40 CAM_PCLK=~CAM_PCLK;
    tri1 CAM_SIOD;
    wire CAM_SIOC,CAM_XCLK,CAM_RESET,CAM_PWDN;
    wire [7:0] LED,TLCD_R,TLCD_G,TLCD_B;
    wire TLCD_DCLK,TLCD_DEN,TLCD_DISP,TLCD_HSYNC,TLCD_VSYNC;
    usagi_board_top #(.TICK_CYCLES(2)) dut(.*);
    integer baseline;
    task steps(input integer n);
        integer i;
        begin
            for(i=0;i<n;i=i+1) begin
                @(posedge dut.core_clk);
                while(!dut.step_en) @(posedge dut.core_clk);
                @(negedge dut.core_clk);
            end
        end
    endtask
    initial begin
        #200;SW_H=0;
        wait(LED[0]===1);#2000;
        if(!TLCD_DISP) $fatal(1,"Panel display enable did not start");
        SW_A=1;#2000;
        if(!dut.happy) $fatal(1,"Manual card did not change expression");
        SW_A=0;#2000;
        if(dut.happy) $fatal(1,"Manual release did not restore expression");
        DIPSW=3'b111;
        wait(dut.auto_done===1);#1000;
        if(dut.weight!=24 || dut.clipped) $fatal(1,"Hardware protocol did not train");
        // Frozen learned weights; remove automatic input, allow decay.
        DIPSW=3'b001;steps(2500);
        baseline=dut.spike_count;
        SW_C=1;steps(800);SW_C=0;
        if(dut.spike_count!=baseline) $fatal(1,"Untrained control elicited spikes");
        steps(2400);baseline=dut.spike_count;
        SW_A=1;steps(800);SW_A=0;
        if(dut.spike_count<=baseline || dut.weight!=24)
            $fatal(1,"Learned card failed or frozen weights changed");
        SW_H=1;#200;SW_H=0;wait(LED[0]===1);#2000;
        if(dut.weight!=0) $fatal(1,"Board reset did not clear learning");
        $display("PASS board: MMCM, reset, buttons, ROM protocol, learning, control, frozen weights, LCD enable");
        $finish;
    end
    initial begin #10000000;$fatal(1,"Board test timeout");end
endmodule
