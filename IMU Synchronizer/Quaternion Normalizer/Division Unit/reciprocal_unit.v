module reciprocal_unit (
    input  logic [31:0] in,   // Q2.30 (unsigned)
    output logic [31:0] out   // Q2.30 (unsigned)
);
    // Initial approximation (12-bit LUT)
    logic [11:0] lut_out;
    reciprocal_lut lut (
        .addr(in[31:20]),
        .data(lut_out)
    );
    
    // Newton-Raphson iteration
    logic [31:0] y0, y1, x_y0, two_minus;
    
    assign y0 = {20'h0, lut_out}; // Q2.30
    assign x_y0 = (in * y0) >> 30; // Q2.30 * Q2.30 = Q4.60 -> Q4.30
    assign two_minus = 32'h8000_0000 - x_y0; // Q2.30
    assign y1 = (y0 * two_minus) >> 30; // Q2.30 * Q2.30 = Q4.60 -> Q4.30
    
    assign out = y1; // Q2.30
endmodule

module reciprocal_lut (
    input  logic [11:0] addr,
    output logic [11:0] data
);
    // 4096-entry LUT for reciprocal approximation
    always_comb begin
        data = 12'h800 / (addr ? addr : 12'h001); // Prevent division by zero
    end
endmodule