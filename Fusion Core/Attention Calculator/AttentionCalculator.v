// Attention Calculator Module
module AttentionCalculator #(
    parameter int SHIFT_AMOUNT = 2,        // sqrt(6) ≈ 2.45 → shift 2 bits ≈ /4
    parameter logic [63:0] LINEAR_NORM = 0 // LinearNorm as a constant, default 0
) (
    input  logic [191:0] Q,    // 192-bit Q vector (6x32-bit fixed-point)
    input  logic [191:0] K,    // 192-bit K vector (6x32-bit fixed-point)
    output logic [63:0] attention_weight // 64-bit attention score
);
    logic [95:0] dot_product_wide; // 96-bit accumulator

    always_comb begin
        dot_product_wide = 96'd0;
        // Compute dot product: Q · K
        for (int i = 0; i < 6; i++) begin
            logic signed [31:0] Q_i = Q[i*32 +: 32];
            logic signed [31:0] K_i = K[i*32 +: 32];
            logic signed [63:0] prod = Q_i * K_i; // 64-bit product
            dot_product_wide = dot_product_wide + {{32{prod[63]}}, prod}; // Sign-extend to 96-bit
        end
        // Compute attention score: (dot_product / sqrt(d)) + LinearNorm
        logic [95:0] shifted = $signed(dot_product_wide) >>> SHIFT_AMOUNT;
        logic [95:0] normalized = shifted + {{32{LINEAR_NORM[63]}}, LINEAR_NORM};
        // Check for overflow
        if (normalized[95:64] != {32{normalized[63]}}) begin
            attention_weight = normalized[63] ? 64'h8000_0000_0000_0000 : 64'h7FFF_FFFF_FFFF_FFFF;
        end else begin
            attention_weight = normalized[63:0];
        end
    end
endmodule