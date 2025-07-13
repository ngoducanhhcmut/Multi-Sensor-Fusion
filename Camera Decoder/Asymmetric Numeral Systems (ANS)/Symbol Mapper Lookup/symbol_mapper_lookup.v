// Module 2: Symbol Mapper Lookup
// Chức năng: Ánh xạ ký hiệu đã giải mã thành phần tử cú pháp (QP, motion vector, ...)
module symbol_mapper_lookup #(
    parameter SYMBOL_WIDTH = 4,
    parameter CONTEXT_WIDTH = 4,
    parameter SYNTAX_WIDTH = 16
) (
    input logic [SYMBOL_WIDTH-1:0] symbol,
    input logic [CONTEXT_WIDTH-1:0] context,
    output logic [SYNTAX_WIDTH-1:0] syntax_element
);

    always_comb begin
        // Xử lý ngữ cảnh không xác định
        if (context >= 16) begin
            syntax_element = '0;
        end else begin
            case (context)
                4'd0: syntax_element = symbol;                   // QP
                4'd1: syntax_element = symbol << 2;              // Motion vector
                4'd2: syntax_element = symbol == 0;              // Binary flag
                4'd3: syntax_element = {8'd0, symbol, 4'd0};    // Custom format
                default: syntax_element = '1;                    // Safe default
            endcase
        end
    end
endmodule
