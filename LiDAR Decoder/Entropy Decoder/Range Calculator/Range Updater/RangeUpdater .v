module RangeUpdater (
    input wire clk,
    input wire reset,
    input wire update_en,
    input wire [15:0] range_current,
    input wire [15:0] cum_prob,
    input wire [15:0] total_prob,
    output reg [15:0] range_updated,
    output reg overflow_flag
);
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            range_updated <= 16'h0000;
            overflow_flag <= 1'b0;
        end
        else if (update_en) begin
            if (total_prob == 16'h0000 || cum_prob >= total_prob) begin
                range_updated <= range_current;
                overflow_flag <= 1'b1;
            end
            else begin
                range_updated <= (range_current * cum_prob) / total_prob;
                overflow_flag <= 1'b0;
            end
        end
    end
endmodule
