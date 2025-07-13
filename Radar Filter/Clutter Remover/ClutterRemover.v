module ClutterRemover #(
    parameter N = 16  // Kích thước cửa sổ trung bình
) (
    input  wire clk,                     // Xung nhịp
    input  wire reset,                   // Tín hiệu reset
    input  wire valid_in,                // Tín hiệu hợp lệ đầu vào
    input  wire [127:0] filtered_point,  // Điểm đã lọc
    output wire valid_out,               // Tín hiệu hợp lệ đầu ra
    output wire [127:0] clean_point      // Điểm sạch
);
    wire [15:0] intensity;
    wire [15:0] threshold;
    IntensityExtractor extractor (
        .filtered_point(filtered_point),
        .intensity(intensity)
    );
    BackgroundModel #(N) bg_model (
        .clk(clk),
        .reset(reset),
        .valid_in(valid_in),
        .intensity(intensity),
        .threshold(threshold)
    );
    StaticFilter static_filter (
        .clk(clk),
        .reset(reset),
        .valid_in(valid_in),
        .filtered_point(filtered_point),
        .threshold(threshold),
        .valid_out(valid_out),
        .clean_point(clean_point)
    );
endmodule