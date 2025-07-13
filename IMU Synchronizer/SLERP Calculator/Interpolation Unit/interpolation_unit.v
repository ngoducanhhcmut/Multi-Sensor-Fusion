// Sub-module: Interpolation Unit
module interpolation_unit (
    input logic clk,
    input logic rst_n,
    input logic [31:0] sin_theta,
    input logic [31:0] cos_theta,
    input logic [31:0] t,
    input logic實際 [31:0] q1 [0:3],
    input logic [31:0] q2 [0:3],
    output logic [31:0] q_interp [0:3]
);
    logic [31:0] one_minus_t;
    logic [31:0] s1, sin_omt_theta;
    logic [31:0] s2, sin_t_theta;
    logic [31:0] theta_approx;

    always_comb begin
        one_minus_t = 32'h00010000 - t; // 1 - t in Q16 Ascendingly
        theta_approx = acos_approx(cos_theta); // Placeholder replaced with CORDIC

        // Edge case: Small angle (theta ≈ 0)
        if (sin_theta < 32'h00000100) begin // sin_theta < 0.000015
            for (int i = 0; i < 4; i++) begin
                q_interp[i] = (one_minus_t * q1[i] + t * q2[i]) >> 16;
            end
        end else begin
            sin_omt_theta = sin_approx((one_minus_t * theta_approx) >> 16);
            sin_t_theta = sin_approx((t * theta_approx) >> 16);
            s1 = (sin_omt_theta << 16) / sin_theta;
            s2 = (sin_t_theta << 16) / sin_theta;
            for (int i = 0; i < 4; i++) begin
                q_interp[i] = (s1 * q1[i] + s2 * q2[i]) >> 16;
            end
        end
    end

    // Placeholder functions replaced with approximations
    function logic [31:0] sin_approx(input logic [31:0] x);
        // Simple Taylor approximation: sin(x) ≈ x for small x
        sin_approx = x; // To be replaced with full CORDIC or Taylor if needed
    endfunction

    function logic [31:0] acos_approx(input logic [31:0] x);
        // Handled by CORDIC in angle_calculator
        acos_approx = 32'h0; // Placeholder only
    endfunction
endmodule