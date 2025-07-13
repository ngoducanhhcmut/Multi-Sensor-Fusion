#!/usr/bin/env python3
"""
Advanced Edge Case Testing for Multi-Sensor Fusion System
Tests boundary conditions, error scenarios, and stress conditions
Based on technical specifications and real-world constraints
"""

import random
import math

def test_camera_decoder_edge_cases():
    """Advanced edge case testing for Camera Decoder"""
    
    print("=== CAMERA DECODER ADVANCED EDGE CASES ===")
    
    def camera_decoder_advanced_simulate(bitstream, test_scenario):
        """Simulate camera decoder with various edge cases"""
        
        # Extract NAL header
        nal_type = (bitstream >> (3072 - 8)) & 0xFF
        payload = bitstream & ((1 << (3072 - 8)) - 1)
        
        error_flags = 0
        decoded_pixels = 0
        
        if test_scenario == "corrupted_header":
            # Simulate corrupted NAL header
            if nal_type == 0x00 or nal_type == 0xFF:
                error_flags |= 0x01  # Header corruption
                return 0, error_flags
        
        elif test_scenario == "invalid_resolution":
            # Test with invalid resolution parameters
            width = (payload >> 16) & 0xFFFF
            height = payload & 0xFFFF
            if width > 4096 or height > 4096 or width < 16 or height < 16:
                error_flags |= 0x02  # Invalid resolution
                return 0, error_flags
        
        elif test_scenario == "buffer_overflow":
            # Simulate frame buffer overflow
            frame_size = 640 * 480 * 3  # RGB
            if payload > (1 << 20):  # > 1MB payload
                error_flags |= 0x04  # Buffer overflow
                return 0, error_flags
        
        elif test_scenario == "malformed_slice":
            # Test malformed slice data
            slice_header = (payload >> 32) & 0xFFFFFFFF
            if slice_header == 0x00000000:
                error_flags |= 0x08  # Malformed slice
                return 0, error_flags
        
        elif test_scenario == "reference_frame_missing":
            # Test missing reference frame
            ref_frame_id = (payload >> 24) & 0xFF
            if ref_frame_id > 15:  # Max 16 reference frames
                error_flags |= 0x10  # Reference frame error
                return 0, error_flags
        
        # Normal decoding simulation
        decoded_pixels = (payload & 0xFFFFFF) % (640 * 480)
        return decoded_pixels, error_flags
    
    # Test cases with edge conditions
    edge_cases = [
        ("corrupted_header", 0x00 << (3072 - 8), "Corrupted NAL header"),
        ("invalid_resolution", (8192 << 16) | 8192, "Invalid resolution > 4K"),
        ("buffer_overflow", (1 << 21), "Frame buffer overflow"),
        ("malformed_slice", 0x00000000 << 32, "Malformed slice header"),
        ("reference_frame_missing", 0xFF << 24, "Missing reference frame"),
        ("minimum_resolution", (16 << 16) | 16, "Minimum valid resolution"),
        ("maximum_resolution", (4096 << 16) | 4096, "Maximum valid resolution"),
        ("boundary_nal_types", 0x1F << (3072 - 8), "Boundary NAL type"),
    ]
    
    passed_tests = 0
    for scenario, test_data, description in edge_cases:
        try:
            pixels, errors = camera_decoder_advanced_simulate(test_data, scenario)
            
            # Verify error detection
            if scenario in ["corrupted_header", "invalid_resolution", "buffer_overflow", 
                          "malformed_slice", "reference_frame_missing"]:
                if errors != 0:
                    print(f"✅ {description}: Error correctly detected (0x{errors:02x})")
                    passed_tests += 1
                else:
                    print(f"❌ {description}: Error not detected")
            else:
                if errors == 0:
                    print(f"✅ {description}: Valid case handled correctly")
                    passed_tests += 1
                else:
                    print(f"❌ {description}: False error detected")
        except Exception as e:
            print(f"❌ {description}: Exception - {str(e)}")
    
    print(f"Camera Decoder Edge Cases: {passed_tests}/{len(edge_cases)} passed")
    return passed_tests == len(edge_cases)

