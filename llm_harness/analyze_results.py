#!/usr/bin/env python3
"""
Analysis script for shader benchmark test results.

This script analyzes all completed harness runs and generates a comprehensive
report on model performance, success rates, and execution patterns.

CRITICAL DOCUMENTATION:
- This script processes harness directories created by benchmark_harness.py
- Each harness run creates logs/ and checkpoints/ directories
- Results are aggregated by model and problem for analysis
- Logs contain detailed execution traces for debugging failures
"""

import json
import os
from pathlib import Path
from collections import defaultdict
from datetime import datetime
import re

class BenchmarkAnalyzer:
    """Analyze shader benchmark test results with comprehensive logging."""

    def __init__(self, harness_dir="/Users/nicholasbardy/git/shader_benchmark/llm_harness"):
        self.harness_dir = Path(harness_dir)
        self.results = {
            'total_runs': 0,
            'total_problems': 0,
            'by_model': defaultdict(lambda: {'runs': 0, 'problems': 0, 'success': 0}),
            'by_problem': defaultdict(lambda: {'runs': 0, 'success': 0}),
            'execution_times': [],
            'failures_by_stage': defaultdict(int),
        }

    def analyze(self):
        """Scan all harness directories and collect results."""
        print("🔍 Analyzing harness results...")

        harness_dirs = sorted([d for d in self.harness_dir.glob('harness_*') if d.is_dir()])
        print(f"Found {len(harness_dirs)} harness runs\n")

        for harness in harness_dirs:
            self._analyze_harness(harness)

        self._generate_report()

    def _analyze_harness(self, harness_path):
        """Analyze a single harness run."""
        # Extract model name from dirname
        dirname = harness_path.name  # e.g., "harness_anthropic_claude-3.5-sonnet_20251024_011837"
        parts = dirname.replace('harness_', '').split('_')

        # Reconstruct model name (everything before the timestamp)
        # Format: harness_MODEL_DATE_TIME where MODEL can have underscores
        # We identify timestamp by the pattern YYYYMMDD_HHMMSS
        timestamp_pattern = r'(\d{8}_\d{6})$'
        match = re.search(timestamp_pattern, dirname)

        if match:
            model = dirname[:match.start()].replace('harness_', '')
        else:
            model = "unknown"

        self.results['total_runs'] += 1
        self.results['by_model'][model]['runs'] += 1

        # Check for logs directory
        logs_dir = harness_path / 'logs'
        if logs_dir.exists():
            self._analyze_logs(logs_dir, model)

    def _analyze_logs(self, logs_dir, model):
        """Analyze execution summary log."""
        summary_log = logs_dir / 'execution_summary.log'

        if not summary_log.exists():
            return

        with open(summary_log, 'r') as f:
            content = f.read()

        # Count problems and extract success/failure
        start_pattern = r'\[.*\] START problem_(\d+): (\S+)'
        end_pattern = r'\[.*\] END problem_(\d+): \S+ - (SUCCESS|FAILURE)'

        starts = re.findall(start_pattern, content)
        ends = re.findall(end_pattern, content)

        for idx, problem_name in starts:
            self.results['total_problems'] += 1
            self.results['by_model'][model]['problems'] += 1
            self.results['by_problem'][problem_name]['runs'] += 1

        for idx, status in ends:
            if status == "SUCCESS":
                self.results['by_model'][model]['success'] += 1
                self.results['by_problem'][list(self.results['by_problem'].keys())[-1]]['success'] += 1

    def _generate_report(self):
        """Generate comprehensive analysis report."""
        print("\n" + "="*70)
        print("SHADER BENCHMARK ANALYSIS REPORT")
        print("="*70 + "\n")

        # Overall statistics
        print("📊 OVERALL STATISTICS")
        print("-" * 70)
        print(f"Total harness runs: {self.results['total_runs']}")
        print(f"Total problems executed: {self.results['total_problems']}")

        if self.results['total_problems'] > 0:
            overall_success = sum(m['success'] for m in self.results['by_model'].values())
            success_rate = (overall_success / self.results['total_problems']) * 100
            print(f"Overall success rate: {success_rate:.1f}% ({overall_success}/{self.results['total_problems']})\n")

        # By model
        print("📈 RESULTS BY MODEL")
        print("-" * 70)
        for model in sorted(self.results['by_model'].keys()):
            data = self.results['by_model'][model]
            rate = (data['success'] / data['problems'] * 100) if data['problems'] > 0 else 0
            print(f"{model}")
            print(f"  Runs: {data['runs']}, Problems: {data['problems']}, "
                  f"Success: {data['success']} ({rate:.1f}%)\n")

        # By problem
        if self.results['by_problem']:
            print("🎯 RESULTS BY PROBLEM")
            print("-" * 70)
            for problem in sorted(self.results['by_problem'].keys())[:10]:  # Top 10
                data = self.results['by_problem'][problem]
                rate = (data['success'] / data['runs'] * 100) if data['runs'] > 0 else 0
                print(f"{problem}: {data['success']}/{data['runs']} ({rate:.1f}%)")

if __name__ == '__main__':
    analyzer = BenchmarkAnalyzer()
    analyzer.analyze()
