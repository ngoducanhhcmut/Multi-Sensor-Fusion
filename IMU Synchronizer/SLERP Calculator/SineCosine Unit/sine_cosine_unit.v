// Sub-module: Sine/Cosine Unit
module sine_cosine_unit (
    input logic clk,
    input logic rst_n,
    input logic [31:0] theta,
    output logic [31:0] sin_theta,
    output logic [31:0] cos_theta
);
    cordic_sincos cordic_inst (
        .clk(clk),
        .rst_n(rst_n),
        .angle(theta),
        .sin(sin_theta),
        .cos(cos_theta)
    );
endmodule