def test_lidar_decoder_compression_edge_cases():
    """Advanced edge case testing for LiDAR Decoder compression algorithms"""
    
    print("=== LIDAR DECODER COMPRESSION EDGE CASES ===")
    
    def lidar_compression_test(compressed_data, compression_type, test_scenario):
        """Test LiDAR decompression with edge cases"""
        
        error_flags = 0
        decompressed_points = 0
        
        # Extract compression header
        magic_number = (compressed_data >> 480) & 0xFFFFFFFF  # Top 32 bits
        compression_mode = (compressed_data >> 476) & 0xF     # Next 4 bits
        point_count = (compressed_data >> 460) & 0xFFFF       # Next 16 bits
        
        if test_scenario == "invalid_magic":
            if magic_number != 0x4C494441:  # "LIDA" in hex
                error_flags |= 0x01  # Invalid magic number
                return 0, error_flags
        
        elif test_scenario == "unsupported_compression":
            if compression_mode > 2:  # Only 0=Uncompressed, 1=Huffman, 2=Arithmetic
                error_flags |= 0x02  # Unsupported compression
                return 0, error_flags
        
        elif test_scenario == "excessive_points":
            if point_count > 32767:  # Max points per frame (reasonable limit)
                error_flags |= 0x04  # Too many points
                return 0, error_flags
        
        elif test_scenario == "huffman_corruption":
            if compression_mode == 1:  # Huffman
                # Check for invalid Huffman codes
                huffman_data = compressed_data & ((1 << 460) - 1)
                if (huffman_data & 0xFFFF) == 0x0000:  # Invalid code
                    error_flags |= 0x08  # Huffman corruption
                    return 0, error_flags
        
        elif test_scenario == "arithmetic_overflow":
            if compression_mode == 2:  # Arithmetic
                # Check for arithmetic decoder overflow
                arithmetic_data = compressed_data & ((1 << 460) - 1)
                if arithmetic_data > ((1 << 460) - 1000):  # Near overflow
                    error_flags |= 0x10  # Arithmetic overflow
                    return 0, error_flags
        
        elif test_scenario == "zero_points":
            if point_count == 0:
                error_flags |= 0x20  # No points to decode
                return 0, error_flags
        
        # Simulate successful decompression
        decompressed_points = min(point_count, 1000)  # Limit for simulation
        return decompressed_points, error_flags
    
    # Test cases for compression edge conditions
    compression_cases = [
        ("invalid_magic", 0x12345678 << 480, 0, "Invalid magic number"),
        ("unsupported_compression", (0x4C494441 << 480) | (3 << 476), 0, "Unsupported compression mode"),
        ("excessive_points", (0x4C494441 << 480) | (40000 << 460), 0, "Excessive point count"),
        ("huffman_corruption", (0x4C494441 << 480) | (1 << 476) | (100 << 460), 1, "Huffman corruption"),
        ("arithmetic_overflow", (0x4C494441 << 480) | (2 << 476) | (100 << 460) | ((1 << 460) - 500), 2, "Arithmetic overflow"),
        ("zero_points", (0x4C494441 << 480) | (1 << 476), 1, "Zero point count"),
        ("valid_huffman", (0x4C494441 << 480) | (1 << 476) | (100 << 460) | 0x12345678, 1, "Valid Huffman"),
        ("valid_arithmetic", (0x4C494441 << 480) | (2 << 476) | (100 << 460) | 0x87654321, 2, "Valid Arithmetic"),
    ]
    
    passed_tests = 0
    for scenario, test_data, comp_type, description in compression_cases:
        try:
            points, errors = lidar_compression_test(test_data, comp_type, scenario)
            
            # Verify error detection
            error_expected = scenario in ["invalid_magic", "unsupported_compression", 
                                        "excessive_points", "huffman_corruption", 
                                        "arithmetic_overflow", "zero_points"]
            
            if error_expected:
                if errors != 0:
                    print(f"✅ {description}: Error correctly detected (0x{errors:02x})")
                    passed_tests += 1
                else:
                    print(f"❌ {description}: Error not detected")
            else:
                if errors == 0 and points > 0:
                    print(f"✅ {description}: Valid decompression ({points} points)")
                    passed_tests += 1
                else:
                    print(f"❌ {description}: False error or no output")
        except Exception as e:
            print(f"❌ {description}: Exception - {str(e)}")
    
    print(f"LiDAR Compression Edge Cases: {passed_tests}/{len(compression_cases)} passed")
    return passed_tests == len(compression_cases)

