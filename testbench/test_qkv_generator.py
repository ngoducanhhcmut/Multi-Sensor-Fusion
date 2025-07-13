#!/usr/bin/env python3
"""
Python simulation for QKV_Generator module testing
Simulates the SystemVerilog QKV_Generator behavior
"""

import random

def qkv_generator_simulate(normalized_vector, W_q, W_k, W_v):
    """
    Simulate QKV_Generator logic
    Input: 
        - normalized_vector: 256-bit vector (as integer)
        - W_q, W_k, W_v: 12x16 weight matrices (as 2D lists)
    Output: (Q, K, V, overflow_flags)
    """
    # Extract 16 elements from normalized_vector
    x = []
    for i in range(16):
        shift = 16 * i
        element_unsigned = (normalized_vector >> shift) & 0xFFFF
        # Convert to signed 16-bit
        if element_unsigned >= 0x8000:
            element = element_unsigned - 0x10000
        else:
            element = element_unsigned
        x.append(element)
    
    Q = 0
    K = 0
    V = 0
    overflow_flags = 0
    
    # Process 12 output elements for each of Q, K, V
    for j in range(12):
        accum_q = 0
        accum_k = 0
        accum_v = 0
        
        # Matrix multiplication: output[j] = sum(W[j][k] * x[k])
        for k in range(16):
            accum_q += W_q[j][k] * x[k]
            accum_k += W_k[j][k] * x[k]
            accum_v += W_v[j][k] * x[k]
        
        # Check for overflow (16-bit signed range: -32768 to 32767)
        if accum_q > 32767 or accum_q < -32768:
            overflow_flags |= 1
        if accum_k > 32767 or accum_k < -32768:
            overflow_flags |= 2
        if accum_v > 32767 or accum_v < -32768:
            overflow_flags |= 4
        
        # Saturate to 16-bit signed range
        q_sat = max(-32768, min(32767, accum_q))
        k_sat = max(-32768, min(32767, accum_k))
        v_sat = max(-32768, min(32767, accum_v))
        
        # Convert to unsigned for storage
        q_unsigned = q_sat & 0xFFFF
        k_unsigned = k_sat & 0xFFFF
        v_unsigned = v_sat & 0xFFFF
        
        # Pack into output vectors
        Q |= (q_unsigned << (16 * j))
        K |= (k_unsigned << (16 * j))
        V |= (v_unsigned << (16 * j))
    
    return Q, K, V, overflow_flags

def create_identity_weights():
    """Create identity-like weight matrices for testing"""
    W = []
    for j in range(12):
        row = []
        for k in range(16):
            if j < 16 and k == j:
                row.append(1)  # Identity element
            else:
                row.append(0)
        W.append(row)
    return W

def create_small_weights():
    """Create small weight matrices to avoid overflow"""
    W = []
    for j in range(12):
        row = []
        for k in range(16):
            row.append((j + k) % 10 - 5)  # Values from -5 to 4
        W.append(row)
    return W

