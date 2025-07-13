// Module: Attribute Combiner
module AttributeCombiner #(
    parameter ATTR_WIDTH = 8
)(
    input  logic [ATTR_WIDTH-1:0]         predicted_attribute,
    input  logic signed [ATTR_WIDTH-1:0]  residual,
    output logic [ATTR_WIDTH-1:0]         final_attribute,
    output logic                          overflow_flag
);
    logic signed [ATTR_WIDTH:0] temp; // Thêm 1 bit để phát hiện tràn

    always_comb begin
        temp = $signed({1'b0, predicted_attribute}) + residual;
        overflow_flag = (temp > 2**ATTR_WIDTH-1) || (temp < 0);
        
        if (temp < 0) begin
            final_attribute = 0;
        end else if (temp > 2**ATTR_WIDTH-1) begin
            final_attribute = 2**ATTR_WIDTH-1;
        end else begin
            final_attribute = temp[ATTR_WIDTH-1:0];
        end
    end
endmodule