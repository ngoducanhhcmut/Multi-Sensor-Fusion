// Module: Matrix Multiplier
// Chuyển đổi YUV sang RGB bằng ma trận 3x3
module matrix_multiplier #(
    parameter int C11 = 16'h0100, // 1.0 in Q8.8
    parameter int C12 = 16'h0000, // 0.0
    parameter int C13 = 16'h0166, // ~1.402 in Q8.8 (BT.601)
    parameter int C21 = 16'h0100, // 1.0
    parameter int C22 = 16'hFF58, // ~-0.344 in Q8.8
    parameter int C23 = 16'hFF49, // ~-0.714 in Q8.8
    parameter int C31 = 16'h0100, // 1.0
    parameter int C32 = 16'h01C5, // ~1.772 in Q8.8
    parameter int C33 = 16'h0000  // 0.0
)(
    input  logic [7:0]  Y,
    input  logic [7:0]  U,
    input  logic [7:0]  V,
    output logic [7:0]  R,
    output logic [7:0]  G,
    output logic [7:0]  B
);
    logic signed [23:0] temp_R, temp_G, temp_B;

    always_comb begin
        // Tính R = Y + 1.402 * (V - 128)
        logic signed [8:0]  V_diff = V - 8'd128;
        logic signed [24:0] prod_R  = V_diff * $signed(C13);
        temp_R = (Y << 8) + (prod_R >>> 8);

        // Tính G = Y - 0.344 * (U - 128) - 0.714 * (V - 128)
        logic signed [8:0]  U_diff = U - 8'd128;
        logic signed [24:0] prod_G1 = U_diff * $signed(C22);
        logic signed [24:0] prod_G2 = V_diff * $signed(C23);
        temp_G = (Y << 8) + (prod_G1 >>> 8) + (prod_G2 >>> 8);

        // Tính B = Y + 1.772 * (U - 128)
        logic signed [24:0] prod_B  = U_diff * $signed(C32);
        temp_B = (Y << 8) + (prod_B >>> 8);

        // Saturation để đảm bảo R, G, B nằm trong [0, 255]
        R = (temp_R[23]) ? 8'd0 : (temp_R[15:8] > 255) ? 8'd255 : temp_R[15:8];
        G = (temp_G[23]) ? 8'd0 : (temp_G[15:8] > 255) ? 8'd255 : temp_G[15:8];
        B = (temp_B[23]) ? 8'd0 : (temp_B[15:8] > 255) ? 8'd255 : temp_B[15:8];
    end
endmodule
