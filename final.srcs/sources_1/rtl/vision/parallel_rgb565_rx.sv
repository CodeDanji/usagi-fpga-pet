// Provisional sensor contract: 8-bit DVP, RGB565 MSB byte first,
// active-high HREF, active-high VSYNC blanking, sample on PCLK rising edge.
// Not a sensor initializer. A real sensor must be configured to this contract.
module parallel_rgb565_rx(
    input wire pclk, rst, input wire [7:0] data,
    input wire href, vsync,
    output reg frame_start, pixel_valid,
    output reg [15:0] pixel, output reg [11:0] x,y,
    output reg frame_bad
);
    reg vs_d, href_d, half_byte;
    reg [7:0] first_byte;
    reg [11:0] col, row;
    always @(posedge pclk) begin
        if(rst) begin
            vs_d<=0; href_d<=0; half_byte<=0; first_byte<=0;
            frame_start<=0; pixel_valid<=0; pixel<=0;
            col<=0; row<=0; x<=0; y<=0; frame_bad<=0;
        end else begin
            vs_d<=vsync; href_d<=href;
            frame_start<=0; pixel_valid<=0;
            if(vsync && !vs_d) begin
                frame_start<=1; col<=0; row<=0; half_byte<=0;
                // frame_bad is consumed with frame_start one cycle later.
            end else if(vsync) begin
                frame_bad<=0; half_byte<=0;
            end else if(href) begin
                if(!half_byte) begin first_byte<=data; half_byte<=1; end
                else begin
                    pixel<={first_byte,data}; x<=col; y<=row;
                    pixel_valid<=1; half_byte<=0;
                    if(col==4095) frame_bad<=1;
                    else col<=col+1'b1;
                end
            end else if(href_d) begin
                if(half_byte) frame_bad<=1;
                half_byte<=0; col<=0;
                if(row==4095) frame_bad<=1;
                else row<=row+1'b1;
            end
        end
    end
endmodule
