# Reporting System Design - Shader Benchmark Harness

**CTO Design Document**
**Version:** 1.0
**Date:** 2025-10-26
**Status:** Ready for Implementation

---

## Executive Summary

This document defines the architecture for a comprehensive reporting system that consolidates scattered test results from the shader benchmark harness into unified, professional reports. The system will generate both Markdown and HTML reports with embedded images, shader code, error diagnostics, and judge scores.

**Core Architecture Principles:**
1. **Hiccup-like data structures** for markup representation (nested Python lists/dicts)
2. **Single source of truth** for report data (typed Python dataclasses)
3. **Multiple output formats** from same data structure (MD and HTML renderers)
4. **Self-contained outputs** with embedded images and organized file structure

---

## 1. Data Structure Design

### 1.1 Core Type Definitions

```python
from dataclasses import dataclass, field
from pathlib import Path
from typing import Optional, List, Dict, Any
from datetime import datetime
from enum import Enum

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

```

---

## 2. Hiccup Data Structure Design

### 2.1 Hiccup Format Specification

Hiccup uses nested Python lists/dicts to represent markup:

```python
# Basic structure: [tag, attributes, *children]
# - tag: string (e.g., "div", "h1", "img")
# - attributes: dict (optional, can be None or {})
# - children: list of strings or nested structures

# Example 1: Simple paragraph
["p", None, "This is a paragraph"]

# Example 2: Paragraph with attributes
["p", {"class": "summary"}, "This is a summary paragraph"]

# Example 3: Nested structure
["div", {"class": "container"},
    ["h1", None, "Title"],
    ["p", None, "Content"]]

# Example 4: Image
["img", {"src": "images/result.png", "alt": "Rendered output"}]

# Example 5: Table
["table", None,
    ["thead", None,
        ["tr", None,
            ["th", None, "Category"],
            ["th", None, "Score"]]],
    ["tbody", None,
        ["tr", None,
            ["td", None, "Math Accuracy"],
            ["td", None, "85/100"]]]]
```

### 2.2 Hiccup Builder Functions

```python
from typing import Union, List, Dict, Any, Optional

HiccupNode = Union[str, List[Any]]  # String or [tag, attrs, *children]
HiccupAttrs = Optional[Dict[str, str]]

def h(tag: str, attrs: HiccupAttrs = None, *children: HiccupNode) -> List:
    """
    Hiccup node builder.

    Usage:
        h("div", {"class": "container"},
            h("h1", None, "Title"),
            h("p", None, "Content"))
    """
    return [tag, attrs or {}, *children]

def text(content: str) -> str:
    """Plain text node"""
    return content

def fragment(*children: HiccupNode) -> List[HiccupNode]:
    """Fragment container (doesn't render wrapper tag)"""
    return list(children)

# Convenience builders for common elements

def div(*children: HiccupNode, **attrs) -> List:
    return h("div", attrs, *children)

def section(*children: HiccupNode, **attrs) -> List:
    return h("section", attrs, *children)

def h1(content: str, **attrs) -> List:
    return h("h1", attrs, text(content))

def h2(content: str, **attrs) -> List:
    return h("h2", attrs, text(content))

def h3(content: str, **attrs) -> List:
    return h("h3", attrs, text(content))

def p(content: str, **attrs) -> List:
    return h("p", attrs, text(content))

def img(src: str, alt: str = "", **attrs) -> List:
    attrs_merged = {"src": src, "alt": alt, **attrs}
    return h("img", attrs_merged)

def table(headers: List[str], rows: List[List[str]], **attrs) -> List:
    """Build table from headers and row data"""
    return h("table", attrs,
        h("thead", None,
            h("tr", None, *[h("th", None, text(hdr)) for hdr in headers])),
        h("tbody", None,
            *[h("tr", None, *[h("td", None, text(cell)) for cell in row])
              for row in rows]))

def code_block(code: str, language: str = "", **attrs) -> List:
    """Code block with optional syntax highlighting"""
    if language:
        attrs_merged = {"class": f"language-{language}", **attrs}
        return h("pre", None, h("code", attrs_merged, text(code)))
    else:
        return h("pre", None, h("code", attrs, text(code)))

def link(href: str, text_content: str, **attrs) -> List:
    attrs_merged = {"href": href, **attrs}
    return h("a", attrs_merged, text(text_content))
```

### 2.3 Example Hiccup Structure for Report

