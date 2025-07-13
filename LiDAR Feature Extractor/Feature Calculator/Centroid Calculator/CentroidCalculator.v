// CentroidCalculator: Tính tâm với số có dấu và kiểm tra lỗi
module CentroidCalculator (
    input  logic signed [31:0] min_x, min_y, min_z,  // Tọa độ tối thiểu (Q16.16 fixed-point)
    input  logic signed [31:0] max_x, max_y, max_z,  // Tọa độ tối đa (Q16.16 fixed-point)
    output logic signed [31:0] centroid_x, centroid_y, centroid_z,  // Tọa độ tâm (Q16.16 fixed-point)
    output logic error  // Cờ báo lỗi
);
    assign error = (min_x > max_x) || (min_y > max_y) || (min_z > max_z);
    assign centroid_x = error ? 32'sh0 : ((min_x + max_x) >>> 1);  // Dịch số học giữ dấu
    assign centroid_y = error ? 32'sh0 : ((min_y + max_y) >>> 1);
    assign centroid_z = error ? 32'sh0 : ((min_z + max_z) >>> 1);
endmodule