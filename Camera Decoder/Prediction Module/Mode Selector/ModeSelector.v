module ModeSelector (
    input  logic [7:0] pred_mode,       // Phần tử cú pháp pred_mode
    output logic       prediction_mode,  // 0: Intra, 1: Inter
    output logic       mode_valid        // 1: Mode hợp lệ, 0: Lỗi
);
    always_comb begin
        mode_valid = 1'b1;
        case (pred_mode)
            8'h00: prediction_mode = 1'b0;  // Intra
            8'h01: prediction_mode = 1'b1;  // Inter
            default: begin
                prediction_mode = 1'b0;     // Mặc định Intra
                mode_valid = 1'b0;          // Báo lỗi mode
            end
        endcase
    end
endmodule