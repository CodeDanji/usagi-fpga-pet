`timescale 1ns/1ps
module tb_conditioning;
    reg clk=0;always #5 clk=~clk;
    reg rst=1,step_en=0,learn_enable=0,card=0,control_card=0,food=0;
    wire pre_spike,control_spike,post_spike,clipped;
    wire signed [31:0] pre_v,pre_u,control_v,control_u,post_v,post_u;
    wire signed [31:0] weight,control_weight,syn_current;
    wire [11:0] pre_trace,control_trace;
    conditioning_top dut(.*);
    reg [3:0] stimulus[0:39599];
    integer f,i;
    reg signed [31:0] held_v,held_u,held_w;
    initial begin
        $readmemh("conditioning_stimulus.mem",stimulus);
        f=$fopen("conditioning_rtl.csv","w");
        if(!f) $fatal(1,"Cannot open RTL output");
        $fdisplay(f,"step,pre_v,pre_u,pre_spike,control_v,control_u,control_spike,post_v,post_u,post_spike,weight,control_weight,syn_current,pre_trace,control_trace,clipped");
        repeat(4) @(negedge clk);
        rst=0;
        for(i=0;i<39600;i=i+1) begin
            @(negedge clk);
            {learn_enable,food,control_card,card}=stimulus[i];step_en=1;
            @(posedge clk);#1;
            $fdisplay(f,"%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d",
                i,pre_v,pre_u,pre_spike,control_v,control_u,control_spike,
                post_v,post_u,post_spike,weight,control_weight,syn_current,
                pre_trace,control_trace,clipped);
            if(clipped) $fatal(1,"Numerical clipping at step %0d",i);
            if(weight<0 || weight>24*65536 || control_weight!=0)
                $fatal(1,"Weight bound/control isolation failed");
        end
        @(negedge clk);step_en=0;
        held_v=post_v;held_u=post_u;held_w=weight;
        repeat(4) begin
            @(posedge clk);#1;
            if(post_v!==held_v || post_u!==held_u || weight!==held_w)
                $fatal(1,"State changed with step_en disabled");
        end
        $fclose(f);$display("PASS conditioning: 39600 steps written");$finish;
    end
    initial begin #1000000;$fatal(1,"Timeout");end
endmodule