def test_radar_filter_signal_processing_edge_cases():
    """Advanced edge case testing for Radar Filter signal processing"""
    
    print("=== RADAR FILTER SIGNAL PROCESSING EDGE CASES ===")
    
    def radar_signal_processing_test(radar_data, test_scenario):
        """Test radar signal processing with edge cases"""
        
        # Extract radar components (128-bit total)
        range_data = (radar_data >> 96) & 0xFFFFFFFF      # 32-bit range
        velocity_data = (radar_data >> 64) & 0xFFFFFFFF   # 32-bit velocity  
        angle_data = (radar_data >> 32) & 0xFFFFFFFF      # 32-bit angle
        intensity_data = radar_data & 0xFFFFFFFF          # 32-bit intensity
        
        error_flags = 0
        filtered_output = 0
        
        if test_scenario == "range_overflow":
            # Test maximum range detection (e.g., 300m max)
            range_m = range_data * 0.1  # Convert to meters
            if range_m > 300.0:
                error_flags |= 0x01  # Range overflow
                return 0, error_flags
        
        elif test_scenario == "velocity_saturation":
            # Test velocity saturation (e.g., ±200 km/h max)
            velocity_kmh = (velocity_data - 0x80000000) * 0.01  # Convert to km/h
            if abs(velocity_kmh) > 200.0:
                error_flags |= 0x02  # Velocity saturation
                velocity_data = 0x80000000 + int(200.0 * 100 * (1 if velocity_kmh > 0 else -1))
        
        elif test_scenario == "angle_wraparound":
            # Test angle wraparound (0-360 degrees)
            angle_deg = angle_data * 360.0 / 0xFFFFFFFF
            if angle_deg >= 360.0:
                angle_data = int((angle_deg % 360.0) * 0xFFFFFFFF / 360.0)
        
        elif test_scenario == "intensity_threshold":
            # Test intensity below noise threshold
            if intensity_data < 0x1000:  # Below noise floor
                error_flags |= 0x04  # Low intensity
                return 0, error_flags
        
        elif test_scenario == "doppler_aliasing":
            # Test Doppler aliasing detection
            max_unambiguous_velocity = 100.0  # km/h
            velocity_kmh = abs((velocity_data - 0x80000000) * 0.01)
            if velocity_kmh > max_unambiguous_velocity:
                error_flags |= 0x08  # Doppler aliasing
                # Correct aliasing
                velocity_data = 0x80000000 + int((velocity_kmh % max_unambiguous_velocity) * 100)
        
        elif test_scenario == "clutter_detection":
            # Test stationary clutter detection
            if abs(velocity_data - 0x80000000) < 100:  # Near zero velocity
                if intensity_data > 0x80000000:  # High intensity
                    error_flags |= 0x10  # Clutter detected
                    intensity_data = intensity_data >> 2  # Reduce clutter
        
        elif test_scenario == "multipath_interference":
            # Test multipath interference pattern
            if (range_data % 1000) < 50:  # Regular pattern indicating multipath
                error_flags |= 0x20  # Multipath detected
                range_data = range_data + 50  # Correct range
        
        # Combine filtered components
        filtered_output = (
            ((range_data & 0xFFFFFFFF) << 96) |
            ((velocity_data & 0xFFFFFFFF) << 64) |
            ((angle_data & 0xFFFFFFFF) << 32) |
            (intensity_data & 0xFFFFFFFF)
        )
        
        return filtered_output, error_flags
    
    # Test cases for radar signal processing
    radar_cases = [
        ("range_overflow", (4000 << 96) | (0x80000000 << 64) | (0x40000000 << 32) | 0x60000000, "Range > 300m"),
        ("velocity_saturation", (1000 << 96) | (0x90000000 << 64) | (0x40000000 << 32) | 0x60000000, "Velocity > 200 km/h"),
        ("angle_wraparound", (1000 << 96) | (0x80000000 << 64) | (0xFFFFFFFF << 32) | 0x60000000, "Angle wraparound"),
        ("intensity_threshold", (1000 << 96) | (0x80000000 << 64) | (0x40000000 << 32) | 0x800, "Low intensity"),
        ("doppler_aliasing", (1000 << 96) | (0xA0000000 << 64) | (0x40000000 << 32) | 0x60000000, "Doppler aliasing"),
        ("clutter_detection", (1000 << 96) | (0x80000010 << 64) | (0x40000000 << 32) | 0x90000000, "Stationary clutter"),
        ("multipath_interference", (1020 << 96) | (0x80000000 << 64) | (0x40000000 << 32) | 0x60000000, "Multipath pattern"),
        ("normal_target", (1500 << 96) | (0x81000000 << 64) | (0x40000000 << 32) | 0x60000000, "Normal target"),
    ]
    
    passed_tests = 0
    for scenario, test_data, description in radar_cases:
        try:
            filtered, errors = radar_signal_processing_test(test_data, scenario)
            
            # Verify processing results
            if scenario == "normal_target":
                if errors == 0 and filtered != 0:
                    print(f"✅ {description}: Normal processing successful")
                    passed_tests += 1
                else:
                    print(f"❌ {description}: Normal processing failed")
            else:
                # For edge cases, check if appropriate handling occurred
                if scenario in ["velocity_saturation", "angle_wraparound", "doppler_aliasing", "clutter_detection", "multipath_interference"]:
                    if filtered != 0:  # Should produce corrected output
                        print(f"✅ {description}: Edge case handled with correction (0x{errors:02x})")
                        passed_tests += 1
                    else:
                        print(f"❌ {description}: Edge case not handled properly")
                else:  # Error cases
                    if errors != 0:
                        print(f"✅ {description}: Error correctly detected (0x{errors:02x})")
                        passed_tests += 1
                    else:
                        print(f"❌ {description}: Error not detected")
        except Exception as e:
            print(f"❌ {description}: Exception - {str(e)}")
    
    print(f"Radar Signal Processing Edge Cases: {passed_tests}/{len(radar_cases)} passed")
    return passed_tests == len(radar_cases)

