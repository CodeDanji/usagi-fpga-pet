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
    output reg [12:0] motion_count,
    output wire motion,motion_ready,
    input wire command_valid,input wire [1:0] command,
    output wire [40:0] analysis,
    output wire [255:0] shape_mask,
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
    // Compare one luminance sample per 4x4 block against the previous frame.
    // Only the central ROI contributes: 80x60 = 4800 samples at VGA.
    localparam MOTION_AREA=(WIDTH/8)*(HEIGHT/8);
    (* ram_style="block" *) reg [7:0] previous_luma[0:WORDS-1];
    wire motion_sample=pv && x<WIDTH && y<HEIGHT && x[1:0]==0 && y[1:0]==0;
    wire [14:0] motion_addr=(y>>2)*PW+(x>>2);
    wire [7:0] luma={2'b0,rgb[15:11],1'b0}+{1'b0,rgb[10:5],1'b0}+{2'b0,rgb[4:0],1'b0};
    reg [7:0] old_luma,new_luma;
    reg compare_pending,roi_pending,previous_valid;
    reg [12:0] motion_acc,motion_result;
    reg motion_result_valid;
    wire [7:0] difference=old_luma>new_luma?old_luma-new_luma:new_luma-old_luma;
    always @(posedge pclk) begin
        if(motion_sample && !capture_rst) begin
            old_luma<=previous_luma[motion_addr];
            previous_luma[motion_addr]<=luma;
        end
    end
    always @(posedge pclk) begin
        if(capture_rst) begin
            compare_pending<=0;roi_pending<=0;previous_valid<=0;
            motion_acc<=0;motion_result<=0;motion_result_valid<=0;
        end else begin
            compare_pending<=motion_sample;
            new_luma<=luma;
            roi_pending<=x>=WIDTH/4 && x<3*WIDTH/4 && y>=HEIGHT/4 && y<3*HEIGHT/4;
            if(fs) begin
                motion_result<=motion_acc;
                motion_result_valid<=frame_ok && previous_valid;
                previous_valid<=frame_ok;
                motion_acc<=0;
            end else if(compare_pending && roi_pending && previous_valid && difference>=24)
                motion_acc<=motion_acc+1'b1;
        end
    end
    wire diag_command_valid,command_busy;wire [1:0] diag_command;
    cdc_mailbox #(.WIDTH(2)) command_mailbox(
        .src_clk(core_clk),.src_rst(core_rst),.src_send(command_valid),.src_data(command),.src_busy(command_busy),
        .dst_clk(pclk),.dst_rst(cam_rst),.dst_valid(diag_command_valid),.dst_data(diag_command));
    wire [40:0] analysis_cam;
    wire [255:0] shape_mask_cam;
    vision_diagnostics #(.WIDTH(WIDTH),.HEIGHT(HEIGHT)) diagnostics(
        .clk(pclk),.rst(capture_rst),.frame_start(fs),.pixel_valid(pv),.frame_good(frame_ok),
        .pixel(rgb),.x(x),.y(y),.command_valid(diag_command_valid),.command(diag_command),.report(analysis_cam),.silhouette_frame(shape_mask_cam));
    wire message,mail_busy;wire [348:0] report;
    // Reset the handshake only on the common board reset; sensor reconfiguration
    // stops publications rather than resetting just one half of the mailbox.
    cdc_mailbox #(.WIDTH(349)) camera_mailbox(
        .src_clk(pclk),.src_rst(cam_rst),.src_send(result),
        .src_data({shape_mask_cam,analysis_cam,motion_result_valid,motion_result,frame_cam,yellow_cam,complete,detected}),.src_busy(mail_busy),
        .dst_clk(core_clk),.dst_rst(core_rst),.dst_valid(message),.dst_data(report));
    reg [24:0] age;
    reg card_hold,good_hold,motion_valid_hold;
    reg [40:0] analysis_hold;
    reg [255:0] shape_mask_hold;
    assign analysis=good?analysis_hold:41'd0;
    assign shape_mask=good?shape_mask_hold:256'd0;
    assign online=configured && age<WATCHDOG_CYCLES;
    assign good=online && good_hold;
    assign card=good && card_hold;
    assign motion_ready=good && motion_valid_hold;
    assign motion=motion_ready && motion_count*100>=MOTION_AREA*5;
    always @(posedge core_clk) begin
        if(core_rst) begin age<=WATCHDOG_CYCLES;card_hold<=0;good_hold<=0;yellow<=0;frames<=0;motion_count<=0;motion_valid_hold<=0;analysis_hold<=0;shape_mask_hold<=0;end
        else begin
            if(age<WATCHDOG_CYCLES) age<=age+1'b1;
            if(!configured) begin age<=WATCHDOG_CYCLES;card_hold<=0;good_hold<=0;motion_valid_hold<=0;motion_count<=0;end
            else if(message) begin
                age<=0;card_hold<=report[0];good_hold<=report[1];
                yellow<=report[21:2];frames<=report[37:22];
                motion_count<=report[50:38];motion_valid_hold<=report[51];
                analysis_hold<=report[92:52];
                shape_mask_hold<=report[348:93];
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
