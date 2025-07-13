// Data Adapter Module
// Converts temporal alignment output (3840-bit) to FusionCore input format (3x256-bit)
module DataAdapter (
    input  logic [3839:0] temporal_aligned_data,  // From temporal alignment
    input  logic          temporal_valid,
    output logic [255:0]  sensor1_normalized,     // Camera features (256-bit)
    output logic [255:0]  sensor2_normalized,     // LiDAR features (256-bit)
    output logic [255:0]  sensor3_normalized,     // Radar features (256-bit)
    output logic          adapter_valid
);

    // Extract data from temporal alignment format:
    // fused_data[3839:3328] = lidar_data (512-bit)
    // fused_data[3327:256] = camera_data (3072-bit) 
    // fused_data[255:128] = radar_data (128-bit)
    // fused_data[127:64] = imu_data (64-bit)
    
    logic [511:0]  lidar_raw;
    logic [3071:0] camera_raw;
    logic [127:0]  radar_raw;
    logic [63:0]   imu_raw;
    
    always_comb begin
        // Extract raw data
        lidar_raw  = temporal_aligned_data[3839:3328];
        camera_raw = temporal_aligned_data[3327:256];
        radar_raw  = temporal_aligned_data[255:128];
        imu_raw    = temporal_aligned_data[127:64];
        
        // Convert to 256-bit normalized format for FusionCore
        // Camera: Take lower 256 bits from 3072-bit data
        sensor1_normalized = camera_raw[255:0];
        
        // LiDAR: Take lower 256 bits from 512-bit data
        sensor2_normalized = lidar_raw[255:0];
        
        // Radar + IMU: Combine 128-bit radar + 64-bit IMU + 64-bit padding
        sensor3_normalized = {64'h0, imu_raw, radar_raw};
        
        // Valid when temporal alignment is valid
        adapter_valid = temporal_valid;
    end

endmodule

// Enhanced Data Adapter with feature extraction
module EnhancedDataAdapter (
    input  logic         clk,
    input  logic         rst_n,
    input  logic [3839:0] temporal_aligned_data,
    input  logic          temporal_valid,
    output logic [255:0]  sensor1_features,    // Camera features
    output logic [255:0]  sensor2_features,    // LiDAR features  
    output logic [255:0]  sensor3_features,    // Radar+IMU features
    output logic          features_valid
);

    // Internal signals
    logic [511:0]  lidar_raw;
    logic [3071:0] camera_raw;
    logic [127:0]  radar_raw;
    logic [63:0]   imu_raw;
    
    // Feature extraction registers
    logic [255:0] camera_features_reg;
    logic [255:0] lidar_features_reg;
    logic [255:0] radar_imu_features_reg;
    logic         valid_reg;
    
    always_comb begin
        // Extract raw data
        lidar_raw  = temporal_aligned_data[3839:3328];
        camera_raw = temporal_aligned_data[3327:256];
        radar_raw  = temporal_aligned_data[255:128];
        imu_raw    = temporal_aligned_data[127:64];
    end
    
    // Camera feature extraction (simplified CNN-like processing)
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            camera_features_reg <= 256'h0;
        end else if (temporal_valid) begin
            // Simple feature extraction: downsample and apply basic filtering
            for (int i = 0; i < 16; i++) begin
                // Extract 16-bit features from different regions of camera data
                camera_features_reg[16*i +: 16] <= camera_raw[192*i +: 16] ^ camera_raw[192*i+96 +: 16];
            end
        end
    end
    
    // LiDAR feature extraction (voxel-based processing)
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            lidar_features_reg <= 256'h0;
        end else if (temporal_valid) begin
            // Voxel-based feature extraction
            for (int i = 0; i < 16; i++) begin
                // Extract spatial features from point cloud
                lidar_features_reg[16*i +: 16] <= lidar_raw[32*i +: 16] + lidar_raw[32*i+16 +: 16];
            end
        end
    end
    
    // Radar+IMU feature extraction
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            radar_imu_features_reg <= 256'h0;
        end else if (temporal_valid) begin
            // Combine radar and IMU features
            // Radar features (8 x 16-bit)
            for (int i = 0; i < 8; i++) begin
                radar_imu_features_reg[16*i +: 16] <= radar_raw[16*i +: 16];
            end
            // IMU features (4 x 16-bit)
            for (int i = 0; i < 4; i++) begin
                radar_imu_features_reg[16*(i+8) +: 16] <= imu_raw[16*i +: 16];
            end
            // Padding (4 x 16-bit)
            for (int i = 12; i < 16; i++) begin
                radar_imu_features_reg[16*i +: 16] <= 16'h0;
            end
        end
    end
    
    // Valid signal pipeline
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_reg <= 1'b0;
        end else begin
            valid_reg <= temporal_valid;
        end
    end
    
    // Output assignments
    assign sensor1_features = camera_features_reg;
    assign sensor2_features = lidar_features_reg;
    assign sensor3_features = radar_imu_features_reg;
    assign features_valid   = valid_reg;

endmodule