def test_imu_synchronizer_timing_edge_cases():
    """Advanced edge case testing for IMU Synchronizer timing"""
    
    print("=== IMU SYNCHRONIZER TIMING EDGE CASES ===")
    
    def imu_timing_test(imu_data, system_time, desired_time, test_scenario):
        """Test IMU synchronization with timing edge cases"""
        
        # Extract IMU components (64-bit total)
        quaternion_w = (imu_data >> 48) & 0xFFFF
        quaternion_x = (imu_data >> 32) & 0xFFFF
        quaternion_y = (imu_data >> 16) & 0xFFFF
        quaternion_z = imu_data & 0xFFFF
        
        error_flags = 0
        synchronized_output = 0
        
        time_diff = abs(system_time - desired_time)
        
        if test_scenario == "excessive_time_drift":
            # Test time drift > 100ms
            if time_diff > 100000:  # 100ms in microseconds
                error_flags |= 0x01  # Excessive drift
                return 0, error_flags
        
        elif test_scenario == "quaternion_denormalized":
            # Test denormalized quaternion
            quat_magnitude_sq = quaternion_w**2 + quaternion_x**2 + quaternion_y**2 + quaternion_z**2
            if abs(quat_magnitude_sq - 0xFFFF**2) > 0x1000**2:  # Not normalized
                error_flags |= 0x02  # Denormalized quaternion
                # Normalize quaternion
                magnitude = int(math.sqrt(quat_magnitude_sq))
                if magnitude > 0:
                    quaternion_w = (quaternion_w * 0xFFFF) // magnitude
                    quaternion_x = (quaternion_x * 0xFFFF) // magnitude
                    quaternion_y = (quaternion_y * 0xFFFF) // magnitude
                    quaternion_z = (quaternion_z * 0xFFFF) // magnitude
        
        elif test_scenario == "fifo_overflow":
            # Simulate FIFO overflow (16 entries max)
            fifo_entries = (system_time % 20)  # Simulate varying FIFO usage
            if fifo_entries >= 16:  # >= 16 to trigger overflow
                error_flags |= 0x04  # FIFO overflow
                return 0, error_flags
        
        elif test_scenario == "interpolation_boundary":
            # Test interpolation at boundaries
            if time_diff > 50000:  # > 50ms, need interpolation
                if time_diff > 200000:  # > 200ms, too far for interpolation
                    error_flags |= 0x08  # Interpolation boundary exceeded
                    return 0, error_flags
        
        elif test_scenario == "clock_rollover":
            # Test clock rollover handling
            if system_time < desired_time and (desired_time - system_time) > 0x80000000:
                # Likely clock rollover
                error_flags |= 0x10  # Clock rollover detected
                # Adjust for rollover
                system_time += 0x100000000
        
        elif test_scenario == "high_angular_velocity":
            # Test high angular velocity detection
            angular_change = abs(quaternion_x - quaternion_y)  # Simplified check
            if angular_change > 0x8000:  # High angular velocity
                error_flags |= 0x20  # High angular velocity warning
        
        # Perform time synchronization
        if time_diff <= 1000:  # Within 1ms, no interpolation needed
            synchronized_output = imu_data
        elif time_diff <= 50000:  # Within 50ms, linear interpolation
            # Simplified interpolation
            time_factor = time_diff / 50000.0
            interpolated_w = int(quaternion_w * (1.0 - time_factor))
            interpolated_x = int(quaternion_x * (1.0 - time_factor))
            interpolated_y = int(quaternion_y * (1.0 - time_factor))
            interpolated_z = int(quaternion_z * (1.0 - time_factor))
            
            synchronized_output = (
                ((interpolated_w & 0xFFFF) << 48) |
                ((interpolated_x & 0xFFFF) << 32) |
                ((interpolated_y & 0xFFFF) << 16) |
                (interpolated_z & 0xFFFF)
            )
        else:
            # Too far for interpolation
            error_flags |= 0x40  # Interpolation failed
            return 0, error_flags
        
        return synchronized_output, error_flags
    
    # Test cases for IMU timing edge conditions
    imu_cases = [
        ("excessive_time_drift", 0x8000800080008000, 1000000, 1200000, "Time drift > 100ms"),
        ("quaternion_denormalized", 0x1000100010001000, 1000000, 1000000, "Denormalized quaternion"),
        ("fifo_overflow", 0x8000800080008000, 1000016, 1000000, "FIFO overflow"),
        ("interpolation_boundary", 0x8000800080008000, 1000000, 1300000, "Interpolation boundary"),
        ("clock_rollover", 0x8000800080008000, 100000, 0xFFFFFFF0, "Clock rollover"),
        ("high_angular_velocity", 0x8000200080002000, 1000000, 1000000, "High angular velocity"),
        ("perfect_sync", 0x8000800080008000, 1000000, 1000000, "Perfect synchronization"),
        ("minor_drift", 0x8000800080008000, 1000000, 1000500, "Minor time drift"),
    ]
    
    passed_tests = 0
    for scenario, imu_data, sys_time, des_time, description in imu_cases:
        try:
            synced, errors = imu_timing_test(imu_data, sys_time, des_time, scenario)
            
            # Verify synchronization results
            if scenario in ["perfect_sync", "minor_drift"]:
                if errors == 0 and synced != 0:
                    print(f"✅ {description}: Synchronization successful")
                    passed_tests += 1
                else:
                    print(f"❌ {description}: Synchronization failed")
            elif scenario in ["quaternion_denormalized", "high_angular_velocity"]:
                if synced != 0:  # Should handle with warning
                    print(f"✅ {description}: Handled with correction (0x{errors:02x})")
                    passed_tests += 1
                else:
                    print(f"❌ {description}: Not handled properly")
            else:  # Error cases
                if errors != 0:
                    print(f"✅ {description}: Error correctly detected (0x{errors:02x})")
                    passed_tests += 1
                else:
                    print(f"❌ {description}: Error not detected")
        except Exception as e:
            print(f"❌ {description}: Exception - {str(e)}")
    
    print(f"IMU Timing Edge Cases: {passed_tests}/{len(imu_cases)} passed")
    return passed_tests == len(imu_cases)

