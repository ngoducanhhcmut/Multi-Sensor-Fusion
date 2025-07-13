// Sub-module: Angle Calculator
module angle_calculator (
    input logic clk,
    input logic rst_n,
    input logic [31:0] dot,
    output logic [31:0] theta
);
    cordic_arccos cordic_inst (
        .clk(clk),
        .rst_n(rst_n),
        .x(dot),
        .angle(theta)
    );

    // Edge case handling
    always_comb begin
        if (dot >= 32'h00010000) begin // dot >= 1.0
            theta = 32'h0;
        end else if (dot <= 32'hFFFF0000) begin // dot <= -1.0
            theta = 32'h6487ED51; // PI in Q16.16
        end
    end
endmodule