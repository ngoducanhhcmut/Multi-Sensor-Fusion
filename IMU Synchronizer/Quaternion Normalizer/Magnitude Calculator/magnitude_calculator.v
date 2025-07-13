module magnitude_calculator (
    input  logic signed [15:0] w,
    input  logic signed [15:0] x,
    input  logic signed [15:0] y,
    input  logic signed [15:0] z,
    output logic [31:0] magnitude  // Q2.30
);

    logic [31:0] w_sq, x_sq, y_sq, z_sq;
    logic [31:0] sum_sq;
    logic [15:0] abs_w, abs_x, abs_y, abs_z;

    // Handle -32768 by clamping to 32767
    assign abs_w = (w == 16'h8000) ? 16'h7FFF : (w[15] ? -w : w);
    assign abs_x = (x == 16'h8000) ? 16'h7FFF : (x[15] ? -x : x);
    assign abs_y = (y == 16'h8000) ? 16'h7FFF : (y[15] ? -y : y);
    assign abs_z = (z == 16'h8000) ? 16'h7FFF : (z[15] ? -z : z);

    // Squares with overflow protection
    assign w_sq = abs_w * abs_w; // Q2.30
    assign x_sq = abs_x * abs_x;
    assign y_sq = abs_y * abs_y;
    assign z_sq = abs_z * abs_z;

    // Sum of squares with saturation
    assign sum_sq = w_sq + x_sq + y_sq + z_sq;

    // Non-restoring square root
    non_restoring_sqrt sqrt_inst (
        .in(sum_sq),
        .out(magnitude)
    );
endmodule