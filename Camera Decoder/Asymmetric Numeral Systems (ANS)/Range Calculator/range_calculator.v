// Module 3: Range Calculator
// Chức năng: Quản lý phạm vi giải mã ANS và xử lý dữ liệu slice mã hóa
module range_calculator #(
    parameter BITSTREAM_WIDTH = 32,
    parameter STATE_WIDTH = 32
) (
    input logic clk,
    input logic rst,
    input logic [BITSTREAM_WIDTH-1:0] bitstream_in,
    input logic bitstream_valid,
    output logic [STATE_WIDTH-1:0] state,
    output logic state_valid,
    input logic state_update,
    input logic [STATE_WIDTH-1:0] next_state
);

    // FIFO cho dữ liệu bitstream (kích thước 4)
    logic [BITSTREAM_WIDTH-1:0] bit_fifo [3:0];
    logic [1:0] fifo_head, fifo_tail;
    logic fifo_empty, fifo_full;
    logic [2:0] fifo_count;

    // Thanh ghi trạng thái
    logic [STATE_WIDTH-1:0] current_state;
    logic state_need_renorm;

    // Ngưỡng renormalization
    localparam RENORM_THRESH = 32'h1000;

    // Logic điều khiển FIFO
    always_ff @(posedge clk) begin
        if (rst) begin
            fifo_head <= 2'b0;
            fifo_tail <= 2'b0;
            fifo_count <= 3'b0;
        end else begin
            if (bitstream_valid && !fifo_full) begin
                bit_fifo[fifo_tail] <= bitstream_in;
                fifo_tail <= fifo_tail + 1;
                fifo_count <= fifo_count + 1;
            end
            if (state_update && state_need_renorm && !fifo_empty) begin
                fifo_head <= fifo_head + 1;
                fifo_count <= fifo_count - 1;
            end
        end
    end

    assign fifo_empty = (fifo_count == 0);
    assign fifo_full = (fifo_count == 4);

    // Logic cập nhật trạng thái
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            current_state <= RENORM_THRESH;
            state_valid <= 1'b1;
        end else if (state_update) begin
            state_need_renorm <= (next_state < RENORM_THRESH);
            if (!state_need_renorm) begin
                current_state <= next_state;
                state_valid <= 1'b1;
            end else if (!fifo_empty) begin
                current_state <= {next_state[STATE_WIDTH-BITSTREAM_WIDTH-1:0], bit_fifo[fifo_head]};
                state_valid <= 1'b1;
            end else begin
                current_state <= current_state;
                state_valid <= 1'b0;
            end
        end
    end

    assign state = current_state;
endmodule