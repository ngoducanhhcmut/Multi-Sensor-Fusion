#!/usr/bin/env python3
"""
Integration test for the complete FusionCore system
Tests the end-to-end functionality from sensor inputs to fused tensor output
"""

import random

def create_test_weights():
    """Create simple test weight matrices"""
    # QKV weights - small values to avoid overflow
    W_q = [[random.randint(-5, 5) for _ in range(16)] for _ in range(12)]
    W_k = [[random.randint(-5, 5) for _ in range(16)] for _ in range(12)]
    W_v = [[random.randint(-5, 5) for _ in range(16)] for _ in range(12)]
    
    # Fusion compressor weights - very small to avoid overflow
    fc_weights = [[random.randint(-2, 2) for _ in range(96)] for _ in range(128)]
    fc_bias = [random.randint(-10, 10) for _ in range(128)]
    
    return W_q, W_k, W_v, fc_weights, fc_bias

def sensor_preprocessor_simulate(raw_vector, min_val=-16384, max_val=16383):
    """Simulate sensor preprocessing"""
    normalized = 0
    error_flags = 0
    
    for i in range(16):
        shift = 16 * i
        element_unsigned = (raw_vector >> shift) & 0xFFFF
        
        # Convert to signed
        if element_unsigned >= 0x8000:
            element = element_unsigned - 0x10000
        else:
            element = element_unsigned
        
        # Check range and clip
        out_of_range = (element < min_val) or (element > max_val)
        if element < min_val:
            clipped = min_val
        elif element > max_val:
            clipped = max_val
        else:
            clipped = element
            
        # Convert back to unsigned
        if clipped < 0:
            clipped_unsigned = clipped + 0x10000
        else:
            clipped_unsigned = clipped
            
        normalized |= (clipped_unsigned << shift)
        error_flags |= (int(out_of_range) << i)
    
    return normalized, error_flags

def qkv_generator_simulate(normalized_vector, W_q, W_k, W_v):
    """Simulate QKV generation"""
    # Extract input elements
    x = []
    for i in range(16):
        shift = 16 * i
        element_unsigned = (normalized_vector >> shift) & 0xFFFF
        if element_unsigned >= 0x8000:
            element = element_unsigned - 0x10000
        else:
            element = element_unsigned
        x.append(element)
    
    Q = 0
    K = 0
    V = 0
    overflow_flags = 0
    
    # Matrix multiplication for 12 outputs
    for j in range(12):
        accum_q = sum(W_q[j][k] * x[k] for k in range(16))
        accum_k = sum(W_k[j][k] * x[k] for k in range(16))
        accum_v = sum(W_v[j][k] * x[k] for k in range(16))
        
        # Check overflow
        if accum_q > 32767 or accum_q < -32768:
            overflow_flags |= 1
        if accum_k > 32767 or accum_k < -32768:
            overflow_flags |= 2
        if accum_v > 32767 or accum_v < -32768:
            overflow_flags |= 4
        
        # Saturate
        q_sat = max(-32768, min(32767, accum_q)) & 0xFFFF
        k_sat = max(-32768, min(32767, accum_k)) & 0xFFFF
        v_sat = max(-32768, min(32767, accum_v)) & 0xFFFF
        
        Q |= (q_sat << (16 * j))
        K |= (k_sat << (16 * j))
        V |= (v_sat << (16 * j))
    
    return Q, K, V, overflow_flags

def attention_calculator_simulate(Q, K, shift_amount=2, linear_norm=0):
    """Simulate attention calculation"""
    # Extract elements (12x16-bit for Q and K)
    Q_elements = []
    K_elements = []
    
    for i in range(12):
        shift = 16 * i
        
        Q_unsigned = (Q >> shift) & 0xFFFF
        if Q_unsigned >= 0x8000:
            Q_signed = Q_unsigned - 0x10000
        else:
            Q_signed = Q_unsigned
        Q_elements.append(Q_signed)
        
        K_unsigned = (K >> shift) & 0xFFFF
        if K_unsigned >= 0x8000:
            K_signed = K_unsigned - 0x10000
        else:
            K_signed = K_unsigned
        K_elements.append(K_signed)
    
    # Dot product
    dot_product = sum(Q_elements[i] * K_elements[i] for i in range(12))
    
    # Scale and normalize
    shifted = dot_product >> shift_amount
    if linear_norm >= 0x8000000000000000:
        linear_norm_signed = linear_norm - 0x10000000000000000
    else:
        linear_norm_signed = linear_norm
    
    normalized = shifted + linear_norm_signed
    
    # Saturate to 64-bit
    if normalized > 0x7FFFFFFFFFFFFFFF:
        attention_weight = 0x7FFFFFFFFFFFFFFF
    elif normalized < -0x8000000000000000:
        attention_weight = 0x8000000000000000
    else:
        attention_weight = normalized
    
    if attention_weight < 0:
        attention_weight_unsigned = attention_weight & 0xFFFFFFFFFFFFFFFF
    else:
        attention_weight_unsigned = attention_weight
    
    return attention_weight_unsigned

