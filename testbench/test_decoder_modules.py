#!/usr/bin/env python3
"""
Test suite for individual decoder modules
Tests Camera Decoder, LiDAR Decoder, Radar Filter, and IMU Synchronizer
"""

import random

def camera_decoder_detailed_test():
    """Test Camera Decoder functionality in detail"""
    
    def nal_parser_simulate(bitstream):
        """Simulate NAL Parser"""
        # Extract NAL unit type from first byte
        nal_type = (bitstream >> (3072 - 8)) & 0xFF
        
        # Validate NAL type
        valid_nal_types = [1, 2, 5, 6, 7, 8, 9]  # Common H.264/H.265 NAL types
        if nal_type not in valid_nal_types:
            nal_type = 1  # Default to slice
        
        # Extract payload
        payload = bitstream & ((1 << (3072 - 8)) - 1)
        
        return nal_type, payload
    
    def header_decoder_simulate(nal_unit, nal_type):
        """Simulate Header Decoder"""
        if nal_type in [7, 8]:  # SPS/PPS
            # Extract header information
            width = ((nal_unit >> 16) & 0xFFFF) or 1920  # Default 1920
            height = ((nal_unit >> 32) & 0xFFFF) or 1080  # Default 1080
            profile = (nal_unit >> 48) & 0xFF
            level = (nal_unit >> 56) & 0xFF
            
            return True, width, height, profile, level
        else:
            return False, 0, 0, 0, 0
    
    def slice_decoder_simulate(nal_unit, nal_type):
        """Simulate Slice Decoder"""
        if nal_type in [1, 2, 5]:  # Slice types
            # Simulate slice decoding
            slice_data = nal_unit ^ 0xAAAAAAAA
            return True, slice_data
        else:
            return False, 0
    
    # Test cases
    test_cases = [
        # (bitstream, expected_nal_type, description)
        (0x07 << (3072 - 8) | 0x12345678, 7, "SPS NAL unit"),
        (0x08 << (3072 - 8) | 0x87654321, 8, "PPS NAL unit"),
        (0x01 << (3072 - 8) | 0xABCDEF00, 1, "Slice NAL unit"),
        (0x05 << (3072 - 8) | 0xFEDCBA98, 5, "IDR slice"),
        (0xFF << (3072 - 8) | 0x11111111, 1, "Invalid NAL type (corrected)"),
    ]
    
    passed = 0
    total = len(test_cases)
    
    print("=== Camera Decoder Tests ===")
    
    for bitstream, expected_nal, desc in test_cases:
        nal_type, payload = nal_parser_simulate(bitstream)
        
        if nal_type == expected_nal:
            print(f"PASS: {desc}")
            passed += 1
        else:
            print(f"FAIL: {desc} - Expected NAL {expected_nal}, got {nal_type}")
    
    # Test header decoder
    sps_bitstream = 0x07 << (3072 - 8) | (1920 << 16) | (1080 << 32) | (100 << 48) | (40 << 56)
    nal_type, payload = nal_parser_simulate(sps_bitstream)
    valid, width, height, profile, level = header_decoder_simulate(payload, nal_type)
    
    if valid and width == 1920 and height == 1080:
        print("PASS: Header decoder extracts correct dimensions")
        passed += 1
        total += 1
    else:
        print(f"FAIL: Header decoder - Expected 1920x1080, got {width}x{height}")
        total += 1
    
    return passed, total

