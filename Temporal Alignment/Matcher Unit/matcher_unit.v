// ==========================================================
// Matcher Unit (with binary search)
// ==========================================================
module matcher_unit #(
    parameter DATA_WIDTH = 512,
    parameter BUFFER_DEPTH = 16
)(
    input clk,
    input rst_n,
    input [63:0] t_common,
    input start,
    output logic done,
    output logic error,
    output logic [DATA_WIDTH+63:0] packet1,
    output logic [DATA_WIDTH+63:0] packet2,
    input [DATA_WIDTH+63:0] fifo_dout,
    input fifo_empty,
    output logic fifo_rd_en,
    input [ADDR_WIDTH:0] fifo_count
);

    localparam ADDR_WIDTH = $clog2(BUFFER_DEPTH);
    
    typedef enum {
        IDLE,
        INIT_SEARCH,
        BINARY_SEARCH,
        READ_SAMPLES,
        OUTPUT_DATA,
        ERROR_STATE
    } state_t;

    state_t state;
    logic [ADDR_WIDTH-1:0] low_ptr, high_ptr, mid_ptr;
    logic [63:0] mid_ts;
    logic found;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            error <= 0;
            fifo_rd_en <= 0;
            packet1 <= 0;
            packet2 <= 0;
        end else begin
            case (state)
                IDLE: begin
                    if (start && fifo_count >= 2) begin
                        state <= INIT_SEARCH;
                        low_ptr <= 0;
                        high_ptr <= fifo_count - 1;
                        found <= 0;
                    end else if (start) begin
                        state <= ERROR_STATE;
                    end
                end
                INIT_SEARCH: begin
                    state <= BINARY_SEARCH;
                end
                BINARY_SEARCH: begin
                    if (low_ptr <= high_ptr) begin
                        mid_ptr = low_ptr + ((high_ptr - low_ptr) >> 1);
                        fifo_rd_en <= 1;
                        state <= READ_MID;
                    end else begin
                        state <= ERROR_STATE;
                    end
                end
                READ_MID: begin
                    fifo_rd_en <= 0;
                    mid_ts <= fifo_dout[DATA_WIDTH +: 64];
                    if (mid_ts == t_common) begin
                        packet1 <= fifo_dout;
                        packet2 <= fifo_dout;
                        found <= 1;
                        state <= OUTPUT_DATA;
                    end else if (mid_ts < t_common) begin
                        low_ptr <= mid_ptr + 1;
                        state <= BINARY_SEARCH;
                    end else begin
                        high_ptr <= mid_ptr - 1;
                        state <= BINARY_SEARCH;
                    end
                end
                OUTPUT_DATA: begin
                    if (found) begin
                        done <= 1;
                        state <= IDLE;
                    end else begin
                        fifo_rd_en <= 1;
                        state <= READ_SAMPLES;
                    end
                end
                READ_SAMPLES: begin
                    packet1 <= fifo_dout;
                    fifo_rd_en <= 1;
                    packet2 <= fifo_dout;
                    state <= OUTPUT_DATA;
                end
                ERROR_STATE: begin
                    error <= 1;
                    done <= 1;
                    state <= IDLE;
                end
            endcase
        end
    end
endmodule