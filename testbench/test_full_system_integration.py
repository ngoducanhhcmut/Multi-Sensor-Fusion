#!/usr/bin/env python3
"""
Full System Integration Test for Multi-Sensor Fusion
Tests the complete pipeline from raw sensor inputs to fused tensor output
Based on the actual file specifications from the Full modules
"""

import random

def camera_decoder_simulate(bitstream_3072):
    """
    Simulate Camera Decoder (H.264/H.265 decoding)
    Input: 3072-bit bitstream
    Output: Decoded frame data (simplified to 3072-bit for testing)
    """
    # Simplified simulation - in reality this would be complex H.264/H.265 decoding
    # For testing, we'll extract meaningful data and apply basic processing
    
    # Extract NAL units (simplified)
    nal_type = (bitstream_3072 >> 3064) & 0xFF
    payload = bitstream_3072 & ((1 << 3064) - 1)
    
    # Simulate decoding process
    decoded_frame = payload ^ 0xAAAAAAAA  # Simple XOR for simulation
    
    # Return decoded frame (3072-bit)
    return decoded_frame & ((1 << 3072) - 1)

def lidar_decoder_simulate(compressed_512):
    """
    Simulate LiDAR Decoder (Point cloud decompression)
    Input: 512-bit compressed point cloud
    Output: Decompressed point cloud data
    """
    # Simplified point cloud decompression
    # Extract header and payload
    header = (compressed_512 >> 480) & 0xFFFFFFFF
    payload = compressed_512 & ((1 << 480) - 1)
    
    # Simulate entropy decoding and geometry decompression
    decompressed = payload ^ (header << 16)
    
    # Return decompressed point cloud (512-bit)
    return decompressed & ((1 << 512) - 1)

def radar_filter_simulate(raw_radar_128):
    """
    Simulate Radar Filter (Noise reduction, clutter removal, Doppler processing)
    Input: 128-bit raw radar data
    Output: Filtered point cloud data
    """
    # Extract range, velocity, and angle components
    range_data = raw_radar_128 & 0xFFFFFFFF
    velocity_data = (raw_radar_128 >> 32) & 0xFFFFFFFF
    angle_data = (raw_radar_128 >> 64) & 0xFFFFFFFF
    intensity_data = (raw_radar_128 >> 96) & 0xFFFFFFFF
    
    # Simulate noise reduction (simple threshold)
    noise_threshold = 0x1000
    if intensity_data < noise_threshold:
        intensity_data = 0
    
    # Simulate clutter removal (median filter approximation)
    filtered_intensity = intensity_data * 0.8  # Simple scaling
    
    # Simulate Doppler processing
    processed_velocity = velocity_data ^ 0x12345678
    
    # Reconstruct filtered data
    filtered_radar = (int(filtered_intensity) << 96) | (processed_velocity << 64) | (angle_data << 32) | range_data
    
    return filtered_radar & ((1 << 128) - 1)

def imu_synchronizer_simulate(raw_imu_64, timestamp):
    """
    Simulate IMU Synchronizer (Time synchronization and interpolation)
    Input: 64-bit raw IMU data + timestamp
    Output: Synchronized IMU data
    """
    # Extract quaternion and acceleration
    quat_w = raw_imu_64 & 0xFFFF
    quat_x = (raw_imu_64 >> 16) & 0xFFFF
    quat_y = (raw_imu_64 >> 32) & 0xFFFF
    quat_z = (raw_imu_64 >> 48) & 0xFFFF
    
    # Simulate time synchronization (simple interpolation)
    sync_factor = (timestamp & 0xFF) / 256.0
    
    # Apply synchronization adjustment
    sync_quat_w = int(quat_w * (1.0 + sync_factor * 0.01)) & 0xFFFF
    sync_quat_x = int(quat_x * (1.0 + sync_factor * 0.01)) & 0xFFFF
    sync_quat_y = int(quat_y * (1.0 + sync_factor * 0.01)) & 0xFFFF
    sync_quat_z = int(quat_z * (1.0 + sync_factor * 0.01)) & 0xFFFF
    
    # Reconstruct synchronized IMU data
    sync_imu = (sync_quat_z << 48) | (sync_quat_y << 32) | (sync_quat_x << 16) | sync_quat_w
    
    return sync_imu & ((1 << 64) - 1)

