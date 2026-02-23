"""
Results Collection System for Shader Benchmark Harness

This module provides the data collection layer that organizes test artifacts
into a structured format for the reporting system. It creates the foundational
data structures that Staff Engineer 2 will use for hiccup/renderer implementation.

Architecture:
- ResultsCollector: Main API for collecting test results during harness execution
- Data classes: Typed structures matching CTO's design specification
- File organization: Manages runs/run-NNN-problem_name/ directory structure
- Metadata generation: Creates metadata.json for each test result

Author: Staff Engineer 1
Date: 2025-10-26
Version: 1.0 (Full Implementation)
"""

from dataclasses import dataclass, field, asdict
from pathlib import Path
from typing import Optional, List, Dict, Any
from datetime import datetime
from enum import Enum
import json
import shutil
import uuid


class ExecutionStatus(Enum):
    """Execution status for individual tests"""
    SUCCESS = "success"
    COMPILE_ERROR = "compile_error"
    RENDER_ERROR = "render_error"
    JUDGE_ERROR = "judge_error"
    UNKNOWN_ERROR = "unknown_error"


@dataclass
class TimingInfo:
    """Timing information for pipeline stages"""
    llm_generation_seconds: Optional[float] = None
    compilation_seconds: Optional[float] = None
    render_seconds: Optional[float] = None
    judge_seconds: Optional[float] = None
    total_seconds: Optional[float] = None

    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary for JSON serialization"""
        return {
            k: v for k, v in asdict(self).items() if v is not None
        }


@dataclass
class JudgeScores:
    """5-score judge evaluation (1-100 scale each)"""
    s1_mathematical_accuracy: int  # Generic: Mathematical correctness
    s2_visual_quality: int         # Generic: Rendering quality
    s3_problem_specific_1: int     # Problem-specific section 1
    s4_problem_specific_2: int     # Problem-specific section 2
    s5_problem_specific_3: int     # Problem-specific section 3

    # Score category labels from critic.txt sections
    s3_label: str = "Problem Specific 1"
    s4_label: str = "Problem Specific 2"
    s5_label: str = "Problem Specific 3"

    @property
    def total(self) -> int:
        """Total score (0-500)"""
        return (self.s1_mathematical_accuracy +
                self.s2_visual_quality +
                self.s3_problem_specific_1 +
                self.s4_problem_specific_2 +
                self.s5_problem_specific_3)

    @property
    def average(self) -> float:
        """Average score (0-100)"""
        return self.total / 5.0

    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary for JSON serialization"""
        return {
            "s1_mathematical_accuracy": self.s1_mathematical_accuracy,
            "s2_visual_quality": self.s2_visual_quality,
            "s3_problem_specific_1": self.s3_problem_specific_1,
            "s4_problem_specific_2": self.s4_problem_specific_2,
            "s5_problem_specific_3": self.s5_problem_specific_3,
            "s3_label": self.s3_label,
            "s4_label": self.s4_label,
            "s5_label": self.s5_label,
            "total": self.total,
            "average": self.average
        }


@dataclass
class ErrorInfo:
    """Structured error information"""
    stage: str                      # "llm_generation", "compile", "render", "judge"
    error_type: str                 # Exception class name
    message: str                    # Error message
    full_traceback: Optional[str]   # Complete stack trace
    compiler_output: Optional[str]  # Compiler stderr/stdout if applicable

    def get_error_category(self) -> str:
        """Classify error into broad categories for grouping"""
        if "timeout" in self.message.lower():
            return "Timeout Errors"
        elif "compilation" in self.message.lower() or "syntax" in self.message.lower():
            return "Compilation Errors"
        elif "api" in self.message.lower() or "rate limit" in self.message.lower():
            return "API Errors"
        elif "shader" in self.message.lower() and "execution" in self.message.lower():
            return "Shader Execution Errors"
        elif "judge" in self.message.lower():
            return "Judge Evaluation Errors"
        else:
            return "Other Errors"


@dataclass
class ShaderArtifacts:
    """Shader code and related artifacts"""
    shader_files: Dict[str, str]           # filename -> code content
    main_shader_name: Optional[str]        # Which shader was executed
    language_spec: str                     # "wgsl", "glsl", "shadertoy", etc.
    llm_generated_main_rs: Optional[str]   # Reference only, not compiled


