// Q16.16 regular-spiking neuron, explicit Euler dt=0.25 ms.
// Constants and update order are intentionally shared with model/reference.py.
module izhikevich_q16(
    input wire clk,rst,step_en,
    input wire signed [31:0] current,
    output reg signed [31:0] v,u,
    output reg spike,clipped
);
    localparam signed [63:0] Q=65536;
    reg signed [63:0] vw,uw,iw,v2,dv,du,vnext,unext;
    reg signed [31:0] vn,un;
    reg sn,cn;
    always @* begin
        vw={{32{v[31]}},v};uw={{32{u[31]}},u};iw={{32{current[31]}},current};
        v2=(vw*vw)>>>16;
        dv=((v2*64'sd2621)>>>16)+5*vw+140*Q-uw+iw;
        du=(64'sd1311*(((64'sd13107*vw)>>>16)-uw))>>>16;
        vnext=vw+(dv>>>2);unext=uw+(du>>>2);
        sn=vnext>=30*Q;cn=0;
        if(sn) begin vnext=-65*Q;unext=unext+8*Q;end
        if(vnext < -120*Q) begin vnext=-120*Q;cn=1;end
        if(vnext > 120*Q) begin vnext=120*Q;cn=1;end
        if(unext < -120*Q) begin unext=-120*Q;cn=1;end
        if(unext > 120*Q) begin unext=120*Q;cn=1;end
        vn=vnext[31:0];un=unext[31:0];
    end
    always @(posedge clk) begin
        if(rst) begin v<=-65*65536;u<=-13*65536;spike<=0;clipped<=0;end
        else if(step_en) begin v<=vn;u<=un;spike<=sn;clipped<=cn;end
    end
endmodule
