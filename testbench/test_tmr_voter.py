#!/usr/bin/env python3
"""
Python simulation for TMR_Voter module testing
Simulates the SystemVerilog TMR_Voter behavior
"""

def tmr_voter_simulate(copy1, copy2, copy3):
    """
    Simulate TMR_Voter logic
    Input: Three 192-bit values (as integers)
    Output: (voted_result, error_flags)
    """
    voted = 0
    error_flags = 0
    
    # Process 12 words of 16 bits each
    for i in range(12):
        # Extract 16-bit words
        shift = 16 * i
        mask = 0xFFFF
        
        c1 = (copy1 >> shift) & mask
        c2 = (copy2 >> shift) & mask  
        c3 = (copy3 >> shift) & mask
        
        # TMR voting logic
        if c1 == c2:
            voted_word = c1
            error = 0
        elif c1 == c3:
            voted_word = c1
            error = 0
        elif c2 == c3:
            voted_word = c2
            error = 0
        else:
            voted_word = c1  # Default to copy1
            error = 1
            
        # Assemble result
        voted |= (voted_word << shift)
        error_flags |= (error << i)
    
    return voted, error_flags

def test_tmr_voter():
    """Run comprehensive tests for TMR_Voter"""
    
    test_count = 0
    pass_count = 0
    fail_count = 0
    
    def run_test(c1, c2, c3, expected_voted, expected_errors, test_name):
        nonlocal test_count, pass_count, fail_count
        test_count += 1
        
        voted, error_flags = tmr_voter_simulate(c1, c2, c3)
        
        if voted == expected_voted and error_flags == expected_errors:
            print(f"PASS: {test_name}")
            pass_count += 1
        else:
            print(f"FAIL: {test_name}")
            print(f"  Expected voted: 0x{expected_voted:048x}, got: 0x{voted:048x}")
            print(f"  Expected errors: 0b{expected_errors:012b}, got: 0b{error_flags:012b}")
            fail_count += 1
    
    print("=== TMR Voter Python Simulation ===")
    
    # Test 1: All copies identical (no errors)
    test_val = 0xAABBCCDDEEFF112233445566778899AABBCCDDEE
    run_test(
        test_val, test_val, test_val,
        test_val, 0b000000000000,
        "All copies identical"
    )
    
    # Test 2: Copy1 and Copy2 match (Copy3 different)
    c1_c2 = 0x123456789ABCDEF0123456789ABCDEF012345678
    c3_diff = 0xFEDCBA9876543210FEDCBA9876543210FEDCBA98
    run_test(
        c1_c2, c1_c2, c3_diff,
        c1_c2, 0b000000000000,
        "Copy1 and Copy2 match"
    )
    
    # Test 3: Copy1 and Copy3 match (Copy2 different)
    c1_c3 = 0x987654321FEDCBA0987654321FEDCBA098765432
    c2_diff = 0x111111111111111111111111111111111111111111
    run_test(
        c1_c3, c2_diff, c1_c3,
        c1_c3, 0b000000000000,
        "Copy1 and Copy3 match"
    )
    
    # Test 4: Copy2 and Copy3 match (Copy1 different)
    c2_c3 = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
    c1_diff = 0x000000000000000000000000000000000000000000
    run_test(
        c1_diff, c2_c3, c2_c3,
        c2_c3, 0b000000000000,
        "Copy2 and Copy3 match"
    )
    
    # Test 5: All copies different (error case) - Fixed for full 192 bits
    c1_all_diff = 0x111111111111111111111111111111111111111111111111
    c2_all_diff = 0x222222222222222222222222222222222222222222222222
    c3_all_diff = 0x333333333333333333333333333333333333333333333333



    run_test(
        c1_all_diff, c2_all_diff, c3_all_diff,
        c1_all_diff, 0b111111111111,  # Expect all errors
        "All copies different"
    )
    
    # Test 6: Mixed scenario - build word by word
    c1 = 0
    c2 = 0
    c3 = 0
    expected = 0
    expected_err = 0
    
    # Word 0: All same
    c1 |= 0x1234
    c2 |= 0x1234
    c3 |= 0x1234
    expected |= 0x1234
    
    # Word 1: c1=c2, c3 different
    c1 |= (0x5678 << 16)
    c2 |= (0x5678 << 16)
    c3 |= (0x9ABC << 16)
    expected |= (0x5678 << 16)
    
    # Word 2: All different
    c1 |= (0xDEF0 << 32)
    c2 |= (0x1111 << 32)
    c3 |= (0x2222 << 32)
    expected |= (0xDEF0 << 32)  # Default to c1
    expected_err |= (1 << 2)
    
    # Fill remaining words with matching values
    for i in range(3, 12):
        val = 0xA000 + i
        c1 |= (val << (16 * i))
        c2 |= (val << (16 * i))
        c3 |= (val << (16 * i))
        expected |= (val << (16 * i))
    
    run_test(c1, c2, c3, expected, expected_err, "Mixed scenario")
    
    # Test 7: Edge case - all zeros
    run_test(0, 0, 0, 0, 0, "All zeros")
    
    # Test 8: Edge case - all ones (192-bit)
    all_ones = (1 << 192) - 1
    run_test(all_ones, all_ones, all_ones, all_ones, 0, "All ones")
    
    # Test 9: Single bit differences
    base_val = 0x123456789ABCDEF0123456789ABCDEF012345678
    diff_val = 0x123456789ABCDEF0123456789ABCDEF012345679  # LSB different
    run_test(
        base_val, diff_val, base_val,
        base_val, 0,
        "Single bit difference"
    )
    
    # Test 10: Word boundary test
    c1_wb = 0
    c2_wb = 0
    c3_wb = 0
    exp_wb = 0
    exp_err_wb = 0
    
    # Word 0: All different
    c1_wb |= 0xFFFF
    c2_wb |= 0x0000
    c3_wb |= 0x1111
    exp_wb |= 0xFFFF  # Default to c1
    exp_err_wb |= 1
    
    # Word 11: All different
    c1_wb |= (0x2222 << (16 * 11))
    c2_wb |= (0x3333 << (16 * 11))
    c3_wb |= (0x4444 << (16 * 11))
    exp_wb |= (0x2222 << (16 * 11))  # Default to c1
    exp_err_wb |= (1 << 11)
    
    # Fill middle words with matching values
    for i in range(1, 11):
        val = 0xB000 + i
        c1_wb |= (val << (16 * i))
        c2_wb |= (val << (16 * i))
        c3_wb |= (val << (16 * i))
        exp_wb |= (val << (16 * i))
    
    run_test(c1_wb, c2_wb, c3_wb, exp_wb, exp_err_wb, "Word boundary test")
    
    # Test 11: Random pattern test
    import random
    random.seed(42)  # For reproducible results
    
    for test_num in range(5):
        # Generate random 192-bit values
        r1 = random.getrandbits(192)
        r2 = random.getrandbits(192)
        r3 = random.getrandbits(192)
        
        # Calculate expected result manually
        expected_voted = 0
        expected_errors = 0
        
        for i in range(12):
            shift = 16 * i
            mask = 0xFFFF
            
            w1 = (r1 >> shift) & mask
            w2 = (r2 >> shift) & mask
            w3 = (r3 >> shift) & mask
            
            if w1 == w2:
                expected_voted |= (w1 << shift)
            elif w1 == w3:
                expected_voted |= (w1 << shift)
            elif w2 == w3:
                expected_voted |= (w2 << shift)
            else:
                expected_voted |= (w1 << shift)
                expected_errors |= (1 << i)
        
        run_test(r1, r2, r3, expected_voted, expected_errors, f"Random test {test_num + 1}")
    
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
    success = test_tmr_voter()
    exit(0 if success else 1)
