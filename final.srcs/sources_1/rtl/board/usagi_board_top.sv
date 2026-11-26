// One bitstream: OV7670, LCD, manual inputs and associative conditioning.
module usagi_board_top #(
    parameter integer TICK_CYCLES=6250,
    parameter bit LCD_SAMPLE_FALLING=1,
    parameter integer CAMERA_QUARTER=63,CAMERA_RESET=250000,CAMERA_SETTLE=7500000
)(
    input wire MAIN_CLOCK1,SW_A,SW_B,SW_C,SW_H,
    input wire [4:0] DIPSW,
    input wire [7:0] CAM_D,
    input wire CAM_PCLK,CAM_HREF,CAM_VSYNC,
    inout wire CAM_SIOD,
    output wire CAM_SIOC,CAM_XCLK,CAM_RESET,CAM_PWDN,
    output wire [7:0] LED,
    output reg [7:0] TLCD_R,TLCD_G,TLCD_B,
    output wire TLCD_DCLK,TLCD_DISP,
    output reg TLCD_DEN,TLCD_HSYNC,TLCD_VSYNC
);
    wire pixel_clk,core_clk,locked,pixel_rst,core_rst,reference_clk;
    board_clocks clocks(.clock_50(MAIN_CLOCK1),.reset(SW_H),
        .pixel_clk(pixel_clk),.core_clk(core_clk),.locked(locked),.reference_clk(reference_clk));
    wire reset_all=SW_H || !locked;
    reset_sync pixel_reset(pixel_clk,reset_all,pixel_rst);
    reset_sync core_reset(core_clk,reset_all,core_rst);
    (* ASYNC_REG="TRUE" *) reg [7:0] input_meta,input_sync;
    always @(posedge core_clk) begin
        if(core_rst) begin input_meta<=0;input_sync<=0;end
        else begin input_meta<={DIPSW,SW_C,SW_B,SW_A};input_sync<=input_meta;end
    end
    wire mode_neuron=input_sync[3];
    wire use_auto=mode_neuron && input_sync[5];
    wire camera_mode=input_sync[6];
    wire diagnostic_mode=camera_mode && !mode_neuron && input_sync[5];
    reg [2:0] previous_buttons;
    reg [18:0] command_cooldown;
    reg diagnostic_command_valid;reg [1:0] diagnostic_command;
    wire [2:0] button_edges=input_sync[2:0] & ~previous_buttons;
    always @(posedge core_clk) begin
        if(core_rst) begin previous_buttons<=0;command_cooldown<=0;diagnostic_command_valid<=0;diagnostic_command<=0;end
        else begin
            previous_buttons<=input_sync[2:0];diagnostic_command_valid<=0;
            if(command_cooldown!=0) command_cooldown<=command_cooldown-1'b1;
            else if(diagnostic_mode && |button_edges) begin
                diagnostic_command<=button_edges[2]?2'd3:(button_edges[1]?2'd2:2'd1);
                diagnostic_command_valid<=1;command_cooldown<=499999;
            end
        end
    end
    wire cam_clk_unbuffered,cam_clk,cam_rst;
    IBUF camera_input(.I(CAM_PCLK),.O(cam_clk_unbuffered));
    BUFG camera_buffer(.I(cam_clk_unbuffered),.O(cam_clk));
    reset_sync camera_reset(cam_clk,reset_all,cam_rst);
    wire scl_low,sda_low,sda_in,cam_ready,cam_failed;
    wire [15:0] cam_id;wire [3:0] cam_error;
    IOBUF camera_sda(.I(1'b0),.T(!sda_low),.O(sda_in),.IO(CAM_SIOD));
    // SIOC is a unidirectional, push-pull clock as on the module schematic.
    assign CAM_SIOC=!scl_low;
    assign CAM_PWDN=1'b0;
    ODDR #(.DDR_CLK_EDGE("SAME_EDGE"),.INIT(1'b0),.SRTYPE("ASYNC")) camera_clock_forward(
        .C(core_clk),.CE(1'b1),.D1(1'b1),.D2(1'b0),.R(core_rst),.S(1'b0),.Q(CAM_XCLK));
    ov7670_config #(.QUARTER_CYCLES(CAMERA_QUARTER),.RESET_CYCLES(CAMERA_RESET),
        .SETTLE_CYCLES(CAMERA_SETTLE)) camera_config(
        .clk(core_clk),.rst(core_rst),.color_bars(input_sync[7]),.sda_in(sda_in),
        .scl_low(scl_low),.sda_low(sda_low),.reset_n(CAM_RESET),.ready(cam_ready),
        .failed(cam_failed),.sensor_id(cam_id),.error_code(cam_error));
    wire cam_online,cam_card,cam_good;wire [19:0] cam_yellow;wire [15:0] cam_frames;
    wire cam_motion,cam_motion_ready;wire [12:0] cam_motion_count;
    wire [40:0] cam_analysis;
    wire [255:0] cam_shape_mask;
    wire [11:0] x,y;wire de,hs,vs,frame_tick;
    wire [15:0] preview_pixel;wire preview_inside;
    camera_pipeline camera(
        .core_clk(core_clk),.core_rst(core_rst),.pclk(cam_clk),.cam_rst(cam_rst),.configured(cam_ready),
        .data(CAM_D),.href(CAM_HREF),.vsync(CAM_VSYNC),.online(cam_online),
        .card(cam_card),.good(cam_good),.yellow(cam_yellow),.frames(cam_frames),
        .motion(cam_motion),.motion_ready(cam_motion_ready),.motion_count(cam_motion_count),
        .command_valid(diagnostic_command_valid),.command(diagnostic_command),.analysis(cam_analysis),
        .shape_mask(cam_shape_mask),
        .pixel_clk(pixel_clk),.pixel_rst(pixel_rst),.frame_tick(frame_tick),.lcd_x(x),.lcd_y(y),
        .preview_pixel(preview_pixel),.preview_inside(preview_inside));
    wire selected_card=camera_mode?cam_card:input_sync[0];
    wire card_active,food_active,control_active,learn_active,step_en;
    wire [5:0] weight;
    wire reaction,clipped,auto_done;
    wire [15:0] spike_count;
    conditioning_demo #(.TICK_CYCLES(TICK_CYCLES)) experiment(
        .clk(core_clk),.rst(core_rst),.manual_card(selected_card),
        .manual_food(input_sync[1]),.manual_control(input_sync[2]),
        .learning(mode_neuron && input_sync[4]),.auto_mode(use_auto),
        .card_active(card_active),.food_active(food_active),.control_active(control_active),
        .learn_active(learn_active),.step_en(step_en),.weight_integer(weight),
        .expected_reaction(reaction),.clipped_sticky(clipped),.auto_done(auto_done),
        .spike_count(spike_count));
    wire ui_happy=mode_neuron?reaction:(selected_card||input_sync[1]);
    wire ui_good=camera_mode?cam_good:!clipped;
    wire ui_live=camera_mode?cam_online:!core_rst;
    wire [19:0] ui_meter=mode_neuron?(weight*20'd800):
        (camera_mode?(cam_yellow>>2):(input_sync[0]?20'd19200:20'd0));
    wire [15:0] ui_number=mode_neuron?{spike_count[7:0],2'b0,weight}:cam_frames;
    wire mailbox_busy,received;wire [375:0] state;
    cdc_mailbox #(.WIDTH(376)) ui_mailbox(
        .src_clk(core_clk),.src_rst(core_rst),.src_send(step_en),
        .src_data({cam_shape_mask,diagnostic_mode,cam_analysis,(!mode_neuron && input_sync[4]),cam_motion_ready,cam_motion,cam_motion_count,camera_mode,cam_ready,cam_failed,cam_error,cam_id,ui_number,ui_meter,ui_live,ui_good,ui_happy}),.src_busy(mailbox_busy),
        .dst_clk(pixel_clk),.dst_rst(pixel_rst),.dst_valid(received),.dst_data(state));
    reg happy,good,live,show_camera,ready_display,failed_display;
    reg [19:0] meter;reg [15:0] number,id_display;reg [3:0] error_display;
    reg highlight_yellow,motion_ready_display,motion_display;reg [12:0] motion_meter;
    reg diagnostics_display;reg [40:0] analysis_display;
    reg [255:0] shape_mask_display;
    always @(posedge pixel_clk) begin
        if(pixel_rst) begin
            happy<=0;good<=1;live<=0;meter<=0;number<=0;show_camera<=0;
            ready_display<=0;failed_display<=0;id_display<=0;error_display<=0;
            highlight_yellow<=0;motion_ready_display<=0;motion_display<=0;motion_meter<=0;
            diagnostics_display<=0;analysis_display<=0;
            shape_mask_display<=0;
        end else if(received) begin
            happy<=state[0];good<=state[1];live<=state[2];meter<=state[22:3];number<=state[38:23];
            id_display<=state[54:39];error_display<=state[58:55];failed_display<=state[59];
            ready_display<=state[60];show_camera<=state[61];
            motion_meter<=state[74:62];motion_display<=state[75];
            motion_ready_display<=state[76];highlight_yellow<=state[77];
            analysis_display<=state[118:78];diagnostics_display<=state[119];
            shape_mask_display<=state[375:120];
        end
    end
    lcd_timing raster(.clk(pixel_clk),.rst(pixel_rst),.x(x),.y(y),
        .de(de),.hsync(hs),.vsync(vs),.frame_tick(frame_tick));
    wire [7:0] base_r,base_g,base_b;wire base_de,base_hs,base_vs;
    usagi_display #(.SPRITE_X(480)) display(.clk(pixel_clk),.rst(pixel_rst),.x(x),.y(y),
        .de_in(de),.hs_in(hs),.vs_in(vs),.happy(happy),.live(live),.good(good),
        .yellow_count(meter),.frame_number(number),.r(base_r),.g(base_g),.b(base_b),
        .de(base_de),.hs(base_hs),.vs(base_vs));
    // Diagnostics above the preview: config green / startup amber / error red.
    // ID and error bits below it are LSB-first, matching the existing counters.
    wire roi_border=((x==104 || x==263) && y>=140 && y<260) ||
                    ((y==140 || y==259) && x>=104 && x<264);
    reg [23:0] overlay_color,overlay_d,overlay_dd;
    reg overlay_mask,mask_d,mask_dd;
    wire diagnostic_square=((x==120 || x==247) && y>=136 && y<264) ||
        ((y==136 || y==263) && x>=120 && x<248);
    wire panel_mask;wire [23:0] panel_rgb;
    wire [11:0] shape_x=x-120,shape_y=y-136;
    wire [7:0] shape_index={shape_y[6:3],shape_x[6:3]};
    vision_diagnostics_display diagnostic_panel(.x(x),.y(y),.enabled(diagnostics_display),
        .valid(live && good),.analysis(analysis_display),.mask(panel_mask),.rgb(panel_rgb));
    always @* begin
        overlay_mask=0;overlay_color=0;
        if(y>=20 && y<44 && x>=330 && x<410) begin
            overlay_mask=1;overlay_color=failed_display?24'hcc4050:(ready_display?24'h36c878:24'hffb830);
        end
        if(show_camera && live && roi_border) begin overlay_mask=1;overlay_color=24'hffda30;end
        if(diagnostics_display && highlight_yellow && x>=120 && x<248 && y>=136 && y<264) begin
            overlay_mask=1;overlay_color=shape_mask_display[shape_index]?24'hffffff:24'h080c14;
        end
        if(diagnostics_display && live && diagnostic_square) begin overlay_mask=1;overlay_color=24'h30e8ff;end
        if(show_camera && y>=20 && y<44 && x>=426 && x<506) begin
            overlay_mask=1;
            overlay_color=!motion_ready_display?24'hffb830:(motion_display?24'hff50d0:24'h344359);
        end
        // Motion fraction, full scale 4800 samples; line marks the 5% threshold.
        if(show_camera && y>=384 && y<400 && x>=80 && x<680) begin
            overlay_mask=1;
            overlay_color=motion_ready_display && (x-80)*8<motion_meter?24'hff50d0:24'h344359;
            if(x==110) overlay_color=24'hffffff;
        end
        // Yellow entry threshold: 35% of a 600-pixel full-scale bar.
        if(show_camera && y>=360 && y<380 && x==290) begin overlay_mask=1;overlay_color=24'hffffff;end
        if(y>=440 && y<452 && x>=24 && x<216) begin
            overlay_mask=1;overlay_color=id_display[(x-24)/12]?24'h76baff:24'h344359;
        end
        if(y>=440 && y<452 && x>=240 && x<288) begin
            overlay_mask=1;overlay_color=error_display[(x-240)/12]?24'hff5060:24'h344359;
        end
        if(panel_mask) begin overlay_mask=1;overlay_color=panel_rgb;end
    end
    wire [23:0] preview_rgb={{preview_pixel[15:11],preview_pixel[15:13]},
        {preview_pixel[10:5],preview_pixel[10:9]},{preview_pixel[4:0],preview_pixel[4:2]}};
    wire [7:0] preview_r=preview_rgb[23:16],preview_g=preview_rgb[15:8],preview_b=preview_rgb[7:0];
    wire preview_yellow=preview_r>=160 && preview_g>=140 && preview_b<=100 &&
        ({1'b0,preview_r}>{1'b0,preview_b}+9'd60) && ({1'b0,preview_g}>{1'b0,preview_b}+9'd50);
    always @(posedge pixel_clk) begin
        overlay_d<=overlay_color;overlay_dd<=overlay_d;mask_d<=overlay_mask;mask_dd<=mask_d;
        TLCD_DEN<=base_de;TLCD_HSYNC<=base_hs;TLCD_VSYNC<=base_vs;
        if(mask_dd) {TLCD_R,TLCD_G,TLCD_B}<=overlay_dd;
        else if(show_camera && live && preview_inside)
            {TLCD_R,TLCD_G,TLCD_B}<=!diagnostics_display && highlight_yellow && preview_yellow?24'hff00ff:preview_rgb;
        else {TLCD_R,TLCD_G,TLCD_B}<={base_r,base_g,base_b};
        if(pixel_rst) begin
            TLCD_DEN<=0;TLCD_HSYNC<=1;TLCD_VSYNC<=1;
            TLCD_R<=0;TLCD_G<=0;TLCD_B<=0;mask_d<=0;mask_dd<=0;
        end
    end
    // PDF p.73 shows falling-edge sampling. Registered RGB changes on rising
    // pixel clock; forward same-phase DCLK so falling edge is half a cycle later.
    ODDR #(.DDR_CLK_EDGE("SAME_EDGE"),.INIT(1'b0),.SRTYPE("ASYNC")) pixel_clock_forward(
        .C(pixel_clk),.CE(1'b1),.D1(LCD_SAMPLE_FALLING),.D2(!LCD_SAMPLE_FALLING),
        .R(pixel_rst),.S(1'b0),.Q(TLCD_DCLK));
    assign TLCD_DISP=!pixel_rst;
    // Hardware visibility must survive missing MMCM lock or a held reset.
    // Spartan-7 initializes this counter at configuration; H intentionally
    // does not reset it. At 50 MHz LED2 toggles every 0.336 seconds.
    reg [24:0] heartbeat=25'd0;
    always @(posedge reference_clk) heartbeat<=heartbeat+1'b1;
    // LED8: configured image marker, LED7: raw H, LED6: raw A,
    // LED5/4: sensor error/ready, LED3: selected card, LED2: raw clock,
    // LED1: MMCM lock. None of the three raw diagnostics needs core_clk.
    assign LED={1'b1,SW_H,SW_A,cam_failed,cam_ready,
        (camera_mode?cam_card:card_active),heartbeat[24],locked};
endmodule
