module Point_Packer (
    input  wire         clk,          // Clock đồng bộ
    input  wire         rst_n,        // Reset tích cực mức thấp
    input  wire [127:0] clean_point,  // Đầu vào: Điểm sạch 128-bit từ Clutter Remover
    input  wire [15:0]  velocity,     // Đầu vào: Vận tốc 16-bit từ Doppler Processor
    output reg  [127:0] point_cloud_data // Đầu ra: Đám mây điểm radar 128-bit
);

// Pipeline đăng ký đầu ra
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        point_cloud_data <= 128'b0; // Khởi tạo đầu ra về 0 khi reset
    end
    else begin
        point_cloud_data <= {clean_point[127:16], velocity}; // Ghép 112 bit cao của clean_point với 16 bit velocity
    end
end

endmodule