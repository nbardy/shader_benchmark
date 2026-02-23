#!/usr/bin/env python3
"""
Test Suite for Reporting System Integration

This module provides comprehensive tests for:
1. ResultScanner functionality (scanning and converting test directories)
2. Data structure conversions
3. Integration with existing harness results
4. End-to-end report generation (when hiccup renderer is available)

Author: Staff Engineer 3
Date: 2025-10-26
Version: 1.0 (Full Implementation)
"""

import unittest
import sys
from pathlib import Path
from datetime import datetime
import tempfile
import json
import shutil

# Add parent directory to path for imports
sys.path.insert(0, str(Path(__file__).parent))

from report_integration import (
    ResultScanner,
    convert_existing_results_to_benchmark_run
)
from results_collector import (
    JudgeScores,
    ExecutionStatus,
    BenchmarkRun
)


class TestResultScanner(unittest.TestCase):
    """Unit tests for ResultScanner class"""

    def setUp(self):
        """Create temporary test directory structure"""
        self.temp_dir = tempfile.mkdtemp()
        self.test_dir = Path(self.temp_dir)

    def tearDown(self):
        """Clean up temporary directory"""
        shutil.rmtree(self.temp_dir, ignore_errors=True)

    def create_mock_test_directory(self, name: str, scores: list = None, success: bool = True) -> Path:
        """Create a mock test directory with minimal structure"""
        test_dir = self.test_dir / name
        test_dir.mkdir(parents=True)

        # Create shaders directory with sample shader
        shaders_dir = test_dir / "shaders"
        shaders_dir.mkdir()
        shader_file = shaders_dir / "test_shader.wgsl"
        shader_file.write_text("// Sample WGSL shader\n@fragment fn main() -> @location(0) vec4<f32> { return vec4<f32>(1.0); }")

        # Create results.json
        results = {
            "scores": scores or [85, 72, 91, 67, 88],
            "test_folder": str(test_dir),
            "status": "completed" if success else "failed",
            "execution_success": success,
            "has_image": success
        }
        results_file = test_dir / "results.json"
        with open(results_file, 'w') as f:
            json.dump(results, f, indent=2)

        # Create artifacts directory with result image (empty file for testing)
        if success:
            artifacts_dir = test_dir / "artifacts"
            artifacts_dir.mkdir()
            result_image = artifacts_dir / "result.png"
            result_image.write_bytes(b'fake png data')

        return test_dir

    def test_find_test_directories(self):
        """Test finding test directories by pattern"""
        # Create some test directories
        self.create_mock_test_directory("test_20251024_120000_abc123_results")
        self.create_mock_test_directory("test_20251024_130000_def456_results")
        self.create_mock_test_directory("not_a_test_dir")

        scanner = ResultScanner(self.test_dir)
        test_dirs = scanner.find_test_directories()

        self.assertEqual(len(test_dirs), 2)
        self.assertTrue(all("test_" in d.name for d in test_dirs))

    def test_parse_test_directory_name(self):
        """Test parsing timestamp and UUID from directory name"""
        scanner = ResultScanner()

        # Valid directory name
        test_dir = Path("test_20251024_143022_abc123-def4-5678-90ab-cdef01234567_results")
        timestamp, uuid = scanner.parse_test_directory_name(test_dir)

        self.assertIsNotNone(timestamp)
        self.assertEqual(timestamp.year, 2025)
        self.assertEqual(timestamp.month, 10)
        self.assertEqual(timestamp.day, 24)
        self.assertEqual(timestamp.hour, 14)
        self.assertEqual(timestamp.minute, 30)
        self.assertEqual(uuid, "abc123-def4-5678-90ab-cdef01234567")

        # Invalid directory name
        invalid_dir = Path("invalid_directory_name")
        timestamp, uuid = scanner.parse_test_directory_name(invalid_dir)
        self.assertIsNone(timestamp)
        self.assertIsNone(uuid)

    def test_load_results_json(self):
        """Test loading results.json from test directory"""
        test_dir = self.create_mock_test_directory("test_20251024_120000_abc123_results",
                                                   scores=[90, 85, 92, 88, 91])

        scanner = ResultScanner(self.test_dir)
        results = scanner.load_results_json(test_dir)

        self.assertIsNotNone(results)
        self.assertEqual(results['scores'], [90, 85, 92, 88, 91])
        self.assertTrue(results['execution_success'])

    def test_parse_judge_scores(self):
        """Test converting score list to JudgeScores object"""
        scanner = ResultScanner()

        # Valid scores
        scores = [85, 72, 91, 67, 88]
        judge_scores = scanner.parse_judge_scores(scores)

        self.assertIsNotNone(judge_scores)
        self.assertEqual(judge_scores.s1_mathematical_accuracy, 85)
        self.assertEqual(judge_scores.s2_visual_quality, 72)
        self.assertEqual(judge_scores.total, 403)
        self.assertAlmostEqual(judge_scores.average, 80.6, places=1)

        # Invalid scores (out of range)
        invalid_scores = [150, 72, 91, 67, 88]
        judge_scores = scanner.parse_judge_scores(invalid_scores)
        self.assertIsNone(judge_scores)

        # Invalid scores (wrong length)
        invalid_scores = [85, 72, 91]
        judge_scores = scanner.parse_judge_scores(invalid_scores)
        self.assertIsNone(judge_scores)

    def test_load_shader_artifacts(self):
        """Test loading shader artifacts from test directory"""
        test_dir = self.create_mock_test_directory("test_20251024_120000_abc123_results")

        scanner = ResultScanner(self.test_dir)
        artifacts = scanner.load_shader_artifacts(test_dir)

        self.assertIsNotNone(artifacts)
        self.assertEqual(len(artifacts.shader_files), 1)
        self.assertIn("test_shader.wgsl", artifacts.shader_files)
        self.assertEqual(artifacts.main_shader_name, "test_shader.wgsl")
        self.assertEqual(artifacts.language_spec, "wgsl")

    def test_convert_successful_test_directory(self):
        """Test converting a successful test directory to TestResult"""
        test_dir = self.create_mock_test_directory(
            "test_20251024_120000_abc123_results",
            scores=[90, 85, 92, 88, 91],
            success=True
        )

        scanner = ResultScanner(self.test_dir)
        result = scanner.convert_test_directory_to_result(test_dir, run_number=1)

        self.assertIsNotNone(result)
        self.assertTrue(result.success)
        self.assertEqual(result.status, ExecutionStatus.SUCCESS)
        self.assertEqual(result.run_number, 1)
        self.assertIsNotNone(result.judge_scores)
        self.assertEqual(result.judge_scores.total, 446)
        self.assertIsNotNone(result.result_image_path)
        self.assertTrue(result.result_image_path.exists())

    def test_convert_failed_test_directory(self):
        """Test converting a failed test directory to TestResult"""
        test_dir = self.create_mock_test_directory(
            "test_20251024_120000_def456_results",
            scores=[0, 0, 0, 0, 0],
            success=False
        )

        scanner = ResultScanner(self.test_dir)
        result = scanner.convert_test_directory_to_result(test_dir, run_number=2)

        self.assertIsNotNone(result)
        self.assertFalse(result.success)
        self.assertEqual(result.status, ExecutionStatus.UNKNOWN_ERROR)
        self.assertIsNone(result.judge_scores)
        self.assertIsNotNone(result.error)

    def test_scan_and_convert_multiple_directories(self):
        """Test scanning and converting multiple test directories to BenchmarkRun"""
        # Create multiple test directories
        self.create_mock_test_directory("test_20251024_120000_aaa111_results", [90, 85, 92, 88, 91], True)
        self.create_mock_test_directory("test_20251024_130000_bbb222_results", [75, 80, 70, 85, 78], True)
        self.create_mock_test_directory("test_20251024_140000_ccc333_results", [0, 0, 0, 0, 0], False)

        scanner = ResultScanner(self.test_dir)
        test_dirs = scanner.find_test_directories()
        benchmark_run = scanner.scan_and_convert(test_dirs, model_name="test_model",
                                                judge_model="test_judge", language_spec="wgsl")

        self.assertIsNotNone(benchmark_run)
        self.assertEqual(benchmark_run.summary.total_tests, 3)
        self.assertEqual(benchmark_run.summary.successful_tests, 2)
        self.assertEqual(benchmark_run.summary.failed_tests, 1)
        self.assertEqual(benchmark_run.summary.model_name, "test_model")

        # Check average scores
        self.assertIsNotNone(benchmark_run.summary.average_scores)
        self.assertGreater(benchmark_run.summary.average_scores.total, 0)

        # Check best/worst tests
        self.assertIsNotNone(benchmark_run.summary.best_test)
        self.assertIsNotNone(benchmark_run.summary.worst_test)

        # Check test results are sorted
        self.assertEqual(len(benchmark_run.test_results), 3)
        for i, result in enumerate(benchmark_run.test_results):
            self.assertEqual(result.run_number, i + 1)