def camera_feature_extractor_simulate(decoded_frame_3072):
    """
    Simulate Camera Feature Extractor (CNN-based feature extraction)
    Input: 3072-bit decoded frame
    Output: 256-bit feature vector
    """
    # Simulate CNN processing (simplified)
    # Extract patches and apply convolution-like operations
    
    feature_vector = 0
    for i in range(16):  # 16 features of 16 bits each
        # Extract 192-bit patch
        patch_start = i * 192
        if patch_start + 192 <= 3072:
            patch = (decoded_frame_3072 >> patch_start) & ((1 << 192) - 1)
        else:
            patch = decoded_frame_3072 & ((1 << 192) - 1)
        
        # Simulate convolution and pooling
        feature = (patch ^ 0xAAAA) & 0xFFFF
        feature_vector |= (feature << (16 * i))
    
    return feature_vector & ((1 << 256) - 1)

def lidar_feature_extractor_simulate(point_cloud_512):
    """
    Simulate LiDAR Feature Extractor (Voxel-based processing)
    Input: 512-bit point cloud
    Output: 256-bit feature vector
    """
    # Simulate voxel grid creation and clustering
    feature_vector = 0
    
    for i in range(16):  # 16 features of 16 bits each
        # Extract 32-bit voxel data
        voxel_start = i * 32
        voxel_data = (point_cloud_512 >> voxel_start) & 0xFFFFFFFF
        
        # Simulate clustering and feature calculation
        feature = (voxel_data ^ 0x12345678) & 0xFFFF
        feature_vector |= (feature << (16 * i))
    
    return feature_vector & ((1 << 256) - 1)

def radar_feature_extractor_simulate(filtered_radar_128):
    """
    Simulate Radar Feature Extractor (Range/Velocity/Angle processing)
    Input: 128-bit filtered radar data
    Output: 256-bit feature vector
    """
    # Extract components
    range_data = filtered_radar_128 & 0xFFFFFFFF
    velocity_data = (filtered_radar_128 >> 32) & 0xFFFFFFFF
    angle_data = (filtered_radar_128 >> 64) & 0xFFFFFFFF
    intensity_data = (filtered_radar_128 >> 96) & 0xFFFFFFFF
    
    # Simulate feature extraction
    feature_vector = 0
    
    # Range features (4 features)
    for i in range(4):
        range_feature = ((range_data >> (8 * i)) & 0xFF) << 8
        feature_vector |= (range_feature << (16 * i))
    
    # Velocity features (4 features)
    for i in range(4):
        vel_feature = ((velocity_data >> (8 * i)) & 0xFF) << 8
        feature_vector |= (vel_feature << (16 * (i + 4)))
    
    # Angle features (4 features)
    for i in range(4):
        angle_feature = ((angle_data >> (8 * i)) & 0xFF) << 8
        feature_vector |= (angle_feature << (16 * (i + 8)))
    
    # Intensity features (4 features)
    for i in range(4):
        intensity_feature = ((intensity_data >> (8 * i)) & 0xFF) << 8
        feature_vector |= (intensity_feature << (16 * (i + 12)))
    
    return feature_vector & ((1 << 256) - 1)

