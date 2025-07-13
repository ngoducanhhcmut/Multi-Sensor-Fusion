module SymbolMapper (
    input wire clk,
    input wire reset,
    input wire mapper_en,
    input wire [15:0] decoded_range,
    output reg [15:0] decoded_symbol,
    output reg mapper_valid,
    output reg mapper_error
);
    wire [7:0] symbol_code;
    wire lookup_valid;
    wire lookup_error;
    wire decode_valid;

    SymbolTableLookup u_lookup (
        .clk(clk),
        .reset(reset),
        .lookup_en(mapper_en),
        .decoded_range(decoded_range),
        .symbol_code(symbol_code),
        .lookup_valid(lookup_valid),
        .lookup_error(lookup_error)
    );

    SymbolDecoder u_decoder (
        .clk(clk),
        .reset(reset),
        .decode_en(lookup_valid),
        .symbol_code(symbol_code),
        .decoded_symbol(decoded_symbol),
        .decode_valid(decode_valid)
    );

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            mapper_valid <= 1'b0;
            mapper_error <= 1'b0;
        end
        else begin
            if (lookup_error) begin
                mapper_valid <= 1'b0;
                mapper_error <= 1'b1;
            end
            else if (decode_valid) begin
                mapper_valid <= 1'b1;
                mapper_error <= 1'b0;
            end
            else begin
                mapper_valid <= 1'b0;
                mapper_error <= 1'b0;
            end
        end
    end
endmodule