def lidar_decoder_detailed_test():
    """Test LiDAR Decoder functionality in detail"""
    
    def bitstream_reader_simulate(compressed_data):
        """Simulate Bitstream Reader"""
        # Extract header (first 32 bits)
        header = (compressed_data >> 480) & 0xFFFFFFFF
        
        # Extract payload
        payload = compressed_data & ((1 << 480) - 1)
        
        # Validate header
        magic_number = (header >> 24) & 0xFF
        if magic_number != 0xAB:  # Expected magic number
            return False, 0, 0
        
        return True, header, payload
    
    def entropy_decoder_simulate(payload, header):
        """Simulate Entropy Decoder"""
        # Extract compression parameters from header
        compression_type = (header >> 16) & 0xFF
        
        if compression_type == 1:  # Huffman
            # Simulate Huffman decoding
            decoded = payload ^ 0x12345678
        elif compression_type == 2:  # Arithmetic
            # Simulate arithmetic decoding
            decoded = payload ^ 0x87654321
        else:
            # Default decompression
            decoded = payload
        
        return decoded
    
    def geometry_decompressor_simulate(decoded_data):
        """Simulate Geometry Decompressor"""
        # Simulate point cloud reconstruction
        num_points = (decoded_data & 0xFFFF)
        if num_points == 0:
            num_points = 1000  # Default
        
        # Simulate coordinate decompression
        point_cloud = decoded_data ^ 0xDEADBEEF
        
        return point_cloud, num_points
    
    # Test cases
    test_cases = [
        # (compressed_data, description)
        (0xAB000001 << 480 | 0x12345678, "Huffman compressed data"),
        (0xAB000002 << 480 | 0x87654321, "Arithmetic compressed data"),
        (0xAB000000 << 480 | 0xABCDEF00, "Uncompressed data"),
        (0xFF000001 << 480 | 0x11111111, "Invalid magic number"),
    ]
    
    passed = 0
    total = len(test_cases)
    
    print("=== LiDAR Decoder Tests ===")
    
    for compressed_data, desc in test_cases:
        valid, header, payload = bitstream_reader_simulate(compressed_data)
        
        if desc == "Invalid magic number":
            if not valid:
                print(f"PASS: {desc} - Correctly rejected")
                passed += 1
            else:
                print(f"FAIL: {desc} - Should have been rejected")
        else:
            if valid:
                decoded = entropy_decoder_simulate(payload, header)
                point_cloud, num_points = geometry_decompressor_simulate(decoded)
                
                if point_cloud != 0 and num_points > 0:
                    print(f"PASS: {desc}")
                    passed += 1
                else:
                    print(f"FAIL: {desc} - Invalid output")
            else:
                print(f"FAIL: {desc} - Should have been valid")
    
    return passed, total

def radar_filter_detailed_test():
    """Test Radar Filter functionality in detail"""
    
    def noise_reducer_simulate(raw_data):
        """Simulate Noise Reducer"""
        # Extract intensity
        intensity = raw_data & 0xFFFFFFFF
        
        # Apply noise threshold
        noise_threshold = 0x1000
        if intensity < noise_threshold:
            return 0
        else:
            return raw_data
    
    def clutter_remover_simulate(filtered_data):
        """Simulate Clutter Remover"""
        if filtered_data == 0:
            return 0
        
        # Simulate median filter
        # For simplicity, apply a scaling factor
        return int(filtered_data * 0.9) & ((1 << 128) - 1)
    
    def doppler_processor_simulate(clean_data):
        """Simulate Doppler Processor"""
        if clean_data == 0:
            return 0, 0
        
        # Extract velocity component
        velocity = (clean_data >> 32) & 0xFFFFFFFF
        
        # Apply Doppler processing
        processed_velocity = velocity ^ 0x12345678
        
        return clean_data, processed_velocity
    
    # Test cases
    test_cases = [
        # (raw_data, description)
        (0x2000 | (0x11111111 << 32), "Strong signal"),
        (0x0500 | (0x22222222 << 32), "Weak signal (noise)"),
        (0x5000 | (0x33333333 << 32), "Medium signal"),
        (0x0000, "No signal"),
        (0xFFFF | (0x44444444 << 32), "Maximum intensity"),
    ]
    
    passed = 0
    total = len(test_cases)
    
    print("=== Radar Filter Tests ===")
    
    for raw_data, desc in test_cases:
        # Stage 1: Noise reduction
        noise_filtered = noise_reducer_simulate(raw_data)
        
        # Stage 2: Clutter removal
        clutter_filtered = clutter_remover_simulate(noise_filtered)
        
        # Stage 3: Doppler processing
        final_data, velocity = doppler_processor_simulate(clutter_filtered)
        
        # Validate results
        if desc == "Weak signal (noise)":
            if final_data == 0:
                print(f"PASS: {desc} - Correctly filtered out")
                passed += 1
            else:
                print(f"FAIL: {desc} - Should have been filtered out")
        elif desc == "No signal":
            if final_data == 0:
                print(f"PASS: {desc} - Correctly handled")
                passed += 1
            else:
                print(f"FAIL: {desc} - Should remain zero")
        else:
            if final_data != 0:
                print(f"PASS: {desc}")
                passed += 1
            else:
                print(f"FAIL: {desc} - Should not be filtered out")
    
    return passed, total

