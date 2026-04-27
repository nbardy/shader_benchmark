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
from judge import Judge, EvaluationContext
from debug_logger import DebugLogger
from language_specs import get_language_spec
from runtimes import get_runtime, default_runtime_for_language

class BenchmarkHarness:
    def __init__(self, model: str, problems: List[str], max_parallel: int = 100, judge_model: str = "anthropic/claude-opus-4-6", run_id: str = None, language: str = "wgsl", runtime: str = None):
        self.model = model
        self.judge_model = judge_model
        self.problems = problems
        self.max_parallel = max_parallel
        self.language = language
        self.runtime_name = runtime  # None → derive from language
        self.results = []
        self.start_time = None
        self.end_time = None

        # Generate or reuse run ID for checkpoint/resume
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        model_safe = self.model.replace('/', '_').replace(':', '_')

        # NEW STRUCTURE: Use UUID for run uniqueness
        import uuid
        run_uuid = str(uuid.uuid4())[:8]  # Short UUID prefix
        self.run_id = run_id or f"{run_uuid}_{model_safe}_{timestamp}"

        # CRITICAL: Directory naming convention used throughout the system
        # Pattern: benchmark_run_output/{run_id}_{model}_{timestamp}/
        #
        # Components that depend on this pattern:
        # - analyze_results.py: Scans for this pattern to find benchmark runs
        # - README.md: Documents this structure for users
        # - .gitignore: Excludes benchmark_run_output/ from version control
        #
        # If you change this pattern, search codebase for "benchmark_run_output" and update:
        # 1. analyze_results.py glob patterns and model name extraction
        # 2. README.md output structure documentation
        # 3. Any reporting/analysis scripts that scan for results

        # NEW STRUCTURE: Create directory structure under benchmark_run_output/
        # CRITICAL: Use absolute path so it remains valid after os.chdir() calls
        script_dir = Path(__file__).parent.absolute()
        self.benchmark_output_root = script_dir / "benchmark_run_output"
        self.benchmark_output_root.mkdir(parents=True, exist_ok=True)

        self.run_dir = (self.benchmark_output_root / self.run_id).resolve()
        self.run_dir.mkdir(parents=True, exist_ok=True)

        # Create results subdirectory
        self.results_dir = self.run_dir / "results"
        self.results_dir.mkdir(parents=True, exist_ok=True)

        self.checkpoint_dir = self.run_dir / "checkpoints"
        self.checkpoint_dir.mkdir(parents=True, exist_ok=True)

        self.manifest_file = self.checkpoint_dir / "manifest.json"

        self.config_file = self.run_dir / "config.json"

        # Pipeline stage semaphores for resource optimization.
        # CLI judges (cli/codex, cli/claude) spawn local subprocesses, each
        # holding hundreds of MB of node/agent state, so 50 concurrent would
        # crush the host. Cap at 4 when the judge is a CLI; OpenRouter
        # judges keep the higher API-bound limit.
        self.llm_semaphore = asyncio.Semaphore(max_parallel)
        self.compile_semaphore = asyncio.Semaphore(os.cpu_count() or 8)
        self.render_semaphore = asyncio.Semaphore(4)
        judge_concurrency = 4 if self.judge_model.startswith("cli/") else 50
        self.judge_semaphore = asyncio.Semaphore(judge_concurrency)

        # Get language specification
        self.language_spec = get_language_spec(self.language)

        # Resolve runtime: explicit --runtime wins, otherwise derive from language.
        if self.runtime_name:
            self.runtime = get_runtime(self.runtime_name)
        else:
            self.runtime = default_runtime_for_language(self.language_spec)

        # Save config AFTER runtime is resolved so it's recorded for resume.
        self._save_config()

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
            render_semaphore=self.render_semaphore,
            language_spec=self.language_spec,
            runtime=self.runtime,
        )

        # Load checkpoints if resuming
        self.problem_checkpoints = self._load_checkpoints()

        # Initialize debug logger
        self.logger = DebugLogger(self.run_id, self.run_dir)
        self.logger.log_harness_init(self.model, self.problems, self.max_parallel)

    def _save_config(self):
        """Save configuration file at run root"""
        config = {
            'run_id': self.run_id,
            'model': self.model,
            'judge_model': self.judge_model,
            'language': self.language,
            'runtime': self.runtime.name if hasattr(self, 'runtime') and self.runtime else None,
            'problems': self.problems,
            'total_problems': len(self.problems),
            'max_parallel': self.max_parallel,
            'created': datetime.now().isoformat()
        }

        try:
            with open(self.config_file, 'w') as f:
                json.dump(config, f, indent=2, default=str)
        except Exception as e:
            print(f"⚠️ Failed to save config: {e}")

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

    def _get_stage_data(self, problem_index: int, stage_name: str) -> Dict:
        """Get the saved data for a completed stage"""
        if problem_index not in self.problem_checkpoints:
            return {}

        problem_data = self.problem_checkpoints[problem_index]
        stage_data = problem_data.get('stages', {}).get(stage_name, {})
        return stage_data.get('data', {})

    def _is_problem_fully_complete(self, problem_index: int) -> bool:
        """Check if all four stages of a problem are complete"""
        return (self._is_stage_complete(problem_index, 'generate') and
                self._is_stage_complete(problem_index, 'compile') and
                self._is_stage_complete(problem_index, 'render') and
                self._is_stage_complete(problem_index, 'judge'))

    async def run_single_problem(self, problem: str, problem_index: int, pbar: tqdm = None) -> Dict:
        """Run full pipeline for a single problem with stage-level checkpointing"""
        # RESUME OPTIMIZATION: If all stages are complete, return cached results immediately
        # This avoids re-parsing/re-loading files for fully completed problems
        if self._is_problem_fully_complete(problem_index):
            self.logger.log_info(problem_index, problem, "Problem fully complete - returning cached results")

            # Load all cached data from checkpoints
            compile_data = self._get_stage_data(problem_index, 'compile')
            render_data = self._get_stage_data(problem_index, 'render')
            judge_data = self._get_stage_data(problem_index, 'judge')

            test_folder = Path(compile_data.get('test_folder', '')) if compile_data.get('test_folder') else None
            result_image = Path(render_data.get('image_path', '')) if render_data.get('image_path') else None
            scores = judge_data.get('scores', [0, 0, 0, 0, 0])
            failure_reason = judge_data.get('failure_reason')

            if pbar:
                pbar.set_postfix_str(f"{problem}: {sum(scores)}/500 (cached)")
                pbar.update(1)

            result = {
                'problem': problem,
                'success': True,
                'scores': scores,
                'image_path': result_image if result_image and result_image.exists() else None,
                'test_dir': test_folder,
                'execution_time': 0,  # Cached result
                'resumed_from_checkpoint': True
            }
            if failure_reason:
                result['failure_reason'] = failure_reason
            return result

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
        llm_response = None  # Store LLM response for saving later
        generation_usage = None  # Cost tracking for generation
        judge_usage = None  # Cost tracking for judging

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

                        reference_image_path = problem_path / "reference.png"
                        ref_img_str = str(reference_image_path) if reference_image_path.exists() else None

                        self.logger.log_api_call(problem_index, problem, "LLM generation", f"model={self.model}, language={self.language}")
                        llm_client = LLMClient(language_spec=self.language_spec)
                        llm_response, generation_usage = await llm_client.generate_shaders(self.model, request_prompt, ref_img_str)
                        self.logger.log_api_response(problem_index, problem, "LLM generation", len(llm_response), True)
                        self.logger.log_info(problem_index, problem, f"Generation cost: ${generation_usage.get('cost', 0):.4f} ({generation_usage.get('total_tokens', 0)} tokens)")

                        self.logger.log_info(problem_index, problem, "Parsing shader response")
                        shader_parser = ShaderParser(language_spec=self.language_spec)
                        shaders, main_rs = shader_parser.parse_response(llm_response)

                        self._save_stage_checkpoint(problem_index, 'generate', 'complete',
                                                    {'shaders': list(shaders.keys()), 'llm_response_len': len(llm_response),
                                                     'generation_usage': generation_usage})
                        self.logger.log_stage_end(problem_index, problem, 'generate', True)
                    except Exception as e:
                        error_msg = str(e)[:500]
                        self.logger.log_exception(problem_index, problem, "generate stage", e)
                        # Save LLM response even on failure for debugging
                        if llm_response:
                            try:
                                problem_result_dir = self.results_dir / f"{problem_index:03d}_{problem}"
                                problem_result_dir.mkdir(parents=True, exist_ok=True)
                                response_path = problem_result_dir / "llm_response.txt"
                                with open(response_path, 'w') as f:
                                    f.write(llm_response)
                                self.logger.log_info(problem_index, problem, f"Saved failed LLM response to {response_path}")
                            except Exception as save_err:
                                self.logger.log_info(problem_index, problem, f"Failed to save LLM response: {save_err}")
                        self._save_stage_checkpoint(problem_index, 'generate', 'failed', {'error': error_msg})
                        self.logger.log_stage_end(problem_index, problem, 'generate', False)
                        print(f"❌ Generation stage failed for {problem}: {error_msg}")
                        raise
            else:
                # RESUME: Load shaders from saved llm_response.txt file
                self.logger.log_info(problem_index, problem, "Resuming from checkpoint - loading saved LLM response")
                problem_result_dir = self.results_dir / f"{problem_index:03d}_{problem}"
                response_path = problem_result_dir / "llm_response.txt"

                if response_path.exists():
                    with open(response_path, 'r') as f:
                        llm_response = f.read()
                    shader_parser = ShaderParser(language_spec=self.language_spec)
                    shaders, main_rs = shader_parser.parse_response(llm_response)
                    self.logger.log_info(problem_index, problem, f"Loaded {len(shaders)} shaders from checkpoint")

                    # Load usage data from checkpoint if available
                    stage_data = self._get_stage_data(problem_index, 'generate')
                    generation_usage = stage_data.get('generation_usage', {'cost': 0, 'total_tokens': 0})
                else:
                    raise RuntimeError(f"Cannot resume: llm_response.txt not found at {response_path}")

            # Stage 2: Compile
            if not self._is_stage_complete(problem_index, 'compile'):
                # NEW STRUCTURE: Create problem-specific directory under results/
                problem_result_dir = self.results_dir / f"{problem_index:03d}_{problem}"
                problem_result_dir.mkdir(parents=True, exist_ok=True)

                # Save LLM request (prompt) and response
                request_path = problem_result_dir / "llm_request.txt"
                response_path = problem_result_dir / "llm_response.txt"
                try:
                    # Save the original request prompt
                    prompt_loader = PromptLoader()
                    original_prompt = prompt_loader.load_request_prompt(str(problem_path))
                    with open(request_path, 'w') as f:
                        f.write(original_prompt)
                    # Save the LLM response
                    with open(response_path, 'w') as f:
                        f.write(llm_response)
                except Exception as e:
                    print(f"⚠️ Failed to save LLM prompt/response: {e}")

                # Use the problem directory as the test folder
                test_folder = problem_result_dir
                test_runner.setup_test_files(test_folder, shaders, main_rs)

                self._save_stage_checkpoint(problem_index, 'compile', 'in_progress', {'test_folder': str(test_folder)})
                compile_success, compile_msg = await test_runner.compile_shader(test_folder)

                if not compile_success:
                    self._save_stage_checkpoint(problem_index, 'compile', 'failed', {'error': compile_msg})
                    raise RuntimeError(compile_msg)

                self._save_stage_checkpoint(problem_index, 'compile', 'complete', {'test_folder': str(test_folder)})
            else:
                # RESUME: Load test_folder from checkpoint
                stage_data = self._get_stage_data(problem_index, 'compile')
                test_folder_str = stage_data.get('test_folder')
                if test_folder_str:
                    test_folder = Path(test_folder_str)
                    if not test_folder.exists():
                        raise RuntimeError(f"Cannot resume: test_folder not found at {test_folder}")
                    self.logger.log_info(problem_index, problem, f"Resuming from checkpoint - compile stage complete, test_folder: {test_folder}")
                else:
                    raise RuntimeError(f"Cannot resume: test_folder not saved in compile checkpoint")

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
                # RESUME: Load result_image path from checkpoint
                stage_data = self._get_stage_data(problem_index, 'render')
                image_path_str = stage_data.get('image_path')
                if image_path_str:
                    result_image = Path(image_path_str)
                    if not result_image.exists():
                        raise RuntimeError(f"Cannot resume: result image not found at {result_image}")
                    self.logger.log_info(problem_index, problem, f"Resuming from checkpoint - render stage complete, image: {result_image}")
                else:
                    raise RuntimeError(f"Cannot resume: image_path not saved in render checkpoint")

            # Stage 4: Judge (with smart skipping for obvious failures)
            failure_reason = None
            if not self._is_stage_complete(problem_index, 'judge'):
                async with self.judge_semaphore:
                    self._save_stage_checkpoint(problem_index, 'judge', 'in_progress')
                    try:
                        judge = Judge(judge_model=self.judge_model)
                        critic_path = problem_path / 'critic.txt'
                        request_path = problem_path / 'request.txt'
                        
                        # setup_test_files writes shaders to test_folder/shaders/
                        # — the top-level test_folder/shader.{language} does not
                        # normally exist; pointing the judge there gave a silent
                        # "no code" check, and worse, picked up rogue files from
                        # a prior cwd-leak race.
                        code_path = test_folder / "shaders" / f"shader.{self.language}"
                        reference_image_path = problem_path / "reference.png"
                        if not reference_image_path.exists():
                            reference_image_path = None
                            
                        context = EvaluationContext(
                            critic_path=critic_path,
                            request_path=request_path,
                            result_image_path=result_image,
                            save_dir=test_folder,
                            code_path=code_path,
                            reference_image_path=reference_image_path
                        )
                        scores, failure_reason, judge_usage = await judge.evaluate_with_template(context)
                        self.logger.log_info(problem_index, problem, f"Judge cost: ${judge_usage.get('cost', 0):.4f} ({judge_usage.get('total_tokens', 0)} tokens)")
                        checkpoint_data = {'scores': scores, 'judge_usage': judge_usage}
                        if failure_reason:
                            checkpoint_data['failure_reason'] = failure_reason
                            checkpoint_data['judge_skipped'] = True
                        self._save_stage_checkpoint(problem_index, 'judge', 'complete', checkpoint_data)
                    except Exception as e:
                        error_msg = str(e)[:500]
                        self._save_stage_checkpoint(problem_index, 'judge', 'failed', {'error': error_msg})
                        print(f"❌ Judge stage failed for {problem}: {error_msg}")
                        raise
            else:
                # RESUME: Load scores from checkpoint - problem is fully complete
                stage_data = self._get_stage_data(problem_index, 'judge')
                scores = stage_data.get('scores', [0, 0, 0, 0, 0])
                failure_reason = stage_data.get('failure_reason')
                judge_usage = stage_data.get('judge_usage', {'cost': 0, 'total_tokens': 0})
                self.logger.log_info(problem_index, problem, f"Resuming from checkpoint - judge stage complete, scores: {scores}")

            # Save final results with cost data
            if test_folder:
                test_runner.save_results(test_folder, scores, True,
                                        generation_usage=generation_usage,
                                        judge_usage=judge_usage)

            end_time = datetime.now()
            execution_time = (end_time - start_time).total_seconds()

            # Log successful completion
            self.logger.log_problem_end(problem_index, problem, True, execution_time)

            if pbar:
                pbar.set_postfix_str(f"{problem}: {sum(scores)}/500")
                pbar.update(1)

            # Calculate costs for this problem
            gen_cost = generation_usage.get('cost', 0) if generation_usage else 0
            judge_cost_val = judge_usage.get('cost', 0) if judge_usage else 0
            total_problem_cost = gen_cost + judge_cost_val

            result = {
                'problem': problem,
                'success': True,
                'scores': scores,
                'image_path': result_image if result_image and result_image.exists() else None,
                'test_dir': test_folder,
                'execution_time': execution_time,
                'cost': {
                    'generation': gen_cost,
                    'judge': judge_cost_val,
                    'total': total_problem_cost
                }
            }
            if failure_reason:
                result['failure_reason'] = failure_reason
            return result

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

        # Generate report in the run directory (self.run_dir)
        model_safe = self.model.replace('/', '_').replace(':', '_')
        output_file = f"benchmark_report.md"

        # Use custom generate_report that only scans our specific test directories
        from generate_report import ReportGenerator
        generator = ReportGenerator(self.model)

        # Add only test directories from THIS harness run
        for test_dir in test_dirs_from_this_run:
            generator.add_test_result(test_dir)

        # Generate report in the run directory (self.run_dir)
        # This will create an images/ subdirectory and copy PNGs there
        report_path = generator.generate_report(output_file, str(self.run_dir))

        print(f"✅ Report generated: {report_path}")
        return report_path
    
    async def run_benchmark(self) -> str:
        """Run all problems and generate report"""
        # Count fully completed problems (all stages done)
        fully_completed = sum(1 for i in range(len(self.problems)) if self._is_problem_fully_complete(i))

        # Count partially completed problems (at least one stage done but not all)
        partially_completed = sum(1 for i in range(len(self.problems))
                                   if not self._is_problem_fully_complete(i) and
                                      (self._is_stage_complete(i, 'generate') or
                                       self._is_stage_complete(i, 'compile') or
                                       self._is_stage_complete(i, 'render')))

        print(f"🎯 Benchmark Harness - Testing {self.model}")
        print(f"🆔 Run ID: {self.run_id}")
        print(f"📊 Total tests: {len(self.problems)}")
        print(f"✅ Fully completed (cached): {fully_completed}")
        print(f"🔄 Partially completed (resuming): {partially_completed}")
        print(f"⏳ Not started: {len(self.problems) - fully_completed - partially_completed}")
        print(f"🔀 Pipeline limits: LLM={self.max_parallel}, Compile={self.compile_semaphore._value}, Render={self.render_semaphore._value}, Judge={self.judge_semaphore._value}")
        print("=" * 60)

        # Runtime prepare: WGPU compiles the cargo binary here; Shadertoy is a no-op.
        # Skip prepare if every problem already has a cached judge result.
        if fully_completed < len(self.problems):
            print(f"🔨 Preparing runtime ({self.runtime.name})...")
            try:
                await self.test_runner.prepare_runtime()
                print("✅ Runtime ready")
            except Exception as e:
                print(f"❌ Runtime prepare failed: {e}")
                raise
        else:
            print("✅ All problems already complete - skipping runtime prepare")

        self.start_time = datetime.now()

        # Run all problems in parallel with progress bar
        # Note: initial=0 because even fully_completed problems will run (quickly) and update the bar
        with tqdm(total=len(self.problems), desc="Running benchmarks", unit="test", initial=0) as pbar:
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
        
        # Aggregate costs across all problems
        total_generation_cost = sum(r.get('cost', {}).get('generation', 0) for r in self.results)
        total_judge_cost = sum(r.get('cost', {}).get('judge', 0) for r in self.results)
        total_run_cost = total_generation_cost + total_judge_cost

        # Save cost summary to config.json
        config_file = self.run_dir / "config.json"
        if config_file.exists():
            with open(config_file, 'r') as f:
                config = json.load(f)
            config['cost_summary'] = {
                'generation_cost': total_generation_cost,
                'judge_cost': total_judge_cost,
                'total_cost': total_run_cost,
                'currency': 'USD (OpenRouter credits)'
            }
            with open(config_file, 'w') as f:
                json.dump(config, f, indent=2)

        # Print summary
        successful = sum(1 for r in self.results if r['success'])
        total_time = (self.end_time - self.start_time).total_seconds()

        print("\n" + "=" * 60)
        print(f"🏁 Benchmark complete for {self.model}")
        print(f"✅ Success rate: {successful}/{len(self.problems)} ({successful/len(self.problems)*100:.1f}%)")
        print(f"💰 Total cost: ${total_run_cost:.4f} (gen: ${total_generation_cost:.4f}, judge: ${total_judge_cost:.4f})")
        print(f"⏱️  Total time: {total_time:.1f} seconds")
        print(f"📊 Report: {report_path}")
        
        return report_path

