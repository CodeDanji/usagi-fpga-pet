// One-entry bundled-data mailbox. The source holds payload until acknowledged.
// Pulses while busy are deliberately dropped; next frame retries latest state.
// Both domains must receive the same reset assertion, synchronized locally.
module cdc_mailbox #(parameter integer WIDTH=64)(
    input wire src_clk, src_rst, src_send,
    input wire [WIDTH-1:0] src_data,
    output wire src_busy,
    input wire dst_clk, dst_rst,
    output reg dst_valid, output reg [WIDTH-1:0] dst_data
);
    reg [WIDTH-1:0] held;
    reg request, acknowledge;
    (* ASYNC_REG="TRUE" *) reg [1:0] req_sync, ack_sync;
    assign src_busy = request != ack_sync[1];
    always @(posedge src_clk) begin
        if(src_rst) begin ack_sync<=0; request<=0; held<=0; end
        else begin
            ack_sync <= {ack_sync[0],acknowledge};
            if(src_send && !src_busy) begin held<=src_data; request<=~request; end
        end
    end
    always @(posedge dst_clk) begin
        if(dst_rst) begin req_sync<=0; acknowledge<=0; dst_valid<=0; dst_data<=0; end
        else begin
            req_sync <= {req_sync[0],request};
            dst_valid <= 0;
            if(req_sync[1] != acknowledge) begin
                dst_data <= held;
                dst_valid <= 1;
                acknowledge <= req_sync[1];
            end
        end
    end
endmodule
