#!/usr/bin/env python3
"""
Experiment Runner - Ablation Study Orchestration
Runs systematic ablation experiments and generates comparative reports
"""

import asyncio
import sys
import os
from pathlib import Path
from datetime import datetime
from typing import List, Dict, Optional
import json
import subprocess
from dataclasses import dataclass, asdict
import shutil

# Add parent directory to path for imports
sys.path.insert(0, str(Path(__file__).parent.parent))

from experiment_config import ExperimentConfig, create_baseline_config
from benchmark_harness import BenchmarkHarness


@dataclass
class ExperimentResults:
    """Results from a single experiment run"""
    experiment_id: str
    config: ExperimentConfig
    run_id: str
    start_time: str
    end_time: str
    duration_seconds: float
    total_problems: int
    successful_problems: int
    failed_problems: int
    success_rate: float
    average_scores: Dict[str, float]  # S1, S2, S3, S4, S5, total
    problem_results: List[Dict]
    errors_by_stage: Dict[str, int]
    performance_metrics: Dict[str, float]

    def to_dict(self) -> Dict:
        """Convert to dictionary for JSON serialization"""
        result = asdict(self)
        result['config'] = self.config.to_dict()
        return result

    def save_to_json(self, output_path: str):
        """Save results to JSON file"""
        with open(output_path, 'w') as f:
            json.dump(self.to_dict(), f, indent=2)

    @classmethod
    def load_from_json(cls, input_path: str) -> 'ExperimentResults':
        """Load results from JSON file"""
        with open(input_path, 'r') as f:
            data = json.load(f)

        # Reconstruct config
        data['config'] = ExperimentConfig.from_dict(data['config'])
        return cls(**data)


@dataclass
class ComparativeReport:
    """Comparative analysis of multiple experiments"""
    baseline_experiment: str
    comparison_experiments: List[str]
    timestamp: str
    summary_table: Dict[str, Dict]  # experiment_id -> metrics
    insights: List[str]
    recommendations: List[str]

    def to_markdown(self) -> str:
        """Generate markdown report"""
        lines = [
            "# Ablation Experiment Comparative Report",
            "",
            f"**Generated**: {self.timestamp}",
            f"**Baseline**: {self.baseline_experiment}",
            "",
            "## Executive Summary",
            ""
        ]

        # Summary table
        lines.extend([
            "| Experiment | Success Rate | Avg Total Score | S1 (Math) | S2 (Visual) | Duration | Status |",
            "|------------|--------------|-----------------|-----------|-------------|----------|--------|"
        ])

        for exp_id, metrics in self.summary_table.items():
            lines.append(
                f"| {exp_id} | "
                f"{metrics['success_rate']:.1f}% | "
                f"{metrics['avg_total_score']:.1f}/500 | "
                f"{metrics['avg_s1']:.1f}/100 | "
                f"{metrics['avg_s2']:.1f}/100 | "
                f"{metrics['duration_hours']:.2f}h | "
                f"{metrics['status']} |"
            )

        lines.extend(["", "## Key Insights", ""])
        for i, insight in enumerate(self.insights, 1):
            lines.append(f"{i}. {insight}")

        lines.extend(["", "## Recommendations", ""])
        for i, rec in enumerate(self.recommendations, 1):
            lines.append(f"{i}. {rec}")

        return "\n".join(lines)

    def save_to_markdown(self, output_path: str):
        """Save report to markdown file"""
        with open(output_path, 'w') as f:
            f.write(self.to_markdown())