@dataclass
class TestResult:
    """Individual test result with all metadata"""
    # Identification
    test_id: str                          # UUID
    problem_name: str                     # e.g., "geometric_cube"
    problem_folder: Path                  # e.g., ../problems/base_set/geometric_cube
    run_number: int                       # Sequential run number in harness (1-indexed)

    # Execution status
    status: ExecutionStatus
    success: bool                         # Overall success flag

    # Timing information
    timing: TimingInfo

    # Outputs
    result_image_path: Optional[Path]     # Path to result.png (if exists)
    shader_artifacts: ShaderArtifacts

    # Judge evaluation
    judge_scores: Optional[JudgeScores]

    # Error information (if failed)
    error: Optional[ErrorInfo]

    # Test environment
    test_directory: Path                  # Path to test_TIMESTAMP_UUID_results/

    # Metadata
    timestamp: datetime

    @property
    def display_name(self) -> str:
        """Human-readable problem name"""
        return self.problem_name.replace('_', ' ').title()


@dataclass
class ErrorSummary:
    """Grouped error analysis"""
    category: str                         # Error category name
    error_count: int                      # Number of occurrences
    affected_problems: List[str]          # Problem names
    example_message: str                  # Representative error message
    example_traceback: Optional[str]      # Representative stack trace


@dataclass
class BenchmarkSummary:
    """High-level statistics for entire benchmark run"""
    # Run metadata
    model_name: str
    judge_model: str
    language_spec: str
    run_id: str
    start_time: datetime
    end_time: datetime
    total_duration_seconds: float

    # Test counts
    total_tests: int
    successful_tests: int
    failed_tests: int

    # Success breakdown
    compile_failures: int
    render_failures: int
    judge_failures: int

    # Score statistics (for successful tests only)
    average_scores: Optional[JudgeScores]  # Average across all successful tests
    median_scores: Optional[JudgeScores]   # Median scores
    best_test: Optional[TestResult]        # Highest scoring test
    worst_test: Optional[TestResult]       # Lowest scoring test

    # Error analysis
    error_summaries: List[ErrorSummary]

    @property
    def success_rate(self) -> float:
        """Success rate as percentage"""
        if self.total_tests == 0:
            return 0.0
        return (self.successful_tests / self.total_tests) * 100.0


@dataclass
class BenchmarkRun:
    """Complete benchmark run data - root data structure"""
    summary: BenchmarkSummary
    test_results: List[TestResult]        # Sorted by run_number

    # Output paths (populated during report generation)
    output_directory: Optional[Path] = None
    markdown_report_path: Optional[Path] = None
    html_report_path: Optional[Path] = None


