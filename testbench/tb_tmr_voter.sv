// Testbench for TMR_Voter module
`timescale 1ns/1ps

module tb_tmr_voter;

    // Test signals
    logic [191:0] copy1, copy2, copy3;
    logic [191:0] voted;
    logic [11:0]  error_flags;
    
    // Test variables
    int test_count = 0;
    int pass_count = 0;
    int fail_count = 0;
    
    // DUT instantiation
    TMR_Voter dut (
        .copy1(copy1),
        .copy2(copy2), 
        .copy3(copy3),
        .voted(voted),
        .error_flags(error_flags)
    );
    
    // Test task
    task test_tmr_voting(
        input [191:0] c1, c2, c3,
        input [191:0] expected_voted,
        input [11:0]  expected_errors,
        input string  test_name
    );
        test_count++;
        copy1 = c1;
        copy2 = c2;
        copy3 = c3;
        
        #10; // Wait for combinational logic
        
        if (voted === expected_voted && error_flags === expected_errors) begin
            $display("PASS: %s", test_name);
            pass_count++;
        end else begin
            $display("FAIL: %s", test_name);
            $display("  Expected voted: %h, got: %h", expected_voted, voted);
            $display("  Expected errors: %b, got: %b", expected_errors, error_flags);
            fail_count++;
        end
    endtask
    
    // Test scenarios
    initial begin
        $display("=== TMR Voter Testbench ===");
        
        // Test 1: All copies identical (no errors)
        test_tmr_voting(
            192'hAABBCCDDEEFF112233445566778899AABBCCDDEE,
            192'hAABBCCDDEEFF112233445566778899AABBCCDDEE,
            192'hAABBCCDDEEFF112233445566778899AABBCCDDEE,
            192'hAABBCCDDEEFF112233445566778899AABBCCDDEE,
            12'b000000000000,
            "All copies identical"
        );
        
        // Test 2: Copy1 and Copy2 match (Copy3 different)
        test_tmr_voting(
            192'h123456789ABCDEF0123456789ABCDEF012345678,
            192'h123456789ABCDEF0123456789ABCDEF012345678,
            192'hFEDCBA9876543210FEDCBA9876543210FEDCBA98,
            192'h123456789ABCDEF0123456789ABCDEF012345678,
            12'b000000000000,
            "Copy1 and Copy2 match"
        );
        
        // Test 3: Copy1 and Copy3 match (Copy2 different)
        test_tmr_voting(
            192'h987654321FEDCBA0987654321FEDCBA098765432,
            192'h111111111111111111111111111111111111111111,
            192'h987654321FEDCBA0987654321FEDCBA098765432,
            192'h987654321FEDCBA0987654321FEDCBA098765432,
            12'b000000000000,
            "Copy1 and Copy3 match"
        );
        
        // Test 4: Copy2 and Copy3 match (Copy1 different)
        test_tmr_voting(
            192'h000000000000000000000000000000000000000000,
            192'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF,
            192'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF,
            192'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF,
            12'b000000000000,
            "Copy2 and Copy3 match"
        );
        
        // Test 5: All copies different (error case)
        test_tmr_voting(
            192'h111111111111111111111111111111111111111111,
            192'h222222222222222222222222222222222222222222,
            192'h333333333333333333333333333333333333333333,
            192'h111111111111111111111111111111111111111111, // Default to copy1
            12'b111111111111, // All words have errors
            "All copies different"
        );
        
        // Test 6: Mixed scenario - some words match, some don't
        begin
            logic [191:0] c1, c2, c3, expected;
            logic [11:0] expected_err;
            
            // Build test vectors word by word
            c1 = 192'h0;
            c2 = 192'h0;
            c3 = 192'h0;
            expected = 192'h0;
            expected_err = 12'b0;
            
            // Word 0: All same
            c1[15:0] = 16'h1234;
            c2[15:0] = 16'h1234;
            c3[15:0] = 16'h1234;
            expected[15:0] = 16'h1234;
            expected_err[0] = 1'b0;
            
            // Word 1: c1=c2, c3 different
            c1[31:16] = 16'h5678;
            c2[31:16] = 16'h5678;
            c3[31:16] = 16'h9ABC;
            expected[31:16] = 16'h5678;
            expected_err[1] = 1'b0;
            
            // Word 2: All different
            c1[47:32] = 16'hDEF0;
            c2[47:32] = 16'h1111;
            c3[47:32] = 16'h2222;
            expected[47:32] = 16'hDEF0; // Default to c1
            expected_err[2] = 1'b1;
            
            // Fill remaining words with matching values
            for (int i = 3; i < 12; i++) begin
                c1[16*i+15:16*i] = 16'hA000 + i;
                c2[16*i+15:16*i] = 16'hA000 + i;
                c3[16*i+15:16*i] = 16'hA000 + i;
                expected[16*i+15:16*i] = 16'hA000 + i;
                expected_err[i] = 1'b0;
            end
            
            test_tmr_voting(c1, c2, c3, expected, expected_err, "Mixed scenario");
        end
        
        // Test 7: Edge case - all zeros
        test_tmr_voting(
            192'h0,
            192'h0,
            192'h0,
            192'h0,
            12'b000000000000,
            "All zeros"
        );
        
        // Test 8: Edge case - all ones
        test_tmr_voting(
            {192{1'b1}},
            {192{1'b1}},
            {192{1'b1}},
            {192{1'b1}},
            12'b000000000000,
            "All ones"
        );
        
        // Test 9: Single bit differences
        test_tmr_voting(
            192'h123456789ABCDEF0123456789ABCDEF012345678,
            192'h123456789ABCDEF0123456789ABCDEF012345679, // LSB different
            192'h123456789ABCDEF0123456789ABCDEF012345678,
            192'h123456789ABCDEF0123456789ABCDEF012345678,
            12'b000000000000,
            "Single bit difference"
        );
        
        // Test 10: Word boundary test
        begin
            logic [191:0] c1_wb, c2_wb, c3_wb, exp_wb;
            logic [11:0] exp_err_wb;
            
            c1_wb = 192'h0;
            c2_wb = 192'h0;
            c3_wb = 192'h0;
            exp_wb = 192'h0;
            exp_err_wb = 12'b0;
            
            // Make word 0 and word 11 different, others same
            c1_wb[15:0] = 16'hFFFF;
            c2_wb[15:0] = 16'h0000;
            c3_wb[15:0] = 16'h1111;
            exp_wb[15:0] = 16'hFFFF; // Default to c1
            exp_err_wb[0] = 1'b1;
            
            c1_wb[191:176] = 16'h2222;
            c2_wb[191:176] = 16'h3333;
            c3_wb[191:176] = 16'h4444;
            exp_wb[191:176] = 16'h2222; // Default to c1
            exp_err_wb[11] = 1'b1;
            
            // Fill middle words with matching values
            for (int i = 1; i < 11; i++) begin
                c1_wb[16*i+15:16*i] = 16'hB000 + i;
                c2_wb[16*i+15:16*i] = 16'hB000 + i;
                c3_wb[16*i+15:16*i] = 16'hB000 + i;
                exp_wb[16*i+15:16*i] = 16'hB000 + i;
                exp_err_wb[i] = 1'b0;
            end
            
            test_tmr_voting(c1_wb, c2_wb, c3_wb, exp_wb, exp_err_wb, "Word boundary test");
        end
        
        // Summary
        $display("\n=== Test Summary ===");
        $display("Total tests: %0d", test_count);
        $display("Passed: %0d", pass_count);
        $display("Failed: %0d", fail_count);
        
        if (fail_count == 0) begin
            $display("ALL TESTS PASSED!");
        end else begin
            $display("SOME TESTS FAILED!");
        end
        
        $finish;
    end

endmodule