class ExperimentRunner:
    """Orchestrates ablation experiments and generates comparative reports"""

    def __init__(self,
                 model: str = "anthropic/claude-3.5-sonnet-20241022",
                 judge_model: str = "anthropic/claude-3.5-haiku",
                 max_parallel: int = 2,
                 results_dir: str = "experiment_results"):
        """Initialize experiment runner

        Args:
            model: LLM model to use for shader generation
            judge_model: LLM model to use for evaluation
            max_parallel: Maximum parallel problem executions
            results_dir: Directory to store all experiment results
        """
        self.model = model
        self.judge_model = judge_model
        self.max_parallel = max_parallel
        self.results_dir = Path(results_dir)
        self.results_dir.mkdir(parents=True, exist_ok=True)

        # Track experiment results
        self.experiment_results: Dict[str, ExperimentResults] = {}

    async def run_experiment(self,
                            config: ExperimentConfig,
                            force_rerun: bool = False) -> ExperimentResults:
        """Execute single experiment with specified configuration

        Args:
            config: Experiment configuration
            force_rerun: If True, run even if results exist

        Returns:
            ExperimentResults with comprehensive metrics
        """
        print(f"\n{'='*80}")
        print(f"STARTING EXPERIMENT: {config.name}")
        print(f"{'='*80}")
        print(f"ID: {config.experiment_id}")
        print(f"Hypothesis: {config.hypothesis}")
        print(f"Variations: {config.get_variant_description()}")
        print(f"Problems: {len(config.problems_to_test)}")
        print(f"Estimated runtime: {config.expected_runtime_hours:.1f} hours")
        print(f"{'='*80}\n")

        # Check if results already exist
        results_file = self.results_dir / f"{config.experiment_id}_results.json"
        if results_file.exists() and not force_rerun:
            print(f"⚠️  Results already exist at {results_file}")
            print(f"    Loading existing results (use force_rerun=True to override)")
            return ExperimentResults.load_from_json(str(results_file))

        # Validate configuration files exist
        missing_files = config.validate_files_exist()
        if missing_files:
            print(f"❌ ERROR: Missing required files:")
            for f in missing_files:
                print(f"   - {f}")
            raise FileNotFoundError(f"Experiment {config.experiment_id} references missing files")

        start_time = datetime.now()
        start_time_str = start_time.isoformat()

        # TODO: Apply experiment configuration to pipeline
        # This requires modifying benchmark_harness to accept configuration overrides
        # For now, we'll run with standard configuration and document the limitation

        print(f"🚀 Running benchmark harness...")
        print(f"   Model: {self.model}")
        print(f"   Judge: {self.judge_model}")
        print(f"   Parallelism: {self.max_parallel}")

        # Create harness with experiment-specific run_id
        run_id = f"exp_{config.experiment_id}_{start_time.strftime('%Y%m%d_%H%M%S')}"
        harness = BenchmarkHarness(
            model=self.model,
            problems=config.problems_to_test,
            max_parallel=self.max_parallel,
            judge_model=self.judge_model,
            run_id=run_id
        )

        # Run the benchmark
        # NOTE: Currently benchmark_harness doesn't support all config overrides
        # Future enhancement: Pass config to harness for language_spec, constraints, etc.
        results = await harness.run_benchmark()

        end_time = datetime.now()
        end_time_str = end_time.isoformat()
        duration = (end_time - start_time).total_seconds()

        # Analyze results
        experiment_results = self._analyze_results(
            config=config,
            run_id=run_id,
            start_time=start_time_str,
            end_time=end_time_str,
            duration=duration,
            benchmark_results=results
        )

        # Save results
        experiment_results.save_to_json(str(results_file))
        print(f"\n✅ Experiment complete: {config.experiment_id}")
        print(f"   Results saved to: {results_file}")
        print(f"   Success rate: {experiment_results.success_rate:.1f}%")
        print(f"   Avg score: {experiment_results.average_scores['total']:.1f}/500")
        print(f"   Duration: {duration/3600:.2f} hours")

        return experiment_results

    def _analyze_results(self,
                        config: ExperimentConfig,
                        run_id: str,
                        start_time: str,
                        end_time: str,
                        duration: float,
                        benchmark_results: List[Dict]) -> ExperimentResults:
        """Analyze benchmark results and compute experiment metrics

        Args:
            config: Experiment configuration
            run_id: Unique run identifier
            start_time: ISO timestamp of start
            end_time: ISO timestamp of end
            duration: Duration in seconds
            benchmark_results: Raw results from benchmark harness

        Returns:
            ExperimentResults with computed metrics
        """
        total_problems = len(benchmark_results)
        successful_problems = sum(1 for r in benchmark_results if r.get('success', False))
        failed_problems = total_problems - successful_problems
        success_rate = (successful_problems / total_problems * 100) if total_problems > 0 else 0.0

        # Compute average scores
        scores = {
            's1': [],
            's2': [],
            's3': [],
            's4': [],
            's5': [],
            'total': []
        }

        for result in benchmark_results:
            if 'scores' in result and result['scores']:
                result_scores = result['scores']
                scores['s1'].append(result_scores.get('s1', 0))
                scores['s2'].append(result_scores.get('s2', 0))
                scores['s3'].append(result_scores.get('s3', 0))
                scores['s4'].append(result_scores.get('s4', 0))
                scores['s5'].append(result_scores.get('s5', 0))
                total = sum([
                    result_scores.get('s1', 0),
                    result_scores.get('s2', 0),
                    result_scores.get('s3', 0),
                    result_scores.get('s4', 0),
                    result_scores.get('s5', 0)
                ])
                scores['total'].append(total)

        average_scores = {
            's1': sum(scores['s1']) / len(scores['s1']) if scores['s1'] else 0.0,
            's2': sum(scores['s2']) / len(scores['s2']) if scores['s2'] else 0.0,
            's3': sum(scores['s3']) / len(scores['s3']) if scores['s3'] else 0.0,
            's4': sum(scores['s4']) / len(scores['s4']) if scores['s4'] else 0.0,
            's5': sum(scores['s5']) / len(scores['s5']) if scores['s5'] else 0.0,
            'total': sum(scores['total']) / len(scores['total']) if scores['total'] else 0.0
        }

        # Count errors by stage
        errors_by_stage = {
            'generate': 0,
            'compile': 0,
            'render': 0,
            'judge': 0
        }

        for result in benchmark_results:
            if 'error_stage' in result and result['error_stage']:
                stage = result['error_stage']
                if stage in errors_by_stage:
                    errors_by_stage[stage] += 1

        # Performance metrics
        compile_times = [r.get('compile_time', 0) for r in benchmark_results if 'compile_time' in r]
        render_times = [r.get('render_time', 0) for r in benchmark_results if 'render_time' in r]

        performance_metrics = {
            'avg_compile_time': sum(compile_times) / len(compile_times) if compile_times else 0.0,
            'avg_render_time': sum(render_times) / len(render_times) if render_times else 0.0,
            'total_duration_hours': duration / 3600
        }

        return ExperimentResults(
            experiment_id=config.experiment_id,
            config=config,
            run_id=run_id,
            start_time=start_time,
            end_time=end_time,
            duration_seconds=duration,
            total_problems=total_problems,
            successful_problems=successful_problems,
            failed_problems=failed_problems,
            success_rate=success_rate,
            average_scores=average_scores,
            problem_results=benchmark_results,
            errors_by_stage=errors_by_stage,
            performance_metrics=performance_metrics
        )

    async def run_all_experiments(self,
                                 experiment_configs: List[ExperimentConfig],
                                 include_baseline: bool = True,
                                 force_rerun: bool = False) -> ComparativeReport:
        """Run multiple experiments and generate comparative report

        Args:
            experiment_configs: List of experiment configurations
            include_baseline: If True, run baseline configuration first
            force_rerun: If True, rerun even if results exist

        Returns:
            ComparativeReport with analysis and recommendations
        """
        print("\n" + "="*80)
        print("ABLATION EXPERIMENT BATCH EXECUTION")
        print("="*80)
        print(f"Total experiments: {len(experiment_configs) + (1 if include_baseline else 0)}")
        print("="*80 + "\n")

        results = {}

        # Run baseline first if requested
        if include_baseline:
            baseline_config = create_baseline_config()
            baseline_results = await self.run_experiment(baseline_config, force_rerun)
            results[baseline_config.experiment_id] = baseline_results

        # Run all experiments
        for config in experiment_configs:
            exp_results = await self.run_experiment(config, force_rerun)
            results[config.experiment_id] = exp_results

        # Generate comparative report
        report = self.generate_comparative_report(results)

        # Save report
        report_path = self.results_dir / f"comparative_report_{datetime.now().strftime('%Y%m%d_%H%M%S')}.md"
        report.save_to_markdown(str(report_path))
        print(f"\n📊 Comparative report saved to: {report_path}")

        return report

    def generate_comparative_report(self,
                                   results: Dict[str, ExperimentResults]) -> ComparativeReport:
        """Generate comparative report from experiment results

        Args:
            results: Dictionary mapping experiment_id to ExperimentResults

        Returns:
            ComparativeReport with analysis and recommendations
        """
        print("\n🔬 Generating comparative analysis...")

        # Build summary table
        summary_table = {}
        baseline_id = "baseline"
        baseline_results = results.get(baseline_id)

        for exp_id, exp_results in results.items():
            summary_table[exp_id] = {
                'success_rate': exp_results.success_rate,
                'avg_total_score': exp_results.average_scores['total'],
                'avg_s1': exp_results.average_scores['s1'],
                'avg_s2': exp_results.average_scores['s2'],
                'avg_s3': exp_results.average_scores['s3'],
                'avg_s4': exp_results.average_scores['s4'],
                'avg_s5': exp_results.average_scores['s5'],
                'duration_hours': exp_results.performance_metrics['total_duration_hours'],
                'status': '✅ Complete'
            }

        # Generate insights
        insights = []
        recommendations = []

        if baseline_results:
            baseline_score = baseline_results.average_scores['total']
            baseline_success = baseline_results.success_rate

            for exp_id, exp_results in results.items():
                if exp_id == baseline_id:
                    continue

                score_diff = exp_results.average_scores['total'] - baseline_score
                success_diff = exp_results.success_rate - baseline_success

                if abs(score_diff) > 10:  # Significant difference
                    direction = "higher" if score_diff > 0 else "lower"
                    insights.append(
                        f"{exp_results.config.name}: {abs(score_diff):.1f} points {direction} "
                        f"than baseline ({score_diff:+.1f} change)"
                    )

                    if score_diff > 0:
                        recommendations.append(
                            f"Consider adopting {exp_results.config.get_variant_description()} - "
                            f"shows {score_diff:+.1f} point improvement"
                        )

                if abs(success_diff) > 5:  # Significant difference
                    direction = "higher" if success_diff > 0 else "lower"
                    insights.append(
                        f"{exp_results.config.name}: {abs(success_diff):.1f}% {direction} "
                        f"success rate ({success_diff:+.1f}% change)"
                    )

        # Add hypothesis validation insights
        for exp_id, exp_results in results.items():
            if exp_id == baseline_id:
                continue

            config = exp_results.config
            insights.append(
                f"Hypothesis for {config.name}: {config.hypothesis}"
            )

        if not insights:
            insights.append("No significant differences observed between experiments")

        if not recommendations:
            recommendations.append("Baseline configuration appears optimal for current test set")

        return ComparativeReport(
            baseline_experiment=baseline_id if baseline_results else "none",
            comparison_experiments=[k for k in results.keys() if k != baseline_id],
            timestamp=datetime.now().isoformat(),
            summary_table=summary_table,
            insights=insights,
            recommendations=recommendations
        )

    def load_experiment_results(self, experiment_id: str) -> Optional[ExperimentResults]:
        """Load previously saved experiment results

        Args:
            experiment_id: ID of experiment to load

        Returns:
            ExperimentResults if found, None otherwise
        """
        results_file = self.results_dir / f"{experiment_id}_results.json"
        if results_file.exists():
            return ExperimentResults.load_from_json(str(results_file))
        return None


