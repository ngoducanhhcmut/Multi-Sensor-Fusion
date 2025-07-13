module Radar_Filter (
    input  wire         clk,            // System clock
    input  wire         reset,          // Active-high asynchronous reset
    input  wire         valid_in,       // Input data valid
    input  wire [127:0] raw_point,      // Raw radar data point
    output wire         valid_out,      // Output data valid
    output wire [127:0] point_cloud_data // Filtered radar point cloud
);

    // Internal pipeline control signals
    wire [127:0] filtered_point;
    wire [127:0] clean_point;
    wire [15:0]  velocity;
    
    wire valid_noise_out;
    wire valid_clutter_out;
    wire valid_doppler_out;
    wire pipeline_stall;

    // Reset synchronization (2-stage synchronizer)
    reg reset_sync1, sync_reset;
    always @(posedge clk) begin
        reset_sync1 <= reset;
        sync_reset  <= reset_sync1;
    end

    // Stall detection: Prevent overflow when downstream is not ready
    assign pipeline_stall = valid_out & ~valid_in;

    //---------------------------------------------------------------------
    // Processing Pipeline
    //---------------------------------------------------------------------
    Noise_Reducer noise_reducer (
        .clk            (clk),
        .rst            (sync_reset || pipeline_stall),
        .valid_in       (valid_in && !pipeline_stall),
        .raw_point      (raw_point),
        .filtered_point (filtered_point),
        .valid_out      (valid_noise_out)
    );

    ClutterRemover #(.N(16)) clutter_remover (
        .clk            (clk),
        .reset          (sync_reset || pipeline_stall),
        .valid_in       (valid_noise_out),
        .filtered_point (filtered_point),
        .valid_out      (valid_clutter_out),
        .clean_point    (clean_point)
    );

    doppler_processor #(
        .PHASE_OFFSET(0),
        .LUT_DEPTH(256)
    ) doppler_proc (
        .clk          (clk),
        .reset        (sync_reset || pipeline_stall),
        .data_valid   (valid_clutter_out),
        .clean_point  (clean_point),
        .velocity     (velocity),
        .vel_valid    (valid_doppler_out)
    );

    Radar_Point_Cloud_Generator pc_generator (
        .clk              (clk),
        .rst_n            (~(sync_reset || pipeline_stall)),
        .clean_point      (clean_point),
        .velocity         (velocity),
        .point_cloud_data (point_cloud_data)
    );

    //---------------------------------------------------------------------
    // Output Validation & Pipeline Control
    //---------------------------------------------------------------------
    reg valid_out_reg;
    always @(posedge clk or posedge sync_reset) begin
        if (sync_reset) valid_out_reg <= 1'b0;
        else if (pipeline_stall) valid_out_reg <= valid_out_reg; // Maintain state
        else valid_out_reg <= valid_doppler_out;
    end

    assign valid_out = valid_out_reg;

endmodule