def temporal_alignment_simulate(camera_features, lidar_features, radar_features, imu_data):
    """
    Simulate Temporal Alignment (Multi-sensor time alignment)
    Input: Feature vectors from all sensors + IMU data
    Output: Time-aligned fused data (3840-bit)
    """
    # Simulate timestamp extraction and alignment
    # For simplicity, assume all data is already time-aligned
    
    # Assemble fused data according to temporal_alignment_full.v specification
    # fused_data[3839:3328] = lidar_data (512-bit)
    # fused_data[3327:256] = camera_data (3072-bit) 
    # fused_data[255:128] = radar_data (128-bit)
    # fused_data[127:64] = imu_data (64-bit)
    
    # Extend features to required sizes
    lidar_extended = lidar_features | ((lidar_features & 0xFFFF) << 256)  # Extend to 512-bit
    camera_extended = camera_features  # Already 256-bit, extend to 3072-bit
    for i in range(11):  # Replicate to fill 3072 bits
        camera_extended |= ((camera_features & 0xFFFF) << (256 + i * 256))
    
    radar_extended = radar_features & ((1 << 128) - 1)  # Truncate to 128-bit
    imu_extended = imu_data & ((1 << 64) - 1)  # Already 64-bit
    
    # Assemble according to specification
    fused_data = 0
    fused_data |= imu_extended  # [63:0]
    fused_data |= (radar_extended << 64)  # [191:64] -> [255:128]
    fused_data |= (camera_extended << 256)  # [3327:256]
    fused_data |= (lidar_extended << 3328)  # [3839:3328]
    
    return fused_data & ((1 << 3840) - 1)

def create_test_weights(seed=42):
    """Create simple test weight matrices with deterministic seed"""
    random.seed(seed)  # Ensure deterministic weights

    # QKV weights - small values to avoid overflow
    W_q = [[random.randint(-5, 5) for _ in range(16)] for _ in range(12)]
    W_k = [[random.randint(-5, 5) for _ in range(16)] for _ in range(12)]
    W_v = [[random.randint(-5, 5) for _ in range(16)] for _ in range(12)]

    # Fusion compressor weights - very small to avoid overflow
    fc_weights = [[random.randint(-2, 2) for _ in range(96)] for _ in range(128)]
    fc_bias = [random.randint(-10, 10) for _ in range(128)]

    return W_q, W_k, W_v, fc_weights, fc_bias

def simple_fusion_core_simulate(camera_features, lidar_features, radar_features):
    """
    Simple fusion core simulation for testing
    """
    # Create test weights
    W_q, W_k, W_v, fc_weights, fc_bias = create_test_weights()

    # Simple fusion: XOR the features and apply basic transformation
    combined = camera_features ^ lidar_features ^ radar_features

    # Simulate basic processing to create 2048-bit output
    fused_tensor = 0
    for i in range(128):  # 128 elements of 16 bits each = 2048 bits
        element = (combined >> (i * 2)) & 0x3  # Extract 2 bits
        element = (element + fc_bias[i % len(fc_bias)]) & 0xFFFF  # Add bias and clip
        fused_tensor |= (element << (16 * i))

    return fused_tensor & ((1 << 2048) - 1)

def full_system_simulate(camera_bitstream, lidar_compressed, radar_raw, imu_raw, timestamp):
    """
    Simulate the complete Multi-Sensor Fusion system
    Input: Raw sensor data
    Output: 2048-bit fused tensor
    """
    # Stage 1: Sensor Decoding/Filtering
    decoded_camera = camera_decoder_simulate(camera_bitstream)
    decoded_lidar = lidar_decoder_simulate(lidar_compressed)
    filtered_radar = radar_filter_simulate(radar_raw)
    synced_imu = imu_synchronizer_simulate(imu_raw, timestamp)
    
    # Stage 2: Feature Extraction
    camera_features = camera_feature_extractor_simulate(decoded_camera)
    lidar_features = lidar_feature_extractor_simulate(decoded_lidar)
    radar_features = radar_feature_extractor_simulate(filtered_radar)
    
    # Stage 3: Temporal Alignment
    aligned_data = temporal_alignment_simulate(camera_features, lidar_features, radar_features, synced_imu)
    
    # Stage 4: Fusion Core Processing
    fused_tensor = simple_fusion_core_simulate(camera_features, lidar_features, radar_features)
    
    return fused_tensor, aligned_data

