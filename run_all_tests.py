#!/usr/bin/env python3
"""
Master test runner for Multi-Sensor Fusion System
Runs all individual module tests and integration tests
"""

import subprocess
import sys
import os

def run_test(test_file, test_name):
    """Run a single test file and return result"""
    print(f"\n{'='*60}")
    print(f"Running {test_name}")
    print(f"{'='*60}")
    
    try:
        result = subprocess.run([sys.executable, test_file], 
                              capture_output=True, text=True, timeout=60)
        
        print(result.stdout)
        if result.stderr:
            print("STDERR:", result.stderr)
        
        if result.returncode == 0:
            print(f"✅ {test_name} PASSED")
            return True
        else:
            print(f"❌ {test_name} FAILED (return code: {result.returncode})")
            return False
            
    except subprocess.TimeoutExpired:
        print(f"⏰ {test_name} TIMED OUT")
        return False
    except Exception as e:
        print(f"💥 {test_name} ERROR: {str(e)}")
        return False

def main():
    """Run all tests in order from basic to complex"""
    
    print("🚀 Multi-Sensor Fusion System - Comprehensive Test Suite")
    print("=" * 80)
    
    # Test configuration - ordered from basic to complex
    tests = [
        # Core module tests
        ("testbench/test_tmr_voter.py", "TMR Voter Module"),
        ("testbench/test_sensor_preprocessor.py", "Sensor Preprocessor Module"),
        ("testbench/test_qkv_generator.py", "QKV Generator Module"),
        ("testbench/test_attention_calculator.py", "Attention Calculator Module"),
        ("testbench/test_feature_fusion.py", "Feature Fusion Module"),

        # Decoder module tests
        ("testbench/test_decoder_modules.py", "Decoder Modules (Camera/LiDAR/Radar/IMU)"),

        # Integration tests
        ("testbench/test_fusion_core_integration.py", "FusionCore Integration Test"),
        ("testbench/test_full_system_integration.py", "Full System Integration Test"),

        # Final verification
        ("testbench/test_final_system_verification.py", "Final System Verification"),

        # Advanced edge case tests
        ("testbench/test_advanced_edge_cases.py", "Advanced Edge Cases"),
        ("testbench/test_fusion_core_advanced.py", "Fusion Core Advanced Tests"),
        ("testbench/test_system_stress.py", "System Stress Testing"),
        ("testbench/test_corrected_system.py", "Corrected System Verification")
    ]
    
    # Check if all test files exist
    missing_files = []
    for test_file, test_name in tests:
        if not os.path.exists(test_file):
            missing_files.append(test_file)
    
    if missing_files:
        print(f"❌ Missing test files: {missing_files}")
        return False
    
    # Run tests
    results = []
    total_tests = len(tests)
    passed_tests = 0
    
    for test_file, test_name in tests:
        success = run_test(test_file, test_name)
        results.append((test_name, success))
        if success:
            passed_tests += 1
    
    # Summary
    print(f"\n{'='*80}")
    print("🏁 FINAL TEST SUMMARY")
    print(f"{'='*80}")
    
    for test_name, success in results:
        status = "✅ PASS" if success else "❌ FAIL"
        print(f"{status:<10} {test_name}")
    
    print(f"\n📊 Overall Results:")
    print(f"   Total Tests: {total_tests}")
    print(f"   Passed: {passed_tests}")
    print(f"   Failed: {total_tests - passed_tests}")
    print(f"   Success Rate: {(passed_tests/total_tests)*100:.1f}%")
    
    if passed_tests == total_tests:
        print(f"\n🎉 ALL TESTS PASSED! The Multi-Sensor Fusion System is working correctly.")
        print(f"✨ System is ready for synthesis and deployment.")
        return True
    else:
        print(f"\n⚠️  {total_tests - passed_tests} test(s) failed. Please review and fix issues.")
        return False

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)
