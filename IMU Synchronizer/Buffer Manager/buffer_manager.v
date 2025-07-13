module buffer_manager (
    input  wire        clk,
    input  wire        rst,
    input  wire [63:0] fifo_data_out,
    input  wire        fifo_empty,
    input  wire        ready,
    output logic [63:0] imu_sync_out,
    output logic       valid,
    output logic       fifo_read_en
);
    // Control logic
    always_comb begin
        valid = ~fifo_empty;
        fifo_read_en = valid && ready;  // Read only if not empty and ready
    end

    // Output register for timing
    always_ff @(posedge clk) begin
        if (rst) begin
            imu_sync_out <= '0;
        end else if (fifo_read_en) begin
            imu_sync_out <= fifo_data_out;
        end
    end
endmodule