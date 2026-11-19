// Hardware experiment runner. 25 MHz / 6250 = 4 kHz model steps.
// DIP auto runs the exact 39600-step stimulus used by reference.py.
module conditioning_demo #(
    parameter integer TICK_CYCLES=6250,
    parameter STIMULUS_FILE="conditioning_stimulus.mem"
)(
    input wire clk,rst,manual_card,manual_control,manual_food,
    input wire learning,auto_mode,
    output wire card_active,food_active,control_active,learn_active,
    output wire step_en,
    output wire [5:0] weight_integer,
    output wire expected_reaction,
    output reg clipped_sticky,
    output wire auto_done,
    output reg [15:0] spike_count
);
    reg [12:0] divider;
    assign step_en=divider==TICK_CYCLES-1;
    always @(posedge clk) begin
        if(rst) divider<=0;
        else if(step_en) divider<=0;
        else divider<=divider+1'b1;
    end
    (* rom_style="block" *) reg [3:0] stimulus[0:39599];
    initial $readmemh(STIMULUS_FILE,stimulus);
    reg [15:0] index;
    reg [3:0] flags;
    // Keep BRAM address/control logic behind a purely synchronous reset stage.
    // The domain reset asserts asynchronously; feeding it through a ROM address
    // mux can otherwise trigger REQP-1839 after synthesis retiming/absorption.
    reg memory_reset=1'b1;
    always @(posedge clk) memory_reset<=rst;
    always @(posedge clk) begin
        flags<=stimulus[index];
        if(memory_reset || !auto_mode) index<=0;
        else if(step_en && index<39599) index<=index+1'b1;
    end
    assign auto_done=auto_mode && index==39599;
    assign card_active=auto_mode?flags[0]:manual_card;
    assign control_active=auto_mode?flags[1]:manual_control;
    assign food_active=auto_mode?flags[2]:manual_food;
    assign learn_active=learning && (!auto_mode || flags[3]);
    wire pre_spike,control_spike,post_spike,clipped;
    wire signed [31:0] pre_v,pre_u,control_v,control_u,post_v,post_u;
    wire signed [31:0] weight,control_weight,syn_current;
    wire [11:0] pre_trace,control_trace;
    conditioning_top brain(
        .clk(clk),.rst(rst),.step_en(step_en),.learn_enable(learn_active),
        .card(card_active),.control_card(control_active),.food(food_active),
        .pre_spike(pre_spike),.control_spike(control_spike),.post_spike(post_spike),
        .clipped(clipped),.pre_v(pre_v),.pre_u(pre_u),.control_v(control_v),
        .control_u(control_u),.post_v(post_v),.post_u(post_u),.weight(weight),
        .control_weight(control_weight),.syn_current(syn_current),
        .pre_trace(pre_trace),.control_trace(control_trace));
    assign weight_integer=weight[21:16];
    reg [9:0] reaction_timer;
    assign expected_reaction=reaction_timer!=0;
    always @(posedge clk) begin
        if(rst) begin reaction_timer<=0;spike_count<=0;clipped_sticky<=0;end
        else if(step_en) begin
            if(clipped) clipped_sticky<=1;
            if(post_spike) begin reaction_timer<=800;spike_count<=spike_count+1'b1;end
            else if(reaction_timer!=0) reaction_timer<=reaction_timer-1'b1;
        end
    end
endmodule
