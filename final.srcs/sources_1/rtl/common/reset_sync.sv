module reset_sync(input wire clk, input wire arst, output wire rst);
    (* ASYNC_REG = "TRUE" *) reg [1:0] pipe;
    always @(posedge clk or posedge arst)
        if (arst) pipe <= 2'b11;
        else pipe <= {pipe[0], 1'b0};
    assign rst = pipe[1];
endmodule