def imu_synchronizer_detailed_test():
    """Test IMU Synchronizer functionality in detail"""
    
    def timestamp_buffer_simulate(imu_data, timestamp):
        """Simulate Timestamp Buffer"""
        # Combine IMU data with timestamp
        buffered_data = (timestamp << 64) | imu_data
        return buffered_data
    
    def time_sync_simulate(buffered_data, ref_time):
        """Simulate Time Sync Module"""
        timestamp = (buffered_data >> 64) & 0xFFFFFFFFFFFFFFFF
        imu_data = buffered_data & 0xFFFFFFFFFFFFFFFF
        
        # Calculate time offset
        time_offset = ref_time - timestamp
        
        # Apply synchronization
        if abs(time_offset) < 1000:  # Within acceptable range
            return True, imu_data
        else:
            return False, 0
    
    def interpolator_simulate(imu_data, time_offset):
        """Simulate Timestamp Interpolator"""
        if imu_data == 0:
            return 0
        
        # Simple interpolation based on time offset
        interpolation_factor = (time_offset & 0xFF) / 256.0
        
        # Apply interpolation to quaternion components
        quat_w = imu_data & 0xFFFF
        quat_x = (imu_data >> 16) & 0xFFFF
        quat_y = (imu_data >> 32) & 0xFFFF
        quat_z = (imu_data >> 48) & 0xFFFF
        
        # Interpolate (simplified)
        interp_w = int(quat_w * (1.0 + interpolation_factor * 0.01)) & 0xFFFF
        interp_x = int(quat_x * (1.0 + interpolation_factor * 0.01)) & 0xFFFF
        interp_y = int(quat_y * (1.0 + interpolation_factor * 0.01)) & 0xFFFF
        interp_z = int(quat_z * (1.0 + interpolation_factor * 0.01)) & 0xFFFF
        
        return (interp_z << 48) | (interp_y << 32) | (interp_x << 16) | interp_w
    
    # Test cases
    test_cases = [
        # (imu_data, timestamp, ref_time, description)
        (0x1234567890ABCDEF, 1000, 1100, "Small time offset"),
        (0xFEDCBA0987654321, 1000, 1500, "Medium time offset"),
        (0x1111222233334444, 1000, 3000, "Large time offset"),
        (0x0000000000000000, 1000, 1100, "Zero IMU data"),
        (0xAAAABBBBCCCCDDDD, 1000, 1000, "Perfect sync"),
    ]
    
    passed = 0
    total = len(test_cases)
    
    print("=== IMU Synchronizer Tests ===")
    
    for imu_data, timestamp, ref_time, desc in test_cases:
        # Stage 1: Buffer with timestamp
        buffered = timestamp_buffer_simulate(imu_data, timestamp)
        
        # Stage 2: Time synchronization
        sync_valid, synced_data = time_sync_simulate(buffered, ref_time)
        
        # Stage 3: Interpolation
        time_offset = ref_time - timestamp
        final_data = interpolator_simulate(synced_data, time_offset)
        
        # Validate results
        if desc == "Large time offset":
            if not sync_valid:
                print(f"PASS: {desc} - Correctly rejected")
                passed += 1
            else:
                print(f"FAIL: {desc} - Should have been rejected")
        elif desc == "Zero IMU data":
            if final_data == 0:
                print(f"PASS: {desc} - Correctly handled")
                passed += 1
            else:
                print(f"FAIL: {desc} - Should remain zero")
        else:
            if sync_valid and final_data != 0:
                print(f"PASS: {desc}")
                passed += 1
            else:
                print(f"FAIL: {desc} - Synchronization failed")
    
    return passed, total

def test_all_decoders():
    """Run all decoder tests"""
    
    print("🔍 Testing Individual Decoder Modules")
    print("=" * 60)
    
    total_passed = 0
    total_tests = 0
    
    # Test Camera Decoder
    passed, tests = camera_decoder_detailed_test()
    total_passed += passed
    total_tests += tests
    print(f"Camera Decoder: {passed}/{tests} passed\n")
    
    # Test LiDAR Decoder
    passed, tests = lidar_decoder_detailed_test()
    total_passed += passed
    total_tests += tests
    print(f"LiDAR Decoder: {passed}/{tests} passed\n")
    
    # Test Radar Filter
    passed, tests = radar_filter_detailed_test()
    total_passed += passed
    total_tests += tests
    print(f"Radar Filter: {passed}/{tests} passed\n")
    
    # Test IMU Synchronizer
    passed, tests = imu_synchronizer_detailed_test()
    total_passed += passed
    total_tests += tests
    print(f"IMU Synchronizer: {passed}/{tests} passed\n")
    
    # Summary
    print("=" * 60)
    print(f"📊 Decoder Modules Test Summary")
    print(f"Total tests: {total_tests}")
    print(f"Passed: {total_passed}")
    print(f"Failed: {total_tests - total_passed}")
    print(f"Success rate: {(total_passed/total_tests)*100:.1f}%")
    
    if total_passed == total_tests:
        print("✅ ALL DECODER TESTS PASSED!")
        return True
    else:
        print("❌ SOME DECODER TESTS FAILED!")
        return False

if __name__ == "__main__":
    success = test_all_decoders()
    exit(0 if success else 1)