def main():
    parser = argparse.ArgumentParser(description='Shader Benchmark Harness - Tier 2 (Pipeline Parallel)')
    parser.add_argument('--model', help='LLM model to test (required unless using --resume)')
    parser.add_argument('--judge-model', default='anthropic/claude-opus-4-6',
                       help='Judge model for evaluation (default: anthropic/claude-opus-4-6)')
    parser.add_argument('--problems', nargs='+',
                       help='List of problems to test (from problems/base_set/)')
    parser.add_argument('--all', action='store_true',
                       help='Run all problems in problems/base_set/')
    parser.add_argument('--max-parallel', type=int, default=100,
                       help='Maximum number of parallel LLM/judge calls (default: 100)')
    parser.add_argument('--run-id', type=str, default=None,
                       help='Run ID for checkpoint/resume (default: auto-generate)')
    parser.add_argument('--language', type=str, default='wgsl',
                       choices=['wgsl', 'glsl', 'shadertoy', 'hlsl_unity'],
                       help='Shader language specification (default: wgsl)')
    parser.add_argument('--runtime', type=str, default=None,
                       choices=['wgpu', 'shadertoy'],
                       help='Rendering runtime (default: derived from --language: shadertoy→shadertoy, else wgpu)')
    parser.add_argument('--resume', type=str, default=None,
                       help=('Resume a specific run folder (e.g. benchmark_run_output/abc123_…). '
                             'Pass "latest" as an explicit alias for default auto-detect.'))
    parser.add_argument('--new', action='store_true',
                       help=('Force a fresh run even if a matching prior run exists. '
                             'Without this flag, the harness auto-resumes the most recent '
                             'run matching --model + --language + --runtime, and prints DONE '
                             'if that run is already fully complete.'))

    args = parser.parse_args()

    # Default behavior: auto-resume the most recent matching run unless the
    # user opted out with --new or named a specific run with --resume <path>.
    # `--resume latest` is treated identically to leaving --resume unset.
    auto_detect = (not args.new) and (args.resume in (None, 'latest'))
    if auto_detect:
        if not args.model:
            # No model means we can't match — fall through to standard fresh-mode
            # error handling below.
            args.resume = None
        else:
            script_dir = Path(__file__).parent.absolute()
            output_root = script_dir / 'benchmark_run_output'

            # Resolve which problem set this invocation is asking for, so we
            # don't auto-resume a 1-problem smoke run when the user passed
            # --all (or vice versa). If neither --all nor --problems is set,
            # we don't have an explicit problem set to compare against and
            # fall back to model/language matching only.
            requested_problems = None
            if args.all:
                base_set = script_dir.parent / "problems" / "base_set"
                if base_set.exists():
                    requested_problems = sorted(
                        d.name for d in base_set.iterdir() if d.is_dir()
                    )
            elif args.problems:
                requested_problems = sorted(args.problems)

            matches = []
            if output_root.exists():
                for d in output_root.iterdir():
                    if not d.is_dir():
                        continue
                    cfg_file = d / 'config.json'
                    if not cfg_file.exists():
                        continue
                    try:
                        with open(cfg_file) as f:
                            cfg = json.load(f)
                    except (OSError, json.JSONDecodeError):
                        continue
                    if cfg.get('model') != args.model:
                        continue
                    if cfg.get('language', 'wgsl') != args.language:
                        continue
                    cfg_runtime = cfg.get('runtime')
                    if args.runtime and cfg_runtime and cfg_runtime != args.runtime:
                        continue
                    if requested_problems is not None:
                        cfg_problems = sorted(cfg.get('problems', []))
                        if cfg_problems != requested_problems:
                            continue
                    matches.append((d.stat().st_mtime, d))
            if matches:
                matches.sort(reverse=True)
                latest_dir = matches[0][1]
                # Check completeness: a problem is fully complete when all four
                # stages are 'complete' in its checkpoint file.
                cfg = json.load(open(latest_dir / 'config.json'))
                expected = cfg.get('total_problems', len(cfg.get('problems', [])))
                cp_dir = latest_dir / 'checkpoints'
                done = 0
                if cp_dir.exists():
                    for f in sorted(cp_dir.glob('problem_*.json')):
                        try:
                            pdata = json.load(open(f))
                        except (OSError, json.JSONDecodeError):
                            continue
                        stages = pdata.get('stages', {})
                        if all(stages.get(s, {}).get('status') == 'complete'
                               for s in ('generate', 'compile', 'render', 'judge')):
                            done += 1
                if expected and done >= expected:
                    print(f"✅ DONE — {latest_dir.name} is fully complete ({done}/{expected} problems).")
                    print(f"   Report: {latest_dir / 'benchmark_report.md'}")
                    print(f"   To start a NEW run for this model, re-invoke with --new.")
                    sys.exit(0)
                args.resume = str(latest_dir)
                print(f"🔄 Auto-resuming {latest_dir.name} ({done}/{expected} problems already complete)")
            else:
                # No prior run for this model — fall through to fresh mode.
                args.resume = None
                print(f"ℹ️  No prior run for model={args.model} language={args.language} — starting fresh.")

    # Handle resume mode
    if args.resume:
        # Load config from the resume folder
        resume_path = Path(args.resume)
        if not resume_path.is_absolute():
            # If relative path, try to find it in benchmark_run_output
            script_dir = Path(__file__).parent.absolute()
            if (script_dir / args.resume).exists():
                resume_path = script_dir / args.resume
            elif (script_dir / "benchmark_run_output" / args.resume).exists():
                resume_path = script_dir / "benchmark_run_output" / args.resume
            else:
                print(f"❌ Resume folder not found: {args.resume}")
                print(f"   Tried: {script_dir / args.resume}")
                print(f"   Tried: {script_dir / 'benchmark_run_output' / args.resume}")
                sys.exit(1)

        config_file = resume_path / "config.json"
        if not config_file.exists():
            print(f"❌ Config file not found: {config_file}")
            sys.exit(1)

        with open(config_file, 'r') as f:
            config = json.load(f)

        # Extract run_id from folder name (it's the folder name itself within benchmark_run_output)
        run_id = resume_path.name

        print(f"🔄 Resuming benchmark run: {run_id}")
        print(f"   Model: {config['model']}")
        print(f"   Problems: {config['total_problems']} total")
        print(f"   Language: {config.get('language', 'wgsl')}")

        # Use config values, but allow CLI overrides for some settings
        model = args.model or config['model']
        judge_model = args.judge_model if args.judge_model != 'anthropic/claude-opus-4-6' else config.get('judge_model', 'anthropic/claude-opus-4-6')
        problems = args.problems or config['problems']
        max_parallel = args.max_parallel if args.max_parallel != 100 else config.get('max_parallel', 100)
        language = args.language if args.language != 'wgsl' else config.get('language', 'wgsl')
        runtime = args.runtime or config.get('runtime')

        harness = BenchmarkHarness(model, problems, max_parallel, judge_model, run_id, language, runtime)
    else:
        # Standard mode - require model and problems
        if not args.model:
            parser.error("--model is required (unless using --resume)")

        # Resolve --all to list of all problem directories
        if args.all:
            base_set = Path(__file__).parent.parent / "problems" / "base_set"
            args.problems = sorted([d.name for d in base_set.iterdir() if d.is_dir()])
            print(f"📋 Running all {len(args.problems)} problems from {base_set}")

        if not args.problems:
            parser.error("--problems or --all is required (unless using --resume)")

        harness = BenchmarkHarness(args.model, args.problems, args.max_parallel, args.judge_model, args.run_id, args.language, args.runtime)

    report_path = asyncio.run(harness.run_benchmark())

    print(f"\n📋 Benchmark report: {report_path}")
    print(f"🆔 Run ID: {harness.run_id} (use --resume benchmark_run_output/{harness.run_id} to resume)")

if __name__ == "__main__":
    main()