// ==========================================================
// Sensor Data Buffer (FIFO with timestamp)
// ==========================================================
module sensor_data_buffer #(
    parameter DATA_WIDTH = 512,
    parameter BUFFER_DEPTH = 16,
    parameter ADDR_WIDTH = $clog2(BUFFER_DEPTH)
)(
    input clk,
    input rst_n,
    input wr_en,
    input [DATA_WIDTH+63:0] din,  // {data, timestamp}
    input rd_en,
    output logic [DATA_WIDTH+63:0] dout,
    output logic full,
    output logic empty,
    output logic [ADDR_WIDTH:0] count
);

    logic [DATA_WIDTH+63:0] mem [0:BUFFER_DEPTH-1];
    logic [ADDR_WIDTH-1:0] wr_ptr, rd_ptr;
    logic [ADDR_WIDTH:0] item_count;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr <= 0;
            rd_ptr <= 0;
            item_count <= 0;
            empty <= 1;
            full <= 0;
            for (int i = 0; i < BUFFER_DEPTH; i++) mem[i] <= 0;
        end else begin
            if (wr_en && !full) begin
                mem[wr_ptr] <= din;
                wr_ptr <= (wr_ptr == BUFFER_DEPTH-1) ? 0 : wr_ptr + 1;
                item_count <= item_count + 1;
            end
            if (rd_en && !empty) begin
                dout <= mem[rd_ptr];
                rd_ptr <= (rd_ptr == BUFFER_DEPTH-1) ? 0 : rd_ptr + 1;
                item_count <= item_count - 1;
            end
            empty <= (item_count == 0);
            full <= (item_count == BUFFER_DEPTH);
        end
    end

    assign count = item_count;
endmodule