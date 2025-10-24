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
        self.shader_harness_path = Path("../shader_harness")
        # Pipeline stage semaphores for resource management
        self.compile_semaphore = compile_semaphore or asyncio.Semaphore(os.cpu_count() or 8)
        self.render_semaphore = render_semaphore or asyncio.Semaphore(4)
        
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
        """Setup the test environment by copying shader_harness and replacing files"""
        
        # Copy the entire shader_harness structure
        if self.shader_harness_path.exists():
            # Create subdirectories
            (test_folder / "src").mkdir(exist_ok=True)
            (test_folder / "shaders").mkdir(exist_ok=True)
            
            # Copy Cargo.toml
            cargo_toml_src = self.shader_harness_path / "Cargo.toml"
            if cargo_toml_src.exists():
                shutil.copy2(cargo_toml_src, test_folder / "Cargo.toml")
            
            # ALWAYS use LLM-generated main.rs for true isolation testing
            with open(test_folder / "src" / "main.rs", 'w') as f:
                f.write(main_rs)
            print(f"Using LLM-generated main.rs (no file reuse)")
            
            # Copy the working main.rs as backup reference only
            main_rs_src = self.shader_harness_path / "src" / "main.rs"
            if main_rs_src.exists():
                shutil.copy2(main_rs_src, test_folder / "main_rs_reference.rs")
                print("Saved working main.rs as reference backup")
            
            # Write shader files
            for filename, content in shaders.items():
                with open(test_folder / "shaders" / filename, 'w') as f:
                    f.write(content)
            
            print(f"Setup test files in {test_folder}")
            print(f"Created {len(shaders)} shader files: {list(shaders.keys())}")
        else:
            raise FileNotFoundError(f"shader_harness directory not found at {self.shader_harness_path}")
    
    async def compile_shader(self, test_folder: Path) -> Tuple[bool, str]:
        """Stage 1: Compile the shader project (CPU-bound)"""
        async with self.compile_semaphore:
            original_cwd = os.getcwd()
            try:
                os.chdir(test_folder)

                # Compile only (cargo build --release)
                cargo_env_cmd = "source ~/.cargo/env && cargo build --release"
                loop = asyncio.get_event_loop()
                result = await loop.run_in_executor(
                    None,
                    lambda: subprocess.run(
                        ["bash", "-c", cargo_env_cmd],
                        capture_output=True,
                        text=True,
                        timeout=120
                    )
                )

                # Save logs (automatically saves error_log if failed)
                save_subprocess_output(test_folder, "compile", result, cargo_env_cmd)

                if result.returncode != 0:
                    return False, f"Compilation failed: {result.stderr[:500]}"

                return True, "Compilation successful"

            finally:
                os.chdir(original_cwd)

    async def render_shader(self, test_folder: Path) -> Path:
        """Stage 2: Execute the compiled shader (GPU-bound)"""
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

                # Check binary exists (name comes from Cargo.toml package name)
                binary_path = "target/release/shader-bench"
                if not Path(binary_path).exists():
                    raise FileNotFoundError(f"Compiled binary not found at {binary_path}")

                # Run shader
                output_path = "artifacts/result.png"
                run_cmd = f"{binary_path} --shader {main_shader} --output {output_path}"

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
                if not Path("artifacts/result.png").exists():
                    raise FileNotFoundError("artifacts/result.png not found - shader execution failed")

                # Return absolute path
                return test_folder / "artifacts" / "result.png"

            finally:
                os.chdir(original_cwd)

    async def run_test(self, test_folder: Path) -> Path:
        """Run full pipeline: compile → render (uses pipeline semaphores)"""
        # Stage 1: Compile
        compile_success, compile_msg = await self.compile_shader(test_folder)
        if not compile_success:
            raise RuntimeError(compile_msg)

        # Stage 2: Render
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