"""
Integration Example: Using ResultsCollector with BenchmarkHarness

This file demonstrates how to integrate ResultsCollector into benchmark_harness.py
to collect results and generate the BenchmarkRun data structure.

Author: Staff Engineer 1
Date: 2025-10-26
"""

from results_collector import ResultsCollector
from pathlib import Path
from datetime import datetime

def integration_example():
    """
    Example showing how benchmark_harness.py should use ResultsCollector.

    KEY INTEGRATION POINTS:
    1. Initialize ResultsCollector in BenchmarkHarness.__init__()
    2. Call collector.add_test_result() after each problem completes
    3. Call collector.finalize() to get BenchmarkRun object
    4. Pass BenchmarkRun to report generator (Staff Engineer 2's work)
    """

    # Step 1: Initialize collector (in BenchmarkHarness.__init__)
    run_id = "harness_anthropic_claude-3.5-sonnet_20251026_143022"
    collector = ResultsCollector(run_id=run_id)

    # Step 2: For each test that completes, add result
    # This would be called at the end of BenchmarkHarness.run_single_problem()

    # Example 1: Successful test with scores
    collector.add_test_result(
        problem_name="geometric_cube",
        run_number=1,
        success=True,
        shader_code={
            "main.wgsl": "// WGSL shader code here...",
            "utils.wgsl": "// Utility functions..."
        },
        image_path=Path("test_20251026_143025_abc123_results/artifacts/result.png"),
        error_log=None,
        scores=[85, 72, 91, 67, 88],  # [s1, s2, s3, s4, s5]
        timings={
            "total": 7.23,
            "llm_generation": 2.34,
            "compilation": 0.0,
            "render": 1.45,
            "judge": 3.21
        },
        test_dir=Path("test_20251026_143025_abc123_results"),
        language_spec="wgsl",
        main_shader_name="main.wgsl",
        llm_generated_main_rs="// LLM-generated main.rs content..."
    )

    # Example 2: Failed test (render error)
    collector.add_test_result(
        problem_name="parametric_surface",
        run_number=2,
        success=False,
        shader_code={
            "main.wgsl": "// Shader with error..."
        },
        image_path=None,
        error_log="Shader execution failed: naga::front::wgsl::ParseError...",
        scores=None,
        timings={
            "total": 4.12,
            "llm_generation": 2.1,
            "compilation": 0.0,
            "render": 0.0,
            "judge": 0.0
        },
        test_dir=Path("test_20251026_143035_def456_results"),
        language_spec="wgsl",
        main_shader_name="main.wgsl"
    )

    # Step 3: Finalize and get BenchmarkRun object
    # This would be called in BenchmarkHarness.run_benchmark() after all tests complete
    start_time = datetime(2025, 10, 26, 14, 30, 22)
    end_time = datetime(2025, 10, 26, 14, 45, 33)

    benchmark_run = collector.finalize(
        model_name="anthropic/claude-3.5-sonnet",
        judge_model="anthropic/claude-opus-4.5",
        language_spec="wgsl",
        start_time=start_time,
        end_time=end_time
    )

    # Step 4: Pass to report generator (Staff Engineer 2's implementation)
    # from report_generator import generate_reports
    # generate_reports(benchmark_run)

    print(f"BenchmarkRun created:")
    print(f"  - Run ID: {benchmark_run.summary.run_id}")
    print(f"  - Total tests: {benchmark_run.summary.total_tests}")
    print(f"  - Successful: {benchmark_run.summary.successful_tests}")
    print(f"  - Failed: {benchmark_run.summary.failed_tests}")
    print(f"  - Output directory: {benchmark_run.output_directory}")

    # Artifacts are already organized:
    # harness_anthropic_claude-3.5-sonnet_20251026_143022/
    #   runs/
    #     run-001-geometric_cube/
    #       result.png
    #       main.wgsl
    #       utils.wgsl
    #       metadata.json
    #     run-002-parametric_surface/
    #       main.wgsl
    #       error.log
    #       metadata.json
    #   images/
    #     run-001.png -> ../runs/run-001-geometric_cube/result.png
    #   summary.json

    return benchmark_run


def benchmark_harness_modifications():
    """
    Detailed modifications needed in benchmark_harness.py

    MODIFICATIONS REQUIRED:

    1. In BenchmarkHarness.__init__():
       Add:
           from results_collector import ResultsCollector
           self.results_collector = ResultsCollector(run_id=self.run_id)

    2. In BenchmarkHarness.run_single_problem():
       After test completes (success or failure), add:

           # Extract shader code from test directory
           shader_code = {}
           shader_dir = test_folder / "shaders"
           if shader_dir.exists():
               for shader_file in shader_dir.iterdir():
                   if shader_file.is_file():
                       shader_code[shader_file.name] = shader_file.read_text()

           # Extract main_rs if exists
           llm_main_rs = None
           llm_main_rs_file = test_folder / "llm_generated_main_rs_reference.txt"
           if llm_main_rs_file.exists():
               llm_main_rs = llm_main_rs_file.read_text()

           # Add result to collector
           self.results_collector.add_test_result(
               problem_name=problem,
               run_number=problem_index + 1,  # 1-indexed
               success=result['success'],
               shader_code=shader_code,
               image_path=result.get('image_path'),
               error_log=result.get('error'),
               scores=result.get('scores'),
               timings={'total': result.get('execution_time')},
               test_dir=test_folder,
               language_spec=self.language,
               main_shader_name=None,  # TODO: Track which shader was executed
               llm_generated_main_rs=llm_main_rs
           )

    3. In BenchmarkHarness.run_benchmark():
       After all tests complete, replace generate_report() with:

           # Finalize results collection
           benchmark_run = self.results_collector.finalize(
               model_name=self.model,
               judge_model=self.judge_model,
               language_spec=self.language,
               start_time=self.start_time,
               end_time=self.end_time
           )

           # TODO: Call Staff Engineer 2's report generator
           # from report_generator import generate_reports
           # generate_reports(benchmark_run)

           return benchmark_run
    """
    pass


if __name__ == "__main__":
    print("ResultsCollector Integration Example\n")
    print("=" * 60)
    benchmark_run = integration_example()
    print("\n" + "=" * 60)
    print("\nIntegration successful!")
    print(f"Check output directory: {benchmark_run.output_directory}")
