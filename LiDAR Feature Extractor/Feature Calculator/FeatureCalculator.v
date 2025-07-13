// FeatureCalculator: Tích hợp Centroid và Dimension
module FeatureCalculator (
    input  logic signed [31:0] min_x, min_y, min_z,  // Tọa độ tối thiểu (Q16.16 fixed-point)
    input  logic signed [31:0] max_x, max_y, max_z,  // Tọa độ tối đa (Q16.16 fixed-point)
    output logic signed [31:0] centroid_x, centroid_y, centroid_z,  // Tọa độ tâm (Q16.16 fixed-point)
    output logic signed [31:0] dx, dy, dz,  // Kích thước (Q16.16 fixed-point)
    output logic error  // Cờ báo lỗi
);
    CentroidCalculator centroid_calc (
        .min_x(min_x), .min_y(min_y), .min_z(min_z),
        .max_x(max_x), .max_y(max_y), .max_z(max_z),
        .centroid_x(centroid_x), .centroid_y(centroid_y), .centroid_z(centroid_z),
        .error(error)
    );
    
    DimensionCalculator dimension_calc (
        .min_x(min_x), .min_y(min_y), .min_z(min_z),
        .max_x(max_x), .max_y(max_y), .max_z(max_z),
        .dx(dx), .dy(dy), .dz(dz)
    );
endmodule