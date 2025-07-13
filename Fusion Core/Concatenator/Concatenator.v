// Concatenator Module
module Concatenator (
    input  logic [511:0] fused_feature1, // Fused feature from sensor 1 (512-bit)
    input  logic [511:0] fused_feature2, // Fused feature from sensor 2 (512-bit)
    input  logic [511:0] fused_feature3, // Fused feature from sensor 3 (512-bit)
    output logic [1535:0] raw_tensor     // 1536-bit concatenated tensor
);
    // Concatenate three 512-bit features into 1536-bit tensor
    // Order: fused_feature3 (MSB), fused_feature2, fused_feature1 (LSB)
    assign raw_tensor = {fused_feature3, fused_feature2, fused_feature1};
endmodule