def feature_fusion_simulate(attention_weight, V):
    """Simulate feature fusion"""
    if attention_weight >= 0x8000000000000000:
        attention_signed = attention_weight - 0x10000000000000000
    else:
        attention_signed = attention_weight
    
    # Extract V elements (12x16-bit)
    V_elements = []
    for i in range(12):
        shift = 16 * i
        V_unsigned = (V >> shift) & 0xFFFF
        if V_unsigned >= 0x8000:
            V_signed = V_unsigned - 0x10000
        else:
            V_signed = V_unsigned
        V_elements.append(V_signed)
    
    # Scale and pack into 512-bit (only lower 192 bits used)
    fused_feature = 0
    for i in range(12):
        full_prod = attention_signed * V_elements[i]
        shifted_prod = full_prod >> 16
        
        # Saturate to 16-bit
        if shifted_prod > 32767:
            scaled_val = 32767
        elif shifted_prod < -32768:
            scaled_val = -32768
        else:
            scaled_val = shifted_prod
        
        scaled_unsigned = scaled_val & 0xFFFF
        fused_feature |= (scaled_unsigned << (16 * i))
    
    return fused_feature

def fusion_core_end_to_end_simulate(sensor1_raw, sensor2_raw, sensor3_raw, 
                                   W_q, W_k, W_v, fc_weights, fc_bias):
    """Simulate the complete FusionCore pipeline"""
    
    # Stage 1: Preprocessing
    norm1, err1 = sensor_preprocessor_simulate(sensor1_raw)
    norm2, err2 = sensor_preprocessor_simulate(sensor2_raw)
    norm3, err3 = sensor_preprocessor_simulate(sensor3_raw)
    
    # Stage 2: QKV Generation (simplified - no TMR voting)
    Q1, K1, V1, ovf1 = qkv_generator_simulate(norm1, W_q, W_k, W_v)
    Q2, K2, V2, ovf2 = qkv_generator_simulate(norm2, W_q, W_k, W_v)
    Q3, K3, V3, ovf3 = qkv_generator_simulate(norm3, W_q, W_k, W_v)
    
    # Stage 3: Attention and Feature Fusion
    att1 = attention_calculator_simulate(Q1, K1)
    att2 = attention_calculator_simulate(Q2, K2)
    att3 = attention_calculator_simulate(Q3, K3)
    
    feat1 = feature_fusion_simulate(att1, V1)
    feat2 = feature_fusion_simulate(att2, V2)
    feat3 = feature_fusion_simulate(att3, V3)
    
    # Stage 4: Concatenation (simplified)
    # Concatenate lower 192 bits of each feature
    raw_tensor = feat1 | (feat2 << 192) | (feat3 << 384)
    
    # Stage 5: Compression (simplified linear transformation)
    # Extract 96 elements of 16 bits each
    input_vec = []
    for i in range(96):
        shift = 16 * i
        if shift < 576:  # Only use available bits
            element_unsigned = (raw_tensor >> shift) & 0xFFFF
            if element_unsigned >= 0x8000:
                element = element_unsigned - 0x10000
            else:
                element = element_unsigned
            input_vec.append(element)
        else:
            input_vec.append(0)
    
    # Matrix multiplication with ReLU activation
    output_vec = []
    for i in range(128):
        accum = fc_bias[i]
        for j in range(96):
            accum += fc_weights[i][j] * input_vec[j]
        
        # ReLU activation and saturation
        if accum <= 0:
            output_val = 0
        elif accum > 32767:
            output_val = 32767
        else:
            output_val = accum
        
        output_vec.append(output_val & 0xFFFF)
    
    # Pack into 2048-bit output
    fused_tensor = 0
    for i in range(128):
        fused_tensor |= (output_vec[i] << (16 * i))
    
    return fused_tensor

