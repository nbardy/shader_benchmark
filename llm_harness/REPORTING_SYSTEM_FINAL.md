# Shader Benchmark Reporting System - Final Documentation

**Version:** 1.0
**Date:** 2025-10-26
**Status:** Design Complete, Implementation Partial (Stub Phase)

---

## Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Quick Start Guide](#quick-start-guide)
4. [API Reference](#api-reference)
5. [Migration Guide](#migration-guide)
6. [Example Workflows](#example-workflows)
7. [File Organization](#file-organization)
8. [Troubleshooting](#troubleshooting)

---

## Overview

### What is the Reporting System?

The Shader Benchmark Reporting System consolidates scattered test results into unified, professional reports. It generates both Markdown and HTML reports with embedded images, shader code, error diagnostics, and judge scores.

### Key Features

- **Unified Reports**: Single directory containing all test artifacts and reports
- **Multiple Formats**: Markdown (for GitHub/docs) and HTML (with navigation) from same data
- **Type-Safe Data**: Python dataclasses ensure correct data handling
- **Hiccup Architecture**: Functional-style markup generation for maintainability
- **Self-Contained**: Embedded images and organized file structure
- **Score Tracking**: Full 5-score system (1-100 scale, /500 total)

### Current Implementation Status

| Component | Status | Notes |
|-----------|--------|-------|
| Data Structures | ✅ Defined | Complete dataclasses in `results_collector.py` |
| Results Collector | 🟡 Stub | Basic structure exists, needs full implementation |
| Hiccup System | ❌ Not Started | Design complete, implementation pending |
| Markdown Renderer | 🟡 Stub | Minimal implementation exists |
| HTML Renderer | 🟡 Stub | Minimal implementation exists |
| Harness Integration | ❌ Not Started | Old system still active |

**Legend:**
- ✅ Complete and tested
- 🟡 Stub/partial implementation
- ❌ Not yet implemented

---

## Architecture

### System Overview

```
┌─────────────────────────────────────────────────────────┐
│                  Benchmark Harness                       │
│  (benchmark_harness.py - runs tests, collects results)  │
└────────────────────┬────────────────────────────────────┘
                     │
                     ▼
          ┌──────────────────────┐
          │  Results Collector   │
          │ (results_collector.py)│
          │                      │
          │  • Scans test dirs   │
          │  • Builds typed data │
          │  • Calculates stats  │
          └──────────┬───────────┘
                     │
                     ▼
              ┌─────────────┐
              │ BenchmarkRun│ (typed data structure)
              └──────┬──────┘
                     │
                     ▼
          ┌──────────────────────┐
          │  Hiccup Builder      │
          │  (NOT YET CREATED)   │
          │                      │
          │  • Build markup tree │
          │  • Single source     │
          └──────┬───────────────┘
                 │
          ┌──────┴──────┐
          ▼             ▼
    ┌──────────┐  ┌──────────┐
    │ Markdown │  │   HTML   │
    │ Renderer │  │ Renderer │
    │          │  │          │
    │ (stub)   │  │  (stub)  │
    └────┬─────┘  └─────┬────┘
         │              │
         ▼              ▼
    all.md          all.html
```

### Core Principles

1. **Hiccup-Like Data Structures**: Markup represented as nested Python lists/dicts
2. **Single Source of Truth**: Typed dataclasses for all test data
3. **Multiple Output Formats**: MD and HTML from same hiccup structure
4. **Self-Contained Outputs**: Organized file structure with embedded images

### Data Flow

```
Test Results (scattered)
    → ResultsCollector
    → BenchmarkRun (typed)
    → Hiccup Structure (markup data)
    → Renderers (MD/HTML)
    → Final Reports (all.md, all.html)
```

---

## Quick Start Guide

### For Users: Generating Reports

**Current State (Legacy System):**

```bash
cd llm_harness

# Generate report from existing harness run
python generate_report.py --model "anthropic/claude-3.5-sonnet" \
                          --harness-dir "harness_anthropic_claude-3.5-sonnet_20251026_143022"
```

**Future State (New System - Not Yet Available):**

```bash
# Will be integrated into benchmark harness automatically
python benchmark_harness.py --model "..." --problems base_set/
# Report generated automatically at end of run
```

### For Developers: Understanding the Code

**Reading the Data Structures:**

```python
from results_collector import BenchmarkRun, TestResult, JudgeScores

# Load a benchmark run (future implementation)
# benchmark = load_benchmark_run("harness_...")

# Access summary statistics
# print(f"Success Rate: {benchmark.summary.success_rate}%")
# print(f"Average Score: {benchmark.summary.average_scores.average}/100")

# Iterate through test results
# for test in benchmark.test_results:
#     print(f"{test.run_number}. {test.display_name}")
#     if test.judge_scores:
#         print(f"   Score: {test.judge_scores.total}/500")
```

**Stub Renderer Example:**

```python
from results_collector import BenchmarkRun
from report_renderer import render_to_files
from pathlib import Path

# Build or load BenchmarkRun
# benchmark = ...

# Generate reports (stub implementation)
output_dir = Path("harness_output")
md_path, html_path = render_to_files(benchmark, output_dir)

print(f"Markdown: {md_path}")
print(f"HTML: {html_path}")
```

---

## API Reference

### Data Structures (results_collector.py)

#### ExecutionStatus (Enum)

```python
class ExecutionStatus(Enum):
    SUCCESS = "success"
    COMPILE_ERROR = "compile_error"
    RENDER_ERROR = "render_error"
    JUDGE_ERROR = "judge_error"
    UNKNOWN_ERROR = "unknown_error"
```

#### TimingInfo

```python
@dataclass
class TimingInfo:
    llm_generation_seconds: Optional[float] = None
    compilation_seconds: Optional[float] = None
    render_seconds: Optional[float] = None
    judge_seconds: Optional[float] = None
    total_seconds: Optional[float] = None

    def to_dict(self) -> Dict[str, Any]: ...
```

#### JudgeScores

```python
@dataclass
class JudgeScores:
    s1_mathematical_accuracy: int   # 1-100
    s2_visual_quality: int          # 1-100
    s3_problem_specific_1: int      # 1-100
    s4_problem_specific_2: int      # 1-100
    s5_problem_specific_3: int      # 1-100

    s3_label: str = "Problem Specific 1"
    s4_label: str = "Problem Specific 2"
    s5_label: str = "Problem Specific 3"

    @property
    def total(self) -> int:         # 0-500
        """Total score across all categories"""

    @property
    def average(self) -> float:     # 0-100
        """Average score (total / 5)"""

    def to_dict(self) -> Dict[str, Any]: ...
```

#### ErrorInfo

```python
@dataclass
class ErrorInfo:
    stage: str                      # "llm_generation", "compile", "render", "judge"
    error_type: str                 # Exception class name
    message: str                    # Error message
    full_traceback: Optional[str]   # Complete stack trace
    compiler_output: Optional[str]  # Compiler stderr/stdout if applicable

    def get_error_category(self) -> str:
        """Classify error into broad categories"""
```

#### ShaderArtifacts

```python
@dataclass
class ShaderArtifacts:
    shader_files: Dict[str, str]           # filename -> code content
    main_shader_name: Optional[str]        # Which shader was executed
    language_spec: str                     # "wgsl", "glsl", "shadertoy", etc.
    llm_generated_main_rs: Optional[str]   # Reference only
```

#### TestResult

```python
@dataclass
class TestResult:
    # Identification
    test_id: str                          # UUID
    problem_name: str                     # e.g., "geometric_cube"
    problem_folder: Path                  # Path to problem in base_set
    run_number: int                       # Sequential (1-indexed)

    # Execution
    status: ExecutionStatus
    success: bool

    # Timing
    timing: TimingInfo

    # Outputs
    result_image_path: Optional[Path]
    shader_artifacts: ShaderArtifacts

    # Evaluation
    judge_scores: Optional[JudgeScores]

    # Error
    error: Optional[ErrorInfo]

    # Environment
    test_directory: Path
    timestamp: datetime

    @property
    def display_name(self) -> str:
        """Human-readable problem name"""
```

#### ErrorSummary

```python
@dataclass
class ErrorSummary:
    category: str                         # Error category name
    error_count: int                      # Number of occurrences
    affected_problems: List[str]          # Problem names
    example_message: str                  # Representative error
    example_traceback: Optional[str]
```

#### BenchmarkSummary

```python
@dataclass
class BenchmarkSummary:
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

    # Failure breakdown
    compile_failures: int
    render_failures: int
    judge_failures: int

    # Score statistics (successful tests only)
    average_scores: Optional[JudgeScores]
    median_scores: Optional[JudgeScores]
    best_test: Optional[TestResult]
    worst_test: Optional[TestResult]

    # Error analysis
    error_summaries: List[ErrorSummary]

    @property
    def success_rate(self) -> float:
        """Success rate as percentage"""
```

#### BenchmarkRun

```python
@dataclass
class BenchmarkRun:
    summary: BenchmarkSummary
    test_results: List[TestResult]        # Sorted by run_number

    # Output paths (populated during report generation)
    output_directory: Optional[Path] = None
    markdown_report_path: Optional[Path] = None
    html_report_path: Optional[Path] = None
```

### Renderers (report_renderer.py - STUB)

#### generate_report()

```python
def generate_report(benchmark: BenchmarkRun) -> Tuple[str, str]:
    """
    Generate both Markdown and HTML reports from BenchmarkRun

    STUB: Returns minimal report strings for testing

    Args:
        benchmark: Complete benchmark run data

    Returns:
        Tuple of (markdown_content, html_content)
    """
```

#### render_to_files()

```python
def render_to_files(benchmark: BenchmarkRun, output_dir: Path) -> Tuple[Path, Path]:
    """
    Generate and write reports to files

    Args:
        benchmark: Complete benchmark run data
        output_dir: Directory to write reports

    Returns:
        Tuple of (markdown_path, html_path)
    """
```

### Results Collection (results_collector.py - STUB)

#### ResultsCollector

```python
class ResultsCollector:
    """Collects results during benchmark execution (STUB)"""

    def __init__(self, run_id: str): ...

    def add_result(self, result: Dict[str, Any]):
        """Add a test result"""

    def finalize(self, model: str, judge_model: str, language: str,
                 start_time: datetime, end_time: datetime) -> BenchmarkRun:
        """Build final BenchmarkRun from collected results (STUB)"""
```

---

## Migration Guide

### Current State vs Future State

| Aspect | Current (Legacy) | Future (New System) |
|--------|------------------|---------------------|
| Report Format | Markdown only | Markdown + HTML |
| File Organization | Scattered test directories | Unified `runs/` structure |
| Data Handling | Untyped dicts | Typed dataclasses |
| Rendering | Direct markdown generation | Hiccup → multiple formats |
| Navigation | None | HTML with sidebar |
| Integration | Separate script | Built into harness |

### Migration Path

**Phase 1: Compatibility (Current)**
- Old system remains default
- New system components being developed
- Both systems can coexist

**Phase 2: Testing (Future)**
- Run both systems side-by-side
- Validate output equivalence
- Gather user feedback

**Phase 3: Transition (Future)**
- New system becomes default
- Old system available via `--legacy-report` flag
- Documentation updated

**Phase 4: Deprecation (Future)**
- Remove old system after validation period
- Archive old code for reference

### What Users Need to Do

**Current (No Action Required):**
- Continue using existing workflows
- Reports generated by `generate_report.py`

**When New System Launches:**
1. Test new system with `--new-report` flag
2. Compare output with legacy reports
3. Report any issues or discrepancies
4. Switch to new system when comfortable

**Breaking Changes (Future):**
- Directory structure will change (documented migration)
- HTML reports require modern browser (IE not supported)
- Symlinks in `images/` may not work on Windows (copies available)

---

## Example Workflows

### Workflow 1: Run Benchmark and Generate Report

```bash
# Run benchmark harness
cd llm_harness
python benchmark_harness.py \
    --model "anthropic/claude-3.5-sonnet" \
    --problems ../problems/base_set/ \
    --max-parallel 10

# Report automatically generated in:
# harness_anthropic_claude-3.5-sonnet_TIMESTAMP/
#   ├── all.md       (Markdown report - future)
#   ├── all.html     (HTML report - future)
#   └── runs/        (Organized test artifacts - future)
```

### Workflow 2: Regenerate Report from Existing Results

**Current (Legacy):**

```bash
python generate_report.py \
    --model "anthropic/claude-3.5-sonnet" \
    --harness-dir "harness_anthropic_claude-3.5-sonnet_20251026_143022"
```

**Future (New System):**

```bash
# Will support regenerating reports from existing data
python regenerate_report.py \
    --harness-dir "harness_anthropic_claude-3.5-sonnet_20251026_143022"
```

### Workflow 3: Compare Two Benchmark Runs

**Future Feature:**

```bash
# Compare two runs
python compare_runs.py \
    --run1 "harness_claude-sonnet_20251026_143022" \
    --run2 "harness_claude-haiku_20251026_150033" \
    --output "comparison_report.md"
```

### Workflow 4: Extract Specific Test Results

**Using Python API (Future):**

```python
from results_collector import BenchmarkRun
from pathlib import Path
import json

# Load benchmark run
run_dir = Path("harness_anthropic_claude-3.5-sonnet_20251026_143022")
summary_file = run_dir / "summary.json"

with open(summary_file, 'r') as f:
    summary_data = json.load(f)

print(f"Model: {summary_data['model_name']}")
print(f"Success Rate: {summary_data['success_rate']}%")
print(f"Average Score: {summary_data['average_scores']['average']}/100")

# Find best performing test
best = summary_data['best_test']
print(f"\nBest Test: {best['problem_name']}")
print(f"Score: {best['total_score']}/500")
```

---

## File Organization

### Output Directory Structure

```
harness_MODEL_TIMESTAMP/
├── all.md                          # Markdown report (future)
├── all.html                        # HTML report with navigation (future)
├── runs/                           # Individual test artifacts (future)
│   ├── run-001-geometric_cube/
│   │   ├── result.png              # Final rendered image
│   │   ├── main.wgsl               # Main shader
│   │   ├── metadata.json           # Test metadata
│   │   └── error.log               # Full stack trace if failed
│   ├── run-002-parametric_surface/
│   └── run-NNN-problem_name/
├── images/                         # Symlinks for easy access (future)
│   ├── run-001.png -> runs/run-001-geometric_cube/result.png
│   └── run-002.png -> runs/run-002-parametric_surface/result.png
├── summary.json                    # Machine-readable summary (future)
└── checkpoints/                    # Checkpoint data (current)
    └── manifest.json
```

### Current Structure (Legacy)

```
harness_MODEL_TIMESTAMP/
├── harness_report_MODEL_TIMESTAMP.md   # Current report
├── checkpoints/
│   └── manifest.json
└── (test directories scattered outside harness dir)

test_TIMESTAMP_UUID_results/
├── result.png
├── results.json
└── shaders/
    └── main.wgsl
```

### Metadata JSON Format (Future)

**Per-Test Metadata** (`runs/run-NNN-problem/metadata.json`):

```json
{
  "test_id": "uuid-string",
  "run_number": 1,
  "problem_name": "geometric_cube",
  "status": "success",
  "timestamp": "2025-10-26T14:30:22.123456",
  "timing": {
    "llm_generation_seconds": 2.34,
    "compilation_seconds": 0.0,
    "render_seconds": 1.45,
    "judge_seconds": 3.21,
    "total_seconds": 7.00
  },
  "judge_scores": {
    "s1_mathematical_accuracy": 85,
    "s2_visual_quality": 72,
    "s3_problem_specific_1": 91,
    "s4_problem_specific_2": 67,
    "s5_problem_specific_3": 88,
    "total": 403,
    "average": 80.6
  },
  "shader_artifacts": {
    "language_spec": "wgsl",
    "main_shader_name": "main.wgsl",
    "shader_files": ["main.wgsl"]
  },
  "error": null
}
```

**Summary JSON** (`summary.json`):

```json
{
  "model_name": "anthropic/claude-3.5-sonnet",
  "judge_model": "anthropic/claude-3.5-haiku",
  "language_spec": "wgsl",
  "run_id": "harness_anthropic_claude-3.5-sonnet_20251026_143022",
  "total_tests": 100,
  "successful_tests": 87,
  "success_rate": 87.0,
  "average_scores": {
    "average": 78.9
  },
  "best_test": {
    "run_number": 42,
    "problem_name": "mobius_strip",
    "total_score": 485
  }
}
```

---

## Troubleshooting

### Common Issues

#### Issue: Import errors when using data structures

```python
# Error: ModuleNotFoundError: No module named 'results_collector'

# Solution: Ensure you're in the llm_harness directory
cd /path/to/shader_benchmark/llm_harness
python your_script.py
```

#### Issue: Stub renderers produce minimal reports

```
Problem: Generated reports only show summary, no test details

Reason: Current implementation is stub/placeholder
        Full hiccup-based rendering not yet implemented

Solution: Wait for full implementation (see REPORTING_ROLLOUT_PLAN.md)
          Or use legacy generate_report.py for full reports
```

#### Issue: Type errors with dataclasses

```python
# Error: TypeError: __init__() missing required positional argument

# Solution: Use proper initialization
from results_collector import JudgeScores

# Correct:
scores = JudgeScores(
    s1_mathematical_accuracy=85,
    s2_visual_quality=72,
    s3_problem_specific_1=91,
    s4_problem_specific_2=67,
    s5_problem_specific_3=88
)

# Can optionally override labels:
scores.s3_label = "Mathematical Accuracy"
```

#### Issue: Symlinks not working on Windows

```
Problem: images/ directory empty or broken links on Windows

Reason: Windows requires admin privileges for symlinks

Solution: Use --copy-images flag instead of symlinks (future feature)
          Or run with administrator privileges
```

### Performance Issues

#### Large Benchmark Runs (1000+ tests)

**Symptom:** Report generation slow or memory issues

**Solution:**
1. Monitor memory usage during generation
2. Consider streaming rendering for large runs (future feature)
3. Use `--limit` flag to test with subset first

#### HTML Report Loading Slowly

**Symptom:** Browser struggles with large HTML files

**Solution:**
1. Use pagination in HTML renderer (future feature)
2. Lazy-load images in HTML (future feature)
3. Use Markdown report for large runs

### Getting Help

**Documentation:**
- Design: `REPORTING_SYSTEM_DESIGN.md`
- Rollout Plan: `REPORTING_ROLLOUT_PLAN.md`
- CTO Review: `CTO_FINAL_REVIEW.md`

**Code References:**
- Data structures: `results_collector.py`
- Renderers: `report_renderer.py`
- Legacy system: `generate_report.py`

**Testing:**
- Test current implementation (when available)
- Report issues with detailed logs
- Include example data and expected vs actual output

---

## Appendix: Future Enhancements

### Planned Features (Post-MVP)

1. **Interactive HTML**
   - JavaScript filtering and sorting
   - Live search across test results
   - Collapsible sections

2. **Comparison Reports**
   - Side-by-side model comparisons
   - Diff visualization for scores
   - Regression detection

3. **PDF Export**
   - Headless browser rendering
   - Print-optimized layouts
   - Distribution-ready format

4. **Real-Time Updates**
   - Live report updates during harness execution
   - WebSocket-based streaming
   - Progress indicators

5. **Dashboard Integration**
   - Weights & Biases integration
   - Custom dashboard templates
   - Historical trend analysis

6. **Advanced Analytics**
   - Statistical analysis of score distributions
   - Error pattern recognition
   - Performance optimization suggestions

---

## Document History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2025-10-26 | Initial comprehensive documentation |

---

**End of Documentation**
