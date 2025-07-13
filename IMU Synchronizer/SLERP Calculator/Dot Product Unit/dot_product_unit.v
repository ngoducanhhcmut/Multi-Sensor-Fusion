// Sub-module: Dot Product Unit
module dot_product_unit (
    input logic [31:0] q1 [0:3],
    input logic [31:0] q2 [0:3],
    output logic [31:0] dot
);
    logic [63:0] prod [0:3];
    logic [63:0] sum;

    always_comb begin
        prod[0] = (q1[0] * q2[0]) >> 16;
        prod[1] = (q1[1] * q2[1]) >> 16;
        prod[2] = (q1[2] * q2[2]) >> 16;
        prod[3] = (q1[3] * q2[3]) >> 16;
        sum = prod[0] + prod[1] + prod[2] + prod[3];
        
        // Edge case: Zero quaternion
        if ((q1[0] == 32'h0 && q1[1] == 32'h0 && q1[2] == 32'h0 && q1[3] == 32'h0) ||
            (q2[0] == 32'h0 && q2[1] == 32'h0 && q2[2] == 32'h0 && q2[3] == 32'h0)) begin
            dot = 32'h0;
        end else begin
            dot = sum[31:0]; // Q16.16 format
        end
    end
endmodule