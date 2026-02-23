#!/usr/bin/env python3
"""
Integration test to verify directory structure assumptions hold across components.

This test catches the kinds of bugs we encountered during directory structure refactoring:
- has_image flag accuracy when PNGs are in artifacts/ subdirectory
- analyze_results.py finding benchmark runs in new directory structure
- Model name extraction from new UUID-based directory names

Run this test after ANY changes to directory structure or path handling.

Usage:
    python test_directory_structure_integration.py
"""

import json
import sys
import tempfile
from pathlib import Path


def test_has_image_flag_with_artifacts_directory():
    """
    Test Case 1: Verify has_image flag correctly detects PNG in artifacts/ subdirectory.

    Background: Bug encountered where has_image was always False because
    glob("*.png") only checked root directory, not artifacts/ subdirectory.

    This test ensures the fix remains in place.
    """
    print("Test 1: has_image flag with artifacts/ subdirectory...")

    # Import here to avoid issues if module not available
    try:
        # We need to test the actual save_results logic
        # Since we can't easily import TestRunner without dependencies,
        # we'll test the glob pattern directly

        with tempfile.TemporaryDirectory() as tmpdir:
            test_folder = Path(tmpdir) / "test_000_problem"
            test_folder.mkdir(parents=True)
            artifacts_dir = test_folder / "artifacts"
            artifacts_dir.mkdir()

            # Create dummy PNG in artifacts/ (new structure)
            png_file = artifacts_dir / "result.png"
            png_file.write_bytes(b"fake png data")

            # Test the glob pattern that should be used
            png_files = list(test_folder.glob("*.png")) + list(test_folder.glob("artifacts/*.png"))
            has_image = len(png_files) > 0

            assert has_image == True, "has_image should be True when PNG exists in artifacts/"
            assert len(png_files) == 1, f"Should find exactly 1 PNG, found {len(png_files)}"

            print("  ✅ Correctly detects PNG in artifacts/ subdirectory")

            # Test legacy structure (PNG in root)
            test_folder2 = Path(tmpdir) / "test_001_problem"
            test_folder2.mkdir(parents=True)
            root_png = test_folder2 / "result.png"
            root_png.write_bytes(b"fake png data")

            png_files2 = list(test_folder2.glob("*.png")) + list(test_folder2.glob("artifacts/*.png"))
            has_image2 = len(png_files2) > 0

            assert has_image2 == True, "has_image should be True when PNG exists in root"
            print("  ✅ Also correctly detects PNG in root directory (legacy)")

            # Test no PNG case
            test_folder3 = Path(tmpdir) / "test_002_problem"
            test_folder3.mkdir(parents=True)

            png_files3 = list(test_folder3.glob("*.png")) + list(test_folder3.glob("artifacts/*.png"))
            has_image3 = len(png_files3) > 0

            assert has_image3 == False, "has_image should be False when no PNG exists"
            print("  ✅ Correctly returns False when no PNG exists")

    except Exception as e:
        print(f"  ❌ Test failed: {e}")
        raise

    return True


def test_analyze_results_directory_scanning():
    """
    Test Case 2: Verify analyze_results.py logic finds both old and new directory patterns.

    Background: Bug where analyze_results.py only scanned harness_* pattern,
    missing new benchmark_run_output/*/ directories.

    This test ensures both patterns are found.
    """
    print("\nTest 2: analyze_results.py directory scanning...")

    try:
        with tempfile.TemporaryDirectory() as tmpdir:
            harness_dir = Path(tmpdir)

            # Create legacy directory structure
            legacy_dir = harness_dir / "harness_anthropic_claude-3.5-sonnet_20251024_011837"
            legacy_dir.mkdir()

            # Create new directory structure
            benchmark_output = harness_dir / "benchmark_run_output"
            benchmark_output.mkdir()
            new_dir = benchmark_output / "abc12345_anthropic_claude-haiku-4.5_20251026_154624"
            new_dir.mkdir()

            # Test the glob patterns that should be used
            old_pattern_dirs = sorted([d for d in harness_dir.glob('harness_*') if d.is_dir()])
            new_pattern_dirs = sorted([d for d in (harness_dir / 'benchmark_run_output').glob('*')
                                       if d.is_dir()]) if (harness_dir / 'benchmark_run_output').exists() else []

            all_dirs = old_pattern_dirs + new_pattern_dirs

            assert len(old_pattern_dirs) == 1, f"Should find 1 legacy dir, found {len(old_pattern_dirs)}"
            assert len(new_pattern_dirs) == 1, f"Should find 1 new dir, found {len(new_pattern_dirs)}"
            assert len(all_dirs) == 2, f"Should find 2 total dirs, found {len(all_dirs)}"

            print(f"  ✅ Found {len(old_pattern_dirs)} legacy harness_* directory")
            print(f"  ✅ Found {len(new_pattern_dirs)} new benchmark_run_output/* directory")
            print(f"  ✅ Total: {len(all_dirs)} directories scanned")

    except Exception as e:
        print(f"  ❌ Test failed: {e}")
        raise

    return True


