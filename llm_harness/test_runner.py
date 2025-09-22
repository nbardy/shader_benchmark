import os
import shutil
import subprocess
import uuid
from datetime import datetime
from pathlib import Path
from typing import Dict

class TestRunner:
    def __init__(self):
        self.shader_harness_path = Path("../shader_harness")
        
    def create_test_folder(self) -> Path:
        """Create a unique test folder with timestamp and UUID for this run"""
        test_uuid = str(uuid.uuid4())
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        test_folder = Path(f"test_{timestamp}_{test_uuid}_results")
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
    
    async def run_test(self, test_folder: Path) -> Path:
        """Run cargo run in the test folder and return path to result.png"""
        
        # NO PNG REMOVAL - Each test gets fresh timestamp-based directory
        # All artifacts are preserved for debugging and analysis
        
        # Change to test directory and run cargo
        original_cwd = os.getcwd()
        
        try:
            os.chdir(test_folder)
            
            print(f"Running cargo run in {test_folder}...")
            
            # Find the main shader file to use (support both .wgsl and .glsl)
            wgsl_files = list(Path("shaders").glob("*.wgsl"))
            glsl_files = list(Path("shaders").glob("*.glsl"))
            shader_files = wgsl_files + glsl_files
            main_shader = None
            
            # Look for a compute or fragment shader
            for shader_file in shader_files:
                if "hopf" in shader_file.name.lower() or "main" in shader_file.name.lower():
                    main_shader = shader_file
                    break
            
            if not main_shader and shader_files:
                main_shader = shader_files[0]  # Use first shader as fallback
            
            if not main_shader:
                raise FileNotFoundError("No shader files found to execute")
            
            # Source cargo environment and run (output to artifacts)
            # Note: Size argument may not be supported by all generated binaries
            output_path = "artifacts/result.png"
            cargo_env_cmd = "source ~/.cargo/env && cargo run -- --shader {} --output {}".format(str(main_shader), output_path)
            result = subprocess.run(
                ["bash", "-c", cargo_env_cmd],
                capture_output=True,
                text=True,
                timeout=120  # 2 minute timeout
            )
            
            if result.returncode != 0:
                print(f"Cargo run failed with return code {result.returncode}")
                print(f"STDOUT: {result.stdout}")
                print(f"STDERR: {result.stderr}")
                raise RuntimeError(f"Cargo run failed: {result.stderr}")
            
            print("Cargo run completed successfully")
            
            # Check for result.png in artifacts folder (we're already in test_folder)
            result_image_local = Path("artifacts/result.png")
            if not result_image_local.exists():
                raise FileNotFoundError("artifacts/result.png not found - shader execution failed")
            
            print(f"SUCCESS: Generated fresh result.png in artifacts/")
            # Return the absolute path for use outside this directory
            return test_folder / "artifacts" / "result.png"
            
        finally:
            os.chdir(original_cwd)
    
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