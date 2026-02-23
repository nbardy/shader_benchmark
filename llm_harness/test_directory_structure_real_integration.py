#!/usr/bin/env python3
"""
REAL Integration Tests for Directory Structure

These tests actually exercise the production code paths, not simulations.
They would have caught all 4 bugs if written before the fixes.
"""

import sys
import unittest
import tempfile
import shutil
from pathlib import Path
import json

# Import the actual production code
from test_runner import TestRunner
from analyze_results import BenchmarkAnalyzer


class TestHasImageFlag(unittest.TestCase):
    """Test the actual has_image flag logic in test_runner.py"""

    def test_has_image_detects_png_in_artifacts_subdirectory(self):
        """
        REAL TEST: Actually call TestRunner.save_results() with PNG in artifacts/
        This would have FAILED before the fix (Bug #1)
        """
        with tempfile.TemporaryDirectory() as tmpdir:
            test_folder = Path(tmpdir)

            # Create artifacts subdirectory with PNG (new structure)
            artifacts_dir = test_folder / "artifacts"
            artifacts_dir.mkdir()
            png_file = artifacts_dir / "result.png"
            png_file.write_bytes(b"fake png data")

            # Create fake results data
            scores = [85, 72, 91, 67, 88]
            metadata = {"model": "test-model"}

            # Call the ACTUAL production code
            runner = TestRunner(
                model_name="test-model",
                test_folder=test_folder,
                problem_spec_folder=Path("../problems/base_set/geometric_cube"),
                shader_harness_path=Path("../shader_harness")
            )

            # Call the actual save_results method
            runner.save_results(scores, metadata)

            # Read the actual results.json that was written
            results_file = test_folder / "results.json"
            self.assertTrue(results_file.exists(), "results.json should be created")

            with open(results_file) as f:
                results = json.load(f)

            # THE KEY ASSERTION: has_image should be True
            self.assertTrue(
                results.get("has_image"),
                "has_image should be True when PNG exists in artifacts/ subdirectory"
            )

    def test_has_image_detects_png_in_root_directory(self):
        """Test legacy structure with PNG in root directory"""
        with tempfile.TemporaryDirectory() as tmpdir:
            test_folder = Path(tmpdir)

            # Create PNG in root (legacy structure)
            png_file = test_folder / "result.png"
            png_file.write_bytes(b"fake png data")

            scores = [85, 72, 91, 67, 88]
            metadata = {"model": "test-model"}

            runner = TestRunner(
                model_name="test-model",
                test_folder=test_folder,
                problem_spec_folder=Path("../problems/base_set/geometric_cube"),
                shader_harness_path=Path("../shader_harness")
            )

            runner.save_results(scores, metadata)

            results_file = test_folder / "results.json"
            with open(results_file) as f:
                results = json.load(f)

            self.assertTrue(
                results.get("has_image"),
                "has_image should be True when PNG exists in root directory"
            )

    def test_has_image_false_when_no_png(self):
        """Test that has_image is False when no PNG exists"""
        with tempfile.TemporaryDirectory() as tmpdir:
            test_folder = Path(tmpdir)

            scores = [85, 72, 91, 67, 88]
            metadata = {"model": "test-model"}

            runner = TestRunner(
                model_name="test-model",
                test_folder=test_folder,
                problem_spec_folder=Path("../problems/base_set/geometric_cube"),
                shader_harness_path=Path("../shader_harness")
            )

            runner.save_results(scores, metadata)

            results_file = test_folder / "results.json"
            with open(results_file) as f:
                results = json.load(f)

            self.assertFalse(
                results.get("has_image"),
                "has_image should be False when no PNG exists"
            )


