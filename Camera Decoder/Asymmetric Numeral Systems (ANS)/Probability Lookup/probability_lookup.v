// Module 1: Probability Lookup
// Chức năng: Cung cấp xác suất ký hiệu dựa trên ngữ cảnh
module probability_lookup #(
    parameter CONTEXT_WIDTH = 4,
    parameter PROB_WIDTH = 8,
    parameter NUM_SYMBOLS = 16,
    parameter NUM_CONTEXTS = 16
) (
    input logic [CONTEXT_WIDTH-1:0] context,
    output logic [PROB_WIDTH-1:0] prob_distribution [NUM_SYMBOLS-1:0]
);

    logic [PROB_WIDTH-1:0] prob_table [NUM_CONTEXTS-1:0][NUM_SYMBOLS-1:0];
    logic [CONTEXT_WIDTH-1:0] safe_context;

    // Xử lý ngữ cảnh vượt quá giới hạn
    assign safe_context = (context < NUM_CONTEXTS) ? context : 0;

    always_comb begin
        for (int i = 0; i < NUM_SYMBOLS; i++) begin
            prob_distribution[i] = prob_table[safe_context][i];
        end
    end

    // Khởi tạo bảng xác suất (ví dụ minh họa)
    initial begin
        for (int ctx = 0; ctx < NUM_CONTEXTS; ctx++) begin
            for (int sym = 0; sym < NUM_SYMBOLS; sym++) begin
                prob_table[ctx][sym] = ctx * 16 + sym;
            end
        end
    end
endmodule