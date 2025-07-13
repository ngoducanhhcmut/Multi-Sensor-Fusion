// Multi-Sensor Fusion System - Complete Architecture
// Follows the exact flow: Decoders -> Temporal Alignment -> Feature Extractors -> Fusion Core -> Fused Tensor
// Architecture Flow:
//   LiDAR Decoder ----\
//   Camera Decoder -----> Temporal Alignment -> Feature Extractors -> Fusion Core -> Fused Tensor
//   Radar Filter ------/
//   IMU Sync ----------/

module MultiSensorFusionSystem #(
    parameter CAMERA_WIDTH = 3072,
    parameter LIDAR_WIDTH = 512,
    parameter RADAR_WIDTH = 128,
    parameter IMU_WIDTH = 64,
    parameter FEATURE_WIDTH = 256,
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
    output logic [7:0]              error_flags,
    
    // Debug outputs for testing
    output logic [CAMERA_WIDTH-1:0] debug_camera_decoded,
    output logic [LIDAR_WIDTH-1:0]  debug_lidar_decoded,
    output logic [RADAR_WIDTH-1:0]  debug_radar_filtered,
    output logic [IMU_WIDTH-1:0]    debug_imu_synced,
    output logic [3839:0]           debug_temporal_aligned,
    output logic [FEATURE_WIDTH-1:0] debug_camera_features,
    output logic [FEATURE_WIDTH-1:0] debug_lidar_features,
    output logic [FEATURE_WIDTH-1:0] debug_radar_features
);

    // ========================================
    // STAGE 1: SENSOR DECODERS
    // ========================================
    
    logic [CAMERA_WIDTH-1:0] camera_decoded;
    logic                    camera_decoded_valid;
    logic [LIDAR_WIDTH-1:0]  lidar_decoded;
    logic                    lidar_decoded_valid;
    logic [RADAR_WIDTH-1:0]  radar_filtered;
    logic                    radar_filtered_valid;
    logic [IMU_WIDTH-1:0]    imu_synced;
    logic                    imu_synced_valid;
    
    // Camera Decoder
    camera_decoder #(
        .WIDTH(640),
        .HEIGHT(480)
    ) camera_dec (
        .clk(clk),
        .rst(~rst_n),
        .bitstream_in(camera_bitstream[7:0]),
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
    
    // Simplified camera output (for now, pass through processed bitstream)
    assign camera_decoded = camera_bitstream;
    
    // LiDAR Decoder
    LiDARDecoder lidar_dec (
        .clk(clk),
        .reset(~rst_n),
        .data_in_valid(lidar_valid),
        .compressed_data(lidar_compressed),
        .decoded_data(lidar_decoded),
        .data_out_valid(lidar_decoded_valid),
        .error_flag()
    );
    
    // Radar Filter
    radar_filter_full radar_filt (
        .clk(clk),
        .rst_n(rst_n),
        .radar_data_in(radar_raw),
        .data_valid_in(radar_valid),
        .radar_data_out(radar_filtered),
        .data_valid_out(radar_filtered_valid),
        .error_flag()
    );
    
    // IMU Synchronizer
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

    // ========================================
    // STAGE 2: TEMPORAL ALIGNMENT
    // ========================================
    
    logic [3839:0] temporal_aligned;
    logic          temporal_valid;
    
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

    // ========================================
    // STAGE 3: FEATURE EXTRACTORS
    // (Process temporally aligned data)
    // ========================================
    
    logic [FEATURE_WIDTH-1:0] camera_features;
    logic [FEATURE_WIDTH-1:0] lidar_features;
    logic [FEATURE_WIDTH-1:0] radar_features;
    logic                     camera_feat_valid;
    logic                     lidar_feat_valid;
    logic                     radar_feat_valid;
    
    // Extract aligned data for feature extractors
    logic [CAMERA_WIDTH-1:0] aligned_camera_data;
    logic [LIDAR_WIDTH-1:0]  aligned_lidar_data;
    logic [RADAR_WIDTH-1:0]  aligned_radar_data;
    logic [IMU_WIDTH-1:0]    aligned_imu_data;
    
    // Data extraction from temporal alignment output
    assign aligned_lidar_data  = temporal_aligned[3839:3328];  // 512-bit LiDAR
    assign aligned_camera_data = temporal_aligned[3327:256];   // 3072-bit Camera
    assign aligned_radar_data  = temporal_aligned[255:128];    // 128-bit Radar
    assign aligned_imu_data    = temporal_aligned[127:64];     // 64-bit IMU
    
    // BatchNorm parameters for camera feature extractor
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
    
    // Camera Feature Extractor
    Camera_Feature_Extractor camera_feat (
        .clk(clk),
        .rst_n(rst_n),
        .start(temporal_valid),
        .input_image(aligned_camera_data),
        .feature_vector(camera_features),
        .valid_out(camera_feat_valid),
        .bn_gamma(bn_gamma),
        .bn_beta(bn_beta),
        .bn_mean(bn_mean),
        .bn_variance(bn_variance),
        .epsilon(epsilon)
    );
    
    // LiDAR Feature Extractor
    LiDAR_Feature_Extractor lidar_feat (
        .clk(clk),
        .rst_n(rst_n),
        .start(temporal_valid),
        .point_cloud(aligned_lidar_data),
        .feature_vector(lidar_features),
        .done(lidar_feat_valid)
    );
    
    // Radar Feature Extractor
    RadarFeatureExtractor radar_feat (
        .clk(clk),
        .rst_n(rst_n),
        .filtered_data(aligned_radar_data),
        .data_valid(temporal_valid),
        .feature_vector(radar_features),
        .feature_valid(radar_feat_valid),
        .error_flag()
    );

    // ========================================
    // STAGE 4: FUSION CORE
    // ========================================
    
    logic [3:0] fusion_error_code;
    logic       all_features_valid;
    
    assign all_features_valid = camera_feat_valid & lidar_feat_valid & radar_feat_valid;
    
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
        .sensor1_raw(camera_features),
        .sensor2_raw(lidar_features),
        .sensor3_raw(radar_features),
        .W_q(W_q),
        .W_k(W_k),
        .W_v(W_v),
        .fc_weights(fc_weights),
        .fc_bias(fc_bias),
        .fused_tensor(fused_tensor),
        .error_code(fusion_error_code)
    );

    // ========================================
    // OUTPUT ASSIGNMENTS
    // ========================================
    
    assign output_valid = all_features_valid;
    assign error_flags = {4'h0, fusion_error_code};
    
    // Debug outputs
    assign debug_camera_decoded = camera_decoded;
    assign debug_lidar_decoded = lidar_decoded;
    assign debug_radar_filtered = radar_filtered;
    assign debug_imu_synced = imu_synced;
    assign debug_temporal_aligned = temporal_aligned;
    assign debug_camera_features = camera_features;
    assign debug_lidar_features = lidar_features;
    assign debug_radar_features = radar_features;

endmodule
