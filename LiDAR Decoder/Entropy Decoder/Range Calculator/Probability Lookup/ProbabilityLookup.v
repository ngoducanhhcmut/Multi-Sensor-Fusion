module ProbabilityLookup (
    input wire clk,
    input wire reset,
    input wire [7:0] encoded_data,
    output reg [15:0] symbol_prob,
    output reg prob_valid
);
    reg [15:0] probability_table [0:255];

    initial begin
        integer i;
        for (i = 0; i < 256; i = i + 1) begin
            probability_table[i] = 16'h1000 + i * 16'h0100;
        end
    end

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            symbol_prob <= 16'h0000;
            prob_valid <= 1'b0;
        end
        else begin
            symbol_prob <= probability_table[encoded_data];
            prob_valid <= 1'b1;
        end
    end
endmodule