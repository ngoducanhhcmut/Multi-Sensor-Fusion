module ContextUpdater (
    input wire clk,
    input wire reset,
    input wire update_en,
    input wire [15:0] decoded_symbol,
    input wire [15:0] current_context,
    output reg [15:0] new_context,
    output reg context_valid
);
    // Bảng ngữ cảnh: ánh xạ biểu tượng giải mã và ngữ cảnh hiện tại
    reg [15:0] context_table [0:255][0:255];

    // Khởi tạo bảng ngữ cảnh
    initial begin
        $readmemh("context_table.mem", context_table);
    end

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            new_context <= 16'h0000;
            context_valid <= 1'b0;
        end
        else if (update_en) begin
            if (decoded_symbol[7:0] < 256 && current_context[7:0] < 256) begin
                new_context <= context_table[decoded_symbol[7:0]][current_context[7:0]];
                context_valid <= 1'b1;
            end
            else begin
                new_context <= current_context; // Giữ nguyên nếu không hợp lệ
                context_valid <= 1'b0;
            end
        end
        else begin
            context_valid <= 1'b0;
        end
    end
endmodule