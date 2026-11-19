// Three neurons: trained-color input, control-color input, expectation output.
// Teacher-gated causal potentiation, NOT a claim of canonical pair-based STDP.
// Only food-associated postsynaptic spikes potentiate recently active inputs.
// No extinction, reward learning, or nonvolatile weight storage in this test.
module conditioning_top(
    input wire clk,rst,step_en,learn_enable,card,control_card,food,
    output wire pre_spike,control_spike,post_spike,clipped,
    output wire signed [31:0] pre_v,pre_u,control_v,control_u,post_v,post_u,
    output reg signed [31:0] weight,control_weight,syn_current,
    output reg [11:0] pre_trace,control_trace
);
    wire c0,c1,c2;
    wire signed [31:0] pre_i=card?32'sd1310720:32'sd0;
    wire signed [31:0] control_i=control_card?32'sd1310720:32'sd0;
    wire signed [31:0] post_i=syn_current+(food?32'sd1572864:32'sd0);
    izhikevich_q16 n0(clk,rst,step_en,pre_i,pre_v,pre_u,pre_spike,c0);
    izhikevich_q16 n1(clk,rst,step_en,control_i,control_v,control_u,control_spike,c1);
    izhikevich_q16 n2(clk,rst,step_en,post_i,post_v,post_u,post_spike,c2);
    assign clipped=c0|c1|c2;
    reg signed [63:0] syn_next;
    always @* begin
        syn_next=$signed(syn_current)-($signed(syn_current)>>>6);
        if(pre_spike) syn_next=syn_next+$signed(weight);
        if(control_spike) syn_next=syn_next+$signed(control_weight);
        if(syn_next>64*65536) syn_next=64*65536;
    end
    always @(posedge clk) begin
        if(rst) begin weight<=0;control_weight<=0;syn_current<=0;pre_trace<=0;control_trace<=0;end
        else if(step_en) begin
            syn_current<=syn_next[31:0];
            if(pre_spike) pre_trace<=2000;
            else if(pre_trace!=0) pre_trace<=pre_trace-1'b1;
            if(control_spike) control_trace<=2000;
            else if(control_trace!=0) control_trace<=control_trace-1'b1;
            if(learn_enable && food && post_spike) begin
                if((pre_trace!=0 || pre_spike) && weight<24*65536)
                    weight<=weight+65536;
                if((control_trace!=0 || control_spike) && control_weight<24*65536)
                    control_weight<=control_weight+65536;
            end
        end
    end
endmodule
