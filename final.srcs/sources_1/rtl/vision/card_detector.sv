module card_detector #(
    parameter integer X0=80, Y0=60, ROI_W=160, ROI_H=120,
    parameter integer ENTER_PERCENT=35, EXIT_PERCENT=20, STABLE_FRAMES=3
)(
    input wire clk,rst,frame_start,pixel_valid,frame_bad,
    input wire [15:0] pixel, input wire [11:0] x,y,
    output reg result_valid, card_present, frame_good,
    output reg [19:0] yellow_count, roi_count,
    output reg [15:0] frame_number
);
    localparam integer AREA=ROI_W*ROI_H;
    reg [19:0] yellow_acc,roi_acc;
    reg [15:0] streak;
    wire in_roi=x>=X0 && x<X0+ROI_W && y>=Y0 && y<Y0+ROI_H;
    wire [7:0] r={pixel[15:11],pixel[15:13]};
    wire [7:0] g={pixel[10:5],pixel[10:9]};
    wire [7:0] b={pixel[4:0],pixel[4:2]};
    // Adjustable baseline, not a lighting-invariant color classifier.
    wire yellow=r>=160 && g>=140 && b<=100 &&
                ({1'b0,r}>{1'b0,b}+9'd60) &&
                ({1'b0,g}>{1'b0,b}+9'd50);
    wire complete_frame=(roi_acc==AREA) && !frame_bad;
    wire candidate=card_present ? (yellow_acc*100>=AREA*EXIT_PERCENT)
                                : (yellow_acc*100>=AREA*ENTER_PERCENT);
    always @(posedge clk) begin
        if(rst) begin
            yellow_acc<=0;roi_acc<=0;streak<=0;
            result_valid<=0;card_present<=0;frame_good<=0;
            yellow_count<=0;roi_count<=0;frame_number<=0;
        end else begin
            result_valid<=0;
            if(frame_start) begin
                result_valid<=1; frame_number<=frame_number+1'b1;
                yellow_count<=yellow_acc;roi_count<=roi_acc;
                frame_good<=complete_frame;
                yellow_acc<=0;roi_acc<=0;
                if(!complete_frame) begin card_present<=0;streak<=0;end
                else if(candidate==card_present) streak<=0;
                else if(streak>=STABLE_FRAMES-1) begin
                    card_present<=candidate;streak<=0;
                end else streak<=streak+1'b1;
            end else if(pixel_valid && in_roi) begin
                if(roi_acc!=20'hfffff) roi_acc<=roi_acc+1'b1;
                if(yellow && yellow_acc!=20'hfffff) yellow_acc<=yellow_acc+1'b1;
            end
        end
    end
endmodule
