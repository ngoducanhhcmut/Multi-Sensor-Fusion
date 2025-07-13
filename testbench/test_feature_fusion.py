#!/usr/bin/env python3
"""
Python simulation for FeatureFusion module testing
Simulates the SystemVerilog FeatureFusion behavior
"""

def feature_fusion_simulate(attention_weight, V):
    """
    Simulate FeatureFusion logic
    Input: 
        - attention_weight: 64-bit attention weight (as integer)
        - V: 192-bit V vector (as integer) representing 6x32-bit elements
    Output: 512-bit fused feature
    """
    # Convert attention_weight to signed 64-bit
    if attention_weight >= 0x8000000000000000:
        attention_signed = attention_weight - 0x10000000000000000
    else:
        attention_signed = attention_weight
    
    # Extract 6 elements of 32 bits each from V
    V_elements = []
    for i in range(6):
        shift = 32 * i
        V_unsigned = (V >> shift) & 0xFFFFFFFF
        # Convert to signed 32-bit
        if V_unsigned >= 0x80000000:
            V_signed = V_unsigned - 0x100000000
        else:
            V_signed = V_unsigned
        V_elements.append(V_signed)
    
    # Scale each V element by attention weight
    scaled_V = []
    for i in range(6):
        # 64-bit * 32-bit = 96-bit product
        full_prod = attention_signed * V_elements[i]
        
        # Shift right 16 bits for Q16.16 fixed-point scaling
        shifted_prod = full_prod >> 16
        
        # Check for 32-bit overflow and saturate
        if shifted_prod > 0x7FFFFFFF:
            scaled_val = 0x7FFFFFFF
        elif shifted_prod < -0x80000000:
            scaled_val = -0x80000000
        else:
            scaled_val = shifted_prod
        
        # Convert to unsigned for storage
        if scaled_val < 0:
            scaled_unsigned = scaled_val & 0xFFFFFFFF
        else:
            scaled_unsigned = scaled_val
        
        scaled_V.append(scaled_unsigned)
    
    # Construct 512-bit output: 320 bits of zero padding + 192 bits of scaled V
    fused_feature = 0
    for i in range(6):
        fused_feature |= (scaled_V[i] << (32 * i))
    
    # The upper 320 bits remain zero (no need to explicitly set)
    
    return fused_feature

