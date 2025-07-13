// Top-level Multi-Sensor Fusion System
// Integrates all components from raw sensor inputs to fused tensor output
module MultiSensorFusionTop #(
    parameter CAMERA_WIDTH = 3072,
    parameter LIDAR_WIDTH = 512,
    parameter RADAR_WIDTH = 128,
    parameter IMU_WIDTH = 64,
    parameter OUTPUT_WIDTH = 2048,
    parameter FUSION_MIN_VAL = -16384,
    parameter FUSION_MAX_VAL = 16383
) (
    input  logic clk,
    input  logic rst_n,
    
    // Raw sensor inputs
    input  logic [CAMERA_WIDTH-1:0] camera_bitstream,
    input  logic                    camera_valid,
    input  logic [LIDAR_WIDTH-1:0]  lidar_compressed,
    input  logic                    lidar_valid,
    input  logic [RADAR_WIDTH-1:0]  radar_raw,
    input  logic                    radar_valid,
    input  logic [IMU_WIDTH-1:0]    imu_raw,
    input  logic                    imu_valid,
    input  logic [63:0]             timestamp,
    
    // Weight matrices for fusion core
    input  logic [15:0] W_q [0:5][0:15],
    input  logic [15:0] W_k [0:5][0:15],
    input  logic [15:0] W_v [0:5][0:15],
    input  logic signed [15:0] fc_weights [0:127][0:95],
    input  logic signed [15:0] fc_bias [0:127],
    
    // Output
    output logic [OUTPUT_WIDTH-1:0] fused_tensor,
    output logic                    output_valid,
    output logic [7:0]              error_flags
);

    // Internal signals
    logic [CAMERA_WIDTH-1:0] camera_decoded;
    logic                    camera_decoded_valid;
    logic [LIDAR_WIDTH-1:0]  lidar_decoded;
    logic                    lidar_decoded_valid;
    logic [RADAR_WIDTH-1:0]  radar_filtered;
    logic                    radar_filtered_valid;
    logic [IMU_WIDTH-1:0]    imu_synced;
    logic                    imu_synced_valid;
    
    logic [255:0] camera_features;
    logic [255:0] lidar_features;
    logic [255:0] radar_features;
    logic         features_valid;
    
    logic [3839:0] temporal_aligned;
    logic          temporal_valid;
    
    logic [255:0] sensor1_normalized;
    logic [255:0] sensor2_normalized;
    logic [255:0] sensor3_normalized;
    logic         adapter_valid;
    
    logic [3:0] fusion_error_code;

    // Stage 1: Sensor Decoders
    camera_decoder #(
        .WIDTH(640),
        .HEIGHT(480)
    ) camera_dec (
        .clk(clk),
        .rst(~rst_n),
        .bitstream_in(camera_bitstream[7:0]),  // Process byte by byte
        .bitstream_valid(camera_valid),
        .bitstream_ready(),
        .pixel_r(),
        .pixel_g(),
        .pixel_b(),
        .pixel_x(),
        .pixel_y(),
        .pixel_valid(camera_decoded_valid),
        .frame_done(),
        .error_flag()
    );
    
    // Simplified camera output for now
    assign camera_decoded = camera_bitstream;
    
    LiDARDecoder lidar_dec (
        .clk(clk),
        .reset(~rst_n),
        .data_in_valid(lidar_valid),
        .compressed_data(lidar_compressed),
        .decoded_data(lidar_decoded),
        .data_out_valid(lidar_decoded_valid),
        .error_flag()
    );
    
    radar_filter_full radar_filt (
        .clk(clk),
        .rst_n(rst_n),
        .radar_data_in(radar_raw),
        .data_valid_in(radar_valid),
        .radar_data_out(radar_filtered),
        .data_valid_out(radar_filtered_valid),
        .error_flag()
    );
    
    imu_synchronizer #(
        .FIFO_DEPTH(16)
    ) imu_sync (
        .clk(clk),
        .rst_n(rst_n),
        .imu_data(imu_raw),
        .imu_valid(imu_valid),
        .sys_time(timestamp),
        .desired_time(timestamp),
        .imu_sync_out(imu_synced),
        .imu_sync_valid(imu_synced_valid),
        .output_ready(1'b1)
    );

    // Stage 2: Feature Extractors
    // BatchNorm parameters (simplified for now)
    logic signed [7:0] bn_gamma [0:31];
    logic signed [7:0] bn_beta [0:31];
    logic signed [7:0] bn_mean [0:31];
    logic [7:0] bn_variance [0:31];
    logic [7:0] epsilon;

    // Initialize BatchNorm parameters
    initial begin
        for (int i = 0; i < 32; i++) begin
            bn_gamma[i] = 8'h01;      // Scale factor = 1
            bn_beta[i] = 8'h00;       // Bias = 0
            bn_mean[i] = 8'h00;       // Mean = 0
            bn_variance[i] = 8'h01;   // Variance = 1
        end
        epsilon = 8'h01;              // Small constant
    end

    Camera_Feature_Extractor camera_feat (
        .clk(clk),
        .rst_n(rst_n),
        .start(camera_decoded_valid),
        .input_image(camera_decoded[3071:0]),
        .feature_vector(camera_features),
        .valid_out(features_valid),
        .bn_gamma(bn_gamma),
        .bn_beta(bn_beta),
        .bn_mean(bn_mean),
        .bn_variance(bn_variance),
        .epsilon(epsilon)
    );
    
    LiDAR_Feature_Extractor lidar_feat (
        .clk(clk),
        .rst_n(rst_n),
        .start(lidar_decoded_valid),
        .point_cloud(lidar_decoded),
        .feature_vector(lidar_features),
        .done()
    );
    
    RadarFeatureExtractor radar_feat (
        .clk(clk),
        .rst_n(rst_n),
        .filtered_data(radar_filtered),
        .data_valid(radar_filtered_valid),
        .feature_vector(radar_features),
        .feature_valid(),
        .error_flag()
    );

    // Stage 3: Temporal Alignment
    temporal_alignment_full temp_align (
        .clk(clk),
        .rst_n(rst_n),
        .camera_data(camera_decoded),
        .camera_valid(camera_decoded_valid),
        .camera_timestamp(timestamp),
        .lidar_data(lidar_decoded),
        .lidar_valid(lidar_decoded_valid),
        .lidar_timestamp(timestamp),
        .radar_data(radar_filtered),
        .radar_valid(radar_filtered_valid),
        .radar_timestamp(timestamp),
        .imu_data(imu_synced),
        .imu_valid(imu_synced_valid),
        .imu_timestamp(timestamp),
        .fused_data(temporal_aligned),
        .fused_valid(temporal_valid),
        .error_flag()
    );

    // Stage 4: Data Adapter
    EnhancedDataAdapter data_adapter (
        .clk(clk),
        .rst_n(rst_n),
        .temporal_aligned_data(temporal_aligned),
        .temporal_valid(temporal_valid),
        .sensor1_features(sensor1_normalized),
        .sensor2_features(sensor2_normalized),
        .sensor3_features(sensor3_normalized),
        .features_valid(adapter_valid)
    );

    // Stage 5: Fusion Core
    FusionCore #(
        .MIN_VAL(FUSION_MIN_VAL),
        .MAX_VAL(FUSION_MAX_VAL),
        .SHIFT_AMOUNT(2),
        .LINEAR_NORM(64'h0),
        .INPUT_SIZE(96),
        .OUTPUT_SIZE(128),
        .BIT_WIDTH(16)
    ) fusion_core (
        .clk(clk),
        .rst_n(rst_n),
        .sensor1_raw(sensor1_normalized),
        .sensor2_raw(sensor2_normalized),
        .sensor3_raw(sensor3_normalized),
        .W_q(W_q),
        .W_k(W_k),
        .W_v(W_v),
        .fc_weights(fc_weights),
        .fc_bias(fc_bias),
        .fused_tensor(fused_tensor),
        .error_code(fusion_error_code)
    );

    // Output assignments
    assign output_valid = adapter_valid;
    assign error_flags = {4'h0, fusion_error_code};

endmodule
