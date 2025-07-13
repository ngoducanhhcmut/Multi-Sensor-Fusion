// Advanced SystemVerilog Testbench for Multi-Sensor Fusion
// Integrates with Python test cases for comprehensive verification
`timescale 1ns/1ps

module tb_advanced_system;

    // Clock and reset
    logic clk;
    logic rst_n;
    
    // Test control signals
    logic test_start;
    logic test_done;
    logic [7:0] test_id;
    logic [31:0] test_status;
    
    // DUT signals
    logic [3071:0] camera_bitstream;
    logic camera_valid;
    logic [511:0] lidar_compressed;
    logic lidar_valid;
    logic [127:0] radar_raw;
    logic radar_valid;
    logic [63:0] imu_raw;
    logic imu_valid;
    logic [63:0] timestamp;
    
    // Weight matrices for fusion core
    logic [15:0] W_q [0:5][0:15];
    logic [15:0] W_k [0:5][0:15];
    logic [15:0] W_v [0:5][0:15];
    logic signed [15:0] fc_weights [0:127][0:95];
    logic signed [15:0] fc_bias [0:127];
    
    // Output signals
    logic [2047:0] fused_tensor;
    logic output_valid;
    logic [7:0] error_flags;
    
    // Test vectors from Python
    logic [3071:0] python_camera_data;
    logic [511:0] python_lidar_data;
    logic [127:0] python_radar_data;
    logic [63:0] python_imu_data;
    logic [2047:0] python_expected_output;
    logic python_test_valid;
    
    // Performance monitoring
    logic [31:0] cycle_count;
    logic [31:0] latency_measurement;
    logic performance_monitor_en;
    
    // DUT instantiation
    MultiSensorFusionTop #(
        .CAMERA_WIDTH(3072),
        .LIDAR_WIDTH(512),
        .RADAR_WIDTH(128),
        .IMU_WIDTH(64),
        .OUTPUT_WIDTH(2048),
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
        .error_flags(error_flags)
    );
    
    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 100MHz clock
    end
    
    // Reset generation
    initial begin
        rst_n = 0;
        #100;
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
    
    // Test execution task
    task automatic run_test_case(
        input [7:0] test_case_id,
        input [3071:0] cam_data,
        input [511:0] lidar_data,
        input [127:0] radar_data,
        input [63:0] imu_data,
        input [2047:0] expected_output
    );
        begin
            test_id = test_case_id;
            test_start = 1;
            
            // Apply test inputs
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
            
            // Check results
            if (fused_tensor == expected_output) begin
                test_status = 32'h00000001; // PASS
                $display("Test %0d PASSED - Latency: %0d cycles", test_case_id, latency_measurement);
            end else begin
                test_status = 32'h00000000; // FAIL
                $display("Test %0d FAILED - Expected: %h, Got: %h", test_case_id, expected_output, fused_tensor);
            end
            
            // Clear inputs
            camera_valid = 0;
            lidar_valid = 0;
            radar_valid = 0;
            imu_valid = 0;
            test_start = 0;
            
            #100; // Wait between tests
        end
    endtask
    
    // Edge case testing task
    task automatic run_edge_case_test(
        input [7:0] test_case_id,
        input string test_name,
        input [3071:0] cam_data,
        input [511:0] lidar_data,
        input [127:0] radar_data,
        input [63:0] imu_data,
        input logic should_error
    );
        begin
            $display("Running edge case: %s", test_name);
            
            // Apply test inputs
            camera_bitstream = cam_data;
            camera_valid = 1;
            lidar_compressed = lidar_data;
            lidar_valid = 1;
            radar_raw = radar_data;
            radar_valid = 1;
            imu_raw = imu_data;
            imu_valid = 1;
            timestamp = $time;
            
            // Wait for processing
            #1000;
            
            // Check error flags
            if (should_error) begin
                if (error_flags != 0) begin
                    $display("Edge case %s PASSED - Error correctly detected: %h", test_name, error_flags);
                    test_status = 32'h00000001;
                end else begin
                    $display("Edge case %s FAILED - Error not detected", test_name);
                    test_status = 32'h00000000;
                end
            end else begin
                if (error_flags == 0 && output_valid) begin
                    $display("Edge case %s PASSED - Valid processing", test_name);
                    test_status = 32'h00000001;
                end else begin
                    $display("Edge case %s FAILED - Unexpected error: %h", test_name, error_flags);
                    test_status = 32'h00000000;
                end
            end
            
            // Clear inputs
            camera_valid = 0;
            lidar_valid = 0;
            radar_valid = 0;
            imu_valid = 0;
            
            #100;
        end
    endtask
    
    // Stress testing task
    task automatic run_stress_test(
        input [7:0] test_case_id,
        input string test_name,
        input int num_iterations
    );
        begin
            int pass_count = 0;
            int total_latency = 0;
            
            $display("Running stress test: %s (%0d iterations)", test_name, num_iterations);
            
            for (int i = 0; i < num_iterations; i++) begin
                // Generate random test data
                camera_bitstream = $random();
                lidar_compressed = $random();
                radar_raw = $random();
                imu_raw = $random();
                timestamp = $time;
                
                camera_valid = 1;
                lidar_valid = 1;
                radar_valid = 1;
                imu_valid = 1;
                
                performance_monitor_en = 1;
                
                // Wait for output or timeout
                fork
                    begin
                        wait(output_valid);
                        pass_count++;
                        total_latency += latency_measurement;
                    end
                    begin
                        #10000; // 10us timeout
                    end
                join_any
                disable fork;
                
                performance_monitor_en = 0;
                camera_valid = 0;
                lidar_valid = 0;
                radar_valid = 0;
                imu_valid = 0;
                
                #50; // Short delay between iterations
            end
            
            $display("Stress test %s completed:", test_name);
            $display("  Passed: %0d/%0d (%.1f%%)", pass_count, num_iterations, 
                    (pass_count * 100.0) / num_iterations);
            if (pass_count > 0) begin
                $display("  Average latency: %0d cycles", total_latency / pass_count);
            end
            
            test_status = (pass_count >= (num_iterations * 0.9)) ? 32'h00000001 : 32'h00000000;
        end
    endtask
    
    // Initialize weight matrices
    initial begin
        // Initialize with small random values
        for (int i = 0; i < 6; i++) begin
            for (int j = 0; j < 16; j++) begin
                W_q[i][j] = $random() % 256 - 128; // -128 to 127
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
    
    // Main test sequence
    initial begin
        $display("Starting Advanced SystemVerilog Testbench");
        
        // Wait for reset
        wait(rst_n);
        #100;
        
        // Run basic functionality tests
        $display("\n=== Basic Functionality Tests ===");
        run_test_case(1, 3072'h123456789ABCDEF, 512'h87654321, 128'hDEADBEEF, 64'hCAFEBABE, 2048'h0);
        
        // Run edge case tests
        $display("\n=== Edge Case Tests ===");
        
        // Camera decoder edge cases
        run_edge_case_test(10, "Corrupted NAL Header", 3072'h00, 512'h12345678, 128'hABCDEF12, 64'h12345678, 1);
        run_edge_case_test(11, "Invalid Resolution", {16'h2000, 16'h2000, 3040'h0}, 512'h12345678, 128'hABCDEF12, 64'h12345678, 1);
        run_edge_case_test(12, "Valid Processing", 3072'h123456789ABCDEF, 512'h87654321, 128'hDEADBEEF, 64'hCAFEBABE, 0);
        
        // LiDAR decoder edge cases
        run_edge_case_test(20, "Invalid Magic Number", 3072'h123456789ABCDEF, 512'h12345678, 128'hDEADBEEF, 64'hCAFEBABE, 1);
        run_edge_case_test(21, "Valid LiDAR Data", 3072'h123456789ABCDEF, {32'h4C494441, 480'h87654321}, 128'hDEADBEEF, 64'hCAFEBABE, 0);
        
        // Radar filter edge cases
        run_edge_case_test(30, "Range Overflow", 3072'h123456789ABCDEF, 512'h87654321, {32'hFFFFFFFF, 96'hDEADBEEF}, 64'hCAFEBABE, 1);
        run_edge_case_test(31, "Normal Radar", 3072'h123456789ABCDEF, 512'h87654321, 128'h12345678, 64'hCAFEBABE, 0);
        
        // IMU synchronizer edge cases
        run_edge_case_test(40, "Time Drift", 3072'h123456789ABCDEF, 512'h87654321, 128'hDEADBEEF, 64'h00000001, 1);
        run_edge_case_test(41, "Normal IMU", 3072'h123456789ABCDEF, 512'h87654321, 128'hDEADBEEF, 64'h80008000, 0);
        
        // Run stress tests
        $display("\n=== Stress Tests ===");
        run_stress_test(50, "High Throughput", 100);
        run_stress_test(51, "Random Data", 50);
        run_stress_test(52, "Burst Processing", 20);
        
        $display("\n=== All Tests Completed ===");
        $finish;
    end
    
    // Waveform dumping
    initial begin
        $dumpfile("advanced_system_tb.vcd");
        $dumpvars(0, tb_advanced_system);
    end

endmodule
