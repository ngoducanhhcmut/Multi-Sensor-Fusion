// Module: SLERP Calculator
// Description: Performs spherical linear interpolation (SLERP) between two quaternions
module slerp_calculator (
    input logic clk,
    input logic rst_n,
    input logic [31:0] q1 [0:3],       // First quaternion (4x32-bit, Q16.16)
    input logic [31:0] q2 [0:3],       // Second quaternion (4x32-bit, Q16.16)
    input logic [31:0] t,              // Interpolation parameter (32-bit, Q16.16)
    output logic [31:0] q_interp [0:3] // Interpolated quaternion (4x32-bit, Q16.16)
);
    logic [31:0] dot;                  // Dot product result
    logic [31:0] theta;                // Angle between quaternions
    logic [31:0] sin_theta, cos_theta; // Sine and cosine of theta

    // Dot product calculation
    dot_product_unit dot_prod (
        .q1(q1),
        .q2(q2),
        .dot(dot)
    );

    // Angle calculation with edge case handling
    angle_calculator angle_calc (
        .clk(clk),
        .rst_n(rst_n),
        .dot(dot),
        .theta(theta)
    );

    // Sine and cosine calculation
    sine_cosine_unit sin_cos (
        .clk(clk),
        .rst_n(rst_n),
        .theta(theta),
        .sin_theta(sin_theta),
        .cos_theta(cos_theta)
    );

    // Interpolation with edge case handling
    interpolation_unit interp (
        .clk(clk),
        .rst_n(rst_n),
        .sin_theta(sin_theta),
        .cos_theta(cos_theta),
        .t(t),
        .q1(q1),
        .q2(q2),
        .q_interp(q_interp)
    );
endmodule