```python
def example_report_hiccup(benchmark: BenchmarkRun) -> HiccupNode:
    """Example showing how to build report structure"""

    return div(
        # Header section
        section(
            h1(f"Shader Benchmark Report: {benchmark.summary.model_name}"),
            p(f"Generated: {benchmark.summary.end_time.isoformat()}"),
            p(f"Run ID: {benchmark.summary.run_id}"),
            **{"class": "report-header"}
        ),

        # Summary section
        section(
            h2("Summary Statistics"),
            table(
                headers=["Metric", "Value"],
                rows=[
                    ["Total Tests", str(benchmark.summary.total_tests)],
                    ["Successful", str(benchmark.summary.successful_tests)],
                    ["Failed", str(benchmark.summary.failed_tests)],
                    ["Success Rate", f"{benchmark.summary.success_rate:.1f}%"],
                    ["Total Time", f"{benchmark.summary.total_duration_seconds:.1f}s"]
                ]
            ),
            **{"class": "summary-section"}
        ),

        # Individual test results
        section(
            h2("Test Results"),
            *[build_test_result_section(test) for test in benchmark.test_results],
            **{"class": "test-results-section"}
        ),

        # Error analysis
        section(
            h2("Error Analysis"),
            *[build_error_summary(err) for err in benchmark.summary.error_summaries],
            **{"class": "error-analysis-section"}
        )
    )

def build_test_result_section(test: TestResult) -> HiccupNode:
    """Build hiccup structure for single test result"""

    children = [
        h3(f"Test {test.run_number}: {test.display_name}"),
        p(f"Status: {test.status.value}"),
        p(f"Execution Time: {test.timing.total_seconds:.2f}s"),
    ]

    # Add scores if available
    if test.judge_scores:
        children.append(
            table(
                headers=["Category", "Score"],
                rows=[
                    ["Mathematical Accuracy", f"{test.judge_scores.s1_mathematical_accuracy}/100"],
                    ["Visual Quality", f"{test.judge_scores.s2_visual_quality}/100"],
                    [test.judge_scores.s3_label, f"{test.judge_scores.s3_problem_specific_1}/100"],
                    [test.judge_scores.s4_label, f"{test.judge_scores.s4_problem_specific_2}/100"],
                    [test.judge_scores.s5_label, f"{test.judge_scores.s5_problem_specific_3}/100"],
                    ["Total", f"{test.judge_scores.total}/500"]
                ]
            )
        )

    # Add image if available
    if test.result_image_path:
        children.append(
            img(src=f"runs/run-{test.run_number:03d}-{test.problem_name}/result.png",
                alt=f"Rendered output for {test.display_name}")
        )

    # Add error info if failed
    if test.error:
        children.extend([
            h4("Error Information"),
            p(f"Stage: {test.error.stage}"),
            p(f"Type: {test.error.error_type}"),
            code_block(test.error.full_traceback or test.error.message, language="text")
        ])

    return section(*children, **{"class": "test-result", "id": f"test-{test.run_number}"})

def build_error_summary(error: ErrorSummary) -> HiccupNode:
    """Build hiccup structure for error summary"""

    return div(
        h4(f"{error.category} ({error.error_count} occurrences)"),
        p(f"Affected problems: {', '.join(error.affected_problems)}"),
        h5("Example Error:"),
        code_block(error.example_message, language="text"),
        **{"class": "error-summary"}
    )
```

---

## 3. Renderer Design

### 3.1 Renderer Function Signatures

