module phase_extractor #(
    parameter PHASE_OFFSET = 0
) (
    input  wire         clk,
    input  wire         reset,
    input  wire         data_valid,
    input  wire [127:0] clean_point,
    output reg  [15:0]  phase_diff,
    output reg          diff_valid
);

    reg [15:0] prev_phase;  // Phase trước đó
    reg        prev_valid;  // Trạng thái valid trước đó

    // Hàm tính chênh lệch pha, xử lý wrap-around
    function automatic signed [16:0] calc_diff(input [15:0] a, b);
        logic signed [16:0] diff = a - b;
        if (diff > 32767)      return diff - 65536;
        else if (diff < -32768) return diff + 65536;
        else                   return diff;
    endfunction

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            prev_phase <= 16'b0;
            phase_diff <= 16'b0;
            diff_valid <= 1'b0;
            prev_valid <= 1'b0;
        end else begin
            diff_valid <= 1'b0;
            
            if (data_valid) begin
                wire [15:0] current_phase = clean_point[PHASE_OFFSET +: 16];
                
                if (prev_valid) begin
                    phase_diff <= calc_diff(current_phase, prev_phase)[15:0];
                    diff_valid <= 1'b1;
                end
                
                prev_phase <= current_phase;
                prev_valid <= 1'b1;
            end else begin
                prev_valid <= 1'b0;
            end
        end
    end
endmodule
