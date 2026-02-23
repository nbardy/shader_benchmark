#!/usr/bin/env python3
"""
Shader Benchmark Report Generator

Generates comprehensive markdown reports from test results for a given model.
Includes judge scores, rendered images, and summary statistics.
"""

import os
import json
import glob
import argparse
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Optional, Tuple
import shutil

class TestResult:
    """Represents a single test result with all available data."""
    
    def __init__(self, test_dir: str):
        self.test_dir = Path(test_dir)
        self.test_id = self._extract_test_id()
        self.timestamp = self._get_timestamp()
        self.has_image = self._check_image_exists()
        self.has_scores = self._check_scores_exist()
        self.scores = self._load_scores()
        self.execution_success = self._load_execution_success()
        self.problem_name = self._infer_problem_name()
        self.shader_files = self._get_shader_files()
        self.prompt_text = self._load_prompt_text()
        
    def _extract_test_id(self) -> str:
        """Extract UUID from directory name."""
        dir_name = self.test_dir.name
        if dir_name.startswith('test_') and dir_name.endswith('_results'):
            return dir_name[5:-8]  # Remove 'test_' prefix and '_results' suffix
        return dir_name
        
    def _get_timestamp(self) -> Optional[datetime]:
        """Get timestamp from result.png file if it exists."""
        result_png = self.test_dir / 'result.png'
        if result_png.exists():
            timestamp = result_png.stat().st_mtime
            return datetime.fromtimestamp(timestamp)
        return None
        
    def _check_image_exists(self) -> bool:
        """Check if result.png exists in test directory or artifacts folder."""
        # Check for result.png in artifacts folder (new location)
        artifacts_png = self.test_dir / 'artifacts' / 'result.png'
        if artifacts_png.exists():
            return True
        # Check for result.png in test directory (legacy location)
        return (self.test_dir / 'result.png').exists()
        
    def _check_scores_exist(self) -> bool:
        """Check if results.json exists."""
        return (self.test_dir / 'results.json').exists()
        
    def _load_scores(self) -> Optional[List[int]]:
        """Load scores from results.json if available."""
        results_file = self.test_dir / 'results.json'
        if results_file.exists():
            try:
                with open(results_file, 'r') as f:
                    data = json.load(f)
                    scores = data.get('scores', None)
                    # Filter out zero scores (failed executions)
                    if scores and all(score == 0 for score in scores):
                        return None
                    return scores
            except (json.JSONDecodeError, FileNotFoundError):
                pass
        return None
        
    def _load_execution_success(self) -> bool:
        """Load execution success status from results.json if available."""
        results_file = self.test_dir / 'results.json'
        if results_file.exists():
            try:
                with open(results_file, 'r') as f:
                    data = json.load(f)
                    return data.get('execution_success', self.has_image)
            except (json.JSONDecodeError, FileNotFoundError):
                pass
        return self.has_image
        
    def _infer_problem_name(self) -> str:
        """Infer the problem name from directory structure.

        Priority:
        1. Directory name format: NNN_problem_name (e.g., 000_ackermann_function_growth)
        2. Fallback to shader filename if directory name doesn't match pattern
        """
        dir_name = self.test_dir.name

        # Check for NNN_problem_name format (e.g., "007_binary_tree_fractal")
        if len(dir_name) >= 4 and dir_name[:3].isdigit() and dir_name[3] == '_':
            # Extract problem name after the NNN_ prefix
            problem_name = dir_name[4:]  # Skip "NNN_"
            # Convert underscores to spaces and title case
            return problem_name.replace('_', ' ').title()

        # Fallback: try shader filename (legacy behavior)
        if (self.test_dir / 'shaders').exists():
            shader_files = list((self.test_dir / 'shaders').glob('*.glsl')) + list((self.test_dir / 'shaders').glob('*.wgsl'))
            if shader_files:
                shader_name = shader_files[0].stem
                # Skip if filename is generic "shader"
                if shader_name.lower() != 'shader':
                    return shader_name.replace('_', ' ').title()

        return "Unknown Problem"

    def _get_shader_files(self) -> List[str]:
        """Get list of shader files (both .glsl and .wgsl)."""
        shader_dir = self.test_dir / 'shaders'
        if shader_dir.exists():
            glsl_files = [f.name for f in shader_dir.glob('*.glsl')]
            wgsl_files = [f.name for f in shader_dir.glob('*.wgsl')]
            return glsl_files + wgsl_files
        return []

    def _load_prompt_text(self) -> Optional[str]:
        """Load the problem prompt/request text."""
        # Try llm_request.txt first (the actual prompt sent to LLM)
        request_file = self.test_dir / 'llm_request.txt'
        if request_file.exists():
            try:
                return request_file.read_text().strip()
            except Exception:
                pass

        # Fallback: try to find original request.txt from problem folder
        # The problem name can be inferred from the test_id (e.g., "000_geometric_cube")
        dir_name = self.test_dir.name
        if dir_name.startswith(('000_', '001_', '002_', '003_', '004_', '005_', '006_', '007_', '008_', '009_')):
            # New format: NNN_problem_name
            problem_name = '_'.join(dir_name.split('_')[1:])
        else:
            problem_name = None

        if problem_name:
            # Try relative path to problems folder
            for problems_base in ['../problems/base_set', '../../problems/base_set']:
                request_path = self.test_dir / problems_base / problem_name / 'request.txt'
                if request_path.exists():
                    try:
                        return request_path.read_text().strip()
                    except Exception:
                        pass

        return None