```python
from pathlib import Path
from typing import TextIO

def hiccup_to_markdown(
    hiccup: HiccupNode,
    benchmark: BenchmarkRun,
    output_path: Path
) -> None:
    """
    Render hiccup structure to Markdown format.

    Args:
        hiccup: Root hiccup node structure
        benchmark: Full benchmark data (for additional context)
        output_path: Path to write markdown file

    Output format:
        - Headers: # H1, ## H2, ### H3
        - Images: ![alt](path)
        - Tables: Markdown table syntax
        - Code blocks: ```language...```
        - Links: [text](url)
    """
    pass

def hiccup_to_html(
    hiccup: HiccupNode,
    benchmark: BenchmarkRun,
    output_path: Path
) -> None:
    """
    Render hiccup structure to HTML format with navigation.

    Args:
        hiccup: Root hiccup node structure
        benchmark: Full benchmark data (for additional context)
        output_path: Path to write HTML file

    Output format:
        - Complete HTML5 document with <head> and <body>
        - Inline CSS for styling
        - Navigation sidebar with test links
        - Responsive design
        - Syntax highlighting for code blocks (via CSS)
    """
    pass

def render_hiccup_node(node: HiccupNode, writer: 'MarkdownWriter' or 'HTMLWriter') -> None:
    """
    Generic renderer that dispatches to appropriate writer methods.

    Args:
        node: Hiccup node (string or list structure)
        writer: Format-specific writer instance
    """
    if isinstance(node, str):
        writer.write_text(node)
    elif isinstance(node, list) and len(node) >= 2:
        tag, attrs, *children = node
        writer.write_tag(tag, attrs, children)
    else:
        raise ValueError(f"Invalid hiccup node: {node}")

class MarkdownWriter:
    """Stateful writer for Markdown output"""

    def __init__(self, output_file: Path):
        self.output_file = output_file
        self.indent_level = 0
        self.list_stack = []  # Track nested list contexts

    def write_text(self, text: str):
        """Write plain text (with escaping if needed)"""
        pass

    def write_tag(self, tag: str, attrs: Dict, children: List[HiccupNode]):
        """Write tag and recursively render children"""
        if tag == "h1":
            self._write_header(1, children)
        elif tag == "h2":
            self._write_header(2, children)
        elif tag == "h3":
            self._write_header(3, children)
        elif tag == "p":
            self._write_paragraph(children)
        elif tag == "img":
            self._write_image(attrs)
        elif tag == "table":
            self._write_table(children)
        elif tag == "pre":
            self._write_code_block(children)
        elif tag == "a":
            self._write_link(attrs, children)
        # ... handle other tags

    def _write_header(self, level: int, children: List[HiccupNode]):
        """Write markdown header: # H1, ## H2, etc."""
        pass

    def _write_image(self, attrs: Dict):
        """Write markdown image: ![alt](src)"""
        pass

    def _write_table(self, children: List[HiccupNode]):
        """Write markdown table with alignment"""
        pass

class HTMLWriter:
    """Stateful writer for HTML output"""

    def __init__(self, output_file: Path, benchmark: BenchmarkRun):
        self.output_file = output_file
        self.benchmark = benchmark
        self.indent_level = 0

    def write_document_start(self):
        """Write HTML5 doctype, head, CSS, and body opening"""
        pass

    def write_document_end(self):
        """Close body and html tags"""
        pass

    def write_navigation(self):
        """Write navigation sidebar with test links"""
        pass

    def write_text(self, text: str):
        """Write plain text (HTML-escaped)"""
        pass

    def write_tag(self, tag: str, attrs: Dict, children: List[HiccupNode]):
        """Write HTML tag with attributes and recursively render children"""
        # Open tag with attributes
        self._write_open_tag(tag, attrs)

        # Render children
        for child in children:
            render_hiccup_node(child, self)

        # Close tag
        self._write_close_tag(tag)

    def _write_open_tag(self, tag: str, attrs: Dict):
        """Write opening HTML tag with attributes"""
        pass

    def _write_close_tag(self, tag: str):
        """Write closing HTML tag"""
        pass
```

### 3.2 Renderer Implementation Strategy

**Markdown Renderer:**
- Tag mapping: `h1` → `# `, `h2` → `## `, `p` → paragraph with blank lines
- Images: Convert to `![alt](relative/path.png)`
- Tables: Use pipe syntax with alignment
- Code blocks: Triple backticks with language hint
- Links: `[text](url)`

**HTML Renderer:**
- Full HTML5 document with proper structure
- Inline CSS for styling (no external dependencies)
- Navigation sidebar: Fixed position, scrollable, links to each test
- Responsive design: Works on desktop and mobile
- Syntax highlighting: Use CSS classes, highlight.js compatible
- Image embedding: Relative paths to runs/ directory

---

## 4. File Organization and Naming

### 4.1 Output Directory Structure

```
harness_MODEL_TIMESTAMP/
├── all.md                          # Markdown report
├── all.html                        # HTML report with navigation
├── runs/                           # Individual test artifacts
│   ├── run-001-geometric_cube/
│   │   ├── result.png              # Final rendered image
│   │   ├── main.wgsl               # Main shader (or .glsl, .hlsl)
│   │   ├── [additional_shaders]    # Any imported/included shaders
│   │   ├── metadata.json           # Test metadata (scores, timing, status)
│   │   └── error.log               # Full stack trace if failed
│   ├── run-002-parametric_surface/
│   │   └── ...
│   └── run-NNN-problem_name/
│       └── ...
├── images/                         # Symlinks or copies for easy access
│   ├── run-001.png -> runs/run-001-geometric_cube/result.png
│   ├── run-002.png -> runs/run-002-parametric_surface/result.png
│   └── ...
└── summary.json                    # Machine-readable summary statistics
```

### 4.2 Naming Conventions

**Directory Names:**
- Harness run: `harness_{model_safe}_{timestamp}/`
  - `model_safe` = model name with `/` and `:` replaced by `_`
  - `timestamp` = `YYYYMMDD_HHMMSS`
  - Example: `harness_anthropic_claude-3.5-sonnet_20251026_143022/`

- Individual runs: `run-{NNN}-{problem_name}/`
  - `NNN` = 3-digit zero-padded run number (001, 002, ...)
  - `problem_name` = problem directory name from base_set/
  - Example: `run-001-geometric_cube/`

