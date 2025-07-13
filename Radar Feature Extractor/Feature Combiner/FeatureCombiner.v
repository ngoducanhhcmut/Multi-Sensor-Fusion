module FeatureCombiner #(
    parameter RANGE_WIDTH = 128,       // Độ rộng vector khoảng cách
    parameter VELOCITY_WIDTH = 64,     // Độ rộng vector vận tốc
    parameter ANGLE_WIDTH = 64,        // Độ rộng vector góc
    parameter FEATURE_WIDTH = 256      // Độ rộng vector đặc trưng
) (
    input wire clk,                    // Clock
    input wire reset,                  // Reset
    input wire valid_in,               // Tín hiệu hợp lệ đầu vào
    input wire [RANGE_WIDTH-1:0] range_vector,      // Vector khoảng cách
    input wire [VELOCITY_WIDTH-1:0] velocity_vector,// Vector vận tốc
    input wire [ANGLE_WIDTH-1:0] angle_vector,      // Vector góc
    output reg [FEATURE_WIDTH-1:0] feature_vector,  // Vector đặc trưng đầu ra
    output reg valid_out               // Tín hiệu hợp lệ đầu ra
);

    // Kiểm tra kích thước tại thời điểm biên dịch
    generate
        if (RANGE_WIDTH + VELOCITY_WIDTH + ANGLE_WIDTH != FEATURE_WIDTH) begin
            initial $fatal("Error: Tổng kích thước đầu vào (%0d + %0d + %0d = %0d) không khớp với FEATURE_WIDTH (%0d)",
                RANGE_WIDTH, VELOCITY_WIDTH, ANGLE_WIDTH, 
                RANGE_WIDTH + VELOCITY_WIDTH + ANGLE_WIDTH, FEATURE_WIDTH);
        end
    endgenerate

    // Kết hợp dữ liệu với tín hiệu điều khiển
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            feature_vector <= 0;
            valid_out <= 0;
        end else if (valid_in) begin
            feature_vector <= {range_vector, velocity_vector, angle_vector};
            valid_out <= 1;
        end else begin
            valid_out <= 0;
        end
    end

endmodule