class ReportGenerator:
    """Generates markdown reports from test results."""
    
    SCORE_CATEGORIES = [
        "Mathematical Accuracy",
        "Visual Quality", 
        "Color Implementation",
        "Geometric Completeness",
        "Reference Elements"
    ]
    
    def __init__(self, model_name: str = "Unknown Model"):
        self.model_name = model_name
        self.results: List[TestResult] = []
        
    def add_test_result(self, test_dir: str):
        """Add a test result directory to the report."""
        result = TestResult(test_dir)
        self.results.append(result)
        
    def scan_for_results(self, base_dir: str = ".", single_test_dir: str = None) -> int:
        """Scan for test result directories and add them to the report."""
        if single_test_dir:
            # Single directory mode: only scan the specified directory
            if Path(single_test_dir).exists():
                self.add_test_result(single_test_dir)
                return 1
            else:
                print(f"Warning: Test directory not found: {single_test_dir}")
                return 0
        else:
            # Multi-directory mode: scan for all test directories (legacy behavior)
            pattern = os.path.join(base_dir, "test_*_results")
            test_dirs = glob.glob(pattern)
            
            for test_dir in sorted(test_dirs):
                self.add_test_result(test_dir)
                
            return len(test_dirs)
        
            
    def _copy_image_to_report_dir(self, image_path: Path, report_dir: Path, test_id: str) -> str:
        """Copy image to report directory and return relative path."""
        if not image_path.exists():
            return ""
            
        try:
            # Create images subdirectory
            images_dir = report_dir / "images"
            images_dir.mkdir(exist_ok=True)
            
            # Copy image with test_id in filename
            dest_path = images_dir / f"{test_id}_result.png"
            shutil.copy2(image_path, dest_path)
            
            # Return relative path for markdown
            return f"images/{test_id}_result.png"
        except Exception as e:
            return ""
            
    def _format_scores_table(self, scores: List[int]) -> str:
        """Format scores as a markdown table."""
        if not scores or len(scores) != 5:
            return "| Category | Score |\n|----------|-------|\n| *No scores available* | - |"
            
        table = "| Category | Score |\n|----------|-------|\n"
        for category, score in zip(self.SCORE_CATEGORIES, scores):
            table += f"| {category} | {score}/100 |\n"
        
        total = sum(scores)
        avg = total / len(scores)
        table += f"| **Total** | **{total}/500** |\n"
        table += f"| **Average** | **{avg:.1f}/100** |\n"
        
        return table
        
    def _calculate_summary_stats(self) -> Dict:
        """Calculate summary statistics across all tests."""
        scored_results = [r for r in self.results if r.scores]
        
        if not scored_results:
            return {
                'total_tests': len(self.results),
                'scored_tests': 0,
                'successful_renders': sum(1 for r in self.results if r.has_image),
                'avg_scores': None,
                'best_test': None,
                'worst_test': None
            }
            
        # Calculate average scores by category
        avg_scores = []
        for i in range(5):
            category_scores = [r.scores[i] for r in scored_results]
            avg_scores.append(sum(category_scores) / len(category_scores))
            
        # Find best and worst tests by total score
        best_test = max(scored_results, key=lambda r: sum(r.scores))
        worst_test = min(scored_results, key=lambda r: sum(r.scores))
        
        return {
            'total_tests': len(self.results),
            'scored_tests': len(scored_results),
            'successful_renders': sum(1 for r in self.results if r.has_image),
            'avg_scores': avg_scores,
            'best_test': best_test,
            'worst_test': worst_test
        }
        
    def generate_report(self, output_file: str = None, target_dir: str = None) -> str:
        """Generate the complete markdown report in isolated UUID directory or target directory."""
        import uuid
        
        if target_dir:
            # Use existing target directory (for single test runs)
            report_dir = Path(target_dir)
            if not report_dir.exists():
                report_dir.mkdir(exist_ok=True)
            
            if output_file is None:
                output_file = "current_results_report.md"
        else:
            # Create isolated report directory with timestamp and UUID (for batch reports)
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            report_uuid = str(uuid.uuid4())
            report_dir_name = f"report_{timestamp}_{report_uuid}"
            report_dir = Path(report_dir_name)
            report_dir.mkdir(exist_ok=True)
            
            if output_file is None:
                timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
                output_file = f"shader_benchmark_report_{self.model_name.replace('/', '_')}_{timestamp}.md"
            
        # Report file goes inside the target directory
        output_path = report_dir / output_file
        
        # Sort results by timestamp (newest first) or test_id if no timestamp
        self.results.sort(key=lambda r: r.timestamp or datetime.min, reverse=True)
        
        # Calculate summary statistics
        stats = self._calculate_summary_stats()
        
        # Generate report content
        report = self._generate_header(stats)
        report += self._generate_summary_section(stats)
        report += self._generate_detailed_results(report_dir)
        
        # Write report to file in UUID directory
        with open(output_path, 'w') as f:
            f.write(report)

        # Also generate HTML version
        html_output_path = output_path.with_suffix('.html')
        html_report = self._generate_html_report(stats, report_dir)
        with open(html_output_path, 'w') as f:
            f.write(html_report)

        print(f"Report generated in isolated directory: {report_dir}")
        print(f"Markdown: {output_path}")
        print(f"HTML: {html_output_path}")
        return str(output_path)
        
    def _generate_header(self, stats: Dict) -> str:
        """Generate the report header."""
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        
        return f"""# Shader Benchmark Report

**Model:** {self.model_name}
**Generated:** {timestamp}
**Total Tests:** {stats['total_tests']}
**Successful Renders:** {stats['successful_renders']}
**Success Rate:** {stats['successful_renders']}/{stats['total_tests']} ({100*stats['successful_renders']/max(stats['total_tests'],1):.1f}%)
**Scored Tests:** {stats['scored_tests']}  

---

"""
        
    def _generate_summary_section(self, stats: Dict) -> str:
        """Generate the summary statistics section."""
        section = "## Summary Statistics\n\n"
        
        if stats['avg_scores']:
            section += "### Average Scores by Category\n\n"
            section += "| Category | Average Score |\n|----------|---------------|\n"
            for category, avg_score in zip(self.SCORE_CATEGORIES, stats['avg_scores']):
                section += f"| {category} | {avg_score:.1f}/100 |\n"
            
            total_avg = sum(stats['avg_scores'])
            overall_avg = total_avg / len(stats['avg_scores'])
            section += f"| **Overall Average** | **{overall_avg:.1f}/100** |\n\n"
            
            # Best and worst performing tests
            if stats['best_test'] and stats['worst_test']:
                section += "### Performance Highlights\n\n"
                section += f"**Best Test:** {stats['best_test'].problem_name} "
                section += f"(Total: {sum(stats['best_test'].scores)}/500)  \n"
                section += f"**Worst Test:** {stats['worst_test'].problem_name} "
                section += f"(Total: {sum(stats['worst_test'].scores)}/500)  \n\n"
        else:
            section += "*No scored tests available for statistical analysis.*\n\n"
            
        section += "---\n\n"
        return section
        
    def _generate_detailed_results(self, report_dir: Path) -> str:
        """Generate the detailed results section."""
        section = "## Detailed Test Results\n\n"
        
        if not self.results:
            section += "*No test results found.*\n"
            return section
            
        for i, result in enumerate(self.results, 1):
            section += f"### Test {i}: {result.problem_name}\n\n"
            section += f"**Test ID:** `{result.test_id}`  \n"
            
            if result.timestamp:
                section += f"**Timestamp:** {result.timestamp.strftime('%Y-%m-%d %H:%M:%S')}  \n"
                
            section += f"**Shader Files:** {', '.join(result.shader_files) if result.shader_files else 'None'}  \n"
            section += f"**Execution Status:** {'✅ Success' if result.execution_success else '❌ Failed'}  \n"
            section += f"**Image Generated:** {'✅ Yes' if result.has_image else '❌ No'}  \n"
            section += f"**Judge Scores:** {'✅ Available' if result.has_scores else '❌ Not Available'}  \n\n"

            # Add prompt/request text
            if result.prompt_text:
                section += "#### Problem Prompt\n\n"
                section += f"> {result.prompt_text.replace(chr(10), chr(10) + '> ')}\n\n"

            # Add scores table if available
            if result.scores:
                section += "#### Judge Scores\n\n"
                section += self._format_scores_table(result.scores) + "\n\n"
                
            # Add image
            if result.has_image:
                section += "#### Rendered Output\n\n"
                # Check for result.png in artifacts folder first, then test directory
                artifacts_png = result.test_dir / 'artifacts' / 'result.png'
                if artifacts_png.exists():
                    image_path = artifacts_png
                else:
                    image_path = result.test_dir / 'result.png'
                
                # Copy image to report directory and embed inline
                relative_path = self._copy_image_to_report_dir(image_path, report_dir, result.test_id)
                if relative_path:
                    section += f"![Rendered Output]({relative_path})\n\n"
                else:
                    section += "*Error: Could not copy image*\n\n"
            else:
                section += "#### Rendered Output\n\n*No image available (compilation or execution failed)*\n\n"
                
            section += "---\n\n"

        return section

    def _generate_html_report(self, stats: Dict, report_dir: Path) -> str:
        """Generate complete HTML report with embedded styles."""
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

        html = f'''<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Shader Benchmark Report - {self.model_name}</title>
    <style>
        :root {{
            --bg-primary: #0d1117;
            --bg-secondary: #161b22;
            --bg-tertiary: #21262d;
            --text-primary: #c9d1d9;
            --text-secondary: #8b949e;
            --accent: #58a6ff;
            --success: #3fb950;
            --warning: #d29922;
            --error: #f85149;
            --border: #30363d;
        }}
        * {{ box-sizing: border-box; margin: 0; padding: 0; }}
        body {{
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, sans-serif;
            background: var(--bg-primary);
            color: var(--text-primary);
            line-height: 1.6;
            padding: 2rem;
        }}
        .container {{ max-width: 1400px; margin: 0 auto; }}
        header {{
            background: var(--bg-secondary);
            padding: 2rem;
            border-radius: 12px;
            margin-bottom: 2rem;
            border: 1px solid var(--border);
        }}
        h1 {{ color: var(--accent); margin-bottom: 1rem; font-size: 2rem; }}
        h2 {{ color: var(--text-primary); margin: 2rem 0 1rem; border-bottom: 1px solid var(--border); padding-bottom: 0.5rem; }}
        h3 {{ color: var(--text-secondary); margin: 1.5rem 0 0.75rem; }}
        h4 {{ color: var(--accent); margin: 1rem 0 0.5rem; font-size: 1rem; }}
        .meta {{ color: var(--text-secondary); font-size: 0.9rem; }}
        .meta span {{ margin-right: 2rem; }}
        .stats-grid {{
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 1rem;
            margin: 1rem 0;
        }}
        .stat-card {{
            background: var(--bg-tertiary);
            padding: 1rem;
            border-radius: 8px;
            text-align: center;
            border: 1px solid var(--border);
        }}
        .stat-value {{ font-size: 2rem; font-weight: bold; color: var(--accent); }}
        .stat-label {{ color: var(--text-secondary); font-size: 0.85rem; }}
        table {{
            width: 100%;
            border-collapse: collapse;
            margin: 1rem 0;
            background: var(--bg-secondary);
            border-radius: 8px;
            overflow: hidden;
        }}
        th, td {{ padding: 0.75rem 1rem; text-align: left; border-bottom: 1px solid var(--border); }}
        th {{ background: var(--bg-tertiary); color: var(--text-secondary); font-weight: 600; }}
        tr:hover {{ background: var(--bg-tertiary); }}
        .test-card {{
            background: var(--bg-secondary);
            border-radius: 12px;
            padding: 1.5rem;
            margin: 1.5rem 0;
            border: 1px solid var(--border);
        }}
        .test-header {{
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 1rem;
            flex-wrap: wrap;
            gap: 0.5rem;
        }}
        .test-title {{ font-size: 1.25rem; color: var(--text-primary); }}
        .badge {{
            padding: 0.25rem 0.75rem;
            border-radius: 20px;
            font-size: 0.8rem;
            font-weight: 500;
        }}
        .badge-success {{ background: rgba(63, 185, 80, 0.2); color: var(--success); }}
        .badge-error {{ background: rgba(248, 81, 73, 0.2); color: var(--error); }}
        .prompt-box {{
            background: var(--bg-tertiary);
            border-left: 3px solid var(--accent);
            padding: 1rem;
            margin: 1rem 0;
            border-radius: 0 8px 8px 0;
            font-size: 0.9rem;
            white-space: pre-wrap;
            max-height: 300px;
            overflow-y: auto;
        }}
        .image-container {{
            margin: 1rem 0;
            text-align: center;
        }}
        .image-container img {{
            max-width: 100%;
            max-height: 600px;
            border-radius: 8px;
            border: 1px solid var(--border);
        }}
        .score-bar {{
            display: flex;
            align-items: center;
            margin: 0.25rem 0;
        }}
        .score-label {{ width: 180px; color: var(--text-secondary); font-size: 0.9rem; }}
        .score-track {{
            flex: 1;
            height: 8px;
            background: var(--bg-tertiary);
            border-radius: 4px;
            overflow: hidden;
            margin: 0 1rem;
        }}
        .score-fill {{
            height: 100%;
            border-radius: 4px;
            transition: width 0.3s ease;
        }}
        .score-value {{ width: 60px; text-align: right; font-weight: 500; }}
        .no-image {{
            background: var(--bg-tertiary);
            padding: 3rem;
            text-align: center;
            color: var(--text-secondary);
            border-radius: 8px;
        }}
        /* Image Gallery Styles */
        .gallery-section {{
            background: var(--bg-secondary);
            border-radius: 12px;
            margin: 2rem 0;
            border: 1px solid var(--border);
            overflow: hidden;
        }}
        .gallery-header {{
            display: flex;
            justify-content: space-between;
            align-items: center;
            padding: 1rem 1.5rem;
            background: var(--bg-tertiary);
            cursor: pointer;
            user-select: none;
        }}
        .gallery-header:hover {{
            background: #2d333b;
        }}
        .gallery-title {{
            font-size: 1.25rem;
            color: var(--text-primary);
            display: flex;
            align-items: center;
            gap: 0.5rem;
        }}
        .gallery-toggle {{
            font-size: 1.5rem;
            color: var(--text-secondary);
            transition: transform 0.3s ease;
        }}
        .gallery-toggle.collapsed {{
            transform: rotate(-90deg);
        }}
        .gallery-content {{
            padding: 1.5rem;
            display: grid;
            grid-template-columns: repeat(auto-fill, minmax(280px, 1fr));
            gap: 1rem;
            max-height: 800px;
            overflow-y: auto;
        }}
        .gallery-content.collapsed {{
            display: none;
        }}
        .gallery-item {{
            position: relative;
            aspect-ratio: 1;
            border-radius: 8px;
            overflow: hidden;
            border: 1px solid var(--border);
            background: var(--bg-tertiary);
        }}
        .gallery-item img {{
            width: 100%;
            height: 100%;
            object-fit: cover;
            transition: transform 0.3s ease;
        }}
        .gallery-item:hover img {{
            transform: scale(1.05);
        }}
        .gallery-item-overlay {{
            position: absolute;
            bottom: 0;
            left: 0;
            right: 0;
            background: linear-gradient(transparent, rgba(0,0,0,0.8));
            padding: 1rem 0.75rem 0.75rem;
            color: white;
        }}
        .gallery-item-title {{
            font-size: 0.85rem;
            font-weight: 500;
            white-space: nowrap;
            overflow: hidden;
            text-overflow: ellipsis;
        }}
        .gallery-item-score {{
            font-size: 0.75rem;
            opacity: 0.8;
        }}
        .gallery-item-failed {{
            display: flex;
            align-items: center;
            justify-content: center;
            color: var(--error);
            font-size: 0.9rem;
        }}
    </style>
</head>
<body>
    <div class="container">
        <header>
            <h1>Shader Benchmark Report</h1>
            <div class="meta">
                <span><strong>Model:</strong> {self.model_name}</span>
                <span><strong>Generated:</strong> {timestamp}</span>
            </div>
        </header>

        <div class="stats-grid">
            <div class="stat-card">
                <div class="stat-value">{stats['total_tests']}</div>
                <div class="stat-label">Total Tests</div>
            </div>
            <div class="stat-card">
                <div class="stat-value">{stats['successful_renders']}/{stats['total_tests']}</div>
                <div class="stat-label">Successful Renders</div>
            </div>
            <div class="stat-card">
                <div class="stat-value">{100*stats['successful_renders']/max(stats['total_tests'],1):.0f}%</div>
                <div class="stat-label">Success Rate</div>
            </div>
            <div class="stat-card">
                <div class="stat-value">{stats['scored_tests']}</div>
                <div class="stat-label">Scored Tests</div>
            </div>
'''

        if stats['avg_scores']:
            overall_avg = sum(stats['avg_scores']) / len(stats['avg_scores'])
            html += f'''            <div class="stat-card">
                <div class="stat-value">{overall_avg:.1f}</div>
                <div class="stat-label">Average Score /100</div>
            </div>
'''

        html += '''        </div>

        <div class="gallery-section">
            <div class="gallery-header" onclick="toggleGallery()">
                <span class="gallery-title">Image Gallery</span>
                <span class="gallery-toggle" id="galleryToggle">▼</span>
            </div>
            <div class="gallery-content" id="galleryContent">
'''

        # Add gallery items for each result
        for i, result in enumerate(self.results, 1):
            if result.has_image:
                # Find the image path
                artifacts_png = result.test_dir / 'artifacts' / 'result.png'
                legacy_png = result.test_dir / 'result.png'
                if artifacts_png.exists():
                    img_path = artifacts_png
                else:
                    img_path = legacy_png

                # Calculate relative path from report directory
                try:
                    rel_path = os.path.relpath(img_path, report_dir)
                except ValueError:
                    rel_path = str(img_path)

                total_score = sum(result.scores) if result.scores else 0
                score_text = f"{total_score}/500" if result.scores else "No score"

                html += f'''                <div class="gallery-item">
                    <img src="{rel_path}" alt="{result.problem_name}" loading="lazy">
                    <div class="gallery-item-overlay">
                        <div class="gallery-item-title">{result.problem_name}</div>
                        <div class="gallery-item-score">{score_text}</div>
                    </div>
                </div>
'''
            else:
                html += f'''                <div class="gallery-item gallery-item-failed">
                    <div>
                        <div class="gallery-item-title" style="color: var(--error);">{result.problem_name}</div>
                        <div style="font-size: 2rem; margin: 0.5rem 0;">✗</div>
                        <div class="gallery-item-score">Render Failed</div>
                    </div>
                </div>
'''

        html += '''            </div>
        </div>

        <h2>Summary Statistics</h2>
'''

        if stats['avg_scores']:
            html += '''        <table>
            <thead>
                <tr><th>Category</th><th>Average Score</th></tr>
            </thead>
            <tbody>
'''
            for category, avg_score in zip(self.SCORE_CATEGORIES, stats['avg_scores']):
                html += f'                <tr><td>{category}</td><td>{avg_score:.1f}/100</td></tr>\n'

            total_avg = sum(stats['avg_scores'])
            overall_avg = total_avg / len(stats['avg_scores'])
            html += f'                <tr><td><strong>Overall Average</strong></td><td><strong>{overall_avg:.1f}/100</strong></td></tr>\n'
            html += '''            </tbody>
        </table>
'''

        html += '''
        <h2>Detailed Test Results</h2>
'''

        for i, result in enumerate(self.results, 1):
            status_badge = 'badge-success' if result.execution_success else 'badge-error'
            status_text = '✓ Success' if result.execution_success else '✗ Failed'

            html += f'''
        <div class="test-card">
            <div class="test-header">
                <span class="test-title">Test {i}: {result.problem_name}</span>
                <span class="badge {status_badge}">{status_text}</span>
            </div>
            <div class="meta">
                <span><strong>Test ID:</strong> {result.test_id}</span>
                <span><strong>Shaders:</strong> {', '.join(result.shader_files) if result.shader_files else 'None'}</span>
            </div>
'''

            # Add prompt
            if result.prompt_text:
                escaped_prompt = result.prompt_text.replace('<', '&lt;').replace('>', '&gt;')
                html += f'''
            <h4>Problem Prompt</h4>
            <div class="prompt-box">{escaped_prompt}</div>
'''

            # Add scores with visual bars
            if result.scores:
                html += '''            <h4>Judge Scores</h4>
'''
                for cat, score in zip(self.SCORE_CATEGORIES, result.scores):
                    color = f'hsl({score * 1.2}, 70%, 50%)'  # Red to green gradient
                    html += f'''            <div class="score-bar">
                <span class="score-label">{cat}</span>
                <div class="score-track">
                    <div class="score-fill" style="width: {score}%; background: {color};"></div>
                </div>
                <span class="score-value">{score}/100</span>
            </div>
'''
                total = sum(result.scores)
                html += f'''            <div class="score-bar" style="margin-top: 0.5rem; font-weight: bold;">
                <span class="score-label">Total</span>
                <div class="score-track">
                    <div class="score-fill" style="width: {total/5}%; background: var(--accent);"></div>
                </div>
                <span class="score-value">{total}/500</span>
            </div>
'''

            # Add image
            if result.has_image:
                artifacts_png = result.test_dir / 'artifacts' / 'result.png'
                if artifacts_png.exists():
                    image_path = artifacts_png
                else:
                    image_path = result.test_dir / 'result.png'
                relative_path = self._copy_image_to_report_dir(image_path, report_dir, result.test_id)
                if relative_path:
                    html += f'''
            <h4>Rendered Output</h4>
            <div class="image-container">
                <img src="{relative_path}" alt="Rendered output for {result.problem_name}">
            </div>
'''
            else:
                html += '''
            <h4>Rendered Output</h4>
            <div class="no-image">No image available (compilation or execution failed)</div>
'''

            html += '''        </div>
'''

        html += '''
    </div>
    <script>
        function toggleGallery() {
            const content = document.getElementById('galleryContent');
            const toggle = document.getElementById('galleryToggle');
            content.classList.toggle('collapsed');
            toggle.classList.toggle('collapsed');
        }
    </script>
</body>
</html>'''

        return html