**File Names:**
- Report files: `all.md`, `all.html` (fixed names)
- Shader files: Preserve original names from LLM response
  - `main.wgsl`, `main.glsl`, `image_shader.glsl`, etc.
- Images: `result.png` (fixed name, matches current convention)
- Metadata: `metadata.json` (structured test info)
- Error logs: `error.log` (full stack trace, only if failed)
- Summary: `summary.json` (machine-readable aggregate stats)

### 4.3 Metadata JSON Format

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
    "s3_label": "Mathematical Accuracy",
    "s4_label": "Visual Implementation",
    "s5_label": "Completeness and Specifications",
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

### 4.4 Summary JSON Format

```json
{
  "model_name": "anthropic/claude-3.5-sonnet",
  "judge_model": "anthropic/claude-3.5-haiku",
  "language_spec": "wgsl",
  "run_id": "harness_anthropic_claude-3.5-sonnet_20251026_143022",
  "start_time": "2025-10-26T14:30:22.000000",
  "end_time": "2025-10-26T14:45:33.000000",
  "total_duration_seconds": 911.0,
  "total_tests": 100,
  "successful_tests": 87,
  "failed_tests": 13,
  "compile_failures": 3,
  "render_failures": 7,
  "judge_failures": 3,
  "success_rate": 87.0,
  "average_scores": {
    "s1_mathematical_accuracy": 78.5,
    "s2_visual_quality": 82.1,
    "s3_problem_specific_1": 75.3,
    "s4_problem_specific_2": 80.7,
    "s5_problem_specific_3": 77.9,
    "total": 394.5,
    "average": 78.9
  },
  "best_test": {
    "run_number": 42,
    "problem_name": "mobius_strip",
    "total_score": 485
  },
  "worst_test": {
    "run_number": 17,
    "problem_name": "julia_set",
    "total_score": 215
  },
  "error_summaries": [
    {
      "category": "Compilation Errors",
      "error_count": 3,
      "affected_problems": ["complex_surface", "recursive_fractal", "quaternion_rotation"]
    },
    {
      "category": "Shader Execution Errors",
      "error_count": 7,
      "affected_problems": ["..."]
    }
  ]
}
```

---

## 5. Integration with Benchmark Harness

### 5.1 Integration Points

**Current State Analysis:**
- `BenchmarkHarness.run_single_problem()` returns a dict with:
  - `problem`, `success`, `scores`, `image_path`, `test_dir`, `execution_time`, `error`
- `BenchmarkHarness.results` list accumulates these dicts
- `BenchmarkHarness.generate_report()` currently uses old `generate_report.py`

**New Integration:**
1. Add `ReportBuilder` class to construct `BenchmarkRun` from harness results
2. Replace `BenchmarkHarness.generate_report()` with new unified report system
3. Maintain checkpoint/resume compatibility

### 5.2 ReportBuilder Class

