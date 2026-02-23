#!/usr/bin/env python3
"""
Report Renderer - Hiccup to Markdown/HTML Conversion
Staff Engineer 2 Implementation

Converts hiccup-like data structures to Markdown and HTML5 reports.
Provides unified rendering layer for benchmark results.

Author: Staff Engineer 2
Date: 2025-10-26
Version: 1.0 (Full Implementation)
"""

from pathlib import Path
from typing import Union, List, Dict, Any, Optional, Tuple
from datetime import datetime
import html as html_lib

# Import data structures from results_collector
from results_collector import (
    ExecutionStatus,
    TimingInfo,
    JudgeScores,
    ErrorInfo,
    ShaderArtifacts,
    TestResult,
    ErrorSummary,
    BenchmarkSummary,
    BenchmarkRun
)


# ============================================================================
# Hiccup Data Structure
# ============================================================================

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
    return h("div", attrs if attrs else None, *children)


def section(*children: HiccupNode, **attrs) -> List:
    return h("section", attrs if attrs else None, *children)


def h1(content: str, **attrs) -> List:
    return h("h1", attrs if attrs else None, text(content))


def h2(content: str, **attrs) -> List:
    return h("h2", attrs if attrs else None, text(content))


def h3(content: str, **attrs) -> List:
    return h("h3", attrs if attrs else None, text(content))


def h4(content: str, **attrs) -> List:
    return h("h4", attrs if attrs else None, text(content))


def h5(content: str, **attrs) -> List:
    return h("h5", attrs if attrs else None, text(content))


def p(content: str, **attrs) -> List:
    return h("p", attrs if attrs else None, text(content))


def img(src: str, alt: str = "", **attrs) -> List:
    attrs_merged = {"src": src, "alt": alt}
    attrs_merged.update(attrs)
    return h("img", attrs_merged)


def table(headers: List[str], rows: List[List[str]], **attrs) -> List:
    """Build table from headers and row data"""
    return h("table", attrs if attrs else None,
        h("thead", None,
            h("tr", None, *[h("th", None, text(hdr)) for hdr in headers])),
        h("tbody", None,
            *[h("tr", None, *[h("td", None, text(str(cell))) for cell in row])
              for row in rows]))


def code_block(code: str, language: str = "", **attrs) -> List:
    """Code block with optional syntax highlighting"""
    if language:
        attrs_merged = {"class": f"language-{language}"}
        attrs_merged.update(attrs)
        return h("pre", None, h("code", attrs_merged if attrs_merged else None, text(code)))
    else:
        return h("pre", None, h("code", attrs if attrs else None, text(code)))


def link(href: str, text_content: str, **attrs) -> List:
    attrs_merged = {"href": href}
    attrs_merged.update(attrs)
    return h("a", attrs_merged, text(text_content))


# ============================================================================
# Report Builder - Converts BenchmarkRun to Hiccup Structure
# ============================================================================

def build_report_hiccup(benchmark: BenchmarkRun) -> HiccupNode:
    """Build complete report hiccup structure from benchmark data"""

    children = []

    # Header section
    children.append(
        section(
            h1(f"Shader Benchmark Report: {benchmark.summary.model_name}"),
            p(f"Generated: {benchmark.summary.end_time.strftime('%Y-%m-%d %H:%M:%S')}"),
            p(f"Run ID: {benchmark.summary.run_id}"),
            p(f"Language: {benchmark.summary.language_spec}"),
            **{"class": "report-header"}
        )
    )

    # Summary section
    children.append(build_summary_section(benchmark.summary))

    # Individual test results
    test_results_children = [h2("Test Results")]
    for test in benchmark.test_results:
        test_results_children.append(build_test_result_section(test))

    children.append(
        section(*test_results_children, **{"class": "test-results-section"})
    )

    # Error analysis (if errors exist)
    if benchmark.summary.error_summaries:
        error_children = [h2("Error Analysis")]
        for err in benchmark.summary.error_summaries:
            error_children.append(build_error_summary(err))

        children.append(
            section(*error_children, **{"class": "error-analysis-section"})
        )

    return div(*children, **{"class": "report-container"})


