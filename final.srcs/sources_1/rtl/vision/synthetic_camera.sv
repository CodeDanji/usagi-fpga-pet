// Produces the exact provisional DVP contract used by parallel_rgb565_rx.
// Yellow card for half of each 120-frame cycle; blue control otherwise.
module synthetic_camera #(parameter integer WIDTH=320, HEIGHT=240)(
    input wire clk,rst,
    output wire [7:0] data, output wire href,vsync
);
    localparam integer LINE_CYCLES=WIDTH*2+16;
    reg [15:0] cycle;
    reg [11:0] line;
    reg [6:0] frame;
    wire [11:0] px=cycle>>1;
    wire card=frame<60 && px>=WIDTH/4 && px<WIDTH*3/4 &&
              line>=HEIGHT/4 && line<HEIGHT*3/4;
    wire [15:0] color=card ? 16'hffe0 : 16'h001f;
    assign vsync=line>=HEIGHT;
    assign href=line<HEIGHT && cycle<WIDTH*2;
    assign data=cycle[0] ? color[7:0] : color[15:8];
    always @(posedge clk) begin
        if(rst) begin cycle<=0;line<=HEIGHT;frame<=0;end
        else if(cycle==LINE_CYCLES-1) begin
            cycle<=0;
            if(line==HEIGHT+3) begin
                line<=0;frame<=(frame==119)?0:frame+1'b1;
            end else line<=line+1'b1;
        end else cycle<=cycle+1'b1;
    end
endmodule