```python
from pathlib import Path
from typing import List, Dict, Any
from datetime import datetime

class ReportBuilder:
    """Build BenchmarkRun data structure from harness results"""

    def __init__(self, harness: 'BenchmarkHarness'):
        self.harness = harness

    def build_benchmark_run(self) -> BenchmarkRun:
        """
        Convert harness.results into BenchmarkRun structure.

        Steps:
        1. Extract metadata from harness (model, run_id, times, etc.)
        2. Convert each result dict to TestResult dataclass
        3. Calculate summary statistics
        4. Group errors by category
        5. Return complete BenchmarkRun structure
        """

        # Build summary
        summary = self._build_summary()

        # Convert individual test results
        test_results = [
            self._build_test_result(result, idx + 1)
            for idx, result in enumerate(self.harness.results)
        ]

        # Sort by run number
        test_results.sort(key=lambda t: t.run_number)

        return BenchmarkRun(
            summary=summary,
            test_results=test_results
        )

    def _build_summary(self) -> BenchmarkSummary:
        """Calculate summary statistics from results"""

        successful = [r for r in self.harness.results if r['success']]
        failed = [r for r in self.harness.results if not r['success']]

        # Calculate average scores (only successful tests)
        avg_scores = None
        if successful:
            score_sums = [0, 0, 0, 0, 0]
            for result in successful:
                scores = result.get('scores', [0, 0, 0, 0, 0])
                for i in range(5):
                    score_sums[i] += scores[i]

            avg_scores = JudgeScores(
                s1_mathematical_accuracy=int(score_sums[0] / len(successful)),
                s2_visual_quality=int(score_sums[1] / len(successful)),
                s3_problem_specific_1=int(score_sums[2] / len(successful)),
                s4_problem_specific_2=int(score_sums[3] / len(successful)),
                s5_problem_specific_3=int(score_sums[4] / len(successful))
            )

        # Group errors
        error_summaries = self._build_error_summaries(failed)

        # Find best/worst tests
        best_test = None
        worst_test = None
        if successful:
            best_result = max(successful, key=lambda r: sum(r.get('scores', [0, 0, 0, 0, 0])))
            worst_result = min(successful, key=lambda r: sum(r.get('scores', [0, 0, 0, 0, 0])))

            # Convert to TestResult (simplified for best/worst references)
            best_test = self._build_test_result(
                best_result,
                self.harness.results.index(best_result) + 1
            )
            worst_test = self._build_test_result(
                worst_result,
                self.harness.results.index(worst_result) + 1
            )

        return BenchmarkSummary(
            model_name=self.harness.model,
            judge_model=self.harness.judge_model,
            language_spec=self.harness.language,
            run_id=self.harness.run_id,
            start_time=self.harness.start_time,
            end_time=self.harness.end_time,
            total_duration_seconds=(self.harness.end_time - self.harness.start_time).total_seconds(),
            total_tests=len(self.harness.results),
            successful_tests=len(successful),
            failed_tests=len(failed),
            compile_failures=self._count_stage_failures(failed, 'compile'),
            render_failures=self._count_stage_failures(failed, 'render'),
            judge_failures=self._count_stage_failures(failed, 'judge'),
            average_scores=avg_scores,
            median_scores=None,  # TODO: Calculate median
            best_test=best_test,
            worst_test=worst_test,
            error_summaries=error_summaries
        )

    def _build_test_result(self, result: Dict[str, Any], run_number: int) -> TestResult:
        """Convert result dict to TestResult dataclass"""

        problem_name = result['problem']
        test_dir = Path(result.get('test_dir', f'test_unknown_{run_number}'))

        # Determine status
        if result['success']:
            status = ExecutionStatus.SUCCESS
        else:
            # Parse error to determine stage
            error_msg = result.get('error', '')
            if 'compile' in error_msg.lower():
                status = ExecutionStatus.COMPILE_ERROR
            elif 'render' in error_msg.lower():
                status = ExecutionStatus.RENDER_ERROR
            elif 'judge' in error_msg.lower():
                status = ExecutionStatus.JUDGE_ERROR
            else:
                status = ExecutionStatus.UNKNOWN_ERROR

        # Build timing info
        timing = TimingInfo(
            total_seconds=result.get('execution_time', 0.0)
        )

        # Build judge scores
        judge_scores = None
        if result['success'] and result.get('scores'):
            scores = result['scores']
            judge_scores = JudgeScores(
                s1_mathematical_accuracy=scores[0],
                s2_visual_quality=scores[1],
                s3_problem_specific_1=scores[2],
                s4_problem_specific_2=scores[3],
                s5_problem_specific_3=scores[4]
            )

        # Build error info
        error = None
        if not result['success']:
            error = ErrorInfo(
                stage="unknown",  # TODO: Parse from error message
                error_type="RuntimeError",
                message=result.get('error', 'Unknown error'),
                full_traceback=None,  # TODO: Load from error.log if exists
                compiler_output=None
            )

        # Build shader artifacts
        shader_artifacts = ShaderArtifacts(
            shader_files={},  # TODO: Load from test_dir/shaders/
            main_shader_name=None,
            language_spec=self.harness.language,
            llm_generated_main_rs=None
        )

        # Result image path
        result_image = None
        if result.get('image_path'):
            result_image = Path(result['image_path'])

        return TestResult(
            test_id=test_dir.name.replace('test_', '').replace('_results', ''),
            problem_name=problem_name,
            problem_folder=self._get_problem_folder(problem_name),
            run_number=run_number,
            status=status,
            success=result['success'],
            timing=timing,
            result_image_path=result_image,
            shader_artifacts=shader_artifacts,
            judge_scores=judge_scores,
            error=error,
            test_directory=test_dir,
            timestamp=datetime.now()  # TODO: Get from test_dir metadata
        )

    def _get_problem_folder(self, problem_name: str) -> Path:
        """Get path to problem folder in base_set"""
        script_dir = Path(__file__).parent.absolute()
        return script_dir.parent / "problems" / "base_set" / problem_name

    def _count_stage_failures(self, failed_results: List[Dict], stage: str) -> int:
        """Count failures at specific pipeline stage"""
        count = 0
        for result in failed_results:
            error_msg = result.get('error', '').lower()
            if stage in error_msg:
                count += 1
        return count

    def _build_error_summaries(self, failed_results: List[Dict]) -> List[ErrorSummary]:
        """Group errors by category"""

        # Categorize errors
        error_groups = {}
        for result in failed_results:
            error_msg = result.get('error', 'Unknown error')

            # Create temporary ErrorInfo for categorization
            temp_error = ErrorInfo(
                stage="unknown",
                error_type="RuntimeError",
                message=error_msg,
                full_traceback=None,
                compiler_output=None
            )

            category = temp_error.get_error_category()

            if category not in error_groups:
                error_groups[category] = []

            error_groups[category].append({
                'problem': result['problem'],
                'message': error_msg
            })

        # Build ErrorSummary objects
        summaries = []
        for category, errors in error_groups.items():
            summaries.append(ErrorSummary(
                category=category,
                error_count=len(errors),
                affected_problems=[e['problem'] for e in errors],
                example_message=errors[0]['message'],
                example_traceback=None
            ))

        return summaries
```

