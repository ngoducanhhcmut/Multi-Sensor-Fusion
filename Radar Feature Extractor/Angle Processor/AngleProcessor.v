module AngleProcessor #(
    parameter NUM_ANTENNAS = 4,        // Số lượng anten
    parameter PHASE_WIDTH = 16,        // Độ rộng dữ liệu pha
    parameter ANGLE_WIDTH = 64,        // Độ rộng dữ liệu góc đầu ra
    parameter FIXED_POINT_FRAC = 48    // Độ chính xác fixed-point
) (
    input wire clk,                    // Clock
    input wire reset,                  // Reset
    input wire [PHASE_WIDTH-1:0] phase_data [0:NUM_ANTENNAS-1], // Dữ liệu pha từ các anten
    output reg [ANGLE_WIDTH-1:0] angle_out     // Góc ước lượng đầu ra
);

    // Thông số hệ thống cố định (fixed-point Q16.32)
    localparam LAMBDA = 48'h0000_0C28_F5C2;    // λ = 0.03m
    localparam D = 48'h0000_061C_0000;         // d = 0.015m
    localparam TWO_PI = 48'h0006_487E_D511;    // 2π
    
    // Biến trung gian
    reg signed [PHASE_WIDTH-1:0] phase_diff [0:NUM_ANTENNAS-2];
    reg signed [47:0] sum_phase_diff; // Fixed-point accumulator (Q16.32)
    reg signed [47:0] avg_phase_diff;
    reg signed [47:0] sin_theta;
    reg signed [47:0] denominator;
    reg valid_calculation;
    
    // Tính chênh lệch pha giữa các anten liền kề
    always @(posedge clk) begin
        if (reset) begin
            for (int i = 0; i < NUM_ANTENNAS-1; i++) begin
                phase_diff[i] <= 0;
            end
        end else begin
            for (int i = 0; i < NUM_ANTENNAS-1; i++) begin
                phase_diff[i] <= $signed(phase_data[i+1]) - $signed(phase_data[i]);
            end
        end
    end
    
    // Tổng hợp và tính trung bình chênh lệch pha
    always @(posedge clk) begin
        if (reset) begin
            sum_phase_diff <= 0;
            avg_phase_diff <= 0;
            valid_calculation <= 0;
        end else begin
            sum_phase_diff <= $signed(phase_diff[0]) + $signed(phase_diff[1]) + $signed(phase_diff[2]);
            avg_phase_diff <= sum_phase_diff / (NUM_ANTENNAS-1);
            valid_calculation <= 1;
        end
    end
    
    // Tính sin(theta) và xử lý trường hợp biên
    always @(posedge clk) begin
        if (reset) begin
            sin_theta <= 0;
            denominator <= 0;
            angle_out <= 0;
        end else if (valid_calculation) begin
            denominator <= TWO_PI * D;
            if (denominator != 0) begin
                sin_theta <= (LAMBDA * avg_phase_diff) / denominator;
            end else begin
                sin_theta <= 0; // Xử lý mẫu số = 0
            end
            
            // Giới hạn sin_theta trong [-1, 1] để tránh tràn số
            if (sin_theta > 48'h0001_0000_0000) begin
                angle_out <= {{(ANGLE_WIDTH-48){1'b0}}, 48'h0001_0000_0000};
            end else if (sin_theta < -48'h0001_0000_0000) begin
                angle_out <= {{(ANGLE_WIDTH-48){1'b1}}, -48'h0001_0000_0000};
            end else begin
                angle_out <= {{(ANGLE_WIDTH-48){sin_theta[47]}}, sin_theta[47:0]};
            end
        end
    end

endmodule