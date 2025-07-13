module inverse_quantizer #(
    parameter COEFF_WIDTH = 16,
    parameter QP_WIDTH = 6,
    parameter BIT_DEPTH = 8
) (
    input  logic signed [COEFF_WIDTH-1:0] quantized_coeff,
    input  logic [QP_WIDTH-1:0]           QP,
    output logic signed [COEFF_WIDTH-1:0] coeff
);

    localparam SF_WIDTH = 20;
    localparam logic [SF_WIDTH-1:0] scale_factor [0:5] = '{
        40 * (1 << 14), 45 * (1 << 14), 51 * (1 << 14),
        57 * (1 << 14), 64 * (1 << 14), 72 * (1 << 14)
    };

    logic [5:0] shift_amount = QP / 6;
    logic [2:0] scale_idx = QP % 6;
    logic signed [35:0] temp_product;
    logic signed [COEFF_WIDTH-1:0] scaled_coeff;

    always_comb begin
        if (QP >= 52) begin
            coeff = 0;
        end else begin
            temp_product = quantized_coeff * scale_factor[scale_idx];
            scaled_coeff = temp_product >>> (14 + BIT_DEPTH - 8 - shift_amount);
            coeff = (scaled_coeff >  (2**(COEFF_WIDTH-1)-1)) ?  (2**(COEFF_WIDTH-1)-1) :
                    (scaled_coeff < -(2**(COEFF_WIDTH-1)))   ? -(2**(COEFF_WIDTH-1))   :
                    scaled_coeff;
        end
    end
endmodule