def test_feature_fusion():
    """Run comprehensive tests for FeatureFusion"""
    
    test_count = 0
    pass_count = 0
    fail_count = 0
    
    def run_test(attention_weight, V, expected_fused, test_name):
        nonlocal test_count, pass_count, fail_count
        test_count += 1
        
        fused = feature_fusion_simulate(attention_weight, V)
        
        if fused == expected_fused:
            print(f"PASS: {test_name}")
            pass_count += 1
        else:
            print(f"FAIL: {test_name}")
            print(f"  Expected: 0x{expected_fused:0128x}")
            print(f"  Got:      0x{fused:0128x}")
            # Show only the lower 192 bits for easier comparison
            print(f"  Expected (lower 192): 0x{expected_fused & ((1 << 192) - 1):048x}")
            print(f"  Got (lower 192):      0x{fused & ((1 << 192) - 1):048x}")
            fail_count += 1
    
    print("=== Feature Fusion Python Simulation ===")
    
    # Test 1: Zero attention weight (should zero out everything)
    V_test = 0
    for i in range(6):
        V_test |= ((i + 1) * 1000 << (32 * i))  # V = [1000, 2000, 3000, 4000, 5000, 6000]
    
    run_test(0, V_test, 0, "Zero attention weight")
    
    # Test 2: Unit attention weight (1.0 in Q16.16 format = 0x10000)
    attention_unit = 0x10000  # 1.0 in Q16.16 fixed-point
    V_simple = 0
    expected_simple = 0
    
    for i in range(6):
        val = (i + 1) * 100  # V = [100, 200, 300, 400, 500, 600]
        V_simple |= (val << (32 * i))
        expected_simple |= (val << (32 * i))  # Should be unchanged with unit weight
    
    run_test(attention_unit, V_simple, expected_simple, "Unit attention weight")
    
    # Test 3: Half attention weight (0.5 in Q16.16 format = 0x8000)
    attention_half = 0x8000  # 0.5 in Q16.16 fixed-point
    V_double = 0
    expected_half = 0
    
    for i in range(6):
        val = (i + 1) * 200  # V = [200, 400, 600, 800, 1000, 1200]
        V_double |= (val << (32 * i))
        expected_val = val // 2  # Should be halved
        expected_half |= (expected_val << (32 * i))
    
    run_test(attention_half, V_double, expected_half, "Half attention weight")
    
    # Test 4: Double attention weight (2.0 in Q16.16 format = 0x20000)
    attention_double = 0x20000  # 2.0 in Q16.16 fixed-point
    V_half = 0
    expected_double = 0
    
    for i in range(6):
        val = (i + 1) * 50  # V = [50, 100, 150, 200, 250, 300]
        V_half |= (val << (32 * i))
        expected_val = val * 2  # Should be doubled
        expected_double |= (expected_val << (32 * i))
    
    run_test(attention_double, V_half, expected_double, "Double attention weight")
    
    # Test 5: Negative attention weight
    attention_neg = (-0x10000) & 0xFFFFFFFFFFFFFFFF  # -1.0 in Q16.16 fixed-point
    V_pos = 0
    expected_neg = 0
    
    for i in range(6):
        val = (i + 1) * 100  # V = [100, 200, 300, 400, 500, 600]
        V_pos |= (val << (32 * i))
        expected_val = (-val) & 0xFFFFFFFF  # Should be negated
        expected_neg |= (expected_val << (32 * i))
    
    run_test(attention_neg, V_pos, expected_neg, "Negative attention weight")
    
    # Test 6: Negative V values
    attention_pos = 0x10000  # 1.0 in Q16.16 fixed-point
    V_neg = 0
    expected_neg_v = 0
    
    for i in range(6):
        val = (-(i + 1) * 100) & 0xFFFFFFFF  # V = [-100, -200, -300, -400, -500, -600]
        V_neg |= (val << (32 * i))
        expected_neg_v |= (val << (32 * i))  # Should remain negative with unit weight
    
    run_test(attention_pos, V_neg, expected_neg_v, "Negative V values")
    
    # Test 7: Small fractional attention weight
    attention_small = 0x1000  # 0.0625 in Q16.16 fixed-point (1/16)
    V_large = 0
    expected_small = 0
    
    for i in range(6):
        val = (i + 1) * 1600  # V = [1600, 3200, 4800, 6400, 8000, 9600]
        V_large |= (val << (32 * i))
        expected_val = val // 16  # Should be divided by 16
        expected_small |= (expected_val << (32 * i))
    
    run_test(attention_small, V_large, expected_small, "Small fractional attention weight")
    
    # Test 8: Test overflow saturation (positive)
    attention_large = 0x7FFFFFFFFFFFFFFF  # Large positive attention weight
    V_max_pos = 0
    expected_saturated_pos = 0
    
    max_pos_32 = 0x7FFFFFFF
    for i in range(6):
        V_max_pos |= (max_pos_32 << (32 * i))
        expected_saturated_pos |= (max_pos_32 << (32 * i))  # Should saturate to max positive
    
    run_test(attention_large, V_max_pos, expected_saturated_pos, "Positive overflow saturation")
    
    # Test 9: Test overflow saturation (negative)
    attention_large_neg = 0x8000000000000000  # Large negative attention weight
    V_max_pos_for_neg = 0
    expected_saturated_neg = 0
    
    max_neg_32 = 0x80000000
    for i in range(6):
        V_max_pos_for_neg |= (max_pos_32 << (32 * i))
        expected_saturated_neg |= (max_neg_32 << (32 * i))  # Should saturate to max negative
    
    run_test(attention_large_neg, V_max_pos_for_neg, expected_saturated_neg, "Negative overflow saturation")
    
    # Test 10: Zero V vector
    attention_any = 0x12345  # Any attention weight
    run_test(attention_any, 0, 0, "Zero V vector")
    
    # Test 11: Mixed positive and negative V values
    attention_mixed = 0x8000  # 0.5 in Q16.16 fixed-point
    V_mixed = 0
    expected_mixed = 0
    
    mixed_values = [1000, -2000, 3000, -4000, 5000, -6000]
    for i, val in enumerate(mixed_values):
        if val < 0:
            val_unsigned = val & 0xFFFFFFFF
        else:
            val_unsigned = val
        V_mixed |= (val_unsigned << (32 * i))
        
        # Calculate expected (halved)
        expected_val = val // 2
        if expected_val < 0:
            expected_val_unsigned = expected_val & 0xFFFFFFFF
        else:
            expected_val_unsigned = expected_val
        expected_mixed |= (expected_val_unsigned << (32 * i))
    
    run_test(attention_mixed, V_mixed, expected_mixed, "Mixed positive/negative V values")
    
    # Test 12: Edge case - very small V values
    attention_normal = 0x10000  # 1.0 in Q16.16 fixed-point
    V_small = 0
    expected_small_v = 0
    
    for i in range(6):
        val = i + 1  # V = [1, 2, 3, 4, 5, 6]
        V_small |= (val << (32 * i))
        expected_small_v |= (val << (32 * i))
    
    run_test(attention_normal, V_small, expected_small_v, "Very small V values")
    
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
    success = test_feature_fusion()
    exit(0 if success else 1)
