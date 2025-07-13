// SystemVerilog Testbench for Multi-Sensor Fusion System
// Tests the complete architecture flow for KITTI/nuScenes compatibility
`timescale 1ns/1ps

module tb_multi_sensor_fusion_system;

    // Parameters
    parameter CAMERA_WIDTH = 3072;
    parameter LIDAR_WIDTH = 512;
    parameter RADAR_WIDTH = 128;
    parameter IMU_WIDTH = 64;
    parameter FEATURE_WIDTH = 256;
    parameter OUTPUT_WIDTH = 2048;
    parameter CLK_PERIOD = 10; // 100MHz

    // Clock and reset
    logic clk;
    logic rst_n;
    
    // DUT signals
    logic [CAMERA_WIDTH-1:0] camera_bitstream;
    logic                    camera_valid;
    logic [LIDAR_WIDTH-1:0]  lidar_compressed;
    logic                    lidar_valid;
    logic [RADAR_WIDTH-1:0]  radar_raw;
    logic                    radar_valid;
    logic [IMU_WIDTH-1:0]    imu_raw;
    logic                    imu_valid;
    logic [63:0]             timestamp;
    
    // Weight matrices
    logic [15:0] W_q [0:5][0:15];
    logic [15:0] W_k [0:5][0:15];
    logic [15:0] W_v [0:5][0:15];
    logic signed [15:0] fc_weights [0:127][0:95];
    logic signed [15:0] fc_bias [0:127];
    
    // Output signals
    logic [OUTPUT_WIDTH-1:0] fused_tensor;
    logic                    output_valid;
    logic [7:0]              error_flags;
    
    // Debug outputs
    logic [CAMERA_WIDTH-1:0] debug_camera_decoded;
    logic [LIDAR_WIDTH-1:0]  debug_lidar_decoded;
    logic [RADAR_WIDTH-1:0]  debug_radar_filtered;
    logic [IMU_WIDTH-1:0]    debug_imu_synced;
    logic [3839:0]           debug_temporal_aligned;
    logic [FEATURE_WIDTH-1:0] debug_camera_features;
    logic [FEATURE_WIDTH-1:0] debug_lidar_features;
    logic [FEATURE_WIDTH-1:0] debug_radar_features;
    
    // Test control
    logic [31:0] test_count;
    logic [31:0] pass_count;
    logic [31:0] fail_count;
    
    // Performance monitoring
    logic [31:0] cycle_count;
    logic [31:0] latency_measurement;
    logic        performance_monitor_en;

    // DUT instantiation
    MultiSensorFusionSystem #(
        .CAMERA_WIDTH(CAMERA_WIDTH),
        .LIDAR_WIDTH(LIDAR_WIDTH),
        .RADAR_WIDTH(RADAR_WIDTH),
        .IMU_WIDTH(IMU_WIDTH),
        .FEATURE_WIDTH(FEATURE_WIDTH),
        .OUTPUT_WIDTH(OUTPUT_WIDTH),
        .FUSION_MIN_VAL(-16384),
        .FUSION_MAX_VAL(16383)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .camera_bitstream(camera_bitstream),
        .camera_valid(camera_valid),
        .lidar_compressed(lidar_compressed),
        .lidar_valid(lidar_valid),
        .radar_raw(radar_raw),
        .radar_valid(radar_valid),
        .imu_raw(imu_raw),
        .imu_valid(imu_valid),
        .timestamp(timestamp),
        .W_q(W_q),
        .W_k(W_k),
        .W_v(W_v),
        .fc_weights(fc_weights),
        .fc_bias(fc_bias),
        .fused_tensor(fused_tensor),
        .output_valid(output_valid),
        .error_flags(error_flags),
        .debug_camera_decoded(debug_camera_decoded),
        .debug_lidar_decoded(debug_lidar_decoded),
        .debug_radar_filtered(debug_radar_filtered),
        .debug_imu_synced(debug_imu_synced),
        .debug_temporal_aligned(debug_temporal_aligned),
        .debug_camera_features(debug_camera_features),
        .debug_lidar_features(debug_lidar_features),
        .debug_radar_features(debug_radar_features)
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    // Reset generation
    initial begin
        rst_n = 0;
        #(CLK_PERIOD * 10);
        rst_n = 1;
    end

    // Performance monitoring
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cycle_count <= 0;
            latency_measurement <= 0;
        end else begin
            if (performance_monitor_en) begin
                cycle_count <= cycle_count + 1;
                if (output_valid) begin
                    latency_measurement <= cycle_count;
                    cycle_count <= 0;
                end
            end
        end
    end

    // Initialize weight matrices
    initial begin
        // Initialize with small random values for testing
        for (int i = 0; i < 6; i++) begin
            for (int j = 0; j < 16; j++) begin
                W_q[i][j] = $random() % 256 - 128;
                W_k[i][j] = $random() % 256 - 128;
                W_v[i][j] = $random() % 256 - 128;
            end
        end
        
        for (int i = 0; i < 128; i++) begin
            for (int j = 0; j < 96; j++) begin
                fc_weights[i][j] = $random() % 256 - 128;
            end
            fc_bias[i] = $random() % 256 - 128;
        end
    end

    // Test task for KITTI-like scenarios
    task automatic test_kitti_scenario(
        input string scenario_name,
        input [CAMERA_WIDTH-1:0] cam_data,
        input [LIDAR_WIDTH-1:0] lidar_data,
        input [RADAR_WIDTH-1:0] radar_data,
        input [IMU_WIDTH-1:0] imu_data
    );
        begin
            $display("Testing KITTI scenario: %s", scenario_name);
            
            // Apply inputs
            camera_bitstream = cam_data;
            camera_valid = 1;
            lidar_compressed = lidar_data;
            lidar_valid = 1;
            radar_raw = radar_data;
            radar_valid = 1;
            imu_raw = imu_data;
            imu_valid = 1;
            timestamp = $time;
            
            // Start performance monitoring
            performance_monitor_en = 1;
            
            // Wait for output
            wait(output_valid);
            
            // Stop performance monitoring
            performance_monitor_en = 0;
            
            // Validate results
            if (fused_tensor != 0 && error_flags == 0) begin
                $display("✅ %s: PASSED - Latency: %0d cycles", scenario_name, latency_measurement);
                pass_count++;
            end else begin
                $display("❌ %s: FAILED - Error flags: 0x%02x", scenario_name, error_flags);
                fail_count++;
            end
            
            test_count++;
            
            // Clear inputs
            camera_valid = 0;
            lidar_valid = 0;
            radar_valid = 0;
            imu_valid = 0;
            
            #(CLK_PERIOD * 10); // Wait between tests
        end
    endtask

    // Test task for nuScenes-like scenarios
    task automatic test_nuscenes_scenario(
        input string scenario_name,
        input [CAMERA_WIDTH-1:0] cam_data,
        input [LIDAR_WIDTH-1:0] lidar_data,
        input [RADAR_WIDTH-1:0] radar_data,
        input [IMU_WIDTH-1:0] imu_data,
        input logic expect_error
    );
        begin
            $display("Testing nuScenes scenario: %s", scenario_name);
            
            // Apply inputs
            camera_bitstream = cam_data;
            camera_valid = 1;
            lidar_compressed = lidar_data;
            lidar_valid = 1;
            radar_raw = radar_data;
            radar_valid = 1;
            imu_raw = imu_data;
            imu_valid = 1;
            timestamp = $time;
            
            // Start performance monitoring
            performance_monitor_en = 1;
            
            // Wait for output or timeout
            fork
                begin
                    wait(output_valid);
                end
                begin
                    #(CLK_PERIOD * 1000); // 10us timeout
                end
            join_any
            disable fork;
            
            // Stop performance monitoring
            performance_monitor_en = 0;
            
            // Validate results
            if (expect_error) begin
                if (error_flags != 0) begin
                    $display("✅ %s: PASSED - Error correctly detected: 0x%02x", scenario_name, error_flags);
                    pass_count++;
                end else begin
                    $display("❌ %s: FAILED - Expected error not detected", scenario_name);
                    fail_count++;
                end
            end else begin
                if (fused_tensor != 0 && error_flags == 0) begin
                    $display("✅ %s: PASSED - Latency: %0d cycles", scenario_name, latency_measurement);
                    pass_count++;
                end else begin
                    $display("❌ %s: FAILED - Error flags: 0x%02x", scenario_name, error_flags);
                    fail_count++;
                end
            end
            
            test_count++;
            
            // Clear inputs
            camera_valid = 0;
            lidar_valid = 0;
            radar_valid = 0;
            imu_valid = 0;
            
            #(CLK_PERIOD * 10);
        end
    endtask

    // Main test sequence
    initial begin
        $display("🧪 Multi-Sensor Fusion System Testbench");
        $display("Testing complete architecture for KITTI/nuScenes compatibility");
        
        // Initialize counters
        test_count = 0;
        pass_count = 0;
        fail_count = 0;
        
        // Wait for reset
        wait(rst_n);
        #(CLK_PERIOD * 10);
        
        $display("\n=== KITTI Dataset Scenarios ===");
        
        // KITTI-like scenarios
        test_kitti_scenario("Urban Street", 
            3072'h123456789ABCDEF0, 512'h87654321FEDCBA98, 
            128'hDEADBEEFCAFEBABE, 64'h1234567890ABCDEF);
            
        test_kitti_scenario("Highway Driving", 
            3072'h111111111111111, 512'h222222222222222, 
            128'h3333333333333333, 64'h4444444444444444);
            
        test_kitti_scenario("Residential Area", 
            3072'hAAAAAAAAAAAAAAAA, 512'h5555555555555555, 
            128'hCCCCCCCCCCCCCCCC, 64'h9999999999999999);
        
        $display("\n=== nuScenes Dataset Scenarios ===");
        
        // nuScenes-like scenarios
        test_nuscenes_scenario("Boston Seaport", 
            3072'hF0F0F0F0F0F0F0F0, 512'h0F0F0F0F0F0F0F0F, 
            128'hFF00FF00FF00FF00, 64'h00FF00FF00FF00FF, 0);
            
        test_nuscenes_scenario("Singapore Night", 
            3072'h0F0F0F0F0F0F0F0F, 512'hF0F0F0F0F0F0F0F0, 
            128'h00FF00FF00FF00FF, 64'hFF00FF00FF00FF00, 0);
            
        test_nuscenes_scenario("Rain Scenario", 
            3072'h3333333333333333, 512'h6666666666666666, 
            128'h9999999999999999, 64'hCCCCCCCCCCCCCCCC, 0);
        
        $display("\n=== Error Scenarios ===");
        
        // Error scenarios
        test_nuscenes_scenario("Corrupted Camera", 
            3072'h0, 512'h87654321FEDCBA98, 
            128'hDEADBEEFCAFEBABE, 64'h1234567890ABCDEF, 1);
            
        test_nuscenes_scenario("Invalid LiDAR", 
            3072'h123456789ABCDEF0, 512'h0, 
            128'hDEADBEEFCAFEBABE, 64'h1234567890ABCDEF, 1);
        
        // Final summary
        $display("\n=== Test Summary ===");
        $display("Total tests: %0d", test_count);
        $display("Passed: %0d", pass_count);
        $display("Failed: %0d", fail_count);
        $display("Success rate: %.1f%%", (pass_count * 100.0) / test_count);
        
        if (pass_count == test_count) begin
            $display("🎉 ALL TESTS PASSED! System ready for dataset testing!");
        end else begin
            $display("⚠️ Some tests failed. Review and fix issues.");
        end
        
        $finish;
    end

    // Waveform dumping
    initial begin
        $dumpfile("multi_sensor_fusion_system.vcd");
        $dumpvars(0, tb_multi_sensor_fusion_system);
    end

endmodule
