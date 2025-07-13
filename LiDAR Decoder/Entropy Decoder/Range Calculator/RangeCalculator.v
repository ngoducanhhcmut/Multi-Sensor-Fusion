module RangeCalculator (
    input wire clk,
    input wire reset,
    input wire init_pulse,
    input wire update_en,
    input wire normalize_en,
    input wire [7:0] encoded_data,
    input wire [15:0] bitstream,
    output reg [15:0] decoded_range,
    output reg error_flag
);
    wire [15:0] range_initial;
    wire [15:0] symbol_prob;
    wire prob_valid;
    wire [15:0] range_updated;
    wire overflow_flag;
    wire [15:0] range_normalized;
    wire [15:0] new_bitstream;
    wire underflow_flag;

    RangeInitializer u_range_init (
        .clk(clk),
        .reset(reset),
        .init_pulse(init_pulse),
        .range_initial(range_initial)
    );

    ProbabilityLookup u_prob_lookup (
        .clk(clk),
        .reset(reset),
        .encoded_data(encoded_data),
        .symbol_prob(symbol_prob),
        .prob_valid(prob_valid)
    );

    RangeUpdater u_range_update (
        .clk(clk),
        .reset(reset),
        .update_en(update_en),
        .range_current(range_initial),
        .cum_prob(symbol_prob),
        .total_prob(16'hFFFF),
        .range_updated(range_updated),
        .overflow_flag(overflow_flag)
    );

    RangeNormalizer u_range_norm (
        .clk(clk),
        .reset(reset),
        .normalize_en(normalize_en),
        .range_updated(range_updated),
        .bitstream(bitstream),
        .range_normalized(range_normalized),
        .new_bitstream(new_bitstream),
        .underflow_flag(underflow_flag)
    );

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            decoded_range <= 16'h0000;
            error_flag <= 1'b0;
        end
        else if (normalize_en) begin
            if (!prob_valid || overflow_flag || underflow

_flag) begin
                decoded_range <= 16'h0000;
                error_flag <= 1'b1;
            end
            else begin
                decoded_range <= range_normalized;
                error_flag <= 1'b0;
            end
        end
    end
endmodule
