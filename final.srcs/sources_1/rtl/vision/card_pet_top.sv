// Core with explicit camera and LCD clocks. No unverified board pin assignments.
// Real mode assumes an already configured sensor; no SCCB/I2C init is included.
module card_pet_top #(
    parameter bit SYNTHETIC=1,
    parameter integer CAMERA_WIDTH=320,CAMERA_HEIGHT=240,STALE_FRAMES=120,
    parameter SPRITE_FILE="usagi_128x128.mem"
)(
    input wire reset,cam_pclk,lcd_pclk,
    input wire [7:0] cam_data,input wire cam_href,cam_vsync,
    output wire [7:0] lcd_r,lcd_g,lcd_b,
    output wire lcd_de,lcd_hsync,lcd_vsync,lcd_disp,
    output wire [7:0] debug
);
    wire cr,lr;
    reset_sync rc(cam_pclk,reset,cr),rl(lcd_pclk,reset,lr);
    wire [7:0] data;wire href,vsync;
    generate if(SYNTHETIC) begin:gen_synthetic
        synthetic_camera #(.WIDTH(CAMERA_WIDTH),.HEIGHT(CAMERA_HEIGHT)) src(
            cam_pclk,cr,data,href,vsync);
    end else begin:gen_real
        assign data=cam_data;assign href=cam_href;assign vsync=cam_vsync;
    end endgenerate
    wire fs,pv,bad;wire [15:0] pixel;wire [11:0] px,py;
    parallel_rgb565_rx rx(cam_pclk,cr,data,href,vsync,fs,pv,pixel,px,py,bad);
    wire valid,present,good;wire [19:0] count,total;wire [15:0] number;
    card_detector #(.X0(CAMERA_WIDTH/4),.Y0(CAMERA_HEIGHT/4),
        .ROI_W(CAMERA_WIDTH/2),.ROI_H(CAMERA_HEIGHT/2)) detector(
        .clk(cam_pclk),.rst(cr),.frame_start(fs),.pixel_valid(pv),.frame_bad(bad),
        .pixel(pixel),.x(px),.y(py),.result_valid(valid),.card_present(present),
        .frame_good(good),.yellow_count(count),.roi_count(total),.frame_number(number));
    wire received,busy;wire [57:0] payload;
    cdc_mailbox #(.WIDTH(58)) mailbox(cam_pclk,cr,valid,
        {number,total,count,good,present},busy,lcd_pclk,lr,received,payload);
    wire [11:0] x,y;wire de,hs,vs,ft;
    lcd_timing timing(lcd_pclk,lr,x,y,de,hs,vs,ft);
    reg [7:0] age;reg card,quality;reg [19:0] yellow;reg [15:0] frame;
    wire live=age<STALE_FRAMES;
    always @(posedge lcd_pclk) begin
        if(lr) begin age<=255;card<=0;quality<=0;yellow<=0;frame<=0;end
        else if(received) begin
            age<=0;card<=payload[0];quality<=payload[1];
            yellow<=payload[21:2];frame<=payload[57:42];
        end else if(ft && age!=255) age<=age+1'b1;
    end
    usagi_display #(.SPRITE_FILE(SPRITE_FILE)) display(
        lcd_pclk,lr,x,y,de,hs,vs,card&&live,live,quality&&live,
        yellow,frame,lcd_r,lcd_g,lcd_b,lcd_de,lcd_hsync,lcd_vsync);
    assign lcd_disp=!lr;
    assign debug={frame[3:0],1'b0,quality&&live,card&&live,live};
endmodule