def build_summary_section(summary: BenchmarkSummary) -> HiccupNode:
    """Build summary statistics section"""

    children = [h2("Summary Statistics")]

    # Basic stats table
    children.append(
        table(
            headers=["Metric", "Value"],
            rows=[
                ["Total Tests", str(summary.total_tests)],
                ["Successful", str(summary.successful_tests)],
                ["Failed", str(summary.failed_tests)],
                ["Success Rate", f"{summary.success_rate:.1f}%"],
                ["Total Time", f"{summary.total_duration_seconds:.1f}s"],
                ["Compile Failures", str(summary.compile_failures)],
                ["Render Failures", str(summary.render_failures)],
                ["Judge Failures", str(summary.judge_failures)]
            ]
        )
    )

    # Average scores (if available)
    if summary.average_scores:
        children.append(h3("Average Scores by Category"))
        children.append(
            table(
                headers=["Category", "Average Score"],
                rows=[
                    ["Mathematical Accuracy", f"{summary.average_scores.s1_mathematical_accuracy:.1f}/100"],
                    ["Visual Quality", f"{summary.average_scores.s2_visual_quality:.1f}/100"],
                    [summary.average_scores.s3_label, f"{summary.average_scores.s3_problem_specific_1:.1f}/100"],
                    [summary.average_scores.s4_label, f"{summary.average_scores.s4_problem_specific_2:.1f}/100"],
                    [summary.average_scores.s5_label, f"{summary.average_scores.s5_problem_specific_3:.1f}/100"],
                    ["Overall Average", f"{summary.average_scores.average:.1f}/100"]
                ]
            )
        )

    # Best and worst tests
    if summary.best_test and summary.worst_test:
        children.append(h3("Performance Highlights"))
        children.append(
            p(f"Best Test: {summary.best_test.display_name} (Total: {summary.best_test.judge_scores.total if summary.best_test.judge_scores else 0}/500)")
        )
        children.append(
            p(f"Worst Test: {summary.worst_test.display_name} (Total: {summary.worst_test.judge_scores.total if summary.worst_test.judge_scores else 0}/500)")
        )

    return section(*children, **{"class": "summary-section"})


def build_test_result_section(test: TestResult) -> HiccupNode:
    """Build hiccup structure for single test result"""

    children = [
        h3(f"Test {test.run_number}: {test.display_name}"),
        p(f"Status: {test.status.value}"),
        p(f"Test ID: {test.test_id}"),
        p(f"Timestamp: {test.timestamp.strftime('%Y-%m-%d %H:%M:%S')}"),
    ]

    # Add timing if available
    if test.timing.total_seconds:
        children.append(p(f"Execution Time: {test.timing.total_seconds:.2f}s"))

    # Add scores if available
    if test.judge_scores:
        children.append(h4("Judge Scores"))
        children.append(
            table(
                headers=["Category", "Score"],
                rows=[
                    ["Mathematical Accuracy", f"{test.judge_scores.s1_mathematical_accuracy}/100"],
                    ["Visual Quality", f"{test.judge_scores.s2_visual_quality}/100"],
                    [test.judge_scores.s3_label, f"{test.judge_scores.s3_problem_specific_1}/100"],
                    [test.judge_scores.s4_label, f"{test.judge_scores.s4_problem_specific_2}/100"],
                    [test.judge_scores.s5_label, f"{test.judge_scores.s5_problem_specific_3}/100"],
                    ["Total", f"{test.judge_scores.total}/500"],
                    ["Average", f"{test.judge_scores.average:.1f}/100"]
                ]
            )
        )

    # Add image if available
    if test.result_image_path and test.result_image_path.exists():
        children.append(h4("Rendered Output"))
        # Use relative path from output directory
        rel_path = f"runs/run-{test.run_number:03d}-{test.problem_name}/result.png"
        children.append(
            img(src=rel_path, alt=f"Rendered output for {test.display_name}")
        )

    # Add shader info
    if test.shader_artifacts.main_shader_name:
        children.append(h4("Shader Information"))
        children.append(p(f"Main Shader: {test.shader_artifacts.main_shader_name}"))
        children.append(p(f"Language: {test.shader_artifacts.language_spec}"))

        # List shader files
        if test.shader_artifacts.shader_files:
            children.append(p(f"Shader Files: {', '.join(test.shader_artifacts.shader_files.keys())}"))

    # Add error info if failed
    if test.error:
        children.append(h4("Error Information"))
        children.append(p(f"Stage: {test.error.stage}"))
        children.append(p(f"Type: {test.error.error_type}"))
        children.append(p(f"Message: {test.error.message}"))

        if test.error.full_traceback:
            children.append(h5("Full Traceback"))
            children.append(code_block(test.error.full_traceback, language="text"))

        if test.error.compiler_output:
            children.append(h5("Compiler Output"))
            children.append(code_block(test.error.compiler_output, language="text"))

    return section(*children, **{"class": "test-result", "id": f"test-{test.run_number}"})