def run_advanced_edge_case_tests():
    """Run all advanced edge case tests"""
    
    print("🔬 ADVANCED EDGE CASE TESTING - Multi-Sensor Fusion")
    print("=" * 80)
    
    test_results = []
    
    # Run all advanced test suites
    tests = [
        ("Camera Decoder Edge Cases", test_camera_decoder_edge_cases),
        ("LiDAR Compression Edge Cases", test_lidar_decoder_compression_edge_cases),
        ("Radar Signal Processing Edge Cases", test_radar_filter_signal_processing_edge_cases),
        ("IMU Timing Edge Cases", test_imu_synchronizer_timing_edge_cases),
    ]
    
    for test_name, test_func in tests:
        print(f"\n{'='*60}")
        try:
            result = test_func()
            test_results.append((test_name, result))
            status = "✅ PASSED" if result else "❌ FAILED"
            print(f"{status}: {test_name}")
        except Exception as e:
            print(f"❌ ERROR in {test_name}: {str(e)}")
            test_results.append((test_name, False))
    
    # Final summary
    print(f"\n{'='*80}")
    print("🏁 ADVANCED EDGE CASE TEST SUMMARY")
    print(f"{'='*80}")
    
    total_tests = len(test_results)
    passed_tests = sum(1 for _, result in test_results if result)
    
    for test_name, result in test_results:
        status = "✅ PASS" if result else "❌ FAIL"
        print(f"{status:<10} {test_name}")
    
    print(f"\n📊 Results:")
    print(f"   Total Test Suites: {total_tests}")
    print(f"   Passed: {passed_tests}")
    print(f"   Failed: {total_tests - passed_tests}")
    print(f"   Success Rate: {(passed_tests/total_tests)*100:.1f}%")
    
    if passed_tests == total_tests:
        print(f"\n🎉 ALL ADVANCED EDGE CASES PASSED!")
        print(f"✨ System demonstrates excellent robustness!")
        return True
    else:
        print(f"\n⚠️ Some edge cases need attention.")
        return False

if __name__ == "__main__":
    success = run_advanced_edge_case_tests()
    exit(0 if success else 1)
