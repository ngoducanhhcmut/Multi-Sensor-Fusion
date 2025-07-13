#!/usr/bin/env python3
"""
Comprehensive Test Suite Runner
Runs all final validation tests for Multi-Sensor Fusion System
"""

import subprocess
import time
import json
import sys
from datetime import datetime

class ComprehensiveTestRunner:
    def __init__(self):
        self.test_results = {}
        self.start_time = None
        self.total_tests = 0
        self.passed_tests = 0
        
    def run_test_suite(self, test_name, script_path, description):
        """Run a test suite and capture results"""
        
        print(f"\n{'='*80}")
        print(f"🧪 RUNNING: {test_name}")
        print(f"📝 Description: {description}")
        print(f"📂 Script: {script_path}")
        print(f"{'='*80}")
        
        start_time = time.time()
        
        try:
            # Run the test script
            result = subprocess.run(
                [sys.executable, script_path],
                capture_output=True,
                text=True,
                timeout=300  # 5 minute timeout
            )
            
            end_time = time.time()
            duration = end_time - start_time
            
            # Parse results
            success = result.returncode == 0
            
            self.test_results[test_name] = {
                'success': success,
                'duration_seconds': duration,
                'return_code': result.returncode,
                'stdout': result.stdout,
                'stderr': result.stderr,
                'description': description
            }
            
            if success:
                self.passed_tests += 1
                print(f"✅ {test_name} PASSED in {duration:.2f}s")
            else:
                print(f"❌ {test_name} FAILED in {duration:.2f}s")
                print(f"Error: {result.stderr}")
            
            self.total_tests += 1
            
        except subprocess.TimeoutExpired:
            print(f"⏰ {test_name} TIMEOUT after 5 minutes")
            self.test_results[test_name] = {
                'success': False,
                'duration_seconds': 300,
                'return_code': -1,
                'stdout': '',
                'stderr': 'Test timeout after 5 minutes',
                'description': description
            }
            self.total_tests += 1
            
        except Exception as e:
            print(f"💥 {test_name} ERROR: {str(e)}")
            self.test_results[test_name] = {
                'success': False,
                'duration_seconds': 0,
                'return_code': -2,
                'stdout': '',
                'stderr': str(e),
                'description': description
            }
            self.total_tests += 1
    
    def run_all_tests(self):
        """Run all comprehensive tests"""
        
        print("🚀 MULTI-SENSOR FUSION - COMPREHENSIVE TEST SUITE")
        print("="*80)
        print("Running all validation tests for production readiness")
        print("="*80)
        
        self.start_time = time.time()
        
        # Test Suite 1: 1000 Comprehensive Edge Cases
        self.run_test_suite(
            "1000_Comprehensive_Edge_Cases",
            "test_final_comprehensive_1000.py",
            "1000 test cases with edge cases, boundary conditions, and stress tests"
        )
        
        # Test Suite 2: Detailed Dataset Testing
        self.run_test_suite(
            "KITTI_nuScenes_Dataset_Testing",
            "test_detailed_datasets.py",
            "Comprehensive KITTI and nuScenes dataset validation"
        )
        
        # Test Suite 3: Real-time Performance
        self.run_test_suite(
            "Real_Time_Performance",
            "test_realtime_kitti_nuscenes.py",
            "Real-time performance validation with KITTI and nuScenes"
        )
        
        # Test Suite 4: Ultra-fast Microsecond Testing
        self.run_test_suite(
            "Ultra_Fast_Microsecond",
            "test_ultra_fast_microsecond.py",
            "Microsecond-level optimization validation"
        )
        
        # Test Suite 5: Hardware Realistic Performance
        self.run_test_suite(
            "Hardware_Realistic_Performance",
            "test_hardware_realistic_performance.py",
            "Hardware-realistic performance testing"
        )
        
        self.generate_final_report()
    
    def generate_final_report(self):
        """Generate comprehensive final report"""
        
        total_time = time.time() - self.start_time
        success_rate = (self.passed_tests / self.total_tests) * 100 if self.total_tests > 0 else 0
        
        print(f"\n{'='*80}")
        print("📊 COMPREHENSIVE TEST SUITE - FINAL REPORT")
        print(f"{'='*80}")
        
        print(f"\n⏱️  Test Execution Summary:")
        print(f"   Total Test Suites: {self.total_tests}")
        print(f"   Passed: {self.passed_tests}")
        print(f"   Failed: {self.total_tests - self.passed_tests}")
        print(f"   Success Rate: {success_rate:.1f}%")
        print(f"   Total Duration: {total_time:.2f} seconds")
        
        print(f"\n📋 Individual Test Results:")
        for test_name, result in self.test_results.items():
            status = "✅ PASS" if result['success'] else "❌ FAIL"
            duration = result['duration_seconds']
            print(f"   {test_name:30s}: {status} ({duration:.2f}s)")
        
        # Overall assessment
        print(f"\n🎯 OVERALL ASSESSMENT:")
        if success_rate >= 100:
            print("✅ EXCELLENT - ALL TESTS PASSED!")
            print("🚀 System is PRODUCTION-READY")
            print("🎉 Recommended for autonomous vehicle deployment")
            overall_status = "EXCELLENT"
        elif success_rate >= 80:
            print("✅ GOOD - Most tests passed")
            print("🔧 Minor issues need attention")
            print("📈 System is mostly production-ready")
            overall_status = "GOOD"
        else:
            print("⚠️ NEEDS IMPROVEMENT")
            print("🔧 Significant issues require resolution")
            print("📊 Additional development needed")
            overall_status = "NEEDS_IMPROVEMENT"
        
        # Save detailed results
        self.save_results_json(overall_status, success_rate, total_time)
        
        print(f"\n📄 Detailed results saved to: comprehensive_test_results.json")
        print(f"📄 Full report available in: FINAL_COMPREHENSIVE_TEST_REPORT.md")
        
        return success_rate >= 80  # Return True if tests are acceptable
    
    def save_results_json(self, overall_status, success_rate, total_time):
        """Save detailed results to JSON file"""
        
        results_data = {
            'test_execution': {
                'timestamp': datetime.now().isoformat(),
                'total_suites': self.total_tests,
                'passed_suites': self.passed_tests,
                'success_rate_percent': success_rate,
                'total_duration_seconds': total_time,
                'overall_status': overall_status
            },
            'test_suites': self.test_results,
            'summary': {
                'production_ready': success_rate >= 80,
                'recommended_action': (
                    "Deploy to production" if success_rate >= 100 else
                    "Address minor issues before deployment" if success_rate >= 80 else
                    "Significant development required"
                )
            }
        }
        
        with open('comprehensive_test_results.json', 'w') as f:
            json.dump(results_data, f, indent=2)

def main():
    """Main test runner"""
    
    runner = ComprehensiveTestRunner()
    success = runner.run_all_tests()
    
    # Exit with appropriate code
    sys.exit(0 if success else 1)

if __name__ == "__main__":
    main()
