`timescale 1ns/1ps
module tb_vision_diagnostics;
    reg clk=0;always #5 clk=~clk;
    reg rst=1,fs=0,pv=0,good=1,cmd_valid=0;
    reg [1:0] cmd=0;reg [15:0] pixel=0;reg [11:0] x=0,y=0;
    wire [40:0] report;
    wire [255:0] shape_mask;
    vision_diagnostics dut(.clk(clk),.rst(rst),.frame_start(fs),.pixel_valid(pv),.frame_good(good),
        .pixel(pixel),.x(x),.y(y),.command_valid(cmd_valid),.command(cmd),.report(report),.silhouette_frame(shape_mask));
    reg [11:0] panel_x=0,panel_y=0;reg [40:0] saved_report=0;
    wire panel_mask;wire [23:0] panel_rgb;
    vision_diagnostics_display panel(.x(panel_x),.y(panel_y),.enabled(1'b1),.valid(1'b1),
        .analysis(saved_report),.mask(panel_mask),.rgb(panel_rgb));
    task render_panel;
        integer fd,px,py;
        begin
            fd=$fopen("vision_panel.ppm","wb");$fwrite(fd,"P6\n416 280\n255\n");
            for(py=64;py<344;py=py+1) for(px=376;px<792;px=px+1) begin
                panel_x=px;panel_y=py;#1;
                $fwrite(fd,"%c%c%c",panel_rgb[23:16],panel_rgb[15:8],panel_rgb[7:0]);
            end
            $fclose(fd);
        end
    endtask
    task command(input [1:0] value);
        begin @(negedge clk);cmd=value;cmd_valid=1;@(negedge clk);cmd_valid=0;end
    endtask
    task boundary;
        begin @(negedge clk);pv=0;fs=1;@(negedge clk);fs=0;end
    endtask
    // mode 0 uniform, 1 mixed colors, 2 box, 3 paper, 4 scissors, 5 novel shape.
    task frame(input integer mode,input [15:0] color,input integer bx,input integer by);
        integer row,col,cx,cy;reg foreground;
        begin
            for(row=0;row<120;row=row+1) for(col=0;col<160;col=col+1) begin
                @(negedge clk);x=col*4;y=row*4;pv=1;
                cx=(col*4-192)/16;cy=(row*4-112)/16;
                foreground=0;
                if(col*4>=192 && col*4<448 && row*4>=112 && row*4<368) begin
                    case(mode)
                        2,6:foreground=cx>=bx && cx<bx+4 && cy>=by && cy<by+4;
                        3:foreground=cx>=4 && cx<12 && cy>=3 && cy<13;
                        4:foreground=(cx>=6 && cx<10 && cy>=8 && cy<13) ||
                            (((cx>=5 && cx<7)||(cx>=9 && cx<11)) && cy>=2 && cy<8);
                        5:foreground=cx<3 && cy<12;
                    endcase
                end
                pixel=mode==0?color:(mode==1?(col[0]?16'hf800:16'h001f):
                    (mode==6?(foreground?color:16'h001f):(foreground?16'hffff:16'h0000)));
            end
            boundary();#1;
        end
    endtask
    task expect_color(input [15:0] value,input integer id);
        begin frame(0,value,0,0);if(report[3:0]!=id || report[10:4]!=100) $fatal(1,"Color %h -> %d %d",value,report[3:0],report[10:4]);end
    endtask
    task teach(input integer mode,input integer bx,input integer by);
        begin command(2);boundary();frame(mode,0,bx,by);end
    endtask
    task expect_shape(input integer mode,input integer id);
        begin
            repeat(4) frame(mode,0,6,6);
            if(report[15:14]!=id) $fatal(1,"Shape mode %d -> %d distance %d",mode,report[15:14],report[31:23]);
        end
    endtask
    initial begin
        repeat(3) @(negedge clk);rst=0;
        expect_color(16'h0000,1);expect_color(16'hffff,2);expect_color(16'h8410,3);
        expect_color(16'hf800,4);expect_color(16'hfb20,5);expect_color(16'hffe0,6);
        expect_color(16'h07e0,7);expect_color(16'h07ff,8);expect_color(16'h001f,9);expect_color(16'hf81f,10);
        frame(1,0,0,0);if(report[3:0]!=0) $fatal(1,"Mixed colors must be unknown");
        if(report[21] || report[15:14]!=0) $fatal(1,"Uncalibrated shape accepted");
        command(3);boundary();frame(0,16'h001f,0,0);
        frame(6,16'hf800,6,6);
        if(!report[22] || report[3:0]!=4 || report[10:4]!=100)
            $fatal(1,"Equal-luminance red object on blue background was lost");
        command(3);boundary();frame(0,0,0,0);
        if(!report[21] || report[20:18]!=0) $fatal(1,"Background capture failed");
        teach(2,6,6);if(report[20:18]!=1) $fatal(1,"Rock teaching failed");
        command(1);teach(3,0,0);if(report[20:18]!=3) $fatal(1,"Paper teaching failed");
        command(1);teach(4,0,0);if(report[20:18]!=7) $fatal(1,"Scissors teaching failed");
        expect_shape(2,1);saved_report=report;
        if(report[3:0]!=2 || report[10:4]!=100) $fatal(1,"Foreground color was overwhelmed by background");
        if(shape_mask[6*16+6]!==1 || shape_mask[0]!==0) $fatal(1,"Silhouette publication failed");
        expect_shape(3,2);expect_shape(4,3);expect_shape(5,0);
        frame(0,0,0,0);if(report[15:14]!=0 || report[22]) $fatal(1,"Empty scene accepted");
        frame(2,0,4,4);frame(2,0,7,4);if(report[13:11]!=3) $fatal(1,"Right not detected");
        frame(2,0,4,4);if(report[13:11]!=2) $fatal(1,"Left not detected");
        frame(2,0,4,7);if(report[13:11]!=5) $fatal(1,"Down not detected");
        frame(2,0,4,4);if(report[13:11]!=4) $fatal(1,"Up not detected");
        frame(2,0,7,7);if(report[13:11]!=6) $fatal(1,"Diagonal not detected");
        repeat(10) frame(2,0,7,7);if(report[13:11]!=1) $fatal(1,"Still state not restored");
        frame(0,16'hffff,0,0);if(report[22] || report[15:14]!=0) $fatal(1,"Global illumination accepted as object");
        good=0;frame(2,0,6,6);if(report[3:0] || report[22] || report[15:14]) $fatal(1,"Bad frame accepted");good=1;
        command(3);boundary();frame(0,0,0,0);if(report[20:18]!=0) $fatal(1,"Recalibration retained templates");
        render_panel();
        $display("PASS vision: ten colors, mixed rejection, calibration, taught templates, unknown/empty rejection, four directions, diagonal, stop, bad frame");
        $finish;
    end
    initial begin #100000000;$fatal(1,"Vision timeout");end
endmodule
