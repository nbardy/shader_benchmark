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
import base64
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
        """Check if result.png exists."""
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
        """Infer the problem name from shader files."""
        shader_files = list((self.test_dir / 'shaders').glob('*.wgsl')) if (self.test_dir / 'shaders').exists() else []
        if shader_files:
            # Extract problem name from shader filename
            shader_name = shader_files[0].stem
            # Convert underscores to spaces and title case
            return shader_name.replace('_', ' ').title()
        return "Unknown Problem"
        
    def _get_shader_files(self) -> List[str]:
        """Get list of shader files."""
        shader_dir = self.test_dir / 'shaders'
        if shader_dir.exists():
            return [f.name for f in shader_dir.glob('*.wgsl')]
        return []

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
        
    def scan_for_results(self, base_dir: str = ".") -> int:
        """Scan for test result directories and add them to the report."""
        pattern = os.path.join(base_dir, "test_*_results")
        test_dirs = glob.glob(pattern)
        
        for test_dir in sorted(test_dirs):
            self.add_test_result(test_dir)
            
        return len(test_dirs)
        
    def _embed_image(self, image_path: Path) -> str:
        """Convert image to base64 data URL for embedding in markdown."""
        if not image_path.exists():
            return "![Image not found]()"
            
        try:
            with open(image_path, 'rb') as f:
                image_data = f.read()
            base64_data = base64.b64encode(image_data).decode('utf-8')
            return f"![Rendered Output](data:image/png;base64,{base64_data})"
        except Exception as e:
            return f"![Error loading image: {e}]()"
            
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
            table += f"| {category} | {score}/10 |\n"
        
        total = sum(scores)
        avg = total / len(scores)
        table += f"| **Total** | **{total}/50** |\n"
        table += f"| **Average** | **{avg:.1f}/10** |\n"
        
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
        
    def generate_report(self, output_file: str = None, embed_images: bool = False) -> str:
        """Generate the complete markdown report."""
        if output_file is None:
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            output_file = f"shader_benchmark_report_{self.model_name.replace('/', '_')}_{timestamp}.md"
            
        report_dir = Path(output_file).parent
        report_dir.mkdir(exist_ok=True)
        
        # Sort results by timestamp (newest first) or test_id if no timestamp
        self.results.sort(key=lambda r: r.timestamp or datetime.min, reverse=True)
        
        # Calculate summary statistics
        stats = self._calculate_summary_stats()
        
        # Generate report content
        report = self._generate_header(stats)
        report += self._generate_summary_section(stats)
        report += self._generate_detailed_results(report_dir, embed_images)
        
        # Write report to file
        with open(output_file, 'w') as f:
            f.write(report)
            
        return output_file
        
    def _generate_header(self, stats: Dict) -> str:
        """Generate the report header."""
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        
        return f"""# Shader Benchmark Report

**Model:** {self.model_name}  
**Generated:** {timestamp}  
**Total Tests:** {stats['total_tests']}  
**Successful Renders:** {stats['successful_renders']}  
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
                section += f"| {category} | {avg_score:.1f}/10 |\n"
            
            total_avg = sum(stats['avg_scores'])
            overall_avg = total_avg / len(stats['avg_scores'])
            section += f"| **Overall Average** | **{overall_avg:.1f}/10** |\n\n"
            
            # Best and worst performing tests
            if stats['best_test'] and stats['worst_test']:
                section += "### Performance Highlights\n\n"
                section += f"**Best Test:** {stats['best_test'].problem_name} "
                section += f"(Total: {sum(stats['best_test'].scores)}/50)  \n"
                section += f"**Worst Test:** {stats['worst_test'].problem_name} "
                section += f"(Total: {sum(stats['worst_test'].scores)}/50)  \n\n"
        else:
            section += "*No scored tests available for statistical analysis.*\n\n"
            
        section += "---\n\n"
        return section
        
    def _generate_detailed_results(self, report_dir: Path, embed_images: bool) -> str:
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
            
            # Add scores table if available
            if result.scores:
                section += "#### Judge Scores\n\n"
                section += self._format_scores_table(result.scores) + "\n\n"
                
            # Add image
            if result.has_image:
                section += "#### Rendered Output\n\n"
                image_path = result.test_dir / 'result.png'
                
                if embed_images:
                    section += self._embed_image(image_path) + "\n\n"
                else:
                    # Copy image to report directory
                    relative_path = self._copy_image_to_report_dir(image_path, report_dir, result.test_id)
                    if relative_path:
                        section += f"![Rendered Output]({relative_path})\n\n"
                    else:
                        section += "*Error: Could not copy image*\n\n"
            else:
                section += "#### Rendered Output\n\n*No image available (compilation or execution failed)*\n\n"
                
            section += "---\n\n"
            
        return section

def main():
    """Main entry point for the report generator."""
    parser = argparse.ArgumentParser(description='Generate shader benchmark reports')
    parser.add_argument('--model', '-m', type=str, default='Unknown Model',
                       help='Name of the model being reported on')
    parser.add_argument('--output', '-o', type=str, 
                       help='Output markdown file (default: auto-generated)')
    parser.add_argument('--embed-images', action='store_true',
                       help='Embed images as base64 data URLs instead of copying files')
    parser.add_argument('--scan-dir', type=str, default='.',
                       help='Directory to scan for test results (default: current directory)')
    
    args = parser.parse_args()
    
    # Create report generator
    generator = ReportGenerator(args.model)
    
    # Scan for test results
    found_tests = generator.scan_for_results(args.scan_dir)
    print(f"Found {found_tests} test result directories")
    
    if found_tests == 0:
        print("No test results found. Make sure you're in the directory containing test_*_results folders.")
        return
        
    # Generate report
    output_file = generator.generate_report(args.output, args.embed_images)
    print(f"Report generated: {output_file}")
    
    # Print summary
    stats = generator._calculate_summary_stats()
    print(f"\nSummary:")
    print(f"  Total tests: {stats['total_tests']}")
    print(f"  Successful renders: {stats['successful_renders']}")
    print(f"  Scored tests: {stats['scored_tests']}")
    
    if stats['avg_scores']:
        overall_avg = sum(stats['avg_scores']) / len(stats['avg_scores'])
        print(f"  Overall average score: {overall_avg:.1f}/10")

if __name__ == '__main__':
    main()