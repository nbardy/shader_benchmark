#!/usr/bin/env python3
"""
Benchmark Harness - Tier 2
Runs multiple problems for a single LLM model and generates comprehensive report
"""

import argparse
import asyncio
import sys
import os
from pathlib import Path
from datetime import datetime
from typing import List, Dict
import subprocess
import json
from tqdm.asyncio import tqdm
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# Import pipeline components
from llm_client import LLMClient
from prompt_loader import PromptLoader
from shader_parser import ShaderParser
from test_runner import TestRunner
from judge import Judge
from debug_logger import DebugLogger

class BenchmarkHarness:
    def __init__(self, model: str, problems: List[str], max_parallel: int = 100, judge_model: str = "anthropic/claude-3.5-haiku", run_id: str = None):
        self.model = model
        self.judge_model = judge_model
        self.problems = problems
        self.max_parallel = max_parallel
        self.results = []
        self.start_time = None
        self.end_time = None

        # Generate or reuse run ID for checkpoint/resume
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        model_safe = self.model.replace('/', '_').replace(':', '_')
        self.run_id = run_id or f"harness_{model_safe}_{timestamp}"

        # Create directory structure
        self.run_dir = Path(self.run_id)
        self.run_dir.mkdir(parents=True, exist_ok=True)

        self.checkpoint_dir = self.run_dir / "checkpoints"
        self.checkpoint_dir.mkdir(parents=True, exist_ok=True)

        self.manifest_file = self.checkpoint_dir / "manifest.json"

        # Pipeline stage semaphores for resource optimization
        self.llm_semaphore = asyncio.Semaphore(max_parallel)  # LLM generation (API limited)
        self.compile_semaphore = asyncio.Semaphore(os.cpu_count() or 8)  # Compilation (CPU cores)
        self.render_semaphore = asyncio.Semaphore(4)  # Rendering (GPU slots)
        self.judge_semaphore = asyncio.Semaphore(50)  # Judge evaluation (API limited)

        # PRE-BUILD FIX: Create shared TestRunner for all problems
        # This ensures shader-bench binary is built once and reused across all problems
        #
        # CRITICAL: Do NOT create new TestRunner instances per-problem!
        # Creating new instances would cause:
        #   - Multiple prebuild compilations (slow)
        #   - Loss of shared binary path
        #   - Potential race conditions
        #
        # CORRECT PATTERN: One TestRunner for entire benchmark (reused by all problems)
        # See test_runner.py module docstring for architecture details
        self.test_runner = TestRunner(
            compile_semaphore=self.compile_semaphore,
            render_semaphore=self.render_semaphore
        )

        # Load checkpoints if resuming
        self.problem_checkpoints = self._load_checkpoints()

        # Initialize debug logger
        self.logger = DebugLogger(self.run_id, self.run_dir)
        self.logger.log_harness_init(self.model, self.problems, self.max_parallel)

    def _load_checkpoints(self) -> Dict[int, Dict]:
        """Load all problem checkpoints from checkpoints/ subfolder"""
        problem_checkpoints = {}

        # Load manifest if exists
        if self.manifest_file.exists():
            try:
                with open(self.manifest_file, 'r') as f:
                    manifest = json.load(f)
                    print(f"📂 Resuming run: {self.run_id}")
                    print(f"📋 Manifest loaded: {manifest.get('total_problems', 0)} problems")
            except Exception as e:
                print(f"⚠️ Failed to load manifest: {e}")

        # Load individual problem checkpoints
        for problem_file in self.checkpoint_dir.glob("problem_*.json"):
            try:
                with open(problem_file, 'r') as f:
                    problem_data = json.load(f)
                    problem_index = problem_data.get('problem_index')
                    if problem_index is not None:
                        problem_checkpoints[problem_index] = problem_data
            except Exception as e:
                print(f"⚠️ Failed to load {problem_file}: {e}")

        if problem_checkpoints:
            # Count stage completions
            generate_done = sum(1 for p in problem_checkpoints.values() if p.get('stages', {}).get('generate', {}).get('status') == 'complete')
            compile_done = sum(1 for p in problem_checkpoints.values() if p.get('stages', {}).get('compile', {}).get('status') == 'complete')
            render_done = sum(1 for p in problem_checkpoints.values() if p.get('stages', {}).get('render', {}).get('status') == 'complete')
            judge_done = sum(1 for p in problem_checkpoints.values() if p.get('stages', {}).get('judge', {}).get('status') == 'complete')

            print(f"✅ Stage completion: Generate={generate_done}, Compile={compile_done}, Render={render_done}, Judge={judge_done}")

        return problem_checkpoints

    def _save_manifest(self):
        """Save/update the manifest.json file"""
        manifest = {
            'run_id': self.run_id,
            'model': self.model,
            'judge_model': self.judge_model,
            'total_problems': len(self.problems),
            'problems': self.problems,
            'created': datetime.now().isoformat() if not self.manifest_file.exists() else None,
            'last_updated': datetime.now().isoformat()
        }

        # Preserve creation time if exists
        if self.manifest_file.exists():
            try:
                with open(self.manifest_file, 'r') as f:
                    existing = json.load(f)
                    manifest['created'] = existing.get('created', manifest['created'])
            except:
                pass

        try:
            temp_file = self.manifest_file.with_suffix('.tmp')
            with open(temp_file, 'w') as f:
                json.dump(manifest, f, indent=2, default=str)
            temp_file.replace(self.manifest_file)
        except Exception as e:
            print(f"⚠️ Failed to save manifest: {e}")

    def _get_problem_checkpoint_file(self, problem_index: int) -> Path:
        """Get checkpoint file path for a specific problem"""
        return self.checkpoint_dir / f"problem_{problem_index:03d}.json"

    def _save_stage_checkpoint(self, problem_index: int, stage_name: str, status: str, data: Dict = None):
        """Save checkpoint for a specific stage in per-problem file"""
        problem_name = self.problems[problem_index] if problem_index < len(self.problems) else 'unknown'

        # Log attempt
        self.logger.log_checkpoint_save_attempt(problem_index, problem_name, stage_name, status)

        checkpoint_file = self._get_problem_checkpoint_file(problem_index)

        # Load existing problem checkpoint
        problem_data = {}
        if checkpoint_file.exists():
            try:
                with open(checkpoint_file, 'r') as f:
                    problem_data = json.load(f)
            except:
                pass

        # Initialize if needed
        if 'stages' not in problem_data:
            problem_data = {
                'problem_index': problem_index,
                'problem_name': problem_name,
                'stages': {},
                'created': datetime.now().isoformat()
            }

        # Update stage
        problem_data['stages'][stage_name] = {
            'status': status,
            'timestamp': datetime.now().isoformat(),
            'data': data or {}
        }
        problem_data['last_updated'] = datetime.now().isoformat()

        # Save atomically
        try:
            temp_file = checkpoint_file.with_suffix('.tmp')
            with open(temp_file, 'w') as f:
                json.dump(problem_data, f, indent=2, default=str)
            temp_file.replace(checkpoint_file)

            # Update in-memory cache
            self.problem_checkpoints[problem_index] = problem_data

            # Update manifest
            self._save_manifest()

            # Log success
            self.logger.log_checkpoint_save_success(problem_index, problem_name, stage_name, checkpoint_file)
        except Exception as e:
            # Log failure with full traceback
            self.logger.log_checkpoint_save_failure(problem_index, problem_name, stage_name, e)
            print(f"⚠️ Failed to save checkpoint for problem {problem_index}: {e}")

    def _is_stage_complete(self, problem_index: int, stage_name: str) -> bool:
        """Check if a specific stage is already complete"""
        if problem_index not in self.problem_checkpoints:
            return False

        problem_data = self.problem_checkpoints[problem_index]
        stage_data = problem_data.get('stages', {}).get(stage_name, {})
        return stage_data.get('status') == 'complete'

    async def run_single_problem(self, problem: str, problem_index: int, pbar: tqdm = None) -> Dict:
        """Run full pipeline for a single problem with stage-level checkpointing"""
        # Log problem start
        self.logger.log_problem_start(problem_index, problem)

        # CRITICAL FIX: Use absolute path based on script location, not relative to CWD
        # This ensures problem directories are found regardless of where the script is invoked from
        script_dir = Path(__file__).parent.absolute()
        problem_path = script_dir.parent / "problems" / "base_set" / problem
        if not Path(problem_path).exists():
            self.logger.log_warning(problem_index, problem, f"Problem directory not found: {problem_path}")
            if pbar:
                pbar.update(1)
            return {'problem': problem, 'success': False, 'error': 'Problem directory not found', 'scores': [0, 0, 0, 0, 0]}

        start_time = datetime.now()

        # PRE-BUILD FIX: Use shared test_runner (created once in __init__)
        # This ensures shader-bench binary is built once and reused across all problems
        test_runner = self.test_runner

        # Initialize variables
        test_folder = None
        shaders = None
        main_rs = None
        result_image = None
        scores = [0, 0, 0, 0, 0]

        try:
            # Stage 1: LLM Generation
            if not self._is_stage_complete(problem_index, 'generate'):
                self.logger.log_stage_start(problem_index, problem, 'generate')
                async with self.llm_semaphore:
                    self._save_stage_checkpoint(problem_index, 'generate', 'in_progress')
                    try:
                        self.logger.log_info(problem_index, problem, "Loading request prompt")
                        prompt_loader = PromptLoader()
                        request_prompt = prompt_loader.load_request_prompt(str(problem_path))

                        self.logger.log_api_call(problem_index, problem, "LLM generation", f"model={self.model}")
                        llm_client = LLMClient()
                        llm_response = await llm_client.generate_shaders(self.model, request_prompt)
                        self.logger.log_api_response(problem_index, problem, "LLM generation", len(llm_response), True)

                        self.logger.log_info(problem_index, problem, "Parsing shader response")
                        shader_parser = ShaderParser()
                        shaders, main_rs = shader_parser.parse_response(llm_response)

                        self._save_stage_checkpoint(problem_index, 'generate', 'complete',
                                                    {'shaders': list(shaders.keys()), 'llm_response_len': len(llm_response)})
                        self.logger.log_stage_end(problem_index, problem, 'generate', True)
                    except Exception as e:
                        error_msg = str(e)[:500]
                        self.logger.log_exception(problem_index, problem, "generate stage", e)
                        self._save_stage_checkpoint(problem_index, 'generate', 'failed', {'error': error_msg})
                        self.logger.log_stage_end(problem_index, problem, 'generate', False)
                        print(f"❌ Generation stage failed for {problem}: {error_msg}")
                        raise
            else:
                # TODO: Load from checkpoint if needed
                raise RuntimeError("Resume from checkpoint not yet implemented")

            # Stage 2: Compile
            if not self._is_stage_complete(problem_index, 'compile'):
                test_folder = test_runner.create_test_folder()
                test_runner.setup_test_files(test_folder, shaders, main_rs)

                self._save_stage_checkpoint(problem_index, 'compile', 'in_progress', {'test_folder': str(test_folder)})
                compile_success, compile_msg = await test_runner.compile_shader(test_folder)

                if not compile_success:
                    self._save_stage_checkpoint(problem_index, 'compile', 'failed', {'error': compile_msg})
                    raise RuntimeError(compile_msg)

                self._save_stage_checkpoint(problem_index, 'compile', 'complete', {'test_folder': str(test_folder)})
            else:
                # TODO: Load test_folder from checkpoint
                raise RuntimeError("Resume from checkpoint not yet implemented")

            # Stage 3: Render
            if not self._is_stage_complete(problem_index, 'render'):
                self._save_stage_checkpoint(problem_index, 'render', 'in_progress')
                try:
                    result_image = await test_runner.render_shader(test_folder)
                    self._save_stage_checkpoint(problem_index, 'render', 'complete', {'image_path': str(result_image)})
                except Exception as e:
                    error_msg = str(e)[:500]
                    self._save_stage_checkpoint(problem_index, 'render', 'failed', {'error': error_msg})
                    print(f"❌ Render stage failed for {problem}: {error_msg}")
                    raise
            else:
                # TODO: Load result_image from checkpoint
                raise RuntimeError("Resume from checkpoint not yet implemented")

            # Stage 4: Judge
            if not self._is_stage_complete(problem_index, 'judge'):
                async with self.judge_semaphore:
                    self._save_stage_checkpoint(problem_index, 'judge', 'in_progress')
                    try:
                        judge = Judge(judge_model=self.judge_model)
                        critic_path = problem_path / 'critic.txt'
                        request_path = problem_path / 'request.txt'
                        scores = await judge.evaluate_with_template(critic_path, request_path, result_image, test_folder)
                        self._save_stage_checkpoint(problem_index, 'judge', 'complete', {'scores': scores})
                    except Exception as e:
                        error_msg = str(e)[:500]
                        self._save_stage_checkpoint(problem_index, 'judge', 'failed', {'error': error_msg})
                        print(f"❌ Judge stage failed for {problem}: {error_msg}")
                        raise
            else:
                # TODO: Load scores from checkpoint
                raise RuntimeError("Resume from checkpoint not yet implemented")

            # Save final results
            if test_folder:
                test_runner.save_results(test_folder, scores, True)

            end_time = datetime.now()
            execution_time = (end_time - start_time).total_seconds()

            # Log successful completion
            self.logger.log_problem_end(problem_index, problem, True, execution_time)

            if pbar:
                pbar.set_postfix_str(f"{problem}: {sum(scores)}/500")
                pbar.update(1)

            return {
                'problem': problem,
                'success': True,
                'scores': scores,
                'image_path': result_image if result_image and result_image.exists() else None,
                'test_dir': test_folder,
                'execution_time': execution_time
            }

        except Exception as e:
            end_time = datetime.now()
            execution_time = (end_time - start_time).total_seconds()

            # Log exception and failure
            self.logger.log_exception(problem_index, problem, "run_single_problem", e)
            self.logger.log_problem_end(problem_index, problem, False, execution_time)

            # Save error state
            if test_folder:
                test_runner.save_results(test_folder, [0, 0, 0, 0, 0], False)

            if pbar:
                pbar.update(1)

            return {
                'problem': problem,
                'success': False,
                'error': str(e)[:500],
                'scores': [0, 0, 0, 0, 0],
                'image_path': None,
                'execution_time': execution_time,
                'test_dir': test_folder
            }
    
    def generate_report(self) -> str:
        """Generate report using unified generate_report.py system"""
        # Get test directories from THIS harness run only
        test_dirs_from_this_run = []
        for result in self.results:
            if result.get('test_dir'):
                test_dirs_from_this_run.append(str(result['test_dir']))
        
        if not test_dirs_from_this_run:
            print("❌ No test directories found from this harness run")
            return None
            
        # Create isolated harness report directory
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        model_safe = self.model.replace('/', '_').replace(':', '_')
        harness_dir = f"harness_{model_safe}_{timestamp}"
        Path(harness_dir).mkdir(exist_ok=True)
        
        output_file = f"harness_report_{model_safe}_{timestamp}.md"
        
        # Use custom generate_report that only scans our specific test directories
        from generate_report import ReportGenerator
        generator = ReportGenerator(self.model)
        
        # Add only test directories from THIS harness run
        for test_dir in test_dirs_from_this_run:
            generator.add_test_result(test_dir)
            
        # Generate report in harness directory
        report_path = generator.generate_report(output_file, harness_dir)
        return report_path
    
    async def run_benchmark(self) -> str:
        """Run all problems and generate report"""
        # Count fully completed problems (all stages done)
        fully_completed = 0
        for i in range(len(self.problems)):
            if (self._is_stage_complete(i, 'generate') and
                self._is_stage_complete(i, 'compile') and
                self._is_stage_complete(i, 'render') and
                self._is_stage_complete(i, 'judge')):
                fully_completed += 1

        print(f"🎯 Benchmark Harness - Testing {self.model}")
        print(f"🆔 Run ID: {self.run_id}")
        print(f"📊 Total tests: {len(self.problems)}")
        print(f"✅ Fully completed: {fully_completed}")
        print(f"⏳ Remaining: {len(self.problems) - fully_completed}")
        print(f"🔄 Pipeline limits: LLM={self.max_parallel}, Compile={self.compile_semaphore._value}, Render={self.render_semaphore._value}, Judge={self.judge_semaphore._value}")
        print("=" * 60)

        # PRE-BUILD FIX: Build shader-bench binary once before running any problems
        print("🔨 Pre-building shader-bench binary...")
        try:
            await self.test_runner.prebuild_shader_binary()
            print("✅ Pre-build complete - binary ready for all problems")
        except Exception as e:
            print(f"❌ Pre-build failed: {e}")
            print("Cannot proceed without working shader-bench binary")
            raise

        self.start_time = datetime.now()

        # Run all problems in parallel with progress bar
        with tqdm(total=len(self.problems), desc="Running benchmarks", unit="test", initial=fully_completed) as pbar:
            tasks = [self.run_single_problem(problem, idx, pbar) for idx, problem in enumerate(self.problems)]
            # Use return_exceptions=True to capture all exceptions instead of raising first one
            results = await asyncio.gather(*tasks, return_exceptions=True)

        # Process results and log any exceptions
        processed_results = []
        for idx, result in enumerate(results):
            if isinstance(result, Exception):
                problem_name = self.problems[idx]
                print(f"❌ Problem {idx} ({problem_name}) raised exception: {type(result).__name__}: {result}")
                # Create a failure result for exceptions
                processed_results.append({
                    'problem': problem_name,
                    'success': False,
                    'error': f'{type(result).__name__}: {result}',
                    'scores': [0, 0, 0, 0, 0]
                })
            elif result is not None:
                processed_results.append(result)

        self.results = processed_results

        self.end_time = datetime.now()

        # Finalize logger
        self.logger.finalize()

        # Generate report
        report_path = self.generate_report()
        
        # Print summary
        successful = sum(1 for r in self.results if r['success'])
        total_time = (self.end_time - self.start_time).total_seconds()
        
        print("\n" + "=" * 60)
        print(f"🏁 Benchmark complete for {self.model}")
        print(f"✅ Success rate: {successful}/{len(self.problems)} ({successful/len(self.problems)*100:.1f}%)")
        print(f"⏱️  Total time: {total_time:.1f} seconds")
        print(f"📊 Report: {report_path}")
        
        return report_path

def main():
    parser = argparse.ArgumentParser(description='Shader Benchmark Harness - Tier 2 (Pipeline Parallel)')
    parser.add_argument('--model', required=True, help='LLM model to test')
    parser.add_argument('--judge-model', default='anthropic/claude-3.5-haiku',
                       help='Judge model for evaluation (default: anthropic/claude-3.5-haiku)')
    parser.add_argument('--problems', nargs='+', required=True,
                       help='List of problems to test (from problems/base_set/)')
    parser.add_argument('--max-parallel', type=int, default=100,
                       help='Maximum number of parallel LLM/judge calls (default: 100)')
    parser.add_argument('--run-id', type=str, default=None,
                       help='Run ID for checkpoint/resume (default: auto-generate)')

    args = parser.parse_args()

    harness = BenchmarkHarness(args.model, args.problems, args.max_parallel, args.judge_model, args.run_id)
    report_path = asyncio.run(harness.run_benchmark())

    print(f"\n📋 Benchmark report: {report_path}")
    print(f"🆔 Run ID: {harness.run_id} (use --run-id to resume)")

if __name__ == "__main__":
    main()