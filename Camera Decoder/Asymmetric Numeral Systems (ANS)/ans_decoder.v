// Module 5: ANS Decoder (Top-Level)
// Chức năng: Kết hợp các module con để giải mã ANS
module ans_decoder #(
    parameter BITSTREAM_WIDTH = 32,
    parameter STATE_WIDTH = 32,
    parameter CONTEXT_WIDTH = 4,
    parameter PROB_WIDTH = 8,
    parameter SYMBOL_WIDTH = 4,
    parameter SYNTAX_WIDTH = 16,
    parameter NUM_SYMBOLS = 16
) (
    input logic clk,
    input logic rst,
    input logic [BITSTREAM_WIDTH-1:0] bitstream_in,
    input logic bitstream_valid,
    input logic [CONTEXT_WIDTH-1:0] context,
    output logic [SYNTAX_WIDTH-1:0] syntax_element,
    output logic syntax_valid,
    
    // Tín hiệu điều khiển luồng
    input logic ready,
    output logic data_request
);

    // Tín hiệu nội bộ
    logic [STATE_WIDTH-1:0] current_state, next_state;
    logic [PROB_WIDTH-1:0] prob_distribution [NUM_SYMBOLS-1:0];
    logic [SYMBOL_WIDTH-1:0] symbol;
    logic state_valid, symbol_valid;

    // Pipeline register
    logic [SYMBOL_WIDTH-1:0] symbol_reg;
    logic [CONTEXT_WIDTH-1:0] context_reg;
    logic symbol_valid_reg;

    // Kiểm soát luồng dữ liệu
    assign data_request = (state_valid && ready);

    // Pipeline stage
    always_ff @(posedge clk) begin
        if (rst) begin
            symbol_reg <= 0;
            context_reg <= 0;
            symbol_valid_reg <= 0;
        end else if (ready) begin
            symbol_reg <= symbol;
            context_reg <= context;
            symbol_valid_reg <= symbol_valid && state_valid;
        end
    end

    // Instantiate modules
    probability_lookup prob_lookup (.*);
    
    range_calculator range_calc (
        .clk(clk),
        .rst(rst),
        .bitstream_in(bitstream_in),
        .bitstream_valid(bitstream_valid && data_request),
        .state(current_state),
        .state_valid(state_valid),
        .state_update(symbol_valid && ready),
        .next_state(next_state)
    );
    
    symbol_decoder sym_decoder (
        .clk(clk),
        .rst(rst),
        .current_state(current_state),
        .prob_distribution(prob_distribution),
        .symbol(symbol),
        .next_state(next_state),
        .symbol_valid(symbol_valid)
    );
    
    symbol_mapper_lookup sym_mapper (
        .symbol(symbol_reg),
        .context(context_reg),
        .syntax_element(syntax_element)
    );

    // Đầu ra hợp lệ
    assign syntax_valid = symbol_valid_reg && ready;
endmodule