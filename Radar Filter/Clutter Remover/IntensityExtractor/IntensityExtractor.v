module IntensityExtractor (
    input  wire [127:0] filtered_point,  // Điểm đã lọc
    output wire [15:0]  intensity        // Cường độ tín hiệu
);
    assign intensity = filtered_point[15:0];
endmodule