### 5.3 Updated BenchmarkHarness.generate_report()

```python
class BenchmarkHarness:
    # ... existing code ...

    def generate_report(self) -> Path:
        """Generate unified report using new reporting system"""

        # Build BenchmarkRun data structure
        builder = ReportBuilder(self)
        benchmark_run = builder.build_benchmark_run()

        # Create output directory
        output_dir = Path(self.run_id)
        output_dir.mkdir(parents=True, exist_ok=True)

        # Organize test artifacts into runs/ subdirectory
        self._organize_test_artifacts(benchmark_run, output_dir)

        # Build hiccup structure
        hiccup = build_report_hiccup(benchmark_run)

        # Render to Markdown
        md_path = output_dir / "all.md"
        hiccup_to_markdown(hiccup, benchmark_run, md_path)

        # Render to HTML
        html_path = output_dir / "all.html"
        hiccup_to_html(hiccup, benchmark_run, html_path)

        # Write summary JSON
        summary_path = output_dir / "summary.json"
        self._write_summary_json(benchmark_run, summary_path)

        # Update benchmark_run with output paths
        benchmark_run.output_directory = output_dir
        benchmark_run.markdown_report_path = md_path
        benchmark_run.html_report_path = html_path

        print(f"Report generated: {output_dir}/")
        print(f"  - Markdown: {md_path}")
        print(f"  - HTML: {html_path}")
        print(f"  - Summary: {summary_path}")

        return output_dir

    def _organize_test_artifacts(self, benchmark_run: BenchmarkRun, output_dir: Path):
        """Copy test artifacts into organized runs/ structure"""

        runs_dir = output_dir / "runs"
        runs_dir.mkdir(exist_ok=True)

        images_dir = output_dir / "images"
        images_dir.mkdir(exist_ok=True)

        for test in benchmark_run.test_results:
            # Create run directory
            run_name = f"run-{test.run_number:03d}-{test.problem_name}"
            run_dir = runs_dir / run_name
            run_dir.mkdir(exist_ok=True)

            # Copy result image
            if test.result_image_path and test.result_image_path.exists():
                shutil.copy2(test.result_image_path, run_dir / "result.png")

                # Create symlink in images/ for easy access
                symlink_path = images_dir / f"run-{test.run_number:03d}.png"
                if not symlink_path.exists():
                    symlink_path.symlink_to(f"../runs/{run_name}/result.png")

            # Copy shader files
            shader_dir = test.test_directory / "shaders"
            if shader_dir.exists():
                for shader_file in shader_dir.glob("*"):
                    shutil.copy2(shader_file, run_dir / shader_file.name)

            # Write metadata JSON
            metadata = {
                "test_id": test.test_id,
                "run_number": test.run_number,
                "problem_name": test.problem_name,
                "status": test.status.value,
                "timestamp": test.timestamp.isoformat(),
                "timing": {
                    "total_seconds": test.timing.total_seconds
                },
                "judge_scores": None,
                "shader_artifacts": {
                    "language_spec": test.shader_artifacts.language_spec,
                    "main_shader_name": test.shader_artifacts.main_shader_name,
                    "shader_files": list(test.shader_artifacts.shader_files.keys())
                },
                "error": None
            }

            if test.judge_scores:
                metadata["judge_scores"] = {
                    "s1_mathematical_accuracy": test.judge_scores.s1_mathematical_accuracy,
                    "s2_visual_quality": test.judge_scores.s2_visual_quality,
                    "s3_problem_specific_1": test.judge_scores.s3_problem_specific_1,
                    "s4_problem_specific_2": test.judge_scores.s4_problem_specific_2,
                    "s5_problem_specific_3": test.judge_scores.s5_problem_specific_3,
                    "s3_label": test.judge_scores.s3_label,
                    "s4_label": test.judge_scores.s4_label,
                    "s5_label": test.judge_scores.s5_label,
                    "total": test.judge_scores.total,
                    "average": test.judge_scores.average
                }

            if test.error:
                metadata["error"] = {
                    "stage": test.error.stage,
                    "error_type": test.error.error_type,
                    "message": test.error.message
                }

                # Write full error log
                error_log_path = run_dir / "error.log"
                with open(error_log_path, 'w') as f:
                    f.write(f"Stage: {test.error.stage}\n")
                    f.write(f"Type: {test.error.error_type}\n")
                    f.write(f"Message: {test.error.message}\n\n")
                    if test.error.full_traceback:
                        f.write("Full Traceback:\n")
                        f.write(test.error.full_traceback)
                    if test.error.compiler_output:
                        f.write("\n\nCompiler Output:\n")
                        f.write(test.error.compiler_output)

            # Write metadata.json
            with open(run_dir / "metadata.json", 'w') as f:
                json.dump(metadata, f, indent=2)

    def _write_summary_json(self, benchmark_run: BenchmarkRun, output_path: Path):
        """Write machine-readable summary JSON"""

        summary = benchmark_run.summary

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
            data["average_scores"] = {
                "s1_mathematical_accuracy": summary.average_scores.s1_mathematical_accuracy,
                "s2_visual_quality": summary.average_scores.s2_visual_quality,
                "s3_problem_specific_1": summary.average_scores.s3_problem_specific_1,
                "s4_problem_specific_2": summary.average_scores.s4_problem_specific_2,
                "s5_problem_specific_3": summary.average_scores.s5_problem_specific_3,
                "total": summary.average_scores.total,
                "average": summary.average_scores.average
            }

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

        with open(output_path, 'w') as f:
            json.dump(data, f, indent=2)
```