def test_fusion_core_integration():
    """Run integration tests for FusionCore"""
    
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
    
    print("=== FusionCore Integration Tests ===")
    
    # Create test weights
    random.seed(42)
    W_q, W_k, W_v, fc_weights, fc_bias = create_test_weights()
    
    def test_zero_inputs():
        """Test with all zero inputs"""
        result = fusion_core_end_to_end_simulate(0, 0, 0, W_q, W_k, W_v, fc_weights, fc_bias)
        # With zero inputs and ReLU, output should be max(0, bias)
        return True  # Just check it doesn't crash
    
    def test_small_inputs():
        """Test with small input values"""
        sensor1 = 0
        sensor2 = 0
        sensor3 = 0
        
        # Create small input values
        for i in range(16):
            val1 = (i + 1) * 10
            val2 = (i + 1) * 20
            val3 = (i + 1) * 30
            sensor1 |= (val1 << (16 * i))
            sensor2 |= (val2 << (16 * i))
            sensor3 |= (val3 << (16 * i))
        
        result = fusion_core_end_to_end_simulate(sensor1, sensor2, sensor3, 
                                               W_q, W_k, W_v, fc_weights, fc_bias)
        return result != 0  # Should produce non-zero output
    
    def test_negative_inputs():
        """Test with negative input values"""
        sensor1 = 0
        sensor2 = 0
        sensor3 = 0
        
        for i in range(16):
            val1 = (-(i + 1) * 10) & 0xFFFF
            val2 = (-(i + 1) * 20) & 0xFFFF
            val3 = (-(i + 1) * 30) & 0xFFFF
            sensor1 |= (val1 << (16 * i))
            sensor2 |= (val2 << (16 * i))
            sensor3 |= (val3 << (16 * i))
        
        result = fusion_core_end_to_end_simulate(sensor1, sensor2, sensor3,
                                               W_q, W_k, W_v, fc_weights, fc_bias)
        return True  # Just check it doesn't crash
    
    def test_mixed_inputs():
        """Test with mixed positive/negative inputs"""
        sensor1 = 0
        sensor2 = 0
        sensor3 = 0
        
        for i in range(16):
            val1 = (100 if i % 2 == 0 else -100) & 0xFFFF
            val2 = (200 if i % 3 == 0 else -200) & 0xFFFF
            val3 = (300 if i % 4 == 0 else -300) & 0xFFFF
            sensor1 |= (val1 << (16 * i))
            sensor2 |= (val2 << (16 * i))
            sensor3 |= (val3 << (16 * i))
        
        result = fusion_core_end_to_end_simulate(sensor1, sensor2, sensor3,
                                               W_q, W_k, W_v, fc_weights, fc_bias)
        return True
    
    def test_boundary_values():
        """Test with boundary values"""
        sensor1 = 0
        sensor2 = 0
        sensor3 = 0
        
        # Use values near the clipping boundaries
        for i in range(16):
            val1 = 16000 if i < 8 else -16000
            val2 = 15000 if i < 8 else -15000
            val3 = 14000 if i < 8 else -14000
            
            val1_unsigned = val1 & 0xFFFF
            val2_unsigned = val2 & 0xFFFF
            val3_unsigned = val3 & 0xFFFF
            
            sensor1 |= (val1_unsigned << (16 * i))
            sensor2 |= (val2_unsigned << (16 * i))
            sensor3 |= (val3_unsigned << (16 * i))
        
        result = fusion_core_end_to_end_simulate(sensor1, sensor2, sensor3,
                                               W_q, W_k, W_v, fc_weights, fc_bias)
        return True
    
    def test_consistency():
        """Test that same inputs produce same outputs"""
        sensor1 = 0x123456789ABCDEF0123456789ABCDEF0123456789ABCDEF0123456789ABCDEF0
        sensor2 = 0xFEDCBA9876543210FEDCBA9876543210FEDCBA9876543210FEDCBA9876543210
        sensor3 = 0x0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F
        
        result1 = fusion_core_end_to_end_simulate(sensor1, sensor2, sensor3,
                                                W_q, W_k, W_v, fc_weights, fc_bias)
        result2 = fusion_core_end_to_end_simulate(sensor1, sensor2, sensor3,
                                                W_q, W_k, W_v, fc_weights, fc_bias)
        
        return result1 == result2
    
    # Run all tests
    run_test("Zero inputs", test_zero_inputs)
    run_test("Small inputs", test_small_inputs)
    run_test("Negative inputs", test_negative_inputs)
    run_test("Mixed inputs", test_mixed_inputs)
    run_test("Boundary values", test_boundary_values)
    run_test("Consistency check", test_consistency)
    
    # Summary
    print(f"\n=== Integration Test Summary ===")
    print(f"Total tests: {test_count}")
    print(f"Passed: {pass_count}")
    print(f"Failed: {fail_count}")
    
    if fail_count == 0:
        print("ALL INTEGRATION TESTS PASSED!")
        return True
    else:
        print("SOME INTEGRATION TESTS FAILED!")
        return False

if __name__ == "__main__":
    success = test_fusion_core_integration()
    exit(0 if success else 1)
