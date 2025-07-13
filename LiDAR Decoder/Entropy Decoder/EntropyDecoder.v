module EntropyDecoder (
    input wire clk,                     // Clock tín hiệu
    input wire reset,                   // Reset tín hiệu
    input wire decode_en,               // Enable để kích hoạt giải mã
    input wire [7:0] encoded_data,      // Dữ liệu mã hóa (8-bit)
    input wire [15:0] bitstream,        // Bitstream để chuẩn hóa range
    output reg [15:0] decoded_symbol,   // Biểu tượng giải mã
    output reg decode_valid,            // Cờ báo kết quả hợp lệ
    output reg decode_error             // Cờ báo lỗi
);

    // Tín hiệu trung gian
    wire [15:0] decoded_range;          // Phạm vi giải mã từ RangeCalculator
    wire range_error;                   // Cờ lỗi từ RangeCalculator
    wire [15:0] mapped_symbol;          // Biểu tượng từ SymbolMapper
    wire mapper_valid;                  // Cờ hợp lệ từ SymbolMapper
    wire mapper_error;                  // Cờ lỗi từ SymbolMapper
    wire [15:0] new_context;            // Ngữ cảnh mới từ ContextUpdater
    wire context_valid;                 // Cờ hợp lệ từ ContextUpdater

    // Thanh ghi lưu trữ ngữ cảnh hiện tại
    reg [15:0] current_context;

    // Khởi tạo các module con
    RangeCalculator u_range_calc (
        .clk(clk),
        .reset(reset),
        .init_pulse(decode_en),
        .update_en(decode_en),
        .normalize_en(decode_en),
        .encoded_data(encoded_data),
        .bitstream(bitstream),
        .decoded_range(decoded_range),
        .error_flag(range_error)
    );

    SymbolMapper u_symbol_map (
        .clk(clk),
        .reset(reset),
        .mapper_en(decode_en),
        .decoded_range(decoded_range),
        .decoded_symbol(mapped_symbol),
        .mapper_valid(mapper_valid),
        .mapper_error(mapper_error)
    );

    ContextUpdater u_context_update (
        .clk(clk),
        .reset(reset),
        .update_en(mapper_valid),
        .decoded_symbol(mapped_symbol),
        .current_context(current_context),
        .new_context(new_context),
        .context_valid(context_valid)
    );

    // Logic điều khiển chính
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            decoded_symbol <= 16'h0000;
            decode_valid <= 1'b0;
            decode_error <= 1'b0;
            current_context <= 16'h0000; // Khởi tạo ngữ cảnh mặc định
        end
        else if (decode_en) begin
            if (range_error || mapper_error || !context_valid) begin
                decoded_symbol <= 16'h0000;
                decode_valid <= 1'b0;
                decode_error <= 1'b1;
            end
            else if (mapper_valid) begin
                decoded_symbol <= mapped_symbol;
                decode_valid <= 1'b1;
                decode_error <= 1'b0;
                current_context <= new_context; // Cập nhật ngữ cảnh
            end
            else begin
                decode_valid <= 1'b0;
                decode_error <= 1'b0;
            end
        end
    end
endmodule