module usagi_display #(
    parameter SPRITE_FILE="usagi_128x128.mem",
    parameter integer SPRITE_X=272,SPRITE_Y=80,SCALE=2
)(
    input wire clk,rst, input wire [11:0] x,y,
    input wire de_in,hs_in,vs_in,
    input wire happy,live,good,
    input wire [19:0] yellow_count,
    input wire [15:0] frame_number,
    output reg [7:0] r,g,b, output reg de,hs,vs
);
    // Two 128x128 4-bit frames: curious and happy. 16 KiB synchronous ROM.
    (* rom_style="block" *) reg [3:0] sprite[0:32767];
    initial $readmemh(SPRITE_FILE,sprite);
    wire inside_sprite=x>=SPRITE_X && x<SPRITE_X+128*SCALE &&
                       y>=SPRITE_Y && y<SPRITE_Y+128*SCALE;
    wire [6:0] sx=(x-SPRITE_X)/SCALE,sy=(y-SPRITE_Y)/SCALE;
    wire [14:0] addr={happy,sy,sx};
    reg [3:0] index;
    // ROM data itself needs no reset. Keep the BRAM read port running; reset
    // only downstream valid/control registers, avoiding async reset on BRAM.
    always @(posedge clk) index<=sprite[addr];
    reg sprite_d,de_d,hs_d,vs_d;
    reg [23:0] bg_d;
    reg [23:0] bg,palette;
    integer bit_index;
    always @* begin
        bg=24'h182334;
        if(x<4 || x>=796 || y<4 || y>=476) bg=24'h52627a;
        // Top status: live stream / complete ROI / detected card.
        if(y>=20 && y<44) begin
            if(x>=24 && x<104) bg=live?24'h36c878:24'hcc4050;
            if(x>=120 && x<200) bg=good?24'h36c878:24'hcc4050;
            if(x>=216 && x<296) bg=happy?24'hffda30:24'h52627a;
        end
        // Raw yellow count bar, 32 pixels per unit of horizontal extent.
        if(y>=360 && y<380 && x>=80 && x<720)
            bg=((x-80)*32<yellow_count)?24'hffda30:24'h344359;
        // Binary frame number; LSB on left. Useful without a text renderer.
        bit_index=(x-80)/24;
        if(y>=408 && y<424 && x>=80 && x<464)
            bg=frame_number[bit_index]?24'h76baff:24'h344359;
        case(index)
            1:palette=24'hf8e6a0;
            2:palette=24'h302c27;
            3:palette=24'hf2a6ac;
            4:palette=24'hfff7d5;
            5:palette=24'he5c978;
            6:palette=24'hb59d66;
            7:palette=24'hf2acb0;
            8:palette=24'he99aa5;
            9:palette=24'hfffff7;
            10:palette=24'hf3d88f;
            11:palette=24'he0a8a0;
            12:palette=24'h6e5f45;
            13:palette=24'hd0be86;
            14:palette=24'hf9ccbc;
            15:palette=24'hfceeb7;
            default:palette=bg_d;
        endcase
    end
    always @(posedge clk) begin
        if(rst) begin
            sprite_d<=0;de_d<=0;hs_d<=1;vs_d<=1;bg_d<=0;
            r<=0;g<=0;b<=0;de<=0;hs<=1;vs<=1;
        end else begin
            sprite_d<=inside_sprite;
            bg_d<=bg;de_d<=de_in;hs_d<=hs_in;vs_d<=vs_in;
            {r,g,b}<=de_d?((sprite_d && index!=0)?palette:bg_d):24'h0;
            de<=de_d;hs<=hs_d;vs<=vs_d;
        end
    end
endmodule
