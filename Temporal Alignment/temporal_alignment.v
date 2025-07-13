// ==========================================================
// Top-Level Temporal Alignment
// ==========================================================
module temporal_alignment (
    input clk,
    input rst_n,
    input sync_signal,
    input [575:0] lidar_din,
    input lidar_wr_en,
    input [3135:0] camera_din,
    input camera_wr_en,
    input [191:0] radar_din,
    input radar_wr_en,
    input [127:0] imu_din,
    input imu_wr_en,
    output logic [3839:0] fused_data,
    output logic valid,
    output logic error
);

    logic [63:0] t_common;
    time_reference time_ref (
        .clk(clk),
        .rst_n(rst_n),
        .sync_signal(sync_signal),
        .t_common(t_common)
    );

    logic [575:0] lidar_dout;
    logic [3135:0] camera_dout;
    logic [191:0] radar_dout;
    logic [127:0] imu_dout;
    
    logic lidar_empty, camera_empty, radar_empty, imu_empty;
    logic lidar_full, camera_full, radar_full, imu_full;
    logic lidar_rd_en, camera_rd_en, radar_rd_en, imu_rd_en;
    
    logic [3:0] lidar_count, camera_count, radar_count, imu_count;

    sensor_data_buffer #(
        .DATA_WIDTH(512),
        .BUFFER_DEPTH(16)
    ) lidar_buffer (
        .clk(clk),
        .rst_n(rst_n),
        .wr_en(lidar_wr_en),
        .din(lidar_din),
        .rd_en(lidar_rd_en),
        .dout(lidar_dout),
        .full(lidar_full),
        .empty(lidar_empty),
        .count(lidar_count)
    );

    sensor_data_buffer #(
        .DATA_WIDTH(3072),
        .BUFFER_DEPTH(16)
    ) camera_buffer (
        .clk(clk),
        .rst_n(rst_n),
        .wr_en(camera_wr_en),
        .din(camera_din),
        .rd_en(camera_rd_en),
        .dout(camera_dout),
        .full(camera_full),
        .empty(camera_empty),
        .count(camera_count)
    );

    sensor_data_buffer #(
        .DATA_WIDTH(128),
        .BUFFER_DEPTH(16)
    ) radar_buffer (
        .clk(clk),
        .rst_n(rst_n),
        .wr_en(radar_wr_en),
        .din(radar_din),
        .rd_en(radar_rd_en),
        .dout(radar_dout),
        .full(radar_full),
        .empty(radar_empty),
        .count(radar_count)
    );

    sensor_data_buffer #(
        .DATA_WIDTH(64),
        .BUFFER_DEPTH(16)
    ) imu_buffer (
        .clk(clk),
        .rst_n(rst_n),
        .wr_en(imu_wr_en),
        .din(imu_din),
        .rd_en(imu_rd_en),
        .dout(imu_dout),
        .full(imu_full),
        .empty(imu_empty),
        .count(imu_count)
    );

    logic [575:0] lidar_packet1, lidar_packet2;
    logic [3135:0] camera_packet1, camera_packet2;
    logic [191:0] radar_packet1, radar_packet2;
    logic [127:0] imu_packet1, imu_packet2;
    
    logic lidar_matcher_done, camera_matcher_done, radar_matcher_done, imu_matcher_done;
    logic lidar_matcher_error, camera_matcher_error, radar_matcher_error, imu_matcher_error;

    matcher_unit #(
        .DATA_WIDTH(512),
        .BUFFER_DEPTH(16)
    ) lidar_matcher (
        .clk(clk),
        .rst_n(rst_n),
        .t_common(t_common),
        .start(sync_signal),
        .done(lidar_matcher_done),
        .error(lidar_matcher_error),
        .packet1(lidar_packet1),
        .packet2(lidar_packet2),
        .fifo_dout(lidar_dout),
        .fifo_empty(lidar_empty),
        .fifo_rd_en(lidar_rd_en),
        .fifo_count(lidar_count)
    );

    matcher_unit #(
        .DATA_WIDTH(3072),
        .BUFFER_DEPTH(16)
    ) camera_matcher (
        .clk(clk),
        .rst_n(rst_n),
        .t_common(t_common),
        .start(sync_signal),
        .done(camera_matcher_done),
        .error(camera_matcher_error),
        .packet1(camera_packet1),
        .packet2(camera_packet2),
        .fifo_dout(camera_dout),
        .fifo_empty(camera_empty),
        .fifo_rd_en(camera_rd_en),
        .fifo_count(camera_count)
    );

    matcher_unit #(
        .DATA_WIDTH(128),
        .BUFFER_DEPTH(16)
    ) radar_matcher (
        .clk(clk),
        .rst_n(rst_n),
        .t_common(t_common),
        .start(sync_signal),
        .done(radar_matcher_done),
        .error(radar_matcher_error),
        .packet1(radar_packet1),
        .packet2(radar_packet2),
        .fifo_dout(radar_dout),
        .fifo_empty(radar_empty),
        .fifo_rd_en(radar_rd_en),
        .fifo_count(radar_count)
    );

    matcher_unit #(
        .DATA_WIDTH(64),
        .BUFFER_DEPTH(16)
    ) imu_matcher (
        .clk(clk),
        .rst_n(rst_n),
        .t_common(t_common),
        .start(sync_signal),
        .done(imu_matcher_done),
        .error(imu_matcher_error),
        .packet1(imu_packet1),
        .packet2(imu_packet2),
        .fifo_dout(imu_dout),
        .fifo_empty(imu_empty),
        .fifo_rd_en(imu_rd_en),
        .fifo_count(imu_count)
    );

    logic [511:0] lidar_interpolated;
    logic [3071:0] camera_interpolated;
    logic [127:0] radar_interpolated;
    logic [63:0] imu_interpolated;
    
    logic lidar_valid, camera_valid, radar_valid, imu_valid;
    logic lidar_interp_error, camera_interp_error, radar_interp_error, imu_interp_error;

    interpolation_calculator #(
        .DATA_WIDTH(512)
    ) lidar_interpolator (
        .clk(clk),
        .rst_n(rst_n),
        .t_common(t_common),
        .packet1(lidar_packet1),
        .packet2(lidar_packet2),
        .start(lidar_matcher_done && !lidar_matcher_error),
        .interpolated_data(lidar_interpolated),
        .valid(lidar_valid),
        .error(lidar_interp_error)
    );

    interpolation_calculator #(
        .DATA_WIDTH(3072)
    ) camera_interpolator (
        .clk(clk),
        .rst_n(rst_n),
        .t_common(t_common),
        .packet1(camera_packet1),
        .packet2(camera_packet2),
        .start(camera_matcher_done && !camera_matcher_error),
        .interpolated_data(camera_interpolated),
        .valid(camera_valid),
        .error(camera_interp_error)
    );

    interpolation_calculator #(
        .DATA_WIDTH(128)
    ) radar_interpolator (
        .clk(clk),
        .rst_n(rst_n),
        .t_common(t_common),
        .packet1(radar_packet1),
        .packet2(radar_packet2),
        .start(radar_matcher_done && !radar_matcher_error),
        .interpolated_data(radar_interpolated),
        .valid(radar_valid),
        .error(radar_interp_error)
    );

    interpolation_calculator #(
        .DATA_WIDTH(64)
    ) imu_interpolator (
        .clk(clk),
        .rst_n(rst_n),
        .t_common(t_common),
        .packet1(imu_packet1),
        .packet2(imu_packet2),
        .start(imu_matcher_done && !imu_matcher_error),
        .interpolated_data(imu_interpolated),
        .valid(imu_valid),
        .error(imu_interp_error)
    );

    data_assembler assembler (
        .lidar_data(lidar_interpolated),
        .lidar_valid(lidar_valid),
        .camera_data(camera_interpolated),
        .camera_valid(camera_valid),
        .radar_data(radar_interpolated),
        .radar_valid(radar_valid),
        .imu_data(imu_interpolated),
        .imu_valid(imu_valid),
        .fused_data(fused_data),
        .valid(valid)
    );

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            error <= 0;
        end else begin
            error <= lidar_matcher_error | camera_matcher_error | radar_matcher_error | imu_matcher_error |
                     lidar_interp_error | camera_interp_error | radar_interp_error | imu_interp_error;
        end
    end
endmodule