def build_error_summary(error: ErrorSummary) -> HiccupNode:
    """Build hiccup structure for error summary"""

    children = [
        h4(f"{error.category} ({error.error_count} occurrences)"),
        p(f"Affected problems: {', '.join(error.affected_problems)}"),
        h5("Example Error:"),
        code_block(error.example_message, language="text")
    ]

    if error.example_traceback:
        children.append(h5("Example Traceback:"))
        children.append(code_block(error.example_traceback, language="text"))

    return div(*children, **{"class": "error-summary"})


# ============================================================================
# Markdown Renderer
# ============================================================================

class MarkdownWriter:
    """Stateful writer for Markdown output"""

    def __init__(self, output_file: Path):
        self.output_file = output_file
        self.buffer = []
        self.table_mode = False

    def write_text(self, text_content: str):
        """Write plain text"""
        self.buffer.append(text_content)

    def write_newline(self, count: int = 1):
        """Write newlines"""
        self.buffer.append("\n" * count)

    def write_tag(self, tag: str, attrs: Dict, children: List[HiccupNode]):
        """Write tag and recursively render children"""
        if tag == "h1":
            self._write_header(1, children)
        elif tag == "h2":
            self._write_header(2, children)
        elif tag == "h3":
            self._write_header(3, children)
        elif tag == "h4":
            self._write_header(4, children)
        elif tag == "h5":
            self._write_header(5, children)
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
        elif tag in ["div", "section"]:
            # Container tags - just render children
            for child in children:
                render_hiccup_node(child, self)
        elif tag == "code":
            # Inline code or part of pre block
            for child in children:
                if isinstance(child, str):
                    self.write_text(child)
        elif tag in ["thead", "tbody", "tr", "th", "td"]:
            # Table components - handled by _write_table
            pass
        else:
            # Unknown tags - just render children
            for child in children:
                render_hiccup_node(child, self)

    def _write_header(self, level: int, children: List[HiccupNode]):
        """Write markdown header: # H1, ## H2, etc."""
        self.write_newline(2)
        self.write_text("#" * level + " ")
        for child in children:
            if isinstance(child, str):
                self.write_text(child)
            else:
                render_hiccup_node(child, self)
        self.write_newline(2)

    def _write_paragraph(self, children: List[HiccupNode]):
        """Write paragraph with blank lines"""
        self.write_newline(1)
        for child in children:
            if isinstance(child, str):
                self.write_text(child)
            else:
                render_hiccup_node(child, self)
        self.write_newline(2)

    def _write_image(self, attrs: Dict):
        """Write markdown image: ![alt](src)"""
        src = attrs.get("src", "")
        alt = attrs.get("alt", "")
        self.write_newline(1)
        self.write_text(f"![{alt}]({src})")
        self.write_newline(2)

    def _write_link(self, attrs: Dict, children: List[HiccupNode]):
        """Write markdown link: [text](url)"""
        href = attrs.get("href", "")
        self.write_text("[")
        for child in children:
            if isinstance(child, str):
                self.write_text(child)
        self.write_text(f"]({href})")

    def _write_table(self, children: List[HiccupNode]):
        """Write markdown table with alignment"""
        self.write_newline(1)

        # Extract headers and rows from children
        headers = []
        rows = []

        for child in children:
            if isinstance(child, list) and len(child) >= 2:
                tag = child[0]
                child_children = child[2:] if len(child) > 2 else []

                if tag == "thead":
                    # Extract headers
                    for thead_child in child_children:
                        if isinstance(thead_child, list) and thead_child[0] == "tr":
                            tr_children = thead_child[2:] if len(thead_child) > 2 else []
                            for th in tr_children:
                                if isinstance(th, list) and th[0] == "th":
                                    th_children = th[2:] if len(th) > 2 else []
                                    header_text = ""
                                    for th_child in th_children:
                                        if isinstance(th_child, str):
                                            header_text += th_child
                                    headers.append(header_text)

                elif tag == "tbody":
                    # Extract rows
                    for tbody_child in child_children:
                        if isinstance(tbody_child, list) and tbody_child[0] == "tr":
                            tr_children = tbody_child[2:] if len(tbody_child) > 2 else []
                            row = []
                            for td in tr_children:
                                if isinstance(td, list) and td[0] == "td":
                                    td_children = td[2:] if len(td) > 2 else []
                                    cell_text = ""
                                    for td_child in td_children:
                                        if isinstance(td_child, str):
                                            cell_text += td_child
                                    row.append(cell_text)
                            if row:
                                rows.append(row)

        # Write table
        if headers:
            self.write_text("| " + " | ".join(headers) + " |")
            self.write_newline(1)
            self.write_text("| " + " | ".join(["---"] * len(headers)) + " |")
            self.write_newline(1)

        for row in rows:
            self.write_text("| " + " | ".join(row) + " |")
            self.write_newline(1)

        self.write_newline(1)

    def _write_code_block(self, children: List[HiccupNode]):
        """Write markdown code block with triple backticks"""
        self.write_newline(1)

        # Extract language from code tag if present
        language = ""
        code_content = ""

        for child in children:
            if isinstance(child, list) and child[0] == "code":
                attrs = child[1] if len(child) > 1 else {}
                if isinstance(attrs, dict):
                    class_name = attrs.get("class", "")
                    if class_name.startswith("language-"):
                        language = class_name[9:]

                code_children = child[2:] if len(child) > 2 else []
                for code_child in code_children:
                    if isinstance(code_child, str):
                        code_content += code_child
            elif isinstance(child, str):
                code_content += child

        self.write_text("```" + language)
        self.write_newline(1)
        self.write_text(code_content)
        self.write_newline(1)
        self.write_text("```")
        self.write_newline(2)

    def save(self):
        """Save buffer to file"""
        with open(self.output_file, 'w', encoding='utf-8') as f:
            f.write(''.join(self.buffer))


