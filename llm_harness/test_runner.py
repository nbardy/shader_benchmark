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

class TestRunner:
    def __init__(self, compile_semaphore=None, render_semaphore=None):
        # CRITICAL FIX: Use absolute path based on script location, not relative to CWD
        # This ensures shader_harness directory is found regardless of where the script is invoked from
        script_dir = Path(__file__).parent.absolute()
        self.shader_harness_path = script_dir.parent / "shader_harness"
        # Pipeline stage semaphores for resource management
        self.compile_semaphore = compile_semaphore or asyncio.Semaphore(os.cpu_count() or 8)
        self.render_semaphore = render_semaphore or asyncio.Semaphore(4)

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
        """Create a unique test folder with timestamp and UUID for this run"""
        test_uuid = str(uuid.uuid4())
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        test_folder = Path(f"test_{timestamp}_{test_uuid}_results").resolve()  # Always return absolute path
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

    async def render_shader(self, test_folder: Path) -> Path:
        """
        Stage 2: Execute pre-built shader binary (GPU-bound).

        PRE-BUILD FIX: Uses self.shader_bench_binary (pre-built at initialization)
        instead of looking for a binary in the test folder.

        Args:
            test_folder: Path to test folder containing shaders/ subdirectory

        Returns: Absolute path to generated result.png
        """
        async with self.render_semaphore:
            original_cwd = os.getcwd()
            try:
                os.chdir(test_folder)

                # Ensure artifacts directory exists
                Path("artifacts").mkdir(exist_ok=True)

                # Find the main shader file to use (support both .wgsl and .glsl)
                shader_files = list(Path("shaders").glob("*.wgsl")) + list(Path("shaders").glob("*.glsl"))
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
                output_path = test_folder / "artifacts" / "result.png"
                main_shader_absolute = (test_folder / main_shader).resolve()

                run_cmd = f"{self.shader_bench_binary} --shader {main_shader_absolute} --output {output_path}"

                loop = asyncio.get_event_loop()
                result = await loop.run_in_executor(
                    None,
                    lambda: subprocess.run(
                        ["bash", "-c", run_cmd],
                        capture_output=True,
                        text=True,
                        timeout=60
                    )
                )

                # Save logs (automatically saves error_log if failed)
                save_subprocess_output(test_folder, "render", result, run_cmd)

                if result.returncode != 0:
                    raise RuntimeError(f"Shader execution failed: {result.stderr[:500]}")

                # Check output was generated
                if not output_path.exists():
                    raise FileNotFoundError(f"{output_path} not found - shader execution failed")

                # Return absolute path
                return output_path.resolve()

            finally:
                os.chdir(original_cwd)

    async def run_test(self, test_folder: Path) -> Path:
        """
        Run full pipeline: prebuild (once) → compile (no-op) → render.

        PRE-BUILD FIX: Ensures shader-bench binary is built before rendering.

        Args:
            test_folder: Path to test folder with shaders/ subdirectory

        Returns: Absolute path to generated result.png
        """
        # Stage 0: Ensure pre-built binary exists (only runs once)
        if not self._prebuild_complete:
            await self.prebuild_shader_binary()

        # Stage 1: Compile (now a no-op, returns immediately)
        compile_success, compile_msg = await self.compile_shader(test_folder)
        if not compile_success:
            raise RuntimeError(compile_msg)

        # Stage 2: Render using pre-built binary
        result_image = await self.render_shader(test_folder)
        return result_image
    
    def save_results(self, test_folder: Path, scores: list, execution_success: bool = True):
        """Save the evaluation results"""
        # Check for any PNG files, not just result.png
        png_files = list(test_folder.glob("*.png"))
        has_image = len(png_files) > 0
        
        results = {
            "scores": scores,
            "test_folder": str(test_folder),
            "status": "completed" if execution_success else "failed",
            "execution_success": execution_success,
            "has_image": has_image
        }
        
        results_file = test_folder / "results.json"
        import json
        with open(results_file, 'w') as f:
            json.dump(results, f, indent=2)
        
        print(f"Results saved to {results_file}")
    
    def cleanup_test_folder(self, test_folder: Path):
        """Clean up the test folder (optional)"""
        if test_folder.exists():
            shutil.rmtree(test_folder)
            print(f"Cleaned up test folder: {test_folder}")