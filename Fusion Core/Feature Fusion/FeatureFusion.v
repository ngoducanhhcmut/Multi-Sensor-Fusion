// Feature Fusion Module
module FeatureFusion (
    input  logic [63:0] attention_weight, // 64-bit attention weight
    input  logic [191:0] V,               // 192-bit V vector (6x32-bit fixed-point)
    output logic [511:0] fused_feature    // 512-bit fused feature
);
    logic [31:0] scaled_V [0:5]; // Array to hold scaled V elements

    for (genvar i = 0; i < 6; i++) begin : scale_block
        always_comb begin
            logic signed [31:0] V_i = V[i*32 +: 32];
            logic signed [95:0] full_prod = $signed(attention_weight) * $signed(V_i); // 64-bit * 32-bit = 96-bit
            logic signed [95:0] shifted_prod = full_prod >>> 16; // Shift right 16 bits for Q16.16
            // Check for overflow in 32-bit
            if (shifted_prod[95:32] != {64{shifted_prod[31]}}) begin
                scaled_V[i] = shifted_prod[31] ? 32'h8000_0000 : 32'h7FFF_FFFF;
            end else begin
                scaled_V[i] = shifted_prod[31:0];
            end
        end
    end

    // Expand 192-bit scaled vector to 512-bit with zero padding
    assign fused_feature = {{320{1'b0}}, // 320-bit zero padding
                           scaled_V[5], scaled_V[4], scaled_V[3],
                           scaled_V[2], scaled_V[1], scaled_V[0]}; // 192-bit scaled V
endmodule
