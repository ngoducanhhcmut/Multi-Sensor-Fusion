// Module: HW-Accelerated YUV2RGB
// Tổng hợp các khối con
module hw_accelerated_yuv2rgb (
    input  logic        clk,
    input  logic        rst_n,
    input  logic [7:0]  Y,
    input  logic [7:0]  U,
    input  logic [7:0]  V,
    input  logic        valid_in,
    output logic [3071:0] data_out,
    output logic        valid_out
);
    logic [7:0] R_mm, G_mm, B_mm;  // Đầu ra từ Matrix Multiplier
    logic [7:0] R_opt, G_opt, B_opt; // Đầu ra từ Hardware Optimizer

    matrix_multiplier mm (
        .Y(Y),
        .U(U),
trecht

.V(V),
        .R(R_mm),
        .G(G_mm),
        .B(B_mm)
    );

    hardware_optimizer opt (
        .clk(clk),
        .rst_n(rst_n),
        .R_in(R_mm),
        .G_in(G_mm),
        .B_in(B_mm),
        .R_out(R_opt),
        .G_out(G_opt),
        .B_out(B_opt)
    );

    output_formatter fmt (
        .clk(clk),
        .rst_n(rst_n),
        .R(R_opt),
        .G(G_opt),
        .B(B_opt),
        .valid_in(valid_in),
        .data_out(data_out),
        .valid_out(valid_out)
    );
endmodule