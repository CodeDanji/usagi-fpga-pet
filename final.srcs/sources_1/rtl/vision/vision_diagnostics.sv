// Diagnostic measurements, not an unrestricted object recognizer.
// Color: dominant per-pixel class in the central ROI, with a reject margin.
// Shape: 16x16 background-subtracted silhouette, one taught template per class.
// Direction: foreground bounding-box displacement in camera image coordinates.
module vision_diagnostics #(
    parameter integer WIDTH=640,HEIGHT=480
)(
    input wire clk,rst,frame_start,pixel_valid,frame_good,
    input wire [15:0] pixel,input wire [11:0] x,y,
    input wire command_valid,input wire [1:0] command,
    output wire [40:0] report,
    output reg [255:0] silhouette_frame
);
    // Commands: 1 select next label, 2 teach selected label, 3 capture background.
    localparam SIDE=256, X0=WIDTH/2-128,Y0=HEIGHT/2-128;
    localparam COLOR_AREA=(WIDTH/8)*(HEIGHT/8);
    reg background_ready;
    reg [8:0] count;
    wire target,sample,foreground;
    wire [7:0] r={pixel[15:11],pixel[15:13]},g={pixel[10:5],pixel[10:9]},b={pixel[4:0],pixel[4:2]};
    wire [7:0] hi=r>g?(r>b?r:b):(g>b?g:b);
    wire [7:0] lo=r<g?(r<b?r:b):(g<b?g:b);
    reg [3:0] pixel_class;
    always @* begin
        pixel_class=0;
        if(hi<48) pixel_class=1;                         // black
        else if(hi-lo<32) pixel_class=lo>=180?2:3;       // white / gray
        else if(r>=160 && g>=140 && b<=100 && {1'b0,r}>{1'b0,b}+60 && {1'b0,g}>{1'b0,b}+50) pixel_class=6;
        else if(r>=120 && g>=60 && g*4<r*3 && r>g && {1'b0,r}>{1'b0,b}+48) pixel_class=5; // orange
        else if({1'b0,r}>{1'b0,g}+40 && {1'b0,r}>{1'b0,b}+40) pixel_class=4;
        else if({1'b0,g}>{1'b0,r}+32 && {1'b0,g}>{1'b0,b}+24) pixel_class=7;
        else if({1'b0,b}>{1'b0,r}+40 && {1'b0,b}>{1'b0,g}+24) pixel_class=9;
        else if(g>=80 && b>=80 && {1'b0,g}>{1'b0,r}+32 && {1'b0,b}>{1'b0,r}+32) pixel_class=8;
        else if(r>=80 && b>=80 && {1'b0,r}>{1'b0,g}+32 && {1'b0,b}>{1'b0,g}+32) pixel_class=10;
    end
    reg [12:0] histogram[0:10];
    reg [8:0] foreground_histogram[0:10];
    reg [12:0] best,second;
    reg [3:0] winner;
    reg [6:0] percentage;
    wire [12:0] color_denominator=background_ready?{4'd0,count}:COLOR_AREA;
    integer i;
    always @* begin
        best=0;second=0;winner=0;
        for(integer k=1;k<=10;k=k+1) begin
            if((background_ready?foreground_histogram[k]:histogram[k])>best) begin
                second=best;best=background_ready?foreground_histogram[k]:histogram[k];winner=k;
            end else if((background_ready?foreground_histogram[k]:histogram[k])>second)
                second=background_ready?foreground_histogram[k]:histogram[k];
        end
        percentage=0;
        for(integer k=1;k<=10;k=k+1)
            if(color_denominator!=0 && best*10>=color_denominator*k) percentage=k*10;
    end
    reg [3:0] color_id;
    reg [6:0] color_percent;
    wire color_sample=pixel_valid && x>=WIDTH/4 && x<3*WIDTH/4 &&
        y>=HEIGHT/4 && y<3*HEIGHT/4 && x[1:0]==0 && y[1:0]==0;
    always @(posedge clk) begin
        if(rst) begin
            for(i=0;i<=10;i=i+1) histogram[i]<=0;
            for(i=0;i<=10;i=i+1) foreground_histogram[i]<=0;
            color_id<=0;color_percent<=0;
        end else if(frame_start) begin
            color_id<=frame_good && (!background_ready || target) && color_denominator!=0 &&
                best*5>=color_denominator*2 && (best-second)*10>=color_denominator?winner:0;
            color_percent<=frame_good && (!background_ready || target)?percentage:0;
            for(i=0;i<=10;i=i+1) histogram[i]<=0;
            for(i=0;i<=10;i=i+1) foreground_histogram[i]<=0;
        end else begin
            if(color_sample) histogram[pixel_class]<=histogram[pixel_class]+1'b1;
            if(sample && foreground) foreground_histogram[pixel_class]<=foreground_histogram[pixel_class]+1'b1;
        end
    end

    // Fixed square, sample centers of sixteen-pixel cells.
    wire [11:0] gx=x-X0,gy=y-Y0;
    assign sample=pixel_valid && x>=X0 && x<X0+SIDE && y>=Y0 && y<Y0+SIDE && gx[3:0]==8 && gy[3:0]==8;
    wire [7:0] address={gy[7:4],gx[7:4]};
    (* ram_style="distributed" *) reg [15:0] background[0:255];
    reg [255:0] templates[0:2];
    reg [255:0] silhouette;
    reg [2:0] trained;
    reg [1:0] selected,pending_command,capture_class;
    reg capture_background,capture_template;
    reg [8:0] shape_count,distance[0:2],match_distance;
    reg [4:0] xmin,xmax,ymin,ymax;
    wire [15:0] old_background=background[address];
    wire [7:0] br={old_background[15:11],old_background[15:13]},
        bg={old_background[10:5],old_background[10:9]},bb={old_background[4:0],old_background[4:2]};
    wire [7:0] dr=r>br?r-br:br-r,dg=g>bg?g-bg:bg-g,db=b>bb?b-bb:bb-b;
    assign foreground=background_ready && (dr>=32 || dg>=32 || db>=32);
    assign target=count>=6 && count<=220;
    wire [5:0] center_x={1'b0,xmin}+{1'b0,xmax},center_y={1'b0,ymin}+{1'b0,ymax};
    reg [5:0] anchor_x,anchor_y;
    reg tracking,target_valid;
    reg [2:0] direction,hold_direction;
    reg [3:0] direction_age;
    wire signed [6:0] dx=$signed({1'b0,center_x})-$signed({1'b0,anchor_x});
    wire signed [6:0] dy=$signed({1'b0,center_y})-$signed({1'b0,anchor_y});
    wire [6:0] ax=dx<0?-dx:dx,ay=dy<0?-dy:dy;
    reg [2:0] next_direction;
    always @* begin
        next_direction=1; // still
        if(ax>=4 || ay>=4) begin // two grid cells, accumulated from anchor
            if(ax>=ay*2) next_direction=dx<0?2:3;
            else if(ay>=ax*2) next_direction=dy<0?4:5;
            else next_direction=6; // diagonal, don't invent a dominant axis
        end
    end
    reg [8:0] nearest,runner_up;
    reg [1:0] nearest_class;
    always @* begin
        nearest=9'd511;runner_up=9'd511;nearest_class=0;
        for(integer k=0;k<3;k=k+1) begin
            if(distance[k]<nearest) begin runner_up=nearest;nearest=distance[k];nearest_class=k+1;end
            else if(distance[k]<runner_up) runner_up=distance[k];
        end
    end
    wire [1:0] candidate=target && trained==3'b111 && nearest<=48 && runner_up-nearest>=12?nearest_class:0;
    reg [1:0] object_class,last_candidate;
    reg [1:0] stable;
    // report [40:32] silhouette count, [31:23] template distance,
    // [22] target, [21] background ready, [20:18] taught mask,
    // [17:16] selected (0..2), [15:14] recognized (0 unknown, 1..3),
    // [13:11] direction, [10:4] dominant percentage, [3:0] color.
    assign report={shape_count,match_distance,target_valid,background_ready,trained,selected,object_class,direction,color_percent,color_id};
    always @(posedge clk) begin
        if(rst) begin
            silhouette<=0;silhouette_frame<=0;trained<=0;selected<=0;pending_command<=0;capture_class<=0;
            capture_background<=0;capture_template<=0;background_ready<=0;
            count<=0;shape_count<=0;match_distance<=256;
            xmin<=31;xmax<=0;ymin<=31;ymax<=0;
            tracking<=0;target_valid<=0;direction<=0;hold_direction<=1;direction_age<=0;
            anchor_x<=0;anchor_y<=0;object_class<=0;last_candidate<=0;stable<=0;
            for(integer k=0;k<3;k=k+1) distance[k]<=0;
        end else begin
            if(command_valid) begin
                if(command==1) selected<=selected==2?0:selected+1'b1;
                else pending_command<=command;
            end
            if(frame_start) begin
                // Read old accumulators before starting a fresh frame.
                shape_count<=frame_good && background_ready?count:0;
                silhouette_frame<=frame_good && background_ready?silhouette:256'd0;
                target_valid<=frame_good && background_ready && target;
                match_distance<=frame_good && background_ready && trained==7?nearest:256;
                if(capture_background) begin
                    background_ready<=frame_good;
                    trained<=0;tracking<=0;target_valid<=0;
                end
                if(capture_template && frame_good && target && background_ready)
                    begin templates[capture_class]<=silhouette;trained[capture_class]<=1;end
                if(!frame_good || !background_ready || capture_background || pending_command==3 || !target) begin
                    tracking<=0;direction<=0;direction_age<=0;
                end else if(!tracking) begin
                    anchor_x<=center_x;anchor_y<=center_y;tracking<=1;direction<=1;
                end else if(next_direction!=1) begin
                    anchor_x<=center_x;anchor_y<=center_y;
                    direction<=next_direction;hold_direction<=next_direction;direction_age<=8;
                end else if(direction_age!=0) begin direction_age<=direction_age-1'b1;direction<=hold_direction;end
                else direction<=1;
                if(!frame_good || !background_ready || capture_background || capture_template || pending_command!=0 || candidate==0) begin
                    object_class<=0;stable<=0;last_candidate<=0;
                end else if(candidate!=last_candidate) begin last_candidate<=candidate;stable<=1;object_class<=0;end
                else if(stable>=2) begin object_class<=candidate;stable<=3;end
                else stable<=stable+1'b1;
                capture_background<=pending_command==3;
                capture_template<=pending_command==2;
                capture_class<=selected;
                if(pending_command==3) begin background_ready<=0;trained<=0;target_valid<=0;end
                // A command arriving on this edge belongs to the next frame.
                if(!command_valid || command==1) pending_command<=0;
                count<=0;silhouette<=0;xmin<=31;xmax<=0;ymin<=31;ymax<=0;
                for(integer k=0;k<3;k=k+1) distance[k]<=0;
            end else if(sample) begin
                if(capture_background) background[address]<=pixel;
                silhouette[address]<=foreground;
                for(integer k=0;k<3;k=k+1)
                    if(trained[k] && foreground!=templates[k][address]) distance[k]<=distance[k]+1'b1;
                if(foreground) begin
                    count<=count+1'b1;
                    if(gx[7:4]<xmin) xmin<=gx[7:4];if(gx[7:4]>xmax) xmax<=gx[7:4];
                    if(gy[7:4]<ymin) ymin<=gy[7:4];if(gy[7:4]>ymax) ymax<=gy[7:4];
                end
            end
        end
    end
endmodule