def render_hiccup_node(node: HiccupNode, writer):
    """Generic renderer that dispatches to appropriate writer methods"""
    if isinstance(node, str):
        writer.write_text(node)
    elif isinstance(node, list) and len(node) >= 2:
        tag = node[0]
        attrs = node[1] if len(node) > 1 else {}
        children = node[2:] if len(node) > 2 else []

        # Ensure attrs is a dict
        if not isinstance(attrs, dict):
            attrs = {}

        writer.write_tag(tag, attrs, children)
    else:
        # Invalid node - skip
        pass


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
    writer = MarkdownWriter(output_path)
    render_hiccup_node(hiccup, writer)
    writer.save()


# ============================================================================
# HTML Renderer
# ============================================================================

class HTMLWriter:
    """Stateful writer for HTML output"""

    def __init__(self, output_file: Path, benchmark: BenchmarkRun):
        self.output_file = output_file
        self.benchmark = benchmark
        self.buffer = []
        self.indent_level = 0

    def write_text(self, text_content: str):
        """Write plain text (HTML-escaped)"""
        escaped = html_lib.escape(text_content)
        self.buffer.append(escaped)

    def write_raw(self, content: str):
        """Write raw HTML without escaping"""
        self.buffer.append(content)

    def write_newline(self):
        """Write newline"""
        self.buffer.append("\n")

    def write_indent(self):
        """Write indentation"""
        self.buffer.append("  " * self.indent_level)

    def write_tag(self, tag: str, attrs: Dict, children: List[HiccupNode]):
        """Write HTML tag with attributes and recursively render children"""
        # Self-closing tags
        if tag == "img":
            self.write_indent()
            self.write_raw(f"<{tag}")
            self._write_attrs(attrs)
            self.write_raw(" />")
            self.write_newline()
            return

        # Opening tag
        self.write_indent()
        self.write_raw(f"<{tag}")
        self._write_attrs(attrs)
        self.write_raw(">")

        # Inline vs block elements
        inline_tags = ["a", "code", "span", "strong", "em", "b", "i"]
        is_inline = tag in inline_tags

        if not is_inline:
            self.write_newline()
            self.indent_level += 1

        # Render children
        for child in children:
            render_hiccup_node(child, self)

        if not is_inline:
            self.indent_level -= 1
            self.write_indent()

        # Closing tag
        self.write_raw(f"</{tag}>")
        self.write_newline()

    def _write_attrs(self, attrs: Dict):
        """Write HTML attributes"""
        if not attrs:
            return

        for key, value in attrs.items():
            if value is not None:
                escaped_value = html_lib.escape(str(value))
                self.write_raw(f' {key}="{escaped_value}"')

    def write_document_start(self):
        """Write HTML5 doctype, head, CSS, and body opening"""
        css = self._get_css()

        html_start = f"""<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Shader Benchmark Report - {html_lib.escape(self.benchmark.summary.model_name)}</title>
    <style>
{css}
    </style>
</head>
<body>
    <div class="container">
"""
        self.write_raw(html_start)
        self.write_newline()
        self.indent_level = 2

    def write_document_end(self):
        """Close body and html tags"""
        self.indent_level = 1
        self.write_raw("""    </div>
</body>
</html>
""")

    def _get_css(self) -> str:
        """Get inline CSS for styling"""
        return """
        /* Reset and base styles */
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }

        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
            line-height: 1.6;
            color: #333;
            background-color: #f5f5f5;
        }

        .container {
            max-width: 1200px;
            margin: 0 auto;
            padding: 20px;
            background-color: white;
            box-shadow: 0 0 10px rgba(0,0,0,0.1);
        }

        /* Headers */
        h1 {
            color: #2c3e50;
            border-bottom: 3px solid #3498db;
            padding-bottom: 10px;
            margin-bottom: 20px;
            font-size: 2.5em;
        }

        h2 {
            color: #34495e;
            border-bottom: 2px solid #95a5a6;
            padding-bottom: 8px;
            margin-top: 30px;
            margin-bottom: 15px;
            font-size: 2em;
        }

        h3 {
            color: #2c3e50;
            margin-top: 25px;
            margin-bottom: 10px;
            font-size: 1.5em;
        }

        h4 {
            color: #34495e;
            margin-top: 20px;
            margin-bottom: 8px;
            font-size: 1.2em;
        }

        h5 {
            color: #7f8c8d;
            margin-top: 15px;
            margin-bottom: 5px;
            font-size: 1em;
        }

        /* Paragraphs */
        p {
            margin-bottom: 10px;
        }

        /* Sections */
        section {
            margin-bottom: 30px;
        }

        .report-header {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 30px;
            border-radius: 8px;
            margin-bottom: 30px;
        }

        .report-header h1 {
            color: white;
            border-bottom: 2px solid rgba(255,255,255,0.3);
        }

        .report-header p {
            color: rgba(255,255,255,0.9);
            font-size: 1.1em;
        }

        .summary-section {
            background-color: #ecf0f1;
            padding: 20px;
            border-radius: 8px;
            margin-bottom: 30px;
        }

        .test-result {
            background-color: #fff;
            border: 1px solid #ddd;
            border-radius: 8px;
            padding: 20px;
            margin-bottom: 20px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.05);
        }

        .test-result:target {
            background-color: #fff9e6;
            border-color: #f39c12;
        }

        .error-summary {
            background-color: #ffe6e6;
            border-left: 4px solid #e74c3c;
            padding: 15px;
            margin-bottom: 15px;
            border-radius: 4px;
        }

        /* Tables */
        table {
            width: 100%;
            border-collapse: collapse;
            margin: 15px 0;
            background-color: white;
            box-shadow: 0 1px 3px rgba(0,0,0,0.1);
        }

        thead {
            background-color: #3498db;
            color: white;
        }

        th, td {
            padding: 12px 15px;
            text-align: left;
            border-bottom: 1px solid #ddd;
        }

        tr:hover {
            background-color: #f8f9fa;
        }

        tbody tr:last-child td {
            border-bottom: none;
        }

        /* Images */
        img {
            max-width: 100%;
            height: auto;
            border: 1px solid #ddd;
            border-radius: 4px;
            margin: 15px 0;
            box-shadow: 0 2px 8px rgba(0,0,0,0.1);
        }

        /* Code blocks */
        pre {
            background-color: #2c3e50;
            color: #ecf0f1;
            padding: 15px;
            border-radius: 4px;
            overflow-x: auto;
            margin: 15px 0;
            font-family: 'Courier New', Courier, monospace;
            font-size: 0.9em;
            line-height: 1.4;
        }

        code {
            background-color: #2c3e50;
            color: #ecf0f1;
            padding: 2px 6px;
            border-radius: 3px;
            font-family: 'Courier New', Courier, monospace;
            font-size: 0.9em;
        }

        pre code {
            background-color: transparent;
            padding: 0;
        }

        /* Links */
        a {
            color: #3498db;
            text-decoration: none;
        }

        a:hover {
            color: #2980b9;
            text-decoration: underline;
        }

        /* Responsive design */
        @media (max-width: 768px) {
            .container {
                padding: 10px;
            }

            h1 {
                font-size: 2em;
            }

            h2 {
                font-size: 1.5em;
            }

            table {
                font-size: 0.9em;
            }

            th, td {
                padding: 8px 10px;
            }
        }

        /* Print styles */
        @media print {
            .container {
                max-width: 100%;
                box-shadow: none;
            }

            .test-result {
                page-break-inside: avoid;
            }
        }
"""

    def save(self):
        """Save buffer to file"""
        with open(self.output_file, 'w', encoding='utf-8') as f:
            f.write(''.join(self.buffer))


