#!/usr/bin/env python3
"""
Report Integration Layer for Shader Benchmark Harness

This module provides the glue code between the benchmark harness execution
and the reporting system. It handles:
1. Scanning existing test result directories
2. Converting legacy format to ResultsCollector data structures
3. Integrating report generation into the harness workflow

Author: Staff Engineer 3
Date: 2025-10-26
Version: 1.0 (Full Implementation)
"""

from pathlib import Path
from typing import List, Dict, Optional, Tuple
from datetime import datetime
import json
import re
from dataclasses import asdict

from results_collector import (
    BenchmarkRun,
    BenchmarkSummary,
    TestResult,
    JudgeScores,
    ShaderArtifacts,
    TimingInfo,
    ErrorInfo,
    ErrorSummary,
    ExecutionStatus
)


class ResultScanner:
    """Scans filesystem for existing test results and converts to data structures"""

    def __init__(self, base_dir: Path = None):
        """
        Initialize scanner

        Args:
            base_dir: Base directory to scan for test results (defaults to current directory)
        """
        self.base_dir = base_dir or Path.cwd()

    def find_test_directories(self, pattern: str = "test_*_results") -> List[Path]:
        """
        Find all test result directories matching pattern

        Args:
            pattern: Glob pattern for test directories

        Returns:
            List of Path objects for test directories
        """
        test_dirs = list(self.base_dir.glob(pattern))
        # Filter out nested test directories (only top-level)
        return [d for d in test_dirs if d.parent == self.base_dir]

    def parse_test_directory_name(self, test_dir: Path) -> Tuple[Optional[datetime], Optional[str]]:
        """
        Extract timestamp and UUID from test directory name

        Args:
            test_dir: Path to test directory

        Returns:
            Tuple of (timestamp, uuid) or (None, None) if parsing fails
        """
        # Expected format: test_YYYYMMDD_HHMMSS_UUID_results
        match = re.match(r'test_(\d{8})_(\d{6})_([a-f0-9-]+)_results', test_dir.name)
        if match:
            date_str = match.group(1)
            time_str = match.group(2)
            uuid_str = match.group(3)

            try:
                timestamp = datetime.strptime(f"{date_str}_{time_str}", "%Y%m%d_%H%M%S")
                return timestamp, uuid_str
            except ValueError:
                return None, None
        return None, None

    def load_results_json(self, test_dir: Path) -> Optional[Dict]:
        """
        Load results.json from test directory

        Args:
            test_dir: Path to test directory

        Returns:
            Dictionary of results or None if not found
        """
        results_file = test_dir / "results.json"
        if not results_file.exists():
            return None

        try:
            with open(results_file, 'r') as f:
                return json.load(f)
        except Exception as e:
            print(f"Warning: Failed to load {results_file}: {e}")
            return None

    def extract_problem_name(self, test_dir: Path) -> Optional[str]:
        """
        Extract problem name from shader file or directory structure

        Args:
            test_dir: Path to test directory

        Returns:
            Problem name or None if not determinable
        """
        # Try to find shader file in shaders/ directory
        shaders_dir = test_dir / "shaders"
        if shaders_dir.exists():
            shader_files = list(shaders_dir.glob("*.wgsl"))
            if shader_files:
                # Use first shader file name (without extension) as problem name
                return shader_files[0].stem

        # Fallback: use directory name
        return test_dir.name

    def load_shader_artifacts(self, test_dir: Path) -> ShaderArtifacts:
        """
        Load shader code and artifacts from test directory

        Args:
            test_dir: Path to test directory

        Returns:
            ShaderArtifacts object
        """
        shader_files = {}
        main_shader_name = None
        language_spec = "wgsl"  # Default

        # Load shaders
        shaders_dir = test_dir / "shaders"
        if shaders_dir.exists():
            for shader_file in shaders_dir.glob("*.wgsl"):
                try:
                    shader_files[shader_file.name] = shader_file.read_text()
                    if main_shader_name is None:
                        main_shader_name = shader_file.name
                except Exception as e:
                    print(f"Warning: Failed to read {shader_file}: {e}")

        # Load main.rs reference if exists
        llm_generated_main_rs = None
        main_rs_ref = test_dir / "main_rs_reference.rs"
        if main_rs_ref.exists():
            try:
                llm_generated_main_rs = main_rs_ref.read_text()
            except Exception:
                pass

        return ShaderArtifacts(
            shader_files=shader_files,
            main_shader_name=main_shader_name,
            language_spec=language_spec,
            llm_generated_main_rs=llm_generated_main_rs
        )

    def parse_judge_scores(self, scores: List[int]) -> Optional[JudgeScores]:
        """
        Convert score list to JudgeScores object

        Args:
            scores: List of 5 integer scores (1-100 scale)

        Returns:
            JudgeScores object or None if invalid
        """
        if not scores or len(scores) != 5:
            return None

        # Validate scores are in reasonable range
        if any(s < 0 or s > 100 for s in scores):
            return None

        return JudgeScores(
            s1_mathematical_accuracy=scores[0],
            s2_visual_quality=scores[1],
            s3_problem_specific_1=scores[2],
            s4_problem_specific_2=scores[3],
            s5_problem_specific_3=scores[4],
            s3_label="Problem Specific 1",
            s4_label="Problem Specific 2",
            s5_label="Problem Specific 3"
        )

    def convert_test_directory_to_result(self, test_dir: Path, run_number: int) -> Optional[TestResult]:
        """
        Convert a test directory to a TestResult object

        Args:
            test_dir: Path to test directory
            run_number: Sequential run number

        Returns:
            TestResult object or None if conversion fails
        """
        # Parse directory name
        timestamp, uuid = self.parse_test_directory_name(test_dir)
        if timestamp is None:
            timestamp = datetime.fromtimestamp(test_dir.stat().st_mtime)

        test_id = uuid or str(test_dir.name)

        # Load results.json
        results_json = self.load_results_json(test_dir)
        if results_json is None:
            # Create minimal error result
            return TestResult(
                test_id=test_id,
                problem_name=self.extract_problem_name(test_dir),
                problem_folder=test_dir,
                run_number=run_number,
                status=ExecutionStatus.UNKNOWN_ERROR,
                success=False,
                timing=TimingInfo(),
                result_image_path=None,
                shader_artifacts=self.load_shader_artifacts(test_dir),
                judge_scores=None,
                error=ErrorInfo(
                    stage="unknown",
                    error_type="MissingResults",
                    message="results.json not found",
                    full_traceback=None,
                    compiler_output=None
                ),
                test_directory=test_dir,
                timestamp=timestamp
            )

        # Extract data from results.json
        success = results_json.get('execution_success', False)
        scores = results_json.get('scores', [0, 0, 0, 0, 0])

        # Determine status
        if success:
            status = ExecutionStatus.SUCCESS
        else:
            status = ExecutionStatus.UNKNOWN_ERROR

        # Load artifacts
        shader_artifacts = self.load_shader_artifacts(test_dir)

        # Parse scores
        judge_scores = self.parse_judge_scores(scores) if success else None

        # Check for result image
        result_image = test_dir / "artifacts" / "result.png"
        if not result_image.exists():
            result_image = test_dir / "result.png"
        if not result_image.exists():
            result_image = None

        # Create timing info (not available in legacy format)
        timing = TimingInfo()

        return TestResult(
            test_id=test_id,
            problem_name=self.extract_problem_name(test_dir),
            problem_folder=test_dir,
            run_number=run_number,
            status=status,
            success=success,
            timing=timing,
            result_image_path=result_image,
            shader_artifacts=shader_artifacts,
            judge_scores=judge_scores,
            error=None if success else ErrorInfo(
                stage="unknown",
                error_type="UnknownError",
                message="Test failed (no error details available)",
                full_traceback=None,
                compiler_output=None
            ),
            test_directory=test_dir,
            timestamp=timestamp
        )

    def scan_and_convert(self, test_dirs: List[Path], model_name: str = "unknown",
                        judge_model: str = "unknown", language_spec: str = "wgsl") -> BenchmarkRun:
        """
        Scan test directories and convert to BenchmarkRun

        Args:
            test_dirs: List of test directory paths
            model_name: Name of LLM model used
            judge_model: Name of judge model used
            language_spec: Shader language specification

        Returns:
            BenchmarkRun object with all test results
        """
        # Sort by directory name (chronological order)
        test_dirs = sorted(test_dirs, key=lambda d: d.name)

        # Convert each directory to TestResult
        test_results = []
        for i, test_dir in enumerate(test_dirs):
            result = self.convert_test_directory_to_result(test_dir, run_number=i+1)
            if result:
                test_results.append(result)

        # Calculate summary statistics
        total_tests = len(test_results)
        successful_tests = sum(1 for r in test_results if r.success)
        failed_tests = total_tests - successful_tests

        # Calculate score statistics (for successful tests)
        successful_results = [r for r in test_results if r.success and r.judge_scores]

        average_scores = None
        median_scores = None
        best_test = None
        worst_test = None

        if successful_results:
            # Calculate averages
            avg_s1 = int(sum(r.judge_scores.s1_mathematical_accuracy for r in successful_results) / len(successful_results))
            avg_s2 = int(sum(r.judge_scores.s2_visual_quality for r in successful_results) / len(successful_results))
            avg_s3 = int(sum(r.judge_scores.s3_problem_specific_1 for r in successful_results) / len(successful_results))
            avg_s4 = int(sum(r.judge_scores.s4_problem_specific_2 for r in successful_results) / len(successful_results))
            avg_s5 = int(sum(r.judge_scores.s5_problem_specific_3 for r in successful_results) / len(successful_results))

            average_scores = JudgeScores(avg_s1, avg_s2, avg_s3, avg_s4, avg_s5)

            # Find best and worst
            best_test = max(successful_results, key=lambda r: r.judge_scores.total)
            worst_test = min(successful_results, key=lambda r: r.judge_scores.total)

        # Determine time range
        if test_results:
            start_time = min(r.timestamp for r in test_results)
            end_time = max(r.timestamp for r in test_results)
            total_duration = (end_time - start_time).total_seconds()
        else:
            start_time = end_time = datetime.now()
            total_duration = 0.0

        # Create summary
        summary = BenchmarkSummary(
            model_name=model_name,
            judge_model=judge_model,
            language_spec=language_spec,
            run_id=f"scan_{datetime.now().strftime('%Y%m%d_%H%M%S')}",
            start_time=start_time,
            end_time=end_time,
            total_duration_seconds=total_duration,
            total_tests=total_tests,
            successful_tests=successful_tests,
            failed_tests=failed_tests,
            compile_failures=0,  # Not tracked in legacy format
            render_failures=0,   # Not tracked in legacy format
            judge_failures=0,    # Not tracked in legacy format
            average_scores=average_scores,
            median_scores=median_scores,
            best_test=best_test,
            worst_test=worst_test,
            error_summaries=[]
        )

        return BenchmarkRun(
            summary=summary,
            test_results=test_results
        )


