module RangeNormalizer (
    input wire clk,
    input wire reset,
    input wire normalize_en,
    input wire [15:0] range_updated,
    input wire [15:0] bitstream,
    output reg [15:0] range_normalized,
    output reg [15:0] new_bitstream,
    output reg underflow_flag
);
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            range_normalized <= 16'h0000;
            new_bitstream <= 16'h0000;
            underflow_flag <= 1'b0;
        end
        else if (normalize_en) begin
            if (range_updated == 16'h0000) begin
                range_normalized <= 16'h0000;
                underflow_flag <= 1'b1;
            end
            else if (range_updated < 16'h8000) begin
                range_normalized <= range_updated << 1;
                new_bitstream <= bitstream >> 1;
                underflow_flag <= (bitstream == 16'h0000);
            end
            else begin
                range_normalized <= range_updated;
                new_bitstream <= bitstream;
                underflow_flag <= 1'b0;
            end
        end
    end
endmodule