def hiccup_to_html(
    hiccup: HiccupNode,
    benchmark: BenchmarkRun,
    output_path: Path
) -> None:
    """
    Render hiccup structure to HTML format.

    Args:
        hiccup: Root hiccup node structure
        benchmark: Full benchmark data (for additional context)
        output_path: Path to write HTML file

    Output format:
        - Complete HTML5 document with <head> and <body>
        - Inline CSS for styling
        - Responsive design
        - Syntax highlighting for code blocks (via CSS)
    """
    writer = HTMLWriter(output_path, benchmark)
    writer.write_document_start()
    render_hiccup_node(hiccup, writer)
    writer.write_document_end()
    writer.save()


# ============================================================================
# Main Entry Point
# ============================================================================

def generate_report(benchmark_run: BenchmarkRun) -> Tuple[str, str]:
    """
    Main entry point for report generation.

    Args:
        benchmark_run: Complete benchmark run data

    Returns:
        Tuple of (markdown_path, html_path)
    """
    # Build hiccup structure
    hiccup = build_report_hiccup(benchmark_run)

    # Determine output paths
    if benchmark_run.output_directory:
        output_dir = benchmark_run.output_directory
    else:
        # Create default output directory
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        model_safe = benchmark_run.summary.model_name.replace('/', '_').replace(':', '_')
        output_dir = Path(f"harness_{model_safe}_{timestamp}")
        benchmark_run.output_directory = output_dir

    # Ensure output directory exists
    output_dir.mkdir(parents=True, exist_ok=True)

    # Render to Markdown
    md_path = output_dir / "all.md"
    hiccup_to_markdown(hiccup, benchmark_run, md_path)
    benchmark_run.markdown_report_path = md_path

    # Render to HTML
    html_path = output_dir / "all.html"
    hiccup_to_html(hiccup, benchmark_run, html_path)
    benchmark_run.html_report_path = html_path

    return (str(md_path), str(html_path))


def render_to_files(benchmark: BenchmarkRun, output_dir: Path) -> Tuple[Path, Path]:
    """
    Generate and write reports to files (compatibility wrapper)

    Args:
        benchmark: Complete benchmark run data
        output_dir: Directory to write reports

    Returns:
        Tuple of (markdown_path, html_path)
    """
    benchmark.output_directory = output_dir
    md_str, html_str = generate_report(benchmark)
    return (Path(md_str), Path(html_str))