def convert_existing_results_to_benchmark_run(
    test_dirs: List[str],
    model_name: str = "unknown",
    judge_model: str = "unknown",
    language_spec: str = "wgsl"
) -> BenchmarkRun:
    """
    Helper function to convert existing test result directories to BenchmarkRun

    Args:
        test_dirs: List of test directory paths (as strings)
        model_name: Name of LLM model used
        judge_model: Name of judge model used
        language_spec: Shader language specification

    Returns:
        BenchmarkRun object
    """
    scanner = ResultScanner()
    test_paths = [Path(d) for d in test_dirs]
    return scanner.scan_and_convert(test_paths, model_name, judge_model, language_spec)


def integrate_reporting_into_harness():
    """
    Example integration function showing how to add reporting to benchmark_harness.py

    This would be called from BenchmarkHarness.generate_report() method
    """
    # Example usage - this is pseudocode for integration
    #
    # In BenchmarkHarness.generate_report():
    #   1. Collect test directories from self.results
    #   2. Use ResultScanner to convert to BenchmarkRun
    #   3. Pass BenchmarkRun to hiccup renderer
    #   4. Generate HTML and Markdown reports

    pass


if __name__ == "__main__":
    # Demo: Scan current directory for test results
    print("ResultScanner Demo")
    print("=" * 60)

    scanner = ResultScanner()
    test_dirs = scanner.find_test_directories()

    print(f"Found {len(test_dirs)} test directories")

    if test_dirs:
        # Convert first 5 for demo
        demo_dirs = test_dirs[:5]
        benchmark_run = scanner.scan_and_convert(demo_dirs, model_name="demo_model")

        print(f"\nConverted to BenchmarkRun:")
        print(f"  Total tests: {benchmark_run.summary.total_tests}")
        print(f"  Successful: {benchmark_run.summary.successful_tests}")
        print(f"  Failed: {benchmark_run.summary.failed_tests}")

        if benchmark_run.summary.average_scores:
            print(f"  Average total score: {benchmark_run.summary.average_scores.total}/500")
