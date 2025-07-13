module reciprocal_lut (
    input  logic [11:0] addr,
    output logic [11:0] data
);
    // 4096-entry LUT for reciprocal approximation
    always_comb begin
        data = 12'h800 / (addr ? addr : 12'h001); // Prevent division by zero
    end
endmodule