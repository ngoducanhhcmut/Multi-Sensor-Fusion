module imu_synchronizer #(
    parameter FIFO_DEPTH = 16,
    parameter PTR_WIDTH = $clog2(FIFO_DEPTH)
) (
    input  logic        clk,
    input  logic        rst_n,
    input  logic [63:0] imu_data,        // Raw IMU (64-bit)
    input  logic        imu_valid,
    input  logic [63:0] sys_time,        // Global timestamp
    input  logic [63:0] desired_time,    // Target sync time
    output logic [63:0] imu_sync_out,    // Synced IMU (64-bit)
    output logic        imu_sync_valid,
    input  logic        output_ready     // Back-pressure support
);

    // Internal signals
    logic [127:0] ts_buf_data_out;      // {imu_data, timestamp}
    logic         ts_buf_valid_out;
    logic         ts_buf_rd_en;
    
    logic [127:0] time_sync_out;
    logic         time_sync_valid;
    
    logic [63:0]  interpolated_data;
    logic         interpolated_valid;
    logic [127:0] prev_sync_data;
    logic         prev_sync_valid;
    
    logic [127:0] quat_buf_data_out;    // {quaternion, timestamp}
    logic         quat_buf_valid_out;
    logic         quat_buf_rd_en;
    logic [31:0]  slerp_t;              // Dynamic interpolation factor
    
    logic [63:0]  normalized_quat;
    logic         normalized_valid;

    // Module instances
    timestamp_buffer #(FIFO_DEPTH) ts_buf (
        .clk(clk),
        .rst_n(rst_n),
        .imu_data(imu_data),
        .sys_time(sys_time),
        .wr_en(imu_valid),
        .rd_en(ts_buf_rd_en),
        .data_out(ts_buf_data_out),
        .valid_out(ts_buf_valid_out),
        .full(), .empty()
    );
    
    time_sync_module time_sync (
        .clk(clk),
        .rst_n(rst_n),
        .data_in(ts_buf_data_out),
        .valid_in(ts_buf_valid_out),
        .ref_time(sys_time),
        .time_offset(16'd0),
        .data_out(time_sync_out),
        .valid_out(time_sync_valid)
    );
    
    timestamp_interpolator interpolator (
        .clk(clk),
        .rst_n(rst_n),
        .data_in(time_sync_out),
        .valid_in(time_sync_valid),
        .prev_data(prev_sync_data),
        .prev_valid(prev_sync_valid),
        .target_time(desired_time),
        .data_out(interpolated_data),
        .valid_out(interpolated_valid)
    );
    
    // Store previous sample with overflow protection
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            prev_sync_data <= '0;
            prev_sync_valid <= 1'b0;
        end else if (time_sync_valid) begin
            prev_sync_data <= time_sync_out;
            prev_sync_valid <= 1'b1;
        end
    end
    
    fifo #(
        .DEPTH(FIFO_DEPTH),
        .WIDTH(128)
    ) quat_buf (
        .clk(clk),
        .rst(!rst_n),
        .write_en(interpolated_valid),
        .data_in({interpolated_data, prev_sync_data[63:0]}),
        .full(),
        .read_en(quat_buf_rd_en),
        .data_out(quat_buf_data_out),
        .empty()
    );
    
    logic [63:0] current_ts, prev_ts;
    assign current_ts = quat_buf_data_out[63:0];
    assign prev_ts = quat_buf_data_out[127:64];
    
    // Dynamic interpolation factor with edge case handling
    always_comb begin
        if (current_ts != prev_ts) begin
            slerp_t = (32'h10000 * (desired_time - prev_ts)) / (current_ts - prev_ts);
        end else begin
            slerp_t = 32'h08000;  // Default to t=0.5 for duplicate timestamps
        end
    end
    
    slerp_calculator slerp (
        .clk(clk),
        .rst_n(rst_n),
        .q1('{quat_buf_data_out[127:96], quat_buf_data_out[95:64], quat_buf_data_out[63:32], quat_buf_data_out[31:0]}),
        .q2('{quat_buf_data_out[191:160], quat_buf_data_out[159:128], quat_buf_data_out[127:96], quat_buf_data_out[95:64]}),
        .t(slerp_t),
        .q_interp({normalized_quat[63:48], normalized_quat[47:32], normalized_quat[31:16], normalized_quat[15:0]})
    );
    
    quaternion_normalizer normalizer (
        .w_in(normalized_quat[63:48]),
        .x_in(normalized_quat[47:32]),
        .y_in(normalized_quat[31:16]),
        .z_in(normalized_quat[15:0]),
        .w_out(imu_sync_out[63:48]),
        .x_out(imu_sync_out[47:32]),
        .y_out(imu_sync_out[31:16]),
        .z_out(imu_sync_out[15:0])
    );
    
    // Output control with back-pressure
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            imu_sync_valid <= 1'b0;
        end else begin
            imu_sync_valid <= normalized_valid && output_ready;
        end
    end
    
    // FIFO read control with status checking
    assign ts_buf_rd_en = !fifo_full && time_sync_ready;
    assign quat_buf_rd_en = !fifo_full && slerp_ready;
    
    // Placeholder status flags (to be implemented based on system)
    logic fifo_full, time_sync_ready, slerp_ready;
    assign fifo_full = 0;          // Replace with actual FIFO status
    assign time_sync_ready = 1;    // Replace with downstream ready
    assign slerp_ready = 1;        // Replace with SLERP input ready

endmodule