module AttributeDecompressor #(
    parameter ATTR_WIDTH = 8,
    parameter K = 4,
    parameter MODE_WIDTH = 3,
    parameter SYMBOL_WIDTH = 8
)(
    input  logic clk,
    input  logic rst_n,
    input  logic [SYMBOL_WIDTH-1:0] decoded_symbols [1:0],
    input  logic [ATTR_WIDTH-1:0]   neighboring_attributes [K-1:0],
    output logic [ATTR_WIDTH-1:0]   final_attribute,
    output logic                    error_flag
);
    // Tín hiệu nội bộ
    logic [MODE_WIDTH-1:0]        prediction_mode;
    logic [SYMBOL_WIDTH-1:0]      residual_symbol;
    logic [ATTR_WIDTH-1:0]        predicted_attribute;
    logic signed [ATTR_WIDTH-1:0] residual;
    logic                         predictor_error;
    logic                         overflow_flag;

    // Phân tích input
    assign prediction_mode = decoded_symbols[0][MODE_WIDTH-1:0];
    assign residual_symbol = decoded_symbols[1];

    // Kiểm tra lỗi mode
    assign predictor_error = (prediction_mode > K);

    // Khối con
    AttributePredictor #(
        .ATTR_WIDTH(ATTR_WIDTH),
        .K(K),
        .MODE_WIDTH(MODE_WIDTH)
    ) predictor (
        .prediction_mode(prediction_mode),
        .neighboring_attributes(neighboring_attributes),
        .predicted_attribute(predicted_attribute)
    );

    AttributeResidualExtractor #(
        .SYMBOL_WIDTH(SYMBOL_WIDTH),
        .ATTR_WIDTH(ATTR_WIDTH)
    ) extractor (
        .residual_symbol(residual_symbol),
        .residual(residual)
    );

    AttributeCombiner #(
        .ATTR_WIDTH(ATTR_WIDTH)
    ) combiner (
        .predicted_attribute(predicted_attribute),
        .residual(residual),
        .final_attribute(final_attribute),
        .overflow_flag(overflow_flag)
    );

    // Tổng hợp lỗi
    assign error_flag = predictor_error || overflow_flag;

    // Pipeline register (tùy chọn)
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            final_attribute <= 0;
        end else begin
            final_attribute <= combiner.final_attribute;
        end
    end
endmodule