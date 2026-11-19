`timescale 1ns/1ps
module tb_card_path;
    reg clk=0,display_clk=0;
    always #5 clk=~clk;always #7 display_clk=~display_clk;
    reg rst=1,href=0,vsync=0;reg [7:0] data=0;
    wire fs,pv,bad;wire [15:0] pixel;wire [11:0] x,y;
    parallel_rgb565_rx rx(clk,rst,data,href,vsync,fs,pv,pixel,x,y,bad);
    wire valid,card,good;wire [19:0] yellow,total;wire [15:0] frame;
    card_detector #(.X0(4),.Y0(3),.ROI_W(8),.ROI_H(6)) detector(
        .clk(clk),.rst(rst),.frame_start(fs),.pixel_valid(pv),.frame_bad(bad),
        .pixel(pixel),.x(x),.y(y),.result_valid(valid),.card_present(card),
        .frame_good(good),.yellow_count(yellow),.roi_count(total),.frame_number(frame));
    wire busy,received;wire [57:0] payload;
    cdc_mailbox #(.WIDTH(58)) mailbox(clk,rst,valid,
        {frame,total,yellow,good,card},busy,display_clk,rst,received,payload);
    reg [57:0] expected;integer deliveries=0,pixels=0;
    reg synthetic_clk=0,synthetic_running=1,integration_done=0;
    always #4 if(synthetic_running) synthetic_clk=~synthetic_clk;
    wire [7:0] integrated_debug,ir,ig,ib;wire ide,ihs,ivs,idisp;
    card_pet_top #(.SYNTHETIC(1),.CAMERA_WIDTH(16),.CAMERA_HEIGHT(12),.STALE_FRAMES(2)) integrated(
        .reset(rst),.cam_pclk(synthetic_clk),.lcd_pclk(display_clk),
        .cam_data(8'h0),.cam_href(1'b0),.cam_vsync(1'b0),
        .lcd_r(ir),.lcd_g(ig),.lcd_b(ib),.lcd_de(ide),
        .lcd_hsync(ihs),.lcd_vsync(ivs),.lcd_disp(idisp),.debug(integrated_debug));
    initial begin
        wait(rst===0);
        wait(integrated_debug[1]===1);
        @(negedge synthetic_clk);synthetic_running=0;
        wait(integrated_debug[0]===0);
        if(integrated_debug[1]!==0) $fatal(1,"Stale camera left pet happy");
        synthetic_running=1;
        wait(integrated_debug[1]===1);
        integration_done=1;
    end
    always @(posedge clk) begin
        if(!rst && $isunknown({valid,card,good,yellow,total,frame}))
            $fatal(1,"Unknown detector output");
        if(!rst && valid && !busy) expected<={frame,total,yellow,good,card};
        if(!rst && pv) begin
            pixels=pixels+1;
            if(x>=16 || y>=12) $fatal(1,"Receiver coordinate overflow");
        end
    end
    always @(posedge display_clk) begin
        #1;
        if(!rst && received) begin
            if(payload!==expected) $fatal(1,"CDC payload torn or reordered");
            deliveries=deliveries+1;
        end
    end
    task send_frame(input [15:0] color,input integer odd_line,input integer lines);
        integer ix,iy;
        begin
            @(negedge clk);href=0;vsync=1;
            repeat(4) @(negedge clk);
            vsync=0;repeat(2) @(negedge clk);
            for(iy=0;iy<lines;iy=iy+1) begin
                for(ix=0;ix<16;ix=ix+1) begin
                    href=1;data=color[15:8];@(negedge clk);
                    if(!(odd_line && iy==4 && ix==15)) begin
                        data=color[7:0];@(negedge clk);
                    end
                end
                href=0;repeat(4) @(negedge clk);
            end
        end
    endtask
    initial begin
        repeat(5) @(negedge clk);rst=0;
        // Three complete yellow frames are required; no immediate trigger.
        send_frame(16'hffe0,0,12);
        send_frame(16'hffe0,0,12);
        if(card) $fatal(1,"Debounce triggered too early");
        send_frame(16'hffe0,0,12);
        if(card) $fatal(1,"Only two completed yellow frames");
        send_frame(16'hffe0,0,12);
        if(!card || !good || yellow!=48 || total!=48) $fatal(1,"Yellow card not detected");
        // A single control frame must not clear a stable card.
        send_frame(16'h001f,0,12);
        send_frame(16'h001f,0,12);
        if(!card) $fatal(1,"Single-frame dropout was not filtered");
        send_frame(16'h001f,0,12);
        send_frame(16'h001f,0,12);
        if(card || !good || yellow!=0) $fatal(1,"Blue control classified as yellow");
        // Restore yellow, then inject a malformed byte stream.
        repeat(4) send_frame(16'hffe0,0,12);
        if(!card) $fatal(1,"Card did not recover");
        send_frame(16'hffe0,1,12);
        send_frame(16'hffe0,0,12);
        if(good || card) $fatal(1,"Odd-byte frame was accepted");
        send_frame(16'hffe0,0,4);
        send_frame(16'hffe0,0,12);
        if(good || card) $fatal(1,"Incomplete ROI frame was accepted");
        repeat(20) @(negedge clk);
        if(deliveries<10 || pixels==0) $fatal(1,"Insufficient activity: deliveries=%0d pixels=%0d",deliveries,pixels);
        wait(integration_done);
        $display("PASS card path: RGB565, ROI, control, malformed/partial frames, CDC (%0d deliveries), synthetic integration, stopped-clock watchdog and recovery",deliveries);
        $finish;
    end
    initial begin #40000000;$fatal(1,"Timeout");end
endmodule