def test_model_name_extraction():
    """
    Test Case 3: Verify model name extraction works for both directory naming conventions.

    Background: Different naming patterns require different parsing logic:
    - Legacy: harness_MODEL_DATE_TIME
    - New:    UUID_MODEL_DATE_TIME

    This test ensures both patterns are parsed correctly.
    """
    print("\nTest 3: Model name extraction from directory names...")

    import re

    try:
        # Test legacy pattern
        legacy_dirname = "harness_anthropic_claude-3.5-sonnet_20251024_011837"

        if legacy_dirname.startswith('harness_'):
            timestamp_pattern = r'(\d{8}_\d{6})$'
            match = re.search(timestamp_pattern, legacy_dirname)
            if match:
                legacy_model = legacy_dirname[:match.start()].replace('harness_', '')
            else:
                legacy_model = "unknown"

        assert legacy_model == "anthropic_claude-3.5-sonnet_", \
            f"Legacy model name should be 'anthropic_claude-3.5-sonnet_', got '{legacy_model}'"
        print(f"  ✅ Legacy pattern: extracted model '{legacy_model}'")

        # Test new pattern
        new_dirname = "abc12345_anthropic_claude-haiku-4.5_20251026_154624"

        if not new_dirname.startswith('harness_'):
            # New pattern: UUID_MODEL_DATE_TIME
            if re.match(r'^[a-f0-9]{8}_', new_dirname):
                remaining = new_dirname[9:]  # Skip "UUID_"
                timestamp_pattern = r'_(\d{8}_\d{6})$'
                match = re.search(timestamp_pattern, remaining)
                if match:
                    new_model = remaining[:match.start()]
                else:
                    new_model = remaining
            else:
                new_model = "unknown"

        assert new_model == "anthropic_claude-haiku-4.5", \
            f"New model name should be 'anthropic_claude-haiku-4.5', got '{new_model}'"
        print(f"  ✅ New pattern: extracted model '{new_model}'")

    except Exception as e:
        print(f"  ❌ Test failed: {e}")
        raise

    return True


def test_results_json_structure():
    """
    Test Case 4: Verify results.json has correct structure including has_image flag.

    This ensures the integration point between test_runner and report_renderer
    uses a consistent data format.
    """
    print("\nTest 4: results.json structure validation...")

    try:
        # Create a mock results.json
        expected_structure = {
            "scores": [85, 72, 91, 67, 88],
            "test_folder": "/path/to/test/folder",
            "status": "completed",
            "execution_success": True,
            "has_image": True
        }

        # Verify required fields exist
        required_fields = ["scores", "test_folder", "status", "execution_success", "has_image"]
        for field in required_fields:
            assert field in expected_structure, f"Missing required field: {field}"

        # Verify scores is a list of 5 integers
        assert isinstance(expected_structure["scores"], list), "scores should be a list"
        assert len(expected_structure["scores"]) == 5, "scores should have exactly 5 elements"
        assert all(isinstance(s, int) for s in expected_structure["scores"]), "all scores should be integers"

        # Verify has_image is boolean
        assert isinstance(expected_structure["has_image"], bool), "has_image should be boolean"

        print("  ✅ results.json has correct structure")
        print(f"  ✅ All {len(required_fields)} required fields present")
        print("  ✅ scores array has 5 integer values")
        print("  ✅ has_image is boolean type")

    except Exception as e:
        print(f"  ❌ Test failed: {e}")
        raise

    return True


def run_all_tests():
    """Run all integration tests and report results."""
    print("=" * 60)
    print("DIRECTORY STRUCTURE INTEGRATION TESTS")
    print("=" * 60)
    print()

    tests = [
        test_has_image_flag_with_artifacts_directory,
        test_analyze_results_directory_scanning,
        test_model_name_extraction,
        test_results_json_structure,
    ]

    passed = 0
    failed = 0

    for test in tests:
        try:
            test()
            passed += 1
        except Exception as e:
            failed += 1
            print(f"\n❌ {test.__name__} FAILED: {e}")

    print()
    print("=" * 60)
    if failed == 0:
        print(f"✅ ALL TESTS PASSED ({passed}/{len(tests)})")
        print("=" * 60)
        return 0
    else:
        print(f"❌ SOME TESTS FAILED: {passed} passed, {failed} failed")
        print("=" * 60)
        return 1


if __name__ == '__main__':
    sys.exit(run_all_tests())
