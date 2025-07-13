// Module: Attribute Residual Extractor
module AttributeResidualExtractor #(
    parameter SYMBOL_WIDTH = 8,
    parameter ATTR_WIDTH = 8
)(
    input  logic [SYMBOL_WIDTH-1:0] residual_symbol,
    output logic signed [ATTR_WIDTH-1:0] residual
);
    always_comb begin
        if (SYMBOL_WIDTH >= ATTR_WIDTH) begin
            residual = residual_symbol[ATTR_WIDTH-1:0];
        end else begin
            residual = {{(ATTR_WIDTH-SYMBOL_WIDTH){residual_symbol[SYMBOL_WIDTH-1]}}, 
                       residual_symbol};
        end
    end
endmodule