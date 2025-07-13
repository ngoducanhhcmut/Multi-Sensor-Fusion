module SymbolDecoder (
    input wire clk,
    input wire reset,
    input wire decode_en,
    input wire [7:0] symbol_code,
    output reg [15:0] decoded_symbol,
    output reg decode_valid
);
    reg [15:0] decode_table [0:255];

    initial begin
        $readmemh("decode_table.mem", decode_table);
    end

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            decoded_symbol <= 0;
            decode_valid <= 0;
        end
        else if (decode_en) begin
            decoded_symbol <= decode_table[symbol_code];
            decode_valid <= 1;
        end
        else begin
            decode_valid <= 0;
        end
    end
endmodule