class ResultsCollector:
    """
    Collects test results from benchmark harness and organizes them into
    structured data formats and clean directory structure.

    Usage:
        collector = ResultsCollector(run_id="harness_model_timestamp")

        # For each test:
        collector.add_test_result(
            problem_name="geometric_cube",
            run_number=1,
            success=True,
            shader_code={"main.wgsl": "..."},
            image_path=Path("test_xxx/artifacts/result.png"),
            error_log=None,
            scores=[85, 72, 91, 67, 88],
            timings={"total": 7.23},
            test_dir=Path("test_xxx_results")
        )

        # Generate final benchmark run object
        benchmark_run = collector.finalize(
            model_name="anthropic/claude-3.5-sonnet",
            judge_model="anthropic/claude-opus-4.5",
            language_spec="wgsl",
            start_time=...,
            end_time=...
        )
    """

    def __init__(self, run_id: str):
        """
        Initialize results collector.

        Args:
            run_id: Unique run identifier (e.g., "harness_model_timestamp")
        """
        self.run_id = run_id
        self.test_results: List[TestResult] = []

        # Create output directory structure
        self.output_dir = Path(run_id)
        self.output_dir.mkdir(parents=True, exist_ok=True)

        self.runs_dir = self.output_dir / "runs"
        self.runs_dir.mkdir(exist_ok=True)

        self.images_dir = self.output_dir / "images"
        self.images_dir.mkdir(exist_ok=True)

    def add_test_result(
        self,
        problem_name: str,
        run_number: int,
        success: bool,
        shader_code: Dict[str, str],
        image_path: Optional[Path],
        error_log: Optional[str],
        scores: Optional[List[int]],
        timings: Dict[str, float],
        test_dir: Path,
        language_spec: str = "wgsl",
        main_shader_name: Optional[str] = None,
        llm_generated_main_rs: Optional[str] = None
    ):
        """
        Add a test result to the collection and copy artifacts to organized structure.

        Args:
            problem_name: Name of the problem (e.g., "geometric_cube")
            run_number: Sequential run number (1-indexed)
            success: Whether test succeeded overall
            shader_code: Dict of filename -> shader code content
            image_path: Path to result.png (if exists)
            error_log: Error message/traceback if failed
            scores: List of 5 scores [s1, s2, s3, s4, s5] (None if failed)
            timings: Dict with timing info (keys: total, llm_generation, etc.)
            test_dir: Path to original test directory
            language_spec: Shader language ("wgsl", "glsl", etc.)
            main_shader_name: Name of main shader file executed
            llm_generated_main_rs: Content of LLM-generated main.rs (if any)
        """
        # Generate test ID from test directory name or UUID
        test_id = test_dir.name.replace('test_', '').replace('_results', '')
        if not test_id:
            test_id = str(uuid.uuid4())

        # Get problem folder path (absolute)
        script_dir = Path(__file__).parent.absolute()
        problem_folder = script_dir.parent / "problems" / "base_set" / problem_name

        # Determine execution status
        if success:
            status = ExecutionStatus.SUCCESS
        else:
            # Parse error message to determine failure stage
            error_lower = error_log.lower() if error_log else ""
            if 'compile' in error_lower or 'syntax' in error_lower:
                status = ExecutionStatus.COMPILE_ERROR
            elif 'render' in error_lower or 'shader' in error_lower:
                status = ExecutionStatus.RENDER_ERROR
            elif 'judge' in error_lower or 'evaluation' in error_lower:
                status = ExecutionStatus.JUDGE_ERROR
            else:
                status = ExecutionStatus.UNKNOWN_ERROR

        # Create timing info
        timing = TimingInfo(
            llm_generation_seconds=timings.get('llm_generation'),
            compilation_seconds=timings.get('compilation'),
            render_seconds=timings.get('render'),
            judge_seconds=timings.get('judge'),
            total_seconds=timings.get('total')
        )

        # Create judge scores (if available)
        judge_scores = None
        if success and scores and len(scores) >= 5:
            judge_scores = JudgeScores(
                s1_mathematical_accuracy=scores[0],
                s2_visual_quality=scores[1],
                s3_problem_specific_1=scores[2],
                s4_problem_specific_2=scores[3],
                s5_problem_specific_3=scores[4],
                # TODO: Extract labels from critic.txt sections
                s3_label="Problem Specific 1",
                s4_label="Problem Specific 2",
                s5_label="Problem Specific 3"
            )

        # Create error info (if failed)
        error_info = None
        if not success and error_log:
            error_info = ErrorInfo(
                stage=status.value.replace('_error', ''),
                error_type="RuntimeError",  # TODO: Extract actual exception type
                message=error_log[:1000],  # Truncate very long errors
                full_traceback=error_log,
                compiler_output=None  # TODO: Extract from error.log if available
            )

        # Create shader artifacts
        shader_artifacts = ShaderArtifacts(
            shader_files=shader_code,
            main_shader_name=main_shader_name,
            language_spec=language_spec,
            llm_generated_main_rs=llm_generated_main_rs
        )

        # Create test result object
        test_result = TestResult(
            test_id=test_id,
            problem_name=problem_name,
            problem_folder=problem_folder,
            run_number=run_number,
            status=status,
            success=success,
            timing=timing,
            result_image_path=image_path,
            shader_artifacts=shader_artifacts,
            judge_scores=judge_scores,
            error=error_info,
            test_directory=test_dir,
            timestamp=datetime.now()  # TODO: Extract from test_dir metadata
        )

        # Copy artifacts to organized structure
        self.copy_artifacts(test_dir, run_number, problem_name, test_result)

        # Generate and save metadata JSON
        self.generate_metadata(test_result)

        # Add to collection
        self.test_results.append(test_result)

    def copy_artifacts(
        self,
        test_dir: Path,
        run_number: int,
        problem_name: str,
        test_result: TestResult
    ):
        """
        Copy test artifacts to organized runs/run-NNN-problem_name/ structure.

        Creates:
        - runs/run-NNN-problem_name/result.png (if exists)
        - runs/run-NNN-problem_name/*.wgsl (shader files)
        - runs/run-NNN-problem_name/error.log (if failed)
        - images/run-NNN.png (symlink to result.png)

        Args:
            test_dir: Source test directory
            run_number: Sequential run number
            problem_name: Problem name
            test_result: TestResult object with metadata
        """
        # Create run directory
        run_name = f"run-{run_number:03d}-{problem_name}"
        run_dir = self.runs_dir / run_name
        run_dir.mkdir(exist_ok=True)

        # Copy result image if exists
        if test_result.result_image_path and test_result.result_image_path.exists():
            dest_image = run_dir / "result.png"
            shutil.copy2(test_result.result_image_path, dest_image)

            # Create symlink in images/ for easy access
            symlink_path = self.images_dir / f"run-{run_number:03d}.png"
            if symlink_path.exists():
                symlink_path.unlink()
            try:
                # Create relative symlink
                symlink_path.symlink_to(f"../runs/{run_name}/result.png")
            except OSError:
                # If symlinks not supported, copy instead
                shutil.copy2(dest_image, symlink_path)

        # Copy shader files from test_dir/shaders/
        shader_dir = test_dir / "shaders"
        if shader_dir.exists():
            for shader_file in shader_dir.iterdir():
                if shader_file.is_file():
                    dest_shader = run_dir / shader_file.name
                    shutil.copy2(shader_file, dest_shader)

        # Copy LLM-generated main.rs reference if exists
        llm_main_rs = test_dir / "llm_generated_main_rs_reference.txt"
        if llm_main_rs.exists():
            shutil.copy2(llm_main_rs, run_dir / "llm_generated_main_rs_reference.txt")

        # Write error.log if test failed
        if test_result.error and test_result.error.full_traceback:
            error_log_path = run_dir / "error.log"
            with open(error_log_path, 'w') as f:
                f.write(f"Stage: {test_result.error.stage}\n")
                f.write(f"Type: {test_result.error.error_type}\n")
                f.write(f"Message: {test_result.error.message}\n\n")
                f.write("Full Traceback:\n")
                f.write(test_result.error.full_traceback)

                if test_result.error.compiler_output:
                    f.write("\n\nCompiler Output:\n")
                    f.write(test_result.error.compiler_output)

    def generate_metadata(self, test_result: TestResult):
        """
        Generate metadata.json for a test result.

        Creates runs/run-NNN-problem_name/metadata.json with:
        - Test identification (test_id, run_number, problem_name)
        - Execution status and timestamp
        - Timing information
        - Judge scores (if available)
        - Shader artifacts info
        - Error info (if failed)

        Args:
            test_result: TestResult object with all metadata
        """
        run_name = f"run-{test_result.run_number:03d}-{test_result.problem_name}"
        run_dir = self.runs_dir / run_name

        # Build metadata dict
        metadata = {
            "test_id": test_result.test_id,
            "run_number": test_result.run_number,
            "problem_name": test_result.problem_name,
            "status": test_result.status.value,
            "timestamp": test_result.timestamp.isoformat(),
            "timing": test_result.timing.to_dict(),
            "judge_scores": None,
            "shader_artifacts": {
                "language_spec": test_result.shader_artifacts.language_spec,
                "main_shader_name": test_result.shader_artifacts.main_shader_name,
                "shader_files": list(test_result.shader_artifacts.shader_files.keys())
            },
            "error": None
        }

        # Add judge scores if available
        if test_result.judge_scores:
            metadata["judge_scores"] = test_result.judge_scores.to_dict()

        # Add error info if failed
        if test_result.error:
            metadata["error"] = {
                "stage": test_result.error.stage,
                "error_type": test_result.error.error_type,
                "message": test_result.error.message
            }

        # Write metadata.json
        metadata_path = run_dir / "metadata.json"
        with open(metadata_path, 'w') as f:
            json.dump(metadata, f, indent=2)

    def finalize(
        self,
        model_name: str,
        judge_model: str,
        language_spec: str,
        start_time: datetime,
        end_time: datetime
    ) -> BenchmarkRun:
        """
        Finalize collection and generate complete BenchmarkRun object.

        Calculates summary statistics, groups errors, and creates the final
        data structure ready for report generation.

        Args:
            model_name: LLM model name
            judge_model: Judge model name
            language_spec: Shader language specification
            start_time: Benchmark start time
            end_time: Benchmark end time

        Returns:
            Complete BenchmarkRun object with summary and test results
        """
        # Sort test results by run number
        self.test_results.sort(key=lambda t: t.run_number)

        # Calculate summary statistics
        successful = [t for t in self.test_results if t.success]
        failed = [t for t in self.test_results if not t.success]

        # Calculate average scores (only successful tests)
        average_scores = None
        if successful:
            score_sums = [0, 0, 0, 0, 0]
            for test in successful:
                if test.judge_scores:
                    score_sums[0] += test.judge_scores.s1_mathematical_accuracy
                    score_sums[1] += test.judge_scores.s2_visual_quality
                    score_sums[2] += test.judge_scores.s3_problem_specific_1
                    score_sums[3] += test.judge_scores.s4_problem_specific_2
                    score_sums[4] += test.judge_scores.s5_problem_specific_3

            average_scores = JudgeScores(
                s1_mathematical_accuracy=int(score_sums[0] / len(successful)),
                s2_visual_quality=int(score_sums[1] / len(successful)),
                s3_problem_specific_1=int(score_sums[2] / len(successful)),
                s4_problem_specific_2=int(score_sums[3] / len(successful)),
                s5_problem_specific_3=int(score_sums[4] / len(successful))
            )

        # Find best/worst tests
        best_test = None
        worst_test = None
        if successful:
            best_test = max(successful, key=lambda t: t.judge_scores.total if t.judge_scores else 0)
            worst_test = min(successful, key=lambda t: t.judge_scores.total if t.judge_scores else 0)

        # Group errors by category
        error_summaries = self._build_error_summaries(failed)

        # Count stage-specific failures
        compile_failures = sum(1 for t in failed if t.status == ExecutionStatus.COMPILE_ERROR)
        render_failures = sum(1 for t in failed if t.status == ExecutionStatus.RENDER_ERROR)
        judge_failures = sum(1 for t in failed if t.status == ExecutionStatus.JUDGE_ERROR)

        # Create summary
        summary = BenchmarkSummary(
            model_name=model_name,
            judge_model=judge_model,
            language_spec=language_spec,
            run_id=self.run_id,
            start_time=start_time,
            end_time=end_time,
            total_duration_seconds=(end_time - start_time).total_seconds(),
            total_tests=len(self.test_results),
            successful_tests=len(successful),
            failed_tests=len(failed),
            compile_failures=compile_failures,
            render_failures=render_failures,
            judge_failures=judge_failures,
            average_scores=average_scores,
            median_scores=None,  # TODO: Calculate median
            best_test=best_test,
            worst_test=worst_test,
            error_summaries=error_summaries
        )

        # Write summary.json
        self._write_summary_json(summary)

        # Create and return BenchmarkRun
        return BenchmarkRun(
            summary=summary,
            test_results=self.test_results,
            output_directory=self.output_dir,
            markdown_report_path=None,  # Set by report generator
            html_report_path=None  # Set by report generator
        )

    def _build_error_summaries(self, failed_tests: List[TestResult]) -> List[ErrorSummary]:
        """
        Group errors by category for summary.

        Args:
            failed_tests: List of failed TestResult objects

        Returns:
            List of ErrorSummary objects grouped by category
        """
        error_groups: Dict[str, List[TestResult]] = {}

        for test in failed_tests:
            if test.error:
                category = test.error.get_error_category()
                if category not in error_groups:
                    error_groups[category] = []
                error_groups[category].append(test)

        # Build ErrorSummary objects
        summaries = []
        for category, tests in error_groups.items():
            example_test = tests[0]
            summaries.append(ErrorSummary(
                category=category,
                error_count=len(tests),
                affected_problems=[t.problem_name for t in tests],
                example_message=example_test.error.message if example_test.error else "",
                example_traceback=example_test.error.full_traceback if example_test.error else None
            ))

        return summaries

    def _write_summary_json(self, summary: BenchmarkSummary):
        """
        Write machine-readable summary.json.

        Args:
            summary: BenchmarkSummary object
        """
        data = {
            "model_name": summary.model_name,
            "judge_model": summary.judge_model,
            "language_spec": summary.language_spec,
            "run_id": summary.run_id,
            "start_time": summary.start_time.isoformat(),
            "end_time": summary.end_time.isoformat(),
            "total_duration_seconds": summary.total_duration_seconds,
            "total_tests": summary.total_tests,
            "successful_tests": summary.successful_tests,
            "failed_tests": summary.failed_tests,
            "compile_failures": summary.compile_failures,
            "render_failures": summary.render_failures,
            "judge_failures": summary.judge_failures,
            "success_rate": summary.success_rate,
            "average_scores": None,
            "best_test": None,
            "worst_test": None,
            "error_summaries": []
        }

        if summary.average_scores:
            data["average_scores"] = summary.average_scores.to_dict()

        if summary.best_test:
            data["best_test"] = {
                "run_number": summary.best_test.run_number,
                "problem_name": summary.best_test.problem_name,
                "total_score": summary.best_test.judge_scores.total if summary.best_test.judge_scores else 0
            }

        if summary.worst_test:
            data["worst_test"] = {
                "run_number": summary.worst_test.run_number,
                "problem_name": summary.worst_test.problem_name,
                "total_score": summary.worst_test.judge_scores.total if summary.worst_test.judge_scores else 0
            }

        for error_summary in summary.error_summaries:
            data["error_summaries"].append({
                "category": error_summary.category,
                "error_count": error_summary.error_count,
                "affected_problems": error_summary.affected_problems
            })

        summary_path = self.output_dir / "summary.json"
        with open(summary_path, 'w') as f:
            json.dump(data, f, indent=2)
