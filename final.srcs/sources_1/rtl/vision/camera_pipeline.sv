// Full VGA frame validation, card detection and a coherent 160x120 preview.
// A published BRAM bank is frozen until the LCD changes banks in vertical blank.
module camera_pipeline #(
    parameter integer WIDTH=640,HEIGHT=480,
    parameter integer WATCHDOG_CYCLES=25000000
)(
    input wire core_clk,core_rst,pclk,cam_rst,configured,
    input wire [7:0] data,input wire href,vsync,
    output wire online,card,good,
    output reg [19:0] yellow,
    output reg [15:0] frames,
    input wire pixel_clk,pixel_rst,frame_tick,
    input wire [11:0] lcd_x,lcd_y,
    output wire [15:0] preview_pixel,
    output reg preview_inside
);
    localparam PW=WIDTH/4,PH=HEIGHT/4,WORDS=PW*PH;
    (* ASYNC_REG="TRUE" *) reg [1:0] config_sync;
    always @(posedge pclk) begin
        if(cam_rst) config_sync<=0;else config_sync<={config_sync[0],configured};
    end
    wire capture_rst=cam_rst || !config_sync[1];
    wire fs,pv,bad;wire [15:0] rgb;wire [11:0] x,y;
    parallel_rgb565_rx receiver(.pclk(pclk),.rst(capture_rst),.data(data),.href(href),.vsync(vsync),
        .frame_start(fs),.pixel_valid(pv),.pixel(rgb),.x(x),.y(y),.frame_bad(bad));
    reg [19:0] pixel_count;
    reg geometry_bad;
    reg [11:0] expected_x,expected_y;
    wire frame_ok=!bad && !geometry_bad && pixel_count==WIDTH*HEIGHT;
    always @(posedge pclk) begin
        if(capture_rst || fs) begin pixel_count<=0;geometry_bad<=0;expected_x<=0;expected_y<=0;end
        else if(pv) begin
            if(pixel_count!=20'hfffff) pixel_count<=pixel_count+1'b1;
            if(x!=expected_x || y!=expected_y || x>=WIDTH || y>=HEIGHT) geometry_bad<=1;
            if(expected_x==WIDTH-1) begin expected_x<=0;expected_y<=expected_y+1'b1;end
            else expected_x<=expected_x+1'b1;
        end
    end
    wire result,detected,complete;wire [19:0] yellow_cam,roi_cam;wire [15:0] frame_cam;
    card_detector #(.X0(WIDTH/4),.Y0(HEIGHT/4),.ROI_W(WIDTH/2),.ROI_H(HEIGHT/2)) detector(
        .clk(pclk),.rst(capture_rst),.frame_start(fs),.pixel_valid(pv),.frame_bad(!frame_ok),
        .pixel(rgb),.x(x),.y(y),.result_valid(result),.card_present(detected),
        .frame_good(complete),.yellow_count(yellow_cam),.roi_count(roi_cam),.frame_number(frame_cam));
    wire message,mail_busy;wire [37:0] report;
    // Reset the handshake only on the common board reset; sensor reconfiguration
    // stops publications rather than resetting just one half of the mailbox.
    cdc_mailbox #(.WIDTH(38)) camera_mailbox(
        .src_clk(pclk),.src_rst(cam_rst),.src_send(result),
        .src_data({frame_cam,yellow_cam,complete,detected}),.src_busy(mail_busy),
        .dst_clk(core_clk),.dst_rst(core_rst),.dst_valid(message),.dst_data(report));
    reg [24:0] age;
    reg card_hold,good_hold;
    assign online=configured && age<WATCHDOG_CYCLES;
    assign good=online && good_hold;
    assign card=good && card_hold;
    always @(posedge core_clk) begin
        if(core_rst) begin age<=WATCHDOG_CYCLES;card_hold<=0;good_hold<=0;yellow<=0;frames<=0;end
        else begin
            if(age<WATCHDOG_CYCLES) age<=age+1'b1;
            if(!configured) begin age<=WATCHDOG_CYCLES;card_hold<=0;good_hold<=0;end
            else if(message) begin
                age<=0;card_hold<=report[0];good_hold<=report[1];
                yellow<=report[21:2];frames<=report[37:22];
            end
        end
    end
    (* ram_style="block" *) reg [15:0] preview_memory[0:2*WORDS-1];
    reg write_bank,published_bank,request,capturing;
    reg acknowledge,read_bank,preview_valid;
    (* ASYNC_REG="TRUE" *) reg [1:0] preview_ack_sync,preview_req_sync;
    reg [19:0] sample_count;
    // Memory ports have no resets; only validity/control has reset.
    wire sample=pv && x<WIDTH && y<HEIGHT && x[1:0]==0 && y[1:0]==0;
    wire [15:0] write_addr=write_bank*WORDS+(y>>2)*PW+(x>>2);
    always @(posedge pclk)
        if(!capture_rst && capturing && sample) preview_memory[write_addr]<=rgb;
    always @(posedge pclk) begin
        if(cam_rst) begin
            write_bank<=1;published_bank<=0;request<=0;capturing<=0;
            preview_ack_sync<=0;sample_count<=0;
        end else begin
            preview_ack_sync<={preview_ack_sync[0],acknowledge};
            if(capture_rst) begin capturing<=0;sample_count<=0;end
            else if(fs) begin
                sample_count<=0;
                if(capturing && frame_ok && sample_count==WORDS) begin
                    published_bank<=write_bank;request<=~request;capturing<=0;
                end else if(request==preview_ack_sync[1]) begin
                    write_bank<=~published_bank;capturing<=1;
                end
            end else if(capturing && sample) sample_count<=sample_count+1'b1;
        end
    end
    wire inside_now=lcd_x>=24 && lcd_x<24+PW*2 && lcd_y>=80 && lcd_y<80+PH*2;
    wire [11:0] px=(lcd_x-24)>>1,py=(lcd_y-80)>>1;
    wire [15:0] read_addr=inside_now?(read_bank*WORDS+py*PW+px):0;
    reg [15:0] read_pixel;
    reg inside_d;
    // Two cycles match the Usagi sprite renderer. Geometry overlay is generated
    // downstream with the same latency, including its yellow ROI rectangle.
    reg [15:0] pixel_d;
    assign preview_pixel=pixel_d;
    always @(posedge pixel_clk) begin
        read_pixel<=preview_memory[read_addr];pixel_d<=read_pixel;
        inside_d<=inside_now && preview_valid;preview_inside<=inside_d;
        if(pixel_rst) begin
            preview_req_sync<=0;acknowledge<=0;read_bank<=0;preview_valid<=0;
            inside_d<=0;preview_inside<=0;
        end else begin
            preview_req_sync<={preview_req_sync[0],request};
            if(frame_tick && preview_req_sync[1]!=acknowledge) begin
                read_bank<=published_bank;preview_valid<=1;acknowledge<=preview_req_sync[1];
            end
        end
    end
endmodule
