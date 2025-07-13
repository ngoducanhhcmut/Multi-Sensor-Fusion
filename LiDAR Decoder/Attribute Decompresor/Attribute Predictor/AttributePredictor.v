// Module: Attribute Predictor
module AttributePredictor #(
    parameter ATTR_WIDTH = 8,
    parameter K = 4,
    parameter MODE_WIDTH = 3
)(
    input  logic [MODE_WIDTH-1:0] prediction_mode,
    input  logic [ATTR_WIDTH-1:0] neighboring_attributes [K-1:0],
    output logic [ATTR_WIDTH-1:0] predicted_attribute
);
    logic [ATTR_WIDTH + $clog2(K):0] sum; // Tự động tính bit cần thiết

    always_comb begin
        predicted_attribute = 0;
        if (prediction_mode < K) begin
            predicted_attribute = neighboring_attributes[prediction_mode];
        end
        else if (prediction_mode == K && K > 0) begin
            sum = 0;
            for (int i = 0; i < K; i++) begin
                sum += neighboring_attributes[i];
            end
            predicted_attribute = sum / K;
        end
    end
endmodule