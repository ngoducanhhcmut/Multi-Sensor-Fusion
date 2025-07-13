// Module 4: Symbol Decoder
// Chức năng: Giải mã ký hiệu từ luồng bit sử dụng ANS
module symbol_decoder #(
    parameter STATE_WIDTH = 32,
    parameter PROB_WIDTH = 8,
    parameter SYMBOL_WIDTH = 4,
    parameter NUM_SYMBOLS = 16,
    parameter TABLE_SIZE = 256
) (
    input logic clk,
    input logic rst,
    input logic [STATE_WIDTH-1:0] current_state,
    input logic [PROB_WIDTH-1:0] prob_distribution [NUM_SYMBOLS-1:0],
    output logic [SYMBOL_WIDTH-1:0] symbol,
    output logic [STATE_WIDTH-1:0] next_state,
    output logic symbol_valid,
    
    // Giao diện nạp bảng
    input logic table_write,
    input logic [7:0] table_addr,
    input logic [SYMBOL_WIDTH-1:0] table_symbol,
    input logic [STATE_WIDTH-1:0] table_state
);

    // Bảng giải mã có thể nạp
    logic [SYMBOL_WIDTH-1:0] decode_table [TABLE_SIZE-1:0];
    logic [STATE_WIDTH-1:0] state_table [TABLE_SIZE-1:0];
    
    // Thanh ghi an toàn cho trạng thái
    logic [STATE_WIDTH-1:0] safe_state;

    // Xử lý trạng thái không hợp lệ
    assign safe_state = (current_state >= (1 << (STATE_WIDTH-1))) ? 
                       current_state : 
                       (1 << (STATE_WIDTH-1));

    // Truy xuất bảng
    assign symbol = decode_table[safe_state[7:0]];
    assign next_state = state_table[safe_state[7:0]];
    assign symbol_valid = (safe_state != 0);

    // Cơ chế nạp bảng
    always_ff @(posedge clk) begin
        if (table_write) begin
            decode_table[table_addr] <= table_symbol;
            state_table[table_addr] <= table_state;
        end
    end

    // Khởi tạo mặc định (cho mô phỏng)
    initial begin
        for (int i = 0; i < TABLE_SIZE; i++) begin
            decode_table[i] = i % NUM_SYMBOLS;
            state_table[i] = (i + 1) << 12;
        end
    end
endmodule