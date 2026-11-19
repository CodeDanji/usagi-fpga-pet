// Provisional 800x480 timing. Must be replaced by verified panel timing.
module lcd_timing #(
    parameter integer H_ACTIVE=800,H_FRONT=40,H_SYNC=48,H_BACK=168,
    parameter integer V_ACTIVE=480,V_FRONT=13,V_SYNC=3,V_BACK=29,
    parameter bit HS_POL=0,VS_POL=0
)(
    input wire clk,rst, output wire [11:0] x,y,
    output wire de,hsync,vsync,frame_tick
);
    localparam integer HT=H_ACTIVE+H_FRONT+H_SYNC+H_BACK;
    localparam integer VT=V_ACTIVE+V_FRONT+V_SYNC+V_BACK;
    reg [11:0] h,v;
    assign x=h; assign y=v;
    assign de=!rst && h<H_ACTIVE && v<V_ACTIVE;
    assign hsync=(h>=H_ACTIVE+H_FRONT && h<H_ACTIVE+H_FRONT+H_SYNC)?HS_POL:!HS_POL;
    assign vsync=(v>=V_ACTIVE+V_FRONT && v<V_ACTIVE+V_FRONT+V_SYNC)?VS_POL:!VS_POL;
    assign frame_tick=!rst && h==0 && v==0;
    always @(posedge clk) begin
        if(rst) begin h<=0;v<=0;end
        else if(h==HT-1) begin h<=0;v<=(v==VT-1)?0:v+1'b1;end
        else h<=h+1'b1;
    end
endmodule
