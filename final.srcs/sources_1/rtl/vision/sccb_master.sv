// Original bounded SCCB controller. 0x42 write / 0x43 read; STOP between
// register-address write and read, and NACK after the single returned byte.
// OV7670 does not stretch SIOC. No response completes with nack=1, never hangs.
module sccb_master #(parameter integer QUARTER_CYCLES=63)(
    input wire clk,rst,start,read,
    input wire [7:0] address,write_data,
    input wire sda_in,
    output reg scl_low,sda_low,busy,done,nack,
    output reg [7:0] read_data
);
    localparam IDLE=0,START_A=1,START_B=2,BIT_A=3,BIT_B=4,BIT_C=5,BIT_D=6,
               ACK_A=7,ACK_B=8,ACK_C=9,ACK_D=10,
               STOP_A=11,STOP_B=12,STOP_C=13,STOP_D=14;
    reg [3:0] state;
    reg [15:0] divider;
    reg [7:0] tx,addr_hold,data_hold;
    reg [2:0] bit_index;
    reg [1:0] byte_index;
    reg reading,second_start,receive_byte;
    (* ASYNC_REG="TRUE" *) reg [1:0] sda_sync;
    always @(posedge clk) begin
        sda_sync<={sda_sync[0],sda_in};
        done<=0;
        if(rst) begin
            state<=IDLE;divider<=0;scl_low<=0;sda_low<=0;busy<=0;
            done<=0;nack<=0;read_data<=0;tx<=0;addr_hold<=0;data_hold<=0;
            bit_index<=7;byte_index<=0;reading<=0;second_start<=0;receive_byte<=0;
        end else if(state==IDLE) begin
            divider<=0;
            if(start) begin
                busy<=1;nack<=0;reading<=read;addr_hold<=address;data_hold<=write_data;
                second_start<=0;receive_byte<=0;byte_index<=0;tx<=8'h42;
                state<=START_A;
            end
        end else if(divider==QUARTER_CYCLES-1) begin
            divider<=0;
            case(state)
                START_A: begin scl_low<=0;sda_low<=0;state<=START_B;end
                START_B: begin sda_low<=1;bit_index<=7;state<=BIT_A;end
                BIT_A: begin scl_low<=1;sda_low<=receive_byte?0:!tx[bit_index];state<=BIT_B;end
                BIT_B: begin scl_low<=0;state<=BIT_C;end
                BIT_C: begin if(receive_byte) read_data[bit_index]<=sda_sync[1];state<=BIT_D;end
                BIT_D: begin
                    scl_low<=1;
                    if(bit_index==0) state<=ACK_A;
                    else begin bit_index<=bit_index-1'b1;state<=BIT_A;end
                end
                ACK_A: begin sda_low<=0;state<=ACK_B;end
                ACK_B: begin scl_low<=0;state<=ACK_C;end
                ACK_C: begin if(!receive_byte && sda_sync[1]) nack<=1;state<=ACK_D;end
                ACK_D: begin
                    scl_low<=1;bit_index<=7;
                    if(receive_byte || (!reading && byte_index==2) || (reading && !second_start && byte_index==1))
                        state<=STOP_A;
                    else begin
                        byte_index<=byte_index+1'b1;state<=BIT_A;
                        if(second_start) receive_byte<=1;
                        else tx<=(byte_index==0)?addr_hold:data_hold;
                    end
                end
                STOP_A: begin scl_low<=1;sda_low<=1;state<=STOP_B;end
                STOP_B: begin scl_low<=0;state<=STOP_C;end
                STOP_C: begin sda_low<=0;state<=STOP_D;end
                STOP_D: begin
                    if(reading && !second_start) begin
                        second_start<=1;byte_index<=0;tx<=8'h43;state<=START_A;
                    end else begin busy<=0;done<=1;state<=IDLE;end
                end
                default: state<=IDLE;
            endcase
        end else divider<=divider+1'b1;
    end
endmodule
