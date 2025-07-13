module velocity_lut #(
    parameter LUT_DEPTH = 256
) (
    input  wire         clk,
    input  wire         reset,
    input  wire         phase_valid,
    input  wire [15:0]  phase_diff,
    output reg  [15:0]  velocity,
    output reg          vel_valid
);

    reg signed [15:0] lut [0:LUT_DEPTH-1];  // LUT chứa giá trị vận tốc
    wire signed [7:0] index = phase_diff[7:0];  // Index có dấu từ 8 bit thấp nhất
    reg valid_pipe;  // Pipeline tín hiệu valid

    // Khởi tạo LUT mẫu
    initial begin
        for (int i = 0; i < LUT_DEPTH; i++) begin
            lut[i] = (i < 128) ? i : i - 256; // Giá trị từ -128 đến 127
        end
    end

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            velocity  <= 16'b0;
            vel_valid <= 1'b0;
            valid_pipe <= 1'b0;
        end else begin
            valid_pipe <= phase_valid;
            vel_valid  <= valid_pipe;
            
            if (phase_valid) begin
                velocity <= lut[index];
            end
        end
    end
endmodule