class TestIntegrationWithRealData(unittest.TestCase):
    """Integration tests using real harness result directories"""

    def setUp(self):
        """Find real test directories in current directory"""
        self.base_dir = Path.cwd()
        self.scanner = ResultScanner(self.base_dir)
        self.test_dirs = self.scanner.find_test_directories()

    def test_scan_real_directories(self):
        """Test scanning real test result directories"""
        if not self.test_dirs:
            self.skipTest("No real test directories found")

        print(f"\n Found {len(self.test_dirs)} real test directories")

        # Try to convert first directory
        test_dir = self.test_dirs[0]
        result = self.scanner.convert_test_directory_to_result(test_dir, run_number=1)

        self.assertIsNotNone(result, f"Failed to convert {test_dir}")
        print(f"\n Converted: {result.problem_name}")
        print(f"   Success: {result.success}")
        print(f"   Status: {result.status.value}")

        if result.judge_scores:
            print(f"   Total score: {result.judge_scores.total}/500")

    def test_convert_real_directories_to_benchmark_run(self):
        """Test converting real directories to full BenchmarkRun"""
        if not self.test_dirs:
            self.skipTest("No real test directories found")

        # Limit to first 10 for testing
        test_dirs = self.test_dirs[:10]

        benchmark_run = self.scanner.scan_and_convert(
            test_dirs,
            model_name="test_scan",
            judge_model="haiku",
            language_spec="wgsl"
        )

        self.assertIsNotNone(benchmark_run)
        print(f"\n BenchmarkRun Statistics:")
        print(f"   Total tests: {benchmark_run.summary.total_tests}")
        print(f"   Successful: {benchmark_run.summary.successful_tests}")
        print(f"   Failed: {benchmark_run.summary.failed_tests}")
        print(f"   Success rate: {benchmark_run.summary.success_rate:.1f}%")

        if benchmark_run.summary.average_scores:
            print(f"   Average score: {benchmark_run.summary.average_scores.total}/500")
            print(f"   S1 (Math): {benchmark_run.summary.average_scores.s1_mathematical_accuracy}/100")
            print(f"   S2 (Visual): {benchmark_run.summary.average_scores.s2_visual_quality}/100")