def main():
    """Main entry point for the report generator."""
    parser = argparse.ArgumentParser(description='Generate shader benchmark reports')
    parser.add_argument('--model', '-m', type=str, default='Unknown Model',
                       help='Name of the model being reported on')
    parser.add_argument('--output', '-o', type=str, 
                       help='Output markdown file (default: auto-generated)')
    parser.add_argument('--scan-dir', type=str, default='.',
                       help='Directory to scan for test results (default: current directory)')
    parser.add_argument('--test-dir', type=str,
                       help='Single test directory to generate report for (enables isolated mode)')
    
    args = parser.parse_args()
    
    # Create report generator
    generator = ReportGenerator(args.model)
    
    # Scan for test results
    if args.test_dir:
        # Single test directory mode
        found_tests = generator.scan_for_results(single_test_dir=args.test_dir)
        print(f"Scanning single test directory: {args.test_dir}")
        target_dir = args.test_dir
    else:
        # Multi-directory mode (legacy)
        found_tests = generator.scan_for_results(args.scan_dir)
        print(f"Found {found_tests} test result directories")
        target_dir = None
    
    if found_tests == 0:
        if args.test_dir:
            print(f"Test directory not found: {args.test_dir}")
        else:
            print("No test results found. Make sure you're in the directory containing test_*_results folders.")
        return
        
    # Generate report
    output_file = generator.generate_report(args.output, target_dir)
    print(f"Report generated: {output_file}")
    
    # Print summary
    stats = generator._calculate_summary_stats()
    print(f"\nSummary:")
    print(f"  Total tests: {stats['total_tests']}")
    print(f"  Successful renders: {stats['successful_renders']}")
    print(f"  Scored tests: {stats['scored_tests']}")
    
    if stats['avg_scores']:
        overall_avg = sum(stats['avg_scores']) / len(stats['avg_scores'])
        print(f"  Overall average score: {overall_avg:.1f}/100")

if __name__ == '__main__':
    main()