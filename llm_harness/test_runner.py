import os
import shutil
import subprocess
import uuid
from pathlib import Path
from typing import Dict

class TestRunner:
    def __init__(self):
        self.shader_harness_path = Path("../shader_harness")
        
    def create_test_folder(self) -> Path:
        """Create a unique test folder for this run"""
        test_uuid = str(uuid.uuid4())
        test_folder = Path(f"test_{test_uuid}_results")
        test_folder.mkdir(exist_ok=True)
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
            
            # Write new main.rs
            with open(test_folder / "src" / "main.rs", 'w') as f:
                f.write(main_rs)
            
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
        
        # Change to test directory and run cargo
        original_cwd = os.getcwd()
        
        try:
            os.chdir(test_folder)
            
            print(f"Running cargo run in {test_folder}...")
            
            # Find the main shader file to use
            shader_files = list(Path("shaders").glob("*.wgsl"))
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
            
            # Run with proper arguments
            cmd = ["cargo", "run", "--", "--shader", str(main_shader), "--output", "result.png", "--size", "1600"]
            result = subprocess.run(
                cmd,
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
            
            # Look for result.png or any PNG output
            result_image = test_folder / "result.png"
            if not result_image.exists():
                # Look for any PNG files
                png_files = list(test_folder.glob("*.png"))
                if png_files:
                    result_image = png_files[0]
                    print(f"Found output image: {result_image}")
                else:
                    raise FileNotFoundError("No PNG output file found after running shader")
            
            return result_image
            
        finally:
            os.chdir(original_cwd)
    
    def save_results(self, test_folder: Path, scores: list, execution_success: bool = True):
        """Save the evaluation results"""
        results = {
            "scores": scores,
            "test_folder": str(test_folder),
            "status": "completed" if execution_success else "failed",
            "execution_success": execution_success,
            "has_image": (test_folder / "result.png").exists()
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