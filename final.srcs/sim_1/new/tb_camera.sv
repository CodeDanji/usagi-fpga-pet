`timescale 1ns/1ps
// Behavioral sensor speaks SCCB on real wires; DVP is independently generated.
module tb_camera;
    localparam W=640,H=480;
    reg core_clk=0,pclk=0,pixel_clk=0,rst=1,pclk_run=1;
    always #20 core_clk=~core_clk;
    always #40 if(pclk_run) pclk=~pclk;
    always #15 pixel_clk=~pixel_clk;
    reg color_bars=0;
    tri1 sda;
    wire scl_low,sda_low,reset_n,ready,failed;
    wire scl=!scl_low;
    wire [15:0] sensor_id;wire [3:0] error_code;
    reg slave_low=0,absent=0,wrong_id=0;
    assign sda=sda_low?1'b0:1'bz;
    assign sda=slave_low?1'b0:1'bz;
    ov7670_config #(.QUARTER_CYCLES(8),.RESET_CYCLES(10),.SETTLE_CYCLES(20)) config_dut(
        .clk(core_clk),.rst(rst),.color_bars(color_bars),.sda_in(sda),
        .scl_low(scl_low),.sda_low(sda_low),.reset_n(reset_n),.ready(ready),
        .failed(failed),.sensor_id(sensor_id),.error_code(error_code));
    reg [7:0] registers[0:255];
    reg [7:0] slave_address,register_address,write_value;
    integer j,writes=0;
    task receive_byte(output reg [7:0] v);
        integer b;
        begin for(b=7;b>=0;b=b-1) begin @(posedge scl);v[b]=sda;end end
    endtask
    task acknowledge_byte;
        begin @(negedge scl);slave_low=!absent;@(posedge scl);@(negedge scl);slave_low=0;end
    endtask
    task wait_start;
        begin @(negedge sda);while(!scl) @(negedge sda);end
    endtask
    task wait_stop;
        begin @(posedge sda);while(!scl) @(posedge sda);end
    endtask
    task send_byte(input reg [7:0] v);
        integer b;
        begin
            for(b=7;b>=0;b=b-1) begin slave_low=!v[b];@(posedge scl);@(negedge scl);end
            slave_low=0;@(posedge scl);
            if(sda!==1'b1) $fatal(1,"SCCB read must end with master NACK");
            @(negedge scl);
        end
    endtask
    initial begin
        for(j=0;j<256;j=j+1) registers[j]=0;
        registers[8'h0a]=8'h76;registers[8'h0b]=8'h73;
        forever begin
            wait_start();receive_byte(slave_address);acknowledge_byte();
            if(slave_address==8'h42) begin
                receive_byte(register_address);acknowledge_byte();
                fork : write_or_stop
                    begin
                        receive_byte(write_value);acknowledge_byte();
                        if(!absent) begin registers[register_address]=write_value;writes=writes+1;end
                        wait_stop();
                    end
                    wait_stop();
                join_any
                disable write_or_stop;
            end else if(slave_address==8'h43) begin
                send_byte(absent?8'hff:((wrong_id && register_address==8'h0a)?8'h00:registers[register_address]));
                wait_stop();
            end else $fatal(1,"Unexpected SCCB address %h",slave_address);
        end
    end
    reg [7:0] data=0;reg href=0,vsync=0;
    wire online,card,good;wire [19:0] yellow;wire [15:0] frames;
    reg frame_tick=0,lcd_swap_enable=1;reg [11:0] lcd_x=24,lcd_y=80;
    wire [15:0] preview_pixel;wire preview_inside;
    camera_pipeline #(.WIDTH(W),.HEIGHT(H),.WATCHDOG_CYCLES(2000000)) path(
        .core_clk(core_clk),.core_rst(rst),.pclk(pclk),.cam_rst(rst),.configured(ready),
        .data(data),.href(href),.vsync(vsync),.online(online),.card(card),.good(good),
        .yellow(yellow),.frames(frames),.pixel_clk(pixel_clk),.pixel_rst(rst),
        .frame_tick(frame_tick),.lcd_x(lcd_x),.lcd_y(lcd_y),
        .preview_pixel(preview_pixel),.preview_inside(preview_inside));
    // Frequent LCD blanking boundaries allow ownership acknowledgements.
    integer lcd_cycle=0;
    always @(negedge pixel_clk) begin
        lcd_cycle=lcd_cycle+1;frame_tick=lcd_swap_enable && (lcd_cycle%100==0);
    end
    task cam_cycle(input reg [7:0] d,input reg h,input reg v);
        begin @(negedge pclk);data=d;href=h;vsync=v;end
    endtask
    task frame(input reg [15:0] color,input integer width);
        integer row,col;
        begin
            cam_cycle(0,0,1);repeat(4) cam_cycle(0,0,1);
            cam_cycle(0,0,0);
            for(row=0;row<H;row=row+1) begin
                for(col=0;col<width;col=col+1) begin
                    cam_cycle(color[15:8],1,0);cam_cycle(color[7:0],1,0);
                end
                repeat(4) cam_cycle(0,0,0);
            end
        end
    endtask
    task end_frame;
        begin cam_cycle(0,0,1);repeat(10) cam_cycle(0,0,1);#1000;end
    endtask
    initial begin
        #200;rst=0;
        wait(ready || failed);
        if(failed || sensor_id!=16'h7673 || writes<28 || registers[8'h40]!=8'hd0)
            $fatal(1,"Camera initialization/readback failed: id=%h error=%d writes=%d",sensor_id,error_code,writes);
        frame(16'hffe0,W);frame(16'hffe0,W);frame(16'hffe0,W);end_frame();
        if(!online || !good || !card || yellow!=W*H/4) $fatal(1,"Real DVP yellow card not detected");
        #10000;
        if(!preview_inside || preview_pixel!=16'hffe0) $fatal(1,"Preview bank/byte order failed %h",preview_pixel);
        lcd_x=24+W/2-1;lcd_y=80+H/2-1;#1000;
        if(!preview_inside || preview_pixel!=16'hffe0) $fatal(1,"Preview last pixel address failed");
        frame(16'h001f,W);frame(16'h001f,W);frame(16'h001f,W);end_frame();
        if(card || !good) $fatal(1,"Blue control incorrectly detected");
        #10000;
        if(preview_pixel!=16'h001f) $fatal(1,"Preview did not switch to blue frame");
        lcd_swap_enable=0;
        frame(16'hffe0,W);frame(16'hffe0,W);frame(16'hffe0,W);end_frame();
        if(preview_pixel!=16'h001f) $fatal(1,"Writer overwrote the displayed preview bank");
        lcd_swap_enable=1;#10000;
        if(preview_pixel!=16'hffe0) $fatal(1,"Published preview bank did not switch in blanking");
        frame(16'hffe0,W-1);end_frame();
        if(good || card) $fatal(1,"Short frame accepted");
        frame(16'hffe0,W);end_frame();pclk_run=0;#90000000;
        if(online || card || good) $fatal(1,"Stopped PCLK/frame watchdog did not clear state");
        pclk_run=1;
        color_bars=1;wait(!ready);wait(ready || failed);
        if(failed || registers[8'h42]!=8'h08) $fatal(1,"Sensor color-bar reconfiguration failed");
        wrong_id=1;color_bars=0;wait(!ready);wait(failed);
        if(error_code!=2) $fatal(1,"Wrong sensor ID accepted");
        absent=1;wrong_id=0;color_bars=1;wait(!failed);wait(failed);
        if(ready || error_code!=1) $fatal(1,"Missing camera was accepted");
        $display("PASS camera: SCCB writes/readback/NACK, ID rejection, missing sensor, VGA geometry, RGB565, card/control, preview ownership, watchdog, color bars");
        $finish;
    end
    initial begin #2000000000;$fatal(1,"Camera test timeout: config state=%d index=%d",config_dut.state,config_dut.index);end
endmodule