class TestHelperFunctions(unittest.TestCase):
    """Test helper functions for easy integration"""

    def test_convert_existing_results_helper(self):
        """Test the helper function for converting existing results"""
        base_dir = Path.cwd()
        scanner = ResultScanner(base_dir)
        test_dirs = scanner.find_test_directories()

        if not test_dirs:
            self.skipTest("No test directories found")

        # Use helper function
        test_dir_strs = [str(d) for d in test_dirs[:5]]
        benchmark_run = convert_existing_results_to_benchmark_run(
            test_dir_strs,
            model_name="helper_test",
            judge_model="haiku"
        )

        self.assertIsNotNone(benchmark_run)
        self.assertGreater(benchmark_run.summary.total_tests, 0)


def run_unit_tests():
    """Run only unit tests (mock data)"""
    suite = unittest.TestLoader().loadTestsFromTestCase(TestResultScanner)
    runner = unittest.TextTestRunner(verbosity=2)
    result = runner.run(suite)
    return result.wasSuccessful()


def run_integration_tests():
    """Run integration tests (real data)"""
    suite = unittest.TestSuite()
    suite.addTests(unittest.TestLoader().loadTestsFromTestCase(TestIntegrationWithRealData))
    suite.addTests(unittest.TestLoader().loadTestsFromTestCase(TestHelperFunctions))
    runner = unittest.TextTestRunner(verbosity=2)
    result = runner.run(suite)
    return result.wasSuccessful()


def run_all_tests():
    """Run all tests"""
    suite = unittest.TestSuite()
    suite.addTests(unittest.TestLoader().loadTestsFromTestCase(TestResultScanner))
    suite.addTests(unittest.TestLoader().loadTestsFromTestCase(TestIntegrationWithRealData))
    suite.addTests(unittest.TestLoader().loadTestsFromTestCase(TestHelperFunctions))
    runner = unittest.TextTestRunner(verbosity=2)
    result = runner.run(suite)
    return result.wasSuccessful()


if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(description='Test Reporting System Integration')
    parser.add_argument('--unit', action='store_true', help='Run only unit tests')
    parser.add_argument('--integration', action='store_true', help='Run only integration tests')
    args = parser.parse_args()

    print("=" * 70)
    print("Reporting System Integration Tests")
    print("=" * 70)

    if args.unit:
        success = run_unit_tests()
    elif args.integration:
        success = run_integration_tests()
    else:
        success = run_all_tests()

    sys.exit(0 if success else 1)
