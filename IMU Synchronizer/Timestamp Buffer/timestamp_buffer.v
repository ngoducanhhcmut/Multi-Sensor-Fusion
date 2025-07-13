// Timestamp Buffer Module
module timestamp_buffer #(
    parameter DEPTH = 16,
    parameter PTR_WIDTH = $clog2(DEPTH)
) (
    input  logic        clk,
    input  logic        rst_n,
    input  logic [63:0] imu_data,
    input  logic [63:0] sys_time,
    input  logic        wr_en,
    output logic        full,
    output logic        empty,
    input  logic        rd_en,
    output logic [127:0] data_out,
    output logic        valid_out
);
    logic [127:0] fifo [0:DEPTH-1];
    logic [PTR_WIDTH-1:0] wr_ptr, rd_ptr;
    logic [PTR_WIDTH:0] count;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr <= '0;
            rd_ptr <= '0;
            count <= '0;
            valid_out <= 1'b0;
        end else begin
            valid_out <= 1'b0;
            if (wr_en) begin
                fifo[wr_ptr] <= {imu_data, sys_time};
                wr_ptr <= (wr_ptr == DEPTH-1) ? 0 : wr_ptr + 1;
                count <= count + 1;
            end
            if (rd_en && !empty) begin
                data_out <= fifo[rd_ptr];
                valid_out <= 1'b1;
                rd_ptr <= (rd_ptr == DEPTH-1) ? 0 : rd_ptr + 1;
                count <= count - 1;
            end
        end
    end
    assign empty = (count == 0);
    assign full = (count == DEPTH);
endmodule