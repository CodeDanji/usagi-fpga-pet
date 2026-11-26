// Synthesizable 5x7 text panel. Coordinates are delayed by the caller.
module vision_diagnostics_display(
    input wire [11:0] x,y,input wire enabled,valid,
    input wire [40:0] analysis,
    output reg mask,output reg [23:0] rgb
);
    wire [3:0] color_id=analysis[3:0];wire [6:0] percent=analysis[10:4];
    wire [2:0] direction=analysis[13:11];wire [1:0] object_id=analysis[15:14],selected=analysis[17:16];
    wire [2:0] trained=analysis[20:18];wire background_ready=analysis[21],target=analysis[22];
    wire [8:0] distance=analysis[31:23],area=analysis[40:32];
    function automatic [79:0] color_name(input [3:0] id);
        case(id)
            4'd0:color_name="UNKNOWN   ";
            4'd1:color_name="BLACK     ";
            4'd2:color_name="WHITE     ";
            4'd3:color_name="GRAY      ";
            4'd4:color_name="RED       ";
            4'd5:color_name="ORANGE    ";
            4'd6:color_name="YELLOW    ";
            4'd7:color_name="GREEN     ";
            4'd8:color_name="CYAN      ";
            4'd9:color_name="BLUE      ";
            4'd10:color_name="MAGENTA   ";
            default:color_name="UNKNOWN   ";
        endcase
    endfunction
    function automatic [79:0] shape_name(input [1:0] id);
        case(id)
            1:shape_name="ROCK      ";
            2:shape_name="PAPER     ";
            3:shape_name="SCISSORS  ";
            default:shape_name="UNKNOWN   ";
        endcase
    endfunction
    function automatic [95:0] move_name(input [2:0] id);
        case(id)
            3'd0:move_name="NO TARGET   ";
            3'd1:move_name="STILL       ";
            3'd2:move_name="LEFT        ";
            3'd3:move_name="RIGHT       ";
            3'd4:move_name="UP          ";
            3'd5:move_name="DOWN        ";
            3'd6:move_name="DIAGONAL    ";
            3'd7:move_name="UNSTABLE    ";
        endcase
    endfunction
    function automatic [34:0] glyph(input [7:0] ch);
        case(ch)
            8'd48:glyph=35'b01110100011001110101110011000101110;
            8'd49:glyph=35'b00100011000010000100001000010001110;
            8'd50:glyph=35'b01110100010000100010001000100011111;
            8'd51:glyph=35'b11110000010000101110000010000111110;
            8'd52:glyph=35'b00010001100101010010111110001000010;
            8'd53:glyph=35'b11111100001000011110000010000111110;
            8'd54:glyph=35'b01110100001000011110100011000101110;
            8'd55:glyph=35'b11111000010001000100010000100001000;
            8'd56:glyph=35'b01110100011000101110100011000101110;
            8'd57:glyph=35'b01110100011000101111000010000101110;
            8'd65:glyph=35'b01110100011000111111100011000110001;
            8'd66:glyph=35'b11110100011000111110100011000111110;
            8'd67:glyph=35'b01111100001000010000100001000001111;
            8'd68:glyph=35'b11110100011000110001100011000111110;
            8'd69:glyph=35'b11111100001000011110100001000011111;
            8'd70:glyph=35'b11111100001000011110100001000010000;
            8'd71:glyph=35'b01111100001000010111100011000101111;
            8'd72:glyph=35'b10001100011000111111100011000110001;
            8'd73:glyph=35'b11111001000010000100001000010011111;
            8'd74:glyph=35'b00111000100001000010100101001001100;
            8'd75:glyph=35'b10001100101010011000101001001010001;
            8'd76:glyph=35'b10000100001000010000100001000011111;
            8'd77:glyph=35'b10001110111010110101100011000110001;
            8'd78:glyph=35'b10001110011010110011100011000110001;
            8'd79:glyph=35'b01110100011000110001100011000101110;
            8'd80:glyph=35'b11110100011000111110100001000010000;
            8'd81:glyph=35'b01110100011000110001101011001001101;
            8'd82:glyph=35'b11110100011000111110101001001010001;
            8'd83:glyph=35'b01111100001000001110000010000111110;
            8'd84:glyph=35'b11111001000010000100001000010000100;
            8'd85:glyph=35'b10001100011000110001100011000101110;
            8'd86:glyph=35'b10001100011000110001100010101000100;
            8'd87:glyph=35'b10001100011000110101101011010101010;
            8'd88:glyph=35'b10001100010101000100010101000110001;
            8'd89:glyph=35'b10001100010101000100001000010000100;
            8'd90:glyph=35'b11111000010001000100010001000011111;
            8'd58:glyph=35'b00000001000010000000001000010000000;
            8'd47:glyph=35'b00001000100001000100010000100010000;
            8'd45:glyph=35'b00000000000000011111000000000000000;
            8'd37:glyph=35'b11001110100010000100010001011000110;
            default:glyph=0;
        endcase
    endfunction
    function automatic [7:0] digit(input [8:0] value,input integer place);
        case(place)
            0:digit=8'd48+value/100;
            1:digit=8'd48+(value/10)%10;
            default:digit=8'd48+value%10;
        endcase
    endfunction
    reg [255:0] line;
    reg [79:0] shape_label;
    reg [95:0] move_label;
    reg [7:0] ch;reg [34:0] bits;
    integer row,col,fx,fy;
    always @* begin
        row=(y-72)/24;col=(x-392)/12;fx=((x-392)%12)/2;fy=((y-72)%24)/2;
        shape_label=shape_name(object_id);move_label=move_name(direction);
        if(!valid) begin shape_label="NO VIDEO  ";move_label="NO VIDEO    ";end
        else if(!background_ready) begin shape_label="NEED BG   ";move_label="NEED BG     ";end
        else begin
            if(trained!=7) shape_label="NEED TRAIN";
            else if(!target) shape_label="NO TARGET ";
        end
        line="                                ";
        case(row)
            0:line="VISION TEST  - IMAGE AXES       ";
            1:line={"COLOR: ",color_name(valid?color_id:4'd0)," ",digit({2'b0,percent},0),digit({2'b0,percent},1),digit({2'b0,percent},2),"%          "};
            2:line={"MOVE: ",move_label,"              "};
            3:line={"SHAPE: ",shape_label,"               "};
            4:line={"DISTANCE: ",digit(distance,0),digit(distance,1),digit(distance,2)," / 256             "};
            5:line={"TARGET: ",digit(area,0),digit(area,1),digit(area,2)," / 256               "};
            6:line="TAUGHT: ROCK 0 PAPER 0 SCISSORS 0";
            7:line={"SELECT: ",shape_name(selected+2'd1),"              "};
            8:line="A SELECT  B TEACH  C BACKGROUND ";
            9:line="EMPTY SQUARE THEN C; TEACH R/P/S";
            10:line="FIXED POSE/SCALE; NO GENERAL AI ";
        endcase
        // Explicit positions in the 32-character status line.
        if(row==6) begin
            line="TAUGHT R:0 P:0 S:0              ";
            line[255-9*8 -:8]=trained[0]?"1":"0";
            line[255-13*8 -:8]=trained[1]?"1":"0";
            line[255-17*8 -:8]=trained[2]?"1":"0";
        end
        ch=32;bits=0;
        if(col>=0 && col<32) ch=line[255-col*8 -:8];
        bits=glyph(ch);
        mask=enabled && x>=376 && x<792 && y>=64 && y<344;
        rgb=24'h142032;
        if(mask && x>=392 && x<776 && fy<7 && fx<5 && row>=0 && row<=10)
            if(bits[34-fy*5-fx]) rgb=row==0?24'hffda30:24'he8f0ff;
    end
endmodule
