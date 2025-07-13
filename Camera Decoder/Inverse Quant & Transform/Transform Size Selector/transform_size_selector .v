module transform_size_selector (
    input  logic [7:0] syntax_elements,
    input  logic [1:0] cu_size,
    output logic [1:0] transform_size
);

    always_comb begin
        if (cu_size == 2'b00) begin // 8x8
            transform_size = syntax_elements[0] ? 2'b00 : 2'b01;
        end else if (cu_size == 2'b01) begin // 16x16
            case (syntax_elements[1:0])
                2'b00: transform_size = 2'b00;
                2'b01: transform_size = 2'b01;
                2'b10: transform_size = 2'b10;
                default: transform_size = 2'b00;
            endcase
        end else begin // >= 32x32
            transform_size = syntax_elements[3] ? 2'b11 : 2'b10;
        end
    end
endmodule