def test_full_system_integration():
    """Run comprehensive full system integration tests"""
    
    test_count = 0
    pass_count = 0
    fail_count = 0
    
    def run_test(test_name, test_func):
        nonlocal test_count, pass_count, fail_count
        test_count += 1
        
        try:
            result = test_func()
            if result:
                print(f"PASS: {test_name}")
                pass_count += 1
            else:
                print(f"FAIL: {test_name}")
                fail_count += 1
        except Exception as e:
            print(f"ERROR: {test_name} - {str(e)}")
            fail_count += 1
    
    print("=== Full System Integration Tests ===")
    
    def test_basic_pipeline():
        """Test basic end-to-end pipeline"""
        # Create test inputs
        camera_bitstream = 0x123456789ABCDEF0 << 2944  # 3072-bit
        lidar_compressed = 0xFEDCBA9876543210FEDCBA9876543210  # 512-bit
        radar_raw = 0x1122334455667788  # 128-bit
        imu_raw = 0xAABBCCDDEEFF1122  # 64-bit
        timestamp = 0x1000
        
        fused_tensor, aligned_data = full_system_simulate(
            camera_bitstream, lidar_compressed, radar_raw, imu_raw, timestamp
        )
        
        # Verify outputs are non-zero and within expected ranges
        return (fused_tensor != 0 and aligned_data != 0 and 
                fused_tensor < (1 << 2048) and aligned_data < (1 << 3840))
    
    def test_zero_inputs():
        """Test with all zero inputs"""
        fused_tensor, aligned_data = full_system_simulate(0, 0, 0, 0, 0)
        
        # With zero inputs, some processing should still occur
        return True  # Just verify no crashes
    
    def test_max_inputs():
        """Test with maximum value inputs"""
        camera_max = (1 << 3072) - 1
        lidar_max = (1 << 512) - 1
        radar_max = (1 << 128) - 1
        imu_max = (1 << 64) - 1
        timestamp_max = 0xFFFF
        
        fused_tensor, aligned_data = full_system_simulate(
            camera_max, lidar_max, radar_max, imu_max, timestamp_max
        )
        
        return fused_tensor != 0 and aligned_data != 0
    
    def test_random_inputs():
        """Test with random inputs"""
        random.seed(42)
        
        camera_random = random.getrandbits(3072)
        lidar_random = random.getrandbits(512)
        radar_random = random.getrandbits(128)
        imu_random = random.getrandbits(64)
        timestamp_random = random.getrandbits(16)
        
        fused_tensor, aligned_data = full_system_simulate(
            camera_random, lidar_random, radar_random, imu_random, timestamp_random
        )
        
        return fused_tensor != 0 and aligned_data != 0
    
    def test_consistency():
        """Test that same inputs produce same outputs"""
        test_inputs = (0x12345, 0x67890, 0xABCDE, 0xF1234, 0x5678)
        
        result1 = full_system_simulate(*test_inputs)
        result2 = full_system_simulate(*test_inputs)
        
        return result1 == result2
    
    # Run all tests
    run_test("Basic pipeline", test_basic_pipeline)
    run_test("Zero inputs", test_zero_inputs)
    run_test("Maximum inputs", test_max_inputs)
    run_test("Random inputs", test_random_inputs)
    run_test("Consistency check", test_consistency)
    
    # Summary
    print(f"\n=== Full System Test Summary ===")
    print(f"Total tests: {test_count}")
    print(f"Passed: {pass_count}")
    print(f"Failed: {fail_count}")
    
    if fail_count == 0:
        print("ALL FULL SYSTEM TESTS PASSED!")
        return True
    else:
        print("SOME FULL SYSTEM TESTS FAILED!")
        return False

if __name__ == "__main__":
    success = test_full_system_integration()
    exit(0 if success else 1)
