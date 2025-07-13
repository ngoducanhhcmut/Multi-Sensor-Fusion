module StaticFilter (
    input  wire clk,                     // Xung nhịp
    input  wire reset,                   // Tín hiệu reset
    input  wire valid_in,                // Tín hiệu hợp lệ đầu vào
    input  wire [127:0] filtered_point,  // Điểm đã lọc
    input  wire [15:0]  threshold,       // Ngưỡng nhiễu
    output reg  valid_out,               // Tín hiệu hợp lệ đầu ra
    output reg  [127:0] clean_point      // Điểm sạch
);
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            valid_out <= 0;
            clean_point <= 0;
        end else begin
            valid_out <= valid_in;
            if (valid_in) begin
                if (filtered_point[15:0] >= threshold) begin
                    clean_point <= filtered_point;
                end else begin
                    clean_point <= {16'h0000, filtered_point[111:0]};
                end
            end else begin
                clean_point <= clean_point;  // Giữ giá trị hiện tại
            end
        end
    end
endmodule