async def main():
    """CLI entry point for running experiments"""
    import argparse

    parser = argparse.ArgumentParser(description="Run ablation experiments")
    parser.add_argument("--config", type=str, help="Path to experiment config YAML")
    parser.add_argument("--experiment-dir", type=str, help="Directory containing all experiment configs")
    parser.add_argument("--model", type=str, default="anthropic/claude-3.5-sonnet-20241022",
                       help="LLM model for shader generation")
    parser.add_argument("--judge-model", type=str, default="anthropic/claude-3.5-haiku",
                       help="LLM model for evaluation")
    parser.add_argument("--max-parallel", type=int, default=2,
                       help="Maximum parallel problem executions")
    parser.add_argument("--force-rerun", action="store_true",
                       help="Rerun experiments even if results exist")
    parser.add_argument("--no-baseline", action="store_true",
                       help="Skip baseline run")

    args = parser.parse_args()

    runner = ExperimentRunner(
        model=args.model,
        judge_model=args.judge_model,
        max_parallel=args.max_parallel
    )

    if args.config:
        # Run single experiment
        config = ExperimentConfig.load_from_yaml(args.config)
        await runner.run_experiment(config, force_rerun=args.force_rerun)

    elif args.experiment_dir:
        # Run all experiments in directory
        exp_dir = Path(args.experiment_dir)
        configs = []

        for config_file in sorted(exp_dir.glob("*/config.yaml")):
            configs.append(ExperimentConfig.load_from_yaml(str(config_file)))

        await runner.run_all_experiments(
            configs,
            include_baseline=not args.no_baseline,
            force_rerun=args.force_rerun
        )

    else:
        print("Error: Must specify either --config or --experiment-dir")
        parser.print_help()
        sys.exit(1)


if __name__ == "__main__":
    asyncio.run(main())
