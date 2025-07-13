module inverse_transform #(
    parameter COEFF_WIDTH = 16,
    parameter MAX_SIZE = 32
) (
    input  logic clk,
    input  logic reset,
    input  logic start,
    output logic done,
    input  logic [1:0] transform_size,
    input  logic signed [COEFF_WIDTH-1:0] coeff_matrix[MAX_SIZE][MAX_SIZE],
    output logic signed [COEFF_WIDTH-1:0] residual_data[MAX_SIZE][MAX_SIZE]
);

    logic signed [COEFF_WIDTH-1:0] stage_buf[MAX_SIZE][MAX_SIZE];
    logic [5:0] process_steps;
    typedef enum {IDLE, ROW_PROCESS, COL_PROCESS, DONE} state_t;
    state_t state;
    logic [5:0] row_cnt, col_cnt;

    always_comb begin
        case (transform_size)
            2'b00: process_steps = 4;
            2'b01: process_steps = 8;
            2'b10: process_steps = 16;
            2'b11: process_steps = 32;
            default: process_steps = 4;
        endcase
    end

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= IDLE;
            done <= 0;
            row_cnt <= 0;
            col_cnt <= 0;
        end else begin
            case (state)
                IDLE: if (start) state <= ROW_PROCESS;
                ROW_PROCESS: if (row_cnt < process_steps) begin
                    logic signed [COEFF_WIDTH-1:0] row_data[0:31];
                    for (int j = 0; j < process_steps; j++) row_data[j] = coeff_matrix[row_cnt][j];
                    idct_1d(row_data, stage_buf[row_cnt], process_steps);
                    row_cnt <= row_cnt + 1;
                end else begin
                    state <= COL_PROCESS;
                    col_cnt <= 0;
                end
                COL_PROCESS: if (col_cnt < process_steps) begin
                    logic signed [COEFF_WIDTH-1:0] col_data[0:31], idct_col[0:31];
                    for (int i = 0; i < process_steps; i++) col_data[i] = stage_buf[i][col_cnt];
                    idct_1d(col_data, idct_col, process_steps);
                    for (int i = 0; i < process_steps; i++) residual_data[i][col_cnt] <= idct_col[i];
                    col_cnt <= col_cnt + 1;
                end else begin
                    state <= DONE;
                    done <= 1;
                end
                DONE: if (!start) begin
                    state <= IDLE;
                    done <= 0;
                end
            endcase
        end
    end

    function automatic void idct_1d(input logic signed [COEFF_WIDTH-1:0] in_data[0:31],
                                   output logic signed [COEFF_WIDTH-1:0] out_data[0:31],
                                   input integer size);
        // Ghi chú: Cần triển khai IDCT chuẩn cho từng kích thước; tạm dùng nhân đơn giản
        for (int i = 0; i < size; i++) out_data[i] = in_data[i] * 64 >>> 6;
    endfunction
endmodule