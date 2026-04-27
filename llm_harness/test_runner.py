"""
TestRunner - Execute shader tests using pre-built shader-bench binary

ARCHITECTURE (PRE-BUILD FIX):
  1. prebuild_shader_binary() - Build shader-bench binary ONCE at initialization
     - Runs in shader_harness/ directory with valid Cargo.toml and src/main.rs
     - Stores path to compiled binary in self.shader_bench_binary
     - Protected by self._prebuild_complete flag to prevent duplicate builds

  2. setup_test_files() - Write shader files to test folder
     - DOES NOT copy Cargo.toml or compile code
     - Only writes LLM-generated shaders to test_folder/shaders/
     - Saves LLM-generated main.rs as reference artifact (not compiled)

  3. compile_shader() - No-op (returns success immediately)
     - Compilation happens once in prebuild, not per-problem
     - Maintains API compatibility with existing code

  4. render_shader() - Execute pre-built binary with shader
     - Uses self.shader_bench_binary (absolute path from prebuild)
     - Passes shader path and output path as arguments
     - No compilation happens here

  5. run_test() - Full pipeline: prebuild → compile (no-op) → render
     - Automatically calls prebuild on first test if needed
     - All subsequent tests reuse the same binary

WHY THIS ARCHITECTURE:
  - Eliminates per-problem compilation (2-3x speedup: 8min → 3min for 5 problems)
  - Avoids "main function not found" errors from LLM-generated main.rs
  - Uses working main.rs from shader_harness/src/main.rs
  - Shared binary across all problems in a benchmark run

CRITICAL: Do NOT create new TestRunner instances per-problem.
          Use one shared TestRunner for all problems in a benchmark.
          See benchmark_harness.py for correct usage pattern.
"""

import os
import shutil
import subprocess
import uuid
import asyncio
from datetime import datetime
from pathlib import Path
from typing import Dict, Tuple
from error_handler import use_safe, save_subprocess_output
from shader_parser import ShaderParser, WGSLRepair
from language_specs import ShaderLanguageSpec, ShadertoySpec
from runtimes import ShaderRuntime, default_runtime_for_language