class TestDirectoryScanning(unittest.TestCase):
    """Test the actual directory scanning logic in analyze_results.py"""

    def test_analyze_finds_both_legacy_and_new_structure(self):
        """
        REAL TEST: Actually call BenchmarkAnalyzer.analyze() with both structures
        This would have FAILED before the fix (Bug #2 and #3)
        """
        with tempfile.TemporaryDirectory() as tmpdir:
            harness_dir = Path(tmpdir)

            # Create LEGACY pattern directory
            legacy_dir = harness_dir / "harness_anthropic_claude-3.5-sonnet_20251024_123456"
            legacy_dir.mkdir()
            (legacy_dir / "logs").mkdir()

            # Create execution_summary.log for legacy
            summary_log = legacy_dir / "logs" / "execution_summary.log"
            summary_log.write_text(
                "[2025-10-24 12:34:56] START problem_000: geometric_cube\n"
                "[2025-10-24 12:35:00] END problem_000: geometric_cube - SUCCESS\n"
            )

            # Create NEW pattern directory structure
            new_output_dir = harness_dir / "benchmark_run_output"
            new_output_dir.mkdir()
            new_dir = new_output_dir / "97fe1f08_anthropic_claude-haiku-4.5_20251026_154624"
            new_dir.mkdir()
            (new_dir / "logs").mkdir()

            # Create execution_summary.log for new structure
            new_summary_log = new_dir / "logs" / "execution_summary.log"
            new_summary_log.write_text(
                "[2025-10-26 15:46:00] START problem_000: klein_bottle\n"
                "[2025-10-26 15:46:30] END problem_000: klein_bottle - SUCCESS\n"
            )

            # Call the ACTUAL production code
            analyzer = BenchmarkAnalyzer(harness_dir=str(harness_dir))
            analyzer.analyze()

            # THE KEY ASSERTIONS
            # Should have found BOTH directories
            self.assertEqual(
                analyzer.results['total_runs'],
                2,
                "Should find both legacy and new directory structures"
            )

            # Should have processed BOTH execution logs
            self.assertEqual(
                analyzer.results['total_problems'],
                2,
                "Should process problems from both directory structures"
            )

            # Should correctly extract model names from BOTH patterns
            models = list(analyzer.results['by_model'].keys())
            self.assertIn(
                "anthropic_claude-3.5-sonnet",
                models,
                "Should extract model name from legacy directory pattern"
            )
            self.assertIn(
                "anthropic_claude-haiku-4.5",
                models,
                "Should extract model name from UUID-prefixed directory pattern"
            )

    def test_analyze_handles_only_legacy_structure(self):
        """Test backward compatibility with only legacy directories"""
        with tempfile.TemporaryDirectory() as tmpdir:
            harness_dir = Path(tmpdir)

            # Create only LEGACY pattern
            legacy_dir = harness_dir / "harness_anthropic_claude-3.5-sonnet_20251024_123456"
            legacy_dir.mkdir()
            (legacy_dir / "logs").mkdir()

            summary_log = legacy_dir / "logs" / "execution_summary.log"
            summary_log.write_text(
                "[2025-10-24 12:34:56] START problem_000: geometric_cube\n"
                "[2025-10-24 12:35:00] END problem_000: geometric_cube - SUCCESS\n"
            )

            analyzer = BenchmarkAnalyzer(harness_dir=str(harness_dir))
            analyzer.analyze()

            self.assertEqual(
                analyzer.results['total_runs'],
                1,
                "Should find legacy directory"
            )

    def test_analyze_handles_only_new_structure(self):
        """Test that only new structure directories are found"""
        with tempfile.TemporaryDirectory() as tmpdir:
            harness_dir = Path(tmpdir)

            # Create only NEW pattern
            new_output_dir = harness_dir / "benchmark_run_output"
            new_output_dir.mkdir()
            new_dir = new_output_dir / "97fe1f08_anthropic_claude-haiku-4.5_20251026_154624"
            new_dir.mkdir()
            (new_dir / "logs").mkdir()

            summary_log = new_dir / "logs" / "execution_summary.log"
            summary_log.write_text(
                "[2025-10-26 15:46:00] START problem_000: klein_bottle\n"
                "[2025-10-26 15:46:30] END problem_000: klein_bottle - SUCCESS\n"
            )

            analyzer = BenchmarkAnalyzer(harness_dir=str(harness_dir))
            analyzer.analyze()

            self.assertEqual(
                analyzer.results['total_runs'],
                1,
                "Should find new structure directory"
            )


class TestResultsJsonStructure(unittest.TestCase):
    """Test the structure of results.json created by production code"""

    def test_results_json_has_required_fields(self):
        """Verify results.json structure matches contract"""
        with tempfile.TemporaryDirectory() as tmpdir:
            test_folder = Path(tmpdir)

            scores = [85, 72, 91, 67, 88]
            metadata = {"model": "test-model", "timestamp": "2025-10-27"}

            runner = TestRunner(
                model_name="test-model",
                test_folder=test_folder,
                problem_spec_folder=Path("../problems/base_set/geometric_cube"),
                shader_harness_path=Path("../shader_harness")
            )

            runner.save_results(scores, metadata)

            results_file = test_folder / "results.json"
            with open(results_file) as f:
                results = json.load(f)

            # Verify all required fields exist
            self.assertIn("scores", results)
            self.assertIn("total_score", results)
            self.assertIn("has_image", results)
            self.assertIn("metadata", results)
            self.assertIn("timestamp", results)

            # Verify scores structure
            self.assertEqual(len(results["scores"]), 5)
            self.assertEqual(results["scores"], scores)
            self.assertEqual(results["total_score"], sum(scores))

            # Verify types
            self.assertIsInstance(results["has_image"], bool)
            self.assertIsInstance(results["scores"], list)
            self.assertIsInstance(results["metadata"], dict)


def run_tests():
    """Run all integration tests and report results"""
    # Create test suite
    loader = unittest.TestLoader()
    suite = unittest.TestSuite()

    suite.addTests(loader.loadTestsFromTestCase(TestHasImageFlag))
    suite.addTests(loader.loadTestsFromTestCase(TestDirectoryScanning))
    suite.addTests(loader.loadTestsFromTestCase(TestResultsJsonStructure))

    # Run with verbose output
    runner = unittest.TextTestRunner(verbosity=2)
    result = runner.run(suite)

    # Print summary
    print("\n" + "="*70)
    print("REAL INTEGRATION TEST SUMMARY")
    print("="*70)
    print(f"Tests run: {result.testsRun}")
    print(f"Successes: {result.testsRun - len(result.failures) - len(result.errors)}")
    print(f"Failures: {len(result.failures)}")
    print(f"Errors: {len(result.errors)}")

    if result.wasSuccessful():
        print("\n✅ ALL TESTS PASSED - Production code is working correctly!")
        return 0
    else:
        print("\n❌ SOME TESTS FAILED - See details above")
        return 1


if __name__ == "__main__":
    sys.exit(run_tests())