---

## 6. Implementation Phases

### Phase 1: Data Structures (Week 1)
- [ ] Define all dataclasses in `report_types.py`
- [ ] Implement `ReportBuilder` class
- [ ] Unit tests for data structure conversion
- [ ] Integration test with mock harness results

### Phase 2: Hiccup System (Week 1-2)
- [ ] Implement hiccup builder functions in `hiccup.py`
- [ ] Create `build_report_hiccup()` function
- [ ] Unit tests for hiccup structure generation
- [ ] Validation utilities for hiccup structures

### Phase 3: Markdown Renderer (Week 2)
- [ ] Implement `MarkdownWriter` class
- [ ] Implement `hiccup_to_markdown()` function
- [ ] Handle all relevant HTML tags → Markdown conversion
- [ ] Unit tests with sample hiccup structures
- [ ] Integration test generating full report

### Phase 4: HTML Renderer (Week 3)
- [ ] Implement `HTMLWriter` class with CSS styling
- [ ] Implement `hiccup_to_html()` function
- [ ] Create navigation sidebar
- [ ] Responsive design and syntax highlighting
- [ ] Unit tests and integration tests

### Phase 5: Harness Integration (Week 3-4)
- [ ] Replace `BenchmarkHarness.generate_report()`
- [ ] Implement `_organize_test_artifacts()`
- [ ] Implement `_write_summary_json()`
- [ ] End-to-end tests with real harness runs
- [ ] Migration testing (old vs new reports)

### Phase 6: Polish and Documentation (Week 4)
- [ ] Error handling and edge cases
- [ ] Performance optimization (large benchmark runs)
- [ ] User documentation
- [ ] Developer documentation
- [ ] Example reports in documentation

---

## 7. Testing Strategy

### Unit Tests
- Data structure validation
- Hiccup builder functions
- Renderer tag conversions
- Error categorization logic

### Integration Tests
- Full report generation pipeline
- Markdown output validation
- HTML output validation
- File organization correctness

### End-to-End Tests
- Run harness with 5-10 problems
- Generate reports (MD + HTML)
- Validate structure and content
- Performance benchmarks

### Regression Tests
- Compare old vs new report outputs
- Ensure no data loss during migration
- Validate checkpoint/resume compatibility

---

## 8. Success Criteria

### Functional Requirements
- [ ] Reports consolidate all test results in single directory
- [ ] Both Markdown and HTML versions generated
- [ ] Images embedded/referenced correctly
- [ ] Shader code accessible and readable
- [ ] Error information complete with stack traces
- [ ] Judge scores displayed accurately (1-100 scale, /500 totals)
- [ ] Summary statistics calculated correctly
- [ ] Error analysis groups similar failures

### Quality Requirements
- [ ] Report generation < 2 seconds for 100 tests
- [ ] HTML navigation functional and responsive
- [ ] Markdown readable in GitHub/editors
- [ ] Code follows project conventions
- [ ] Full test coverage (>90%)
- [ ] Documentation complete and accurate