def test_qkv_generator():
    """Run comprehensive tests for QKV_Generator"""
    
    test_count = 0
    pass_count = 0
    fail_count = 0
    
    def run_test(norm_vec, W_q, W_k, W_v, expected_Q, expected_K, expected_V, expected_ovf, test_name):
        nonlocal test_count, pass_count, fail_count
        test_count += 1
        
        Q, K, V, overflow = qkv_generator_simulate(norm_vec, W_q, W_k, W_v)
        
        if Q == expected_Q and K == expected_K and V == expected_V and overflow == expected_ovf:
            print(f"PASS: {test_name}")
            pass_count += 1
        else:
            print(f"FAIL: {test_name}")
            if Q != expected_Q:
                print(f"  Q mismatch: expected 0x{expected_Q:048x}, got 0x{Q:048x}")
            if K != expected_K:
                print(f"  K mismatch: expected 0x{expected_K:048x}, got 0x{K:048x}")
            if V != expected_V:
                print(f"  V mismatch: expected 0x{expected_V:048x}, got 0x{V:048x}")
            if overflow != expected_ovf:
                print(f"  Overflow mismatch: expected 0b{expected_ovf:03b}, got 0b{overflow:03b}")
            fail_count += 1
    
    print("=== QKV Generator Python Simulation ===")
    
    # Test 1: Zero input vector with identity weights
    W_identity = create_identity_weights()
    run_test(
        0,  # All zeros input
        W_identity, W_identity, W_identity,
        0, 0, 0, 0,  # All outputs should be zero
        "Zero input with identity weights"
    )
    
    # Test 2: Simple input with identity weights
    simple_input = 0
    expected_simple = 0
    for i in range(12):  # Only first 12 elements will affect output
        val = i + 1  # Values 1, 2, 3, ..., 12
        simple_input |= (val << (16 * i))
        expected_simple |= (val << (16 * i))
    
    run_test(
        simple_input,
        W_identity, W_identity, W_identity,
        expected_simple, expected_simple, expected_simple, 0,
        "Simple input with identity weights"
    )
    
    # Test 3: All ones input with small weights
    W_small = create_small_weights()
    all_ones_input = 0
    for i in range(16):
        all_ones_input |= (1 << (16 * i))
    
    # Calculate expected output manually
    expected_Q_small = 0
    expected_K_small = 0
    expected_V_small = 0
    
    for j in range(12):
        sum_weights = sum(W_small[j])  # Sum of weights in row j
        # Since all inputs are 1, output[j] = sum of weights in row j
        sum_unsigned = sum_weights & 0xFFFF
        expected_Q_small |= (sum_unsigned << (16 * j))
        expected_K_small |= (sum_unsigned << (16 * j))
        expected_V_small |= (sum_unsigned << (16 * j))
    
    run_test(
        all_ones_input,
        W_small, W_small, W_small,
        expected_Q_small, expected_K_small, expected_V_small, 0,
        "All ones input with small weights"
    )
    
    # Test 4: Test overflow detection
    W_large = []
    for j in range(12):
        row = []
        for k in range(16):
            row.append(1000)  # Large weights to cause overflow
        W_large.append(row)
    
    large_input = 0
    for i in range(16):
        large_input |= (10 << (16 * i))  # Input values of 10
    
    # Expected: 12 * 1000 * 10 = 120000 > 32767, so overflow and saturation
    expected_saturated = 0
    saturated_val = 32767 & 0xFFFF
    for j in range(12):
        expected_saturated |= (saturated_val << (16 * j))
    
    run_test(
        large_input,
        W_large, W_large, W_large,
        expected_saturated, expected_saturated, expected_saturated, 7,  # All overflow flags set
        "Overflow test with large weights"
    )
    
    # Test 5: Negative overflow test
    W_neg_large = []
    for j in range(12):
        row = []
        for k in range(16):
            row.append(-1000)  # Large negative weights
        W_neg_large.append(row)
    
    # Expected: 12 * (-1000) * 10 = -120000 < -32768, so negative overflow
    expected_neg_saturated = 0
    neg_saturated_val = (-32768) & 0xFFFF
    for j in range(12):
        expected_neg_saturated |= (neg_saturated_val << (16 * j))
    
    run_test(
        large_input,
        W_neg_large, W_neg_large, W_neg_large,
        expected_neg_saturated, expected_neg_saturated, expected_neg_saturated, 7,
        "Negative overflow test"
    )
    
    # Test 6: Mixed weights (some positive, some negative)
    W_mixed = []
    for j in range(12):
        row = []
        for k in range(16):
            if k % 2 == 0:
                row.append(j + 1)  # Positive weights
            else:
                row.append(-(j + 1))  # Negative weights
        W_mixed.append(row)
    
    mixed_input = 0
    for i in range(16):
        val = i + 1  # Values 1, 2, 3, ..., 16
        mixed_input |= (val << (16 * i))
    
    # Calculate expected manually
    expected_Q_mixed = 0
    expected_K_mixed = 0
    expected_V_mixed = 0
    
    for j in range(12):
        accum = 0
        for k in range(16):
            input_val = k + 1
            weight = W_mixed[j][k]
            accum += weight * input_val
        
        accum_sat = max(-32768, min(32767, accum))
        accum_unsigned = accum_sat & 0xFFFF
        expected_Q_mixed |= (accum_unsigned << (16 * j))
        expected_K_mixed |= (accum_unsigned << (16 * j))
        expected_V_mixed |= (accum_unsigned << (16 * j))
    
    run_test(
        mixed_input,
        W_mixed, W_mixed, W_mixed,
        expected_Q_mixed, expected_K_mixed, expected_V_mixed, 0,
        "Mixed positive/negative weights"
    )
    
    # Test 7: Different weights for Q, K, V
    W_q_diff = create_small_weights()
    W_k_diff = []
    W_v_diff = []
    
    for j in range(12):
        row_k = []
        row_v = []
        for k in range(16):
            row_k.append((j * 2 + k) % 8 - 4)  # Different pattern for K
            row_v.append((j + k * 3) % 6 - 3)  # Different pattern for V
        W_k_diff.append(row_k)
        W_v_diff.append(row_v)
    
    test_input = 0
    for i in range(16):
        val = (i * 7) % 100  # Some pattern
        test_input |= (val << (16 * i))
    
    # Calculate expected for each matrix separately
    def calc_expected(W, input_vec):
        result = 0
        x = []
        for i in range(16):
            shift = 16 * i
            element_unsigned = (input_vec >> shift) & 0xFFFF
            if element_unsigned >= 0x8000:
                element = element_unsigned - 0x10000
            else:
                element = element_unsigned
            x.append(element)
        
        for j in range(12):
            accum = sum(W[j][k] * x[k] for k in range(16))
            accum_sat = max(-32768, min(32767, accum))
            accum_unsigned = accum_sat & 0xFFFF
            result |= (accum_unsigned << (16 * j))
        return result
    
    expected_Q_diff = calc_expected(W_q_diff, test_input)
    expected_K_diff = calc_expected(W_k_diff, test_input)
    expected_V_diff = calc_expected(W_v_diff, test_input)
    
    run_test(
        test_input,
        W_q_diff, W_k_diff, W_v_diff,
        expected_Q_diff, expected_K_diff, expected_V_diff, 0,
        "Different weights for Q, K, V"
    )
    
    # Test 8: Edge case - maximum positive input
    max_pos_input = 0
    for i in range(16):
        max_pos_input |= (32767 << (16 * i))  # Max positive 16-bit signed
    
    W_unit = []
    for j in range(12):
        row = [0] * 16
        if j < 16:
            row[j] = 1  # Unit matrix (only one non-zero element per row)
        W_unit.append(row)
    
    expected_max_pos = 0
    for j in range(12):
        expected_max_pos |= (32767 << (16 * j))
    
    run_test(
        max_pos_input,
        W_unit, W_unit, W_unit,
        expected_max_pos, expected_max_pos, expected_max_pos, 0,
        "Maximum positive input with unit weights"
    )
    
    # Test 9: Edge case - maximum negative input
    max_neg_input = 0
    neg_val = (-32768) & 0xFFFF
    for i in range(16):
        max_neg_input |= (neg_val << (16 * i))
    
    expected_max_neg = 0
    for j in range(12):
        expected_max_neg |= (neg_val << (16 * j))
    
    run_test(
        max_neg_input,
        W_unit, W_unit, W_unit,
        expected_max_neg, expected_max_neg, expected_max_neg, 0,
        "Maximum negative input with unit weights"
    )
    
    # Test 10: Random test with very small weights to avoid overflow
    random.seed(42)  # For reproducible results

    random_input = 0
    for i in range(16):
        val = random.randint(-100, 100)  # Smaller input range
        val_unsigned = val & 0xFFFF
        random_input |= (val_unsigned << (16 * i))

    W_random = []
    for j in range(12):
        row = []
        for k in range(16):
            row.append(random.randint(-2, 2))  # Very small weights
        W_random.append(row)

    # Calculate expected and check for potential overflow
    def calc_expected_with_overflow_check(W, input_vec):
        result = 0
        overflow = 0
        x = []
        for i in range(16):
            shift = 16 * i
            element_unsigned = (input_vec >> shift) & 0xFFFF
            if element_unsigned >= 0x8000:
                element = element_unsigned - 0x10000
            else:
                element = element_unsigned
            x.append(element)

        for j in range(12):
            accum = sum(W[j][k] * x[k] for k in range(16))
            if accum > 32767 or accum < -32768:
                overflow = 7  # Set all overflow flags
            accum_sat = max(-32768, min(32767, accum))
            accum_unsigned = accum_sat & 0xFFFF
            result |= (accum_unsigned << (16 * j))
        return result, overflow

    expected_random, expected_overflow = calc_expected_with_overflow_check(W_random, random_input)

    run_test(
        random_input,
        W_random, W_random, W_random,
        expected_random, expected_random, expected_random, expected_overflow,
        "Random test with very small weights"
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
    success = test_qkv_generator()
    exit(0 if success else 1)