class TestRunner:
    def __init__(self, compile_semaphore=None, render_semaphore=None,
                 language_spec: ShaderLanguageSpec = None,
                 runtime: ShaderRuntime = None):
        # CRITICAL FIX: Use absolute path based on script location, not relative to CWD
        # This ensures shader_harness directory is found regardless of where the script is invoked from
        script_dir = Path(__file__).parent.absolute()
        self.shader_harness_path = script_dir.parent / "shader_harness"

        # INFINITE LOOP FIX: Store base directory for test folders to prevent nesting
        # Test folders should always be created in llm_harness/, not relative to CWD
        self.test_base_dir = script_dir

        # Pipeline stage semaphores for resource management
        self.compile_semaphore = compile_semaphore or asyncio.Semaphore(os.cpu_count() or 8)
        self.render_semaphore = render_semaphore or asyncio.Semaphore(4)

        # Language specification (used by prompts/parsers — runtime is now
        # an independent slot, see `runtime` below).
        self.language_spec = language_spec

        # Runtime decides which renderer is invoked. Defaults to whichever
        # backend used to be implicitly tied to the language. Override by
        # passing an explicit ShaderRuntime (e.g. when --runtime is given).
        self.runtime: ShaderRuntime = runtime or default_runtime_for_language(language_spec)

        # PRE-BUILD FIX: Store path to pre-built shader-bench binary
        # This binary is built ONCE at initialization, not per-problem
        self.shader_bench_binary = None
        self._prebuild_complete = False

    async def prebuild_shader_binary(self):
        """
        PRE-BUILD FIX: Compile shader-bench binary ONCE at initialization.

        This method builds the shader-bench binary in the actual shader_harness directory,
        not in isolated test folders. Each problem then uses this pre-built binary instead
        of rebuilding from scratch.

        Benefits:
        - Eliminates per-problem compilation (2-3x speedup)
        - Avoids "main function not found" errors from LLM-generated main.rs
        - Uses the working main.rs from shader_harness/src/main.rs

        Returns: Path to compiled shader-bench binary
        """
        if self._prebuild_complete:
            return self.shader_bench_binary

        async with self.compile_semaphore:
            original_cwd = os.getcwd()
            try:
                # Change to shader_harness directory (where Cargo.toml and working src/main.rs exist)
                os.chdir(self.shader_harness_path)

                print(f"Pre-building shader-bench binary in {self.shader_harness_path}...")

                # Build the shader-bench binary once
                cargo_env_cmd = "source ~/.cargo/env && cargo build --release"
                loop = asyncio.get_event_loop()
                result = await loop.run_in_executor(
                    None,
                    lambda: subprocess.run(
                        ["bash", "-c", cargo_env_cmd],
                        capture_output=True,
                        text=True,
                        timeout=180  # Allow more time for initial build
                    )
                )

                if result.returncode != 0:
                    error_msg = f"Pre-build failed: {result.stderr[:500]}"
                    print(f"ERROR: {error_msg}")
                    raise RuntimeError(error_msg)

                # Store absolute path to compiled binary
                self.shader_bench_binary = (self.shader_harness_path / "target" / "release" / "shader-bench").resolve()

                if not self.shader_bench_binary.exists():
                    raise FileNotFoundError(f"Binary not found at expected path: {self.shader_bench_binary}")

                self._prebuild_complete = True
                print(f"Pre-build successful: {self.shader_bench_binary}")
                return self.shader_bench_binary

            finally:
                os.chdir(original_cwd)

    def create_test_folder(self) -> Path:
        """
        Create a unique test folder with timestamp and UUID for this run.

        INFINITE LOOP FIX: Test folders are always created in self.test_base_dir
        (the llm_harness directory), not relative to the current working directory.
        This prevents nested test directories when render_shader_wgpu() does os.chdir().
        """
        test_uuid = str(uuid.uuid4())
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")

        # CRITICAL: Create test folder in fixed base directory, not CWD
        test_folder = (self.test_base_dir / f"test_{timestamp}_{test_uuid}_results").resolve()
        test_folder.mkdir(exist_ok=True)

        # Create artifacts subfolder for preserving all outputs
        artifacts_folder = test_folder / "artifacts"
        artifacts_folder.mkdir(exist_ok=True)

        print(f"Created isolated test environment: {test_folder}")
        return test_folder
    
    def setup_test_files(self, test_folder: Path, shaders: Dict[str, str], main_rs: str):
        """
        Setup test environment with shader files only.

        PRE-BUILD FIX: No longer copies Cargo.toml or main.rs since we use pre-built binary.
        We only need to write the LLM-generated shader files to the test folder.

        COMPILER-ERROR-DRIVEN REPAIR: Error repairs are now applied during render phase
        based on actual compiler output, not predictive linting.

        Args:
            test_folder: Path to test results folder
            shaders: Dict mapping shader filenames to shader code content
            main_rs: LLM-generated main.rs (saved for reference only, not compiled)
        """
        if not self.shader_harness_path.exists():
            raise FileNotFoundError(f"shader_harness directory not found at {self.shader_harness_path}")

        # Create shaders subdirectory
        (test_folder / "shaders").mkdir(exist_ok=True)

        # Write shader files (these will be executed by pre-built binary)
        # Repairs are applied during render phase based on actual compiler errors
        for filename, content in shaders.items():
            with open(test_folder / "shaders" / filename, 'w') as f:
                f.write(content)

        # Save LLM-generated main.rs as reference artifact (not compiled)
        # This allows debugging/analysis but doesn't cause compilation errors
        with open(test_folder / "llm_generated_main_rs_reference.txt", 'w') as f:
            f.write(main_rs)

        print(f"Setup test files in {test_folder}")
        print(f"Created {len(shaders)} shader files: {list(shaders.keys())}")
        print(f"Saved LLM-generated main.rs as reference (not compiled)")
    
    async def compile_shader(self, test_folder: Path) -> Tuple[bool, str]:
        """
        PRE-BUILD FIX: This method is now a no-op since compilation happens once at initialization.

        Previously compiled shader project per-problem (causing "main function not found" errors).
        Now returns success immediately since prebuild_shader_binary() handles compilation.

        Returns: (True, "Using pre-built binary")
        """
        # No compilation needed - using pre-built binary
        return True, "Using pre-built binary"

    async def render_shader_shadertoy(self, test_folder: Path) -> Path:
        """
        Stage 2 (Shadertoy): Execute Shadertoy shader using WebGL runtime.

        Uses Playwright-based WebGL execution for Shadertoy-format shaders.
        This bypasses the WGPU/Rust shader_harness and runs directly in browser.

        Args:
            test_folder: Path to test folder containing shaders/ subdirectory

        Returns: Absolute path to generated result.png
        """
        async with self.render_semaphore:
            try:
                # Import Shadertoy runtime
                from shadertoy_runtime import ShadertoyRuntime

                # Ensure artifacts directory exists
                artifacts_dir = test_folder / "artifacts"
                artifacts_dir.mkdir(exist_ok=True)

                # Find the main shader file
                shader_files = list((test_folder / "shaders").glob("*.glsl"))
                if not shader_files:
                    raise FileNotFoundError("No .glsl shader files found in shaders/ directory")

                main_shader_path = shader_files[0]

                # Read shader code
                with open(main_shader_path, 'r') as f:
                    shader_code = f.read()

                # Render using Shadertoy runtime
                output_path = artifacts_dir / "result.png"
                async with ShadertoyRuntime() as runtime:
                    success, error = await runtime.render_shader(
                        shader_code,
                        output_path,
                        time=0.0,  # Static frame at t=0
                        resolution=(1600, 1600)
                    )

                    if not success:
                        raise RuntimeError(f"Shadertoy rendering failed: {error}")

                # Check output was generated
                if not output_path.exists():
                    raise FileNotFoundError(f"{output_path} not found - Shadertoy rendering failed")

                # Return absolute path
                return output_path.resolve()

            except ImportError:
                raise RuntimeError(
                    "Shadertoy runtime requires Playwright. Install with: "
                    "pip install playwright && python -m playwright install chromium"
                )

    async def prepare_runtime(self) -> None:
        """One-time runtime setup. WGPU prebuilds the cargo binary; Shadertoy is a no-op."""
        await self.runtime.prepare(self)

    async def render_shader(self, test_folder: Path) -> Path:
        """Stage 2: render via the configured runtime backend.

        See runtimes.py for the registry; pass an explicit `runtime=` to
        TestRunner to override the language-derived default.
        """
        return await self.runtime.render(self, test_folder)

    async def render_shader_wgpu(self, test_folder: Path) -> Path:
        """
        Stage 2 (WGPU): Execute pre-built shader binary (GPU-bound).

        PRE-BUILD FIX: Uses self.shader_bench_binary (pre-built at initialization)
        instead of looking for a binary in the test folder.

        Args:
            test_folder: Path to test folder containing shaders/ subdirectory

        Returns: Absolute path to generated result.png
        """
        async with self.render_semaphore:
            # NOTE: Do NOT use os.chdir() here. The harness runs problems
            # concurrently in one Python process; chdir is process-wide and
            # will leak into any subprocess (e.g. a still-running `claude` LLM
            # call) that starts during the render window — that subprocess
            # then resolves relative paths against the wrong directory and
            # can write files into another problem's results dir.
            shaders_dir = test_folder / "shaders"
            artifacts_dir = test_folder / "artifacts"
            artifacts_dir.mkdir(exist_ok=True)

            # Find the main shader file to use (support both .wgsl and .glsl)
            shader_files = list(shaders_dir.glob("*.wgsl")) + list(shaders_dir.glob("*.glsl"))
            main_shader = None

            # Look for specific shader names first
            for shader_file in shader_files:
                if "hopf" in shader_file.name.lower() or "main" in shader_file.name.lower():
                    main_shader = shader_file
                    break

            # Use first shader as fallback
            if not main_shader and shader_files:
                main_shader = shader_files[0]

            if not main_shader:
                raise FileNotFoundError("No shader files found to execute")

            # PRE-BUILD FIX: Use pre-built binary (absolute path)
            if not self.shader_bench_binary or not self.shader_bench_binary.exists():
                raise FileNotFoundError(
                    f"Pre-built shader-bench binary not found. "
                    f"Call prebuild_shader_binary() first. "
                    f"Expected path: {self.shader_bench_binary}"
                )

            # Run shader using pre-built binary with absolute paths
            output_path = artifacts_dir / "result.png"
            main_shader_absolute = main_shader.resolve()

            run_cmd = f"{self.shader_bench_binary} --shader {main_shader_absolute} --output {output_path}"

            loop = asyncio.get_event_loop()

            # First attempt: try to run as-is. Pass cwd=test_folder so the
            # binary's working dir is per-task without polluting the parent.
            result = await loop.run_in_executor(
                None,
                lambda: subprocess.run(
                    ["bash", "-c", run_cmd],
                    capture_output=True,
                    text=True,
                    timeout=60,
                    cwd=str(test_folder),
                )
            )

            # Save logs (automatically saves error_log if failed)
            save_subprocess_output(test_folder, "render", result, run_cmd)

            if result.returncode != 0:
                # COMPILE FAILED: Try to repair based on actual compiler error
                error_output = result.stderr + result.stdout
                print(f"\n  ⚠️ Shader execution failed, attempting repair...")
                print(f"  Error message (first 200 chars): {error_output[:200]}")

                # Try repair if we detect a compilable error
                if self._attempt_repair_and_retry(
                    test_folder, main_shader, error_output, run_cmd
                ):
                    # Retry after repair
                    result = await loop.run_in_executor(
                        None,
                        lambda: subprocess.run(
                            ["bash", "-c", run_cmd],
                            capture_output=True,
                            text=True,
                            timeout=60,
                            cwd=str(test_folder),
                        )
                    )
                    save_subprocess_output(test_folder, "render_retry", result, run_cmd)

                    if result.returncode != 0:
                        raise RuntimeError(
                            f"Shader execution still failing after repair: {result.stderr[:500]}"
                        )
                else:
                    raise RuntimeError(f"Shader execution failed: {result.stderr[:500]}")

            # Check output was generated
            if not output_path.exists():
                raise FileNotFoundError(f"{output_path} not found - shader execution failed")

            # Return absolute path
            return output_path.resolve()

    def _attempt_repair_and_retry(
        self, test_folder: Path, main_shader: Path, error_output: str, run_cmd: str
    ) -> bool:
        """Repair shader from compiler error and retry."""
        shader_path = test_folder / main_shader
        with open(shader_path) as f:
            code = f.read()

        repaired = WGSLRepair().repair_from_error(code, error_output)
        if repaired == code:
            # No repair was possible - error doesn't match known patterns
            return False

        # Repair was successful - write back to file
        with open(shader_path, 'w') as f:
            f.write(repaired)
        print(f"  ✅ Applied repair - removed duplicate definitions")
        return True

    async def run_test(self, test_folder: Path) -> Path:
        """
        Run full pipeline: prebuild (once) → compile (no-op) → render.

        PRE-BUILD FIX: Ensures shader-bench binary is built before rendering.

        Args:
            test_folder: Path to test folder with shaders/ subdirectory

        Returns: Absolute path to generated result.png
        """
        # Stage 0: Runtime prepare (idempotent: WGPU caches the cargo build,
        # Shadertoy is a no-op).
        await self.prepare_runtime()

        # Stage 1: Compile (now a no-op, returns immediately)
        compile_success, compile_msg = await self.compile_shader(test_folder)
        if not compile_success:
            raise RuntimeError(compile_msg)

        # Stage 2: Render using pre-built binary
        result_image = await self.render_shader(test_folder)
        return result_image
    
    def save_results(self, test_folder: Path, scores: list, execution_success: bool = True,
                     generation_usage: dict = None, judge_usage: dict = None):
        """Save the evaluation results including cost data.

        Args:
            test_folder: Path to test folder
            scores: List of 5 scores
            execution_success: Whether execution succeeded
            generation_usage: Cost data from LLM generation (prompt_tokens, completion_tokens, cost, etc.)
            judge_usage: Cost data from LLM judging (prompt_tokens, completion_tokens, cost, etc.)
        """
        # CRITICAL: Check for PNG files in BOTH root and artifacts/ subdirectory
        # Why both locations?
        # - Legacy single-problem runs: result.png in root directory
        # - New multi-problem runs: result.png in artifacts/ subdirectory
        # If directory structure changes, update BOTH glob patterns here
        # This flag is used by report_renderer.py to determine if image embedding should occur
        png_files = list(test_folder.glob("*.png")) + list(test_folder.glob("artifacts/*.png"))
        has_image = len(png_files) > 0

        # Calculate total cost
        gen_cost = generation_usage.get('cost', 0) if generation_usage else 0
        judge_cost = judge_usage.get('cost', 0) if judge_usage else 0
        total_cost = gen_cost + judge_cost

        results = {
            "scores": scores,
            "test_folder": str(test_folder),
            "status": "completed" if execution_success else "failed",
            "execution_success": execution_success,
            "has_image": has_image,
            "cost": {
                "generation": gen_cost,
                "judge": judge_cost,
                "total": total_cost
            }
        }

        # Add detailed usage if available
        if generation_usage:
            results["generation_usage"] = generation_usage
        if judge_usage:
            results["judge_usage"] = judge_usage

        results_file = test_folder / "results.json"
        import json
        with open(results_file, 'w') as f:
            json.dump(results, f, indent=2)

        print(f"Results saved to {results_file} (cost: ${total_cost:.4f})")
    
    def cleanup_test_folder(self, test_folder: Path):
        """Clean up the test folder (optional)"""
        if test_folder.exists():
            shutil.rmtree(test_folder)
            print(f"Cleaned up test folder: {test_folder}")