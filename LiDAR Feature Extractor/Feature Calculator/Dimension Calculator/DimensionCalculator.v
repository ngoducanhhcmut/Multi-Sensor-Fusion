// DimensionCalculator: Tính kích thước với giá trị tuyệt đối
module DimensionCalculator (
    input  logic signed [31:0] min_x, min_y, min_z,  // Tọa độ tối thiểu (Q16.16 fixed-point)
    input  logic signed [31:0] max_x, max_y, max_z,  // Tọa độ tối đa (Q16.16 fixed-point)
    output logic signed [31:0] dx, dy, dz  // Kích thước (Q16.16 fixed-point)
);
    assign dx = (max_x >= min_x) ? (max_x - min_x) : (min_x - max_x);
    assign dy = (max_y >= min_y) ? (max_y - min_y) : (min_y - max_y);
    assign dz = (max_z >= min_z) ? (max_z - min_z) : (min_z - max_z);
endmodule