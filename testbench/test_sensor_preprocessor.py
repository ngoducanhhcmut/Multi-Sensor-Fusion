#!/usr/bin/env python3
"""
Python simulation for Sensor_Preprocessor module testing
Simulates the SystemVerilog Sensor_Preprocessor behavior
"""

def sensor_preprocessor_simulate(raw_vector, min_val=-16384, max_val=16383):
    """
    Simulate Sensor_Preprocessor logic
    Input: 256-bit raw vector (as integer), min_val, max_val
    Output: (normalized_vector, error_flags)
    """
    normalized = 0
    error_flags = 0
    
    # Process 16 elements of 16 bits each
    for i in range(16):
        # Extract 16-bit signed element
        shift = 16 * i
        mask = 0xFFFF
        
        element_unsigned = (raw_vector >> shift) & mask
        
        # Convert to signed 16-bit
        if element_unsigned >= 0x8000:
            element = element_unsigned - 0x10000
        else:
            element = element_unsigned
        
        # Check if out of range
        out_of_range = (element < min_val) or (element > max_val)
        
        # Clip element
        if element < min_val:
            clipped = min_val
        elif element > max_val:
            clipped = max_val
        else:
            clipped = element
            
        # Convert back to unsigned for storage
        if clipped < 0:
            clipped_unsigned = clipped + 0x10000
        else:
            clipped_unsigned = clipped
            
        # Assemble result
        normalized |= (clipped_unsigned << shift)
        error_flags |= (int(out_of_range) << i)
    
    return normalized, error_flags

def test_sensor_preprocessor():
    """Run comprehensive tests for Sensor_Preprocessor"""
    
    test_count = 0
    pass_count = 0
    fail_count = 0
    
    def run_test(raw_vec, expected_norm, expected_errors, test_name, min_val=-16384, max_val=16383):
        nonlocal test_count, pass_count, fail_count
        test_count += 1
        
        normalized, error_flags = sensor_preprocessor_simulate(raw_vec, min_val, max_val)
        
        if normalized == expected_norm and error_flags == expected_errors:
            print(f"PASS: {test_name}")
            pass_count += 1
        else:
            print(f"FAIL: {test_name}")
            print(f"  Expected normalized: 0x{expected_norm:064x}, got: 0x{normalized:064x}")
            print(f"  Expected errors: 0b{expected_errors:016b}, got: 0b{error_flags:016b}")
            fail_count += 1
    
    print("=== Sensor Preprocessor Python Simulation ===")
    
    # Test 1: All values within range (no clipping, no errors)
    raw_in_range = 0
    expected_out = 0
    for i in range(16):
        val = 1000 + i * 100  # Values from 1000 to 2500 (within range)
        raw_in_range |= (val << (16 * i))
        expected_out |= (val << (16 * i))
    
    run_test(
        raw_in_range, expected_out, 0x0000,
        "All values within range"
    )
    
    # Test 2: All values at minimum boundary
    raw_min = 0
    expected_min = 0
    min_val_unsigned = (-16384) & 0xFFFF  # Convert to unsigned representation
    for i in range(16):
        raw_min |= (min_val_unsigned << (16 * i))
        expected_min |= (min_val_unsigned << (16 * i))
    
    run_test(
        raw_min, expected_min, 0x0000,
        "All values at minimum boundary"
    )
    
    # Test 3: All values at maximum boundary
    raw_max = 0
    expected_max = 0
    for i in range(16):
        raw_max |= (16383 << (16 * i))
        expected_max |= (16383 << (16 * i))
    
    run_test(
        raw_max, expected_max, 0x0000,
        "All values at maximum boundary"
    )
    
    # Test 4: Values below minimum (should be clipped)
    raw_below = 0
    expected_clipped_min = 0
    below_val_unsigned = (-20000) & 0xFFFF  # -20000 in unsigned 16-bit
    min_val_unsigned = (-16384) & 0xFFFF
    for i in range(16):
        raw_below |= (below_val_unsigned << (16 * i))
        expected_clipped_min |= (min_val_unsigned << (16 * i))
    
    run_test(
        raw_below, expected_clipped_min, 0xFFFF,  # All elements have errors
        "All values below minimum"
    )
    
    # Test 5: Values above maximum (should be clipped)
    raw_above = 0
    expected_clipped_max = 0
    for i in range(16):
        raw_above |= (20000 << (16 * i))  # Above max
        expected_clipped_max |= (16383 << (16 * i))  # Clipped to max
    
    run_test(
        raw_above, expected_clipped_max, 0xFFFF,  # All elements have errors
        "All values above maximum"
    )
    
    # Test 6: Mixed values - some in range, some out of range
    raw_mixed = 0
    expected_mixed = 0
    expected_errors_mixed = 0
    
    test_values = [
        (1000, False),    # In range
        (-20000, True),   # Below min -> clip to min
        (16383, False),   # At max
        (25000, True),    # Above max -> clip to max
        (-16384, False),  # At min
        (0, False),       # Zero
        (-10000, False),  # Negative in range
        (30000, True),    # Way above max
        (-30000, True),   # Way below min
        (8000, False),    # Positive in range
        (-8000, False),   # Negative in range
        (16384, True),    # Just above max
        (-16385, True),   # Just below min
        (100, False),     # Small positive
        (-100, False),    # Small negative
        (16000, False)    # Near max but in range
    ]
    
    for i, (val, should_error) in enumerate(test_values):
        # Convert to unsigned representation
        if val < 0:
            val_unsigned = val & 0xFFFF
        else:
            val_unsigned = val
            
        raw_mixed |= (val_unsigned << (16 * i))
        
        # Calculate expected output
        if val < -16384:
            clipped = -16384
        elif val > 16383:
            clipped = 16383
        else:
            clipped = val
            
        if clipped < 0:
            clipped_unsigned = clipped & 0xFFFF
        else:
            clipped_unsigned = clipped
            
        expected_mixed |= (clipped_unsigned << (16 * i))
        expected_errors_mixed |= (int(should_error) << i)
    
    run_test(
        raw_mixed, expected_mixed, expected_errors_mixed,
        "Mixed values scenario"
    )
    
    # Test 7: Edge case - all zeros
    run_test(0, 0, 0, "All zeros")
    
    # Test 8: Edge case - alternating pattern
    raw_alt = 0
    expected_alt = 0
    expected_errors_alt = 0
    
    for i in range(16):
        if i % 2 == 0:
            val = 1000  # In range
            raw_alt |= (val << (16 * i))
            expected_alt |= (val << (16 * i))
        else:
            val = 25000  # Above max
            val_unsigned = val & 0xFFFF
            raw_alt |= (val_unsigned << (16 * i))
            expected_alt |= (16383 << (16 * i))  # Clipped to max
            expected_errors_alt |= (1 << i)
    
    run_test(
        raw_alt, expected_alt, expected_errors_alt,
        "Alternating in-range/out-of-range pattern"
    )
    
    # Test 9: Custom range parameters
    raw_custom = 0
    expected_custom = 0
    custom_min = -1000
    custom_max = 1000
    
    # Build test with custom range
    for i in range(16):
        val = -2000 + i * 300  # Values from -2000 to 2500
        if val < 0:
            val_unsigned = val & 0xFFFF
        else:
            val_unsigned = val
        raw_custom |= (val_unsigned << (16 * i))
        
        # Calculate expected with custom range
        if val < custom_min:
            clipped = custom_min
        elif val > custom_max:
            clipped = custom_max
        else:
            clipped = val
            
        if clipped < 0:
            clipped_unsigned = clipped & 0xFFFF
        else:
            clipped_unsigned = clipped
        expected_custom |= (clipped_unsigned << (16 * i))
    
    # Calculate expected errors for custom range
    expected_errors_custom = 0
    for i in range(16):
        val = -2000 + i * 300
        if val < custom_min or val > custom_max:
            expected_errors_custom |= (1 << i)
    
    run_test(
        raw_custom, expected_custom, expected_errors_custom,
        "Custom range parameters", custom_min, custom_max
    )
    
    # Test 10: Boundary conditions
    raw_boundary = 0
    expected_boundary = 0
    expected_errors_boundary = 0
    
    boundary_values = [
        -16385,  # Just below min
        -16384,  # At min
        -16383,  # Just above min
        -1,      # -1
        0,       # Zero
        1,       # +1
        16382,   # Just below max
        16383,   # At max
        16384,   # Just above max
        32767,   # Max positive 16-bit signed
        -32768,  # Min negative 16-bit signed
        -1000,   # Random negative
        1000,    # Random positive
        -20000,  # Way below min
        20000,   # Way above max
        -16000   # Near min but in range
    ]
    
    for i, val in enumerate(boundary_values):
        if val < 0:
            val_unsigned = val & 0xFFFF
        else:
            val_unsigned = val
        raw_boundary |= (val_unsigned << (16 * i))
        
        # Calculate expected
        if val < -16384:
            clipped = -16384
            error = True
        elif val > 16383:
            clipped = 16383
            error = True
        else:
            clipped = val
            error = False
            
        if clipped < 0:
            clipped_unsigned = clipped & 0xFFFF
        else:
            clipped_unsigned = clipped
            
        expected_boundary |= (clipped_unsigned << (16 * i))
        expected_errors_boundary |= (int(error) << i)
    
    run_test(
        raw_boundary, expected_boundary, expected_errors_boundary,
        "Boundary conditions test"
    )
    
    # Summary
    print(f"\n=== Test Summary ===")
    print(f"Total tests: {test_count}")
    print(f"Passed: {pass_count}")
    print(f"Failed: {fail_count}")
    
    if fail_count == 0:
        print("ALL TESTS PASSED!")
        return True
    else:
        print("SOME TESTS FAILED!")
        return False

if __name__ == "__main__":
    success = test_sensor_preprocessor()
    exit(0 if success else 1)
