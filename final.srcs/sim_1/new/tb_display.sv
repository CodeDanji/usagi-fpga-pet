`timescale 1ns/1ps
module tb_display;
    reg clk=0;always #5 clk=~clk;
    reg rst=1,happy=0;
    wire [11:0] x,y;wire de,hs,vs,ft;
    lcd_timing timing(clk,rst,x,y,de,hs,vs,ft);
    wire [7:0] r,g,b;wire dout,hout,vout;
    usagi_display display(clk,rst,x,y,de,hs,vs,happy,1'b1,1'b1,
        20'd19200,16'h52a5,r,g,b,dout,hout,vout);
    integer f,count,frames=0;
    task capture(input integer which);
        begin
            @(negedge clk);rst=1;happy=which;
            repeat(4) @(negedge clk);
            rst=0;
            f=$fopen(which?"display_happy.ppm":"display_neutral.ppm","w");
            if(!f) $fatal(1,"Cannot open preview");
            $fdisplay(f,"P3\n800 480\n255");
            count=0;
            while(count<800*480) begin
                @(posedge clk);#1;
                if(dout) begin
                    if((^{r,g,b})===1'bx) $fatal(1,"Unknown display pixel");
                    $fdisplay(f,"%0d %0d %0d",r,g,b);count=count+1;
                end
            end
            $fclose(f);frames=frames+1;
        end
    endtask
    // Check active pixel count and sync widths across a full raster separately.
    integer active=0,hslow=0,vslow=0,cycles=0;
    initial begin
        capture(0);capture(1);
        @(negedge clk);rst=1;repeat(4) @(negedge clk);rst=0;
        repeat(1056*525) begin
            #1;
            if(de) active=active+1;
            if(!hs) hslow=hslow+1;
            if(!vs) vslow=vslow+1;
            cycles=cycles+1;
            @(negedge clk);
        end
        if(active!=800*480 || hslow!=48*525 || vslow!=3*1056)
            $fatal(1,"Raster dimensions or sync widths incorrect");
        $display("PASS display: 2 full previews, active pixels and HS/VS widths");$finish;
    end
    initial begin #20000000;$fatal(1,"Timeout");end
endmodule
