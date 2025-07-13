module Data_Reassembler (
    input  logic [31:0]  median_X,
    input  logic [31:0]  median_Y,
    input  logic [31:0]  median_Z,
    input  logic [127:0] current_point,  // Điểm gốc để lấy W
    output logic [127:0] filtered_point
);

    // W field (bits [127:96]) giữ nguyên từ điểm hiện tại
    assign filtered_point = {current_point[127:96], median_Z, median_Y, median_X};
endmodule