### User Experience
- [ ] Reports easy to share (single directory)
- [ ] Visual design professional and clear
- [ ] Navigation intuitive (HTML)
- [ ] Error messages helpful for debugging
- [ ] Summary provides actionable insights

---

## 9. Migration Path

### Backward Compatibility
- Old `generate_report.py` kept for reference
- New system activated via flag initially: `--new-report`
- Side-by-side comparison during transition
- Full migration after validation period

### Deprecation Timeline
1. **Week 1-2:** New system developed, old system remains default
2. **Week 3:** New system tested alongside old system
3. **Week 4:** New system becomes default, old system available via `--legacy-report`
4. **Week 5-6:** Validation period, gather feedback
5. **Week 7:** Remove old system if no critical issues

---

## 10. Open Questions and Future Enhancements

### Open Questions for Staff Engineers
1. **Image handling:** Symlinks vs copies for images/ directory? (Symlinks save space, copies ensure portability)
2. **Shader artifact preservation:** Copy all intermediate files or only final versions?
3. **HTML styling:** Inline CSS vs external stylesheet? (Inline = self-contained, external = customizable)
4. **Large benchmark runs:** Memory optimization strategies for 1000+ tests?
5. **Concurrent report generation:** Support generating report while harness still running?

### Future Enhancements (Post-MVP)
- Interactive HTML with JavaScript (filtering, sorting, search)
- Comparison reports (diff between two benchmark runs)
- PDF export via headless browser
- Real-time report updates during harness execution
- Report thumbnails and image galleries
- Integration with external dashboards (e.g., Weights & Biases)
- Historical trend analysis across multiple runs

---

## Appendices

### A. Example Markdown Output

```markdown
# Shader Benchmark Report: anthropic/claude-3.5-sonnet

**Generated:** 2025-10-26 14:45:33
**Run ID:** harness_anthropic_claude-3.5-sonnet_20251026_143022
**Total Tests:** 100
**Successful Renders:** 87
**Failed Tests:** 13

---

## Summary Statistics

| Metric | Value |
|--------|-------|
| Total Tests | 100 |
| Successful | 87 |
| Failed | 13 |
| Success Rate | 87.0% |
| Total Time | 911.0s |

### Average Scores by Category

| Category | Average Score |
|----------|---------------|
| Mathematical Accuracy | 78.5/100 |
| Visual Quality | 82.1/100 |
| Problem Specific 1 | 75.3/100 |
| Problem Specific 2 | 80.7/100 |
| Problem Specific 3 | 77.9/100 |
| **Overall Average** | **78.9/100** |

### Performance Highlights

**Best Test:** Mobius Strip (Total: 485/500)
**Worst Test:** Julia Set (Total: 215/500)

---

## Test Results

### Test 1: Geometric Cube

**Status:** success
**Execution Time:** 7.23s
**Shader Files:** main.wgsl

#### Judge Scores

| Category | Score |
|----------|-------|
| Mathematical Accuracy | 85/100 |
| Visual Quality | 72/100 |
| Mathematical Accuracy | 91/100 |
| Visual Implementation | 67/100 |
| Completeness and Specifications | 88/100 |
| **Total** | **403/500** |

#### Rendered Output

![Rendered Output](runs/run-001-geometric_cube/result.png)

---

### Test 2: Parametric Surface

**Status:** render_error
**Execution Time:** 4.12s
**Shader Files:** main.wgsl

#### Error Information

**Stage:** render
**Type:** RuntimeError

```
Shader execution failed: naga::front::wgsl::ParseError { message: "unexpected token", labels: [(naga::Span { start: 234, end: 245 }, "expected semicolon")] }
```

---

## Error Analysis

### Compilation Errors (3 occurrences)

**Affected problems:** complex_surface, recursive_fractal, quaternion_rotation

**Example Error:**

```
Shader execution failed: naga::front::wgsl::ParseError { message: "unexpected token" }
```

---

### Shader Execution Errors (7 occurrences)

**Affected problems:** ...

**Example Error:**

```
...
```

---
```

### B. File Size Estimates

For a 100-test benchmark run:

- `all.md`: ~500 KB (text + references)
- `all.html`: ~800 KB (with inline CSS)
- `runs/`: ~300 MB (100 images @ 2-3 MB each, shader files)
- `images/`: Negligible (symlinks) or ~300 MB (copies)
- `summary.json`: ~50 KB
- **Total:** ~300-600 MB per benchmark run

### C. Performance Targets

- Report generation: < 2 seconds for 100 tests
- HTML page load: < 1 second (even with 100 embedded images)
- Markdown rendering: Instant in GitHub/VSCode
- File organization: < 5 seconds for 100 tests

---

## Document Revision History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2025-10-26 | CTO | Initial design document |

