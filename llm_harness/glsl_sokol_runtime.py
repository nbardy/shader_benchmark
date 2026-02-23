"""
GLSL Sokol Runtime - Python wrapper for Sokol-based GLSL ES 3.0 shader execution

This module provides a Python interface to execute GLSL ES 3.0 shaders using
the Sokol graphics library (C backend). It handles:
- Compilation of shaders using OpenGL ES 3.0
- Rendering to offscreen framebuffers
- PNG output generation
- Error parsing and repair loops

Architecture:
1. Python calls C executable (glsl_sokol_harness) with shader path
2. C program uses Sokol app + gfx to render shader
3. Output PNG saved via stb_image_write
4. Compilation errors returned to Python for repair

Dependencies:
- Sokol headers (header-only C library)
- OpenGL ES 3.0 / Metal backend
- stb_image_write.h for PNG output
"""

import subprocess
import os
from pathlib import Path
from typing import Tuple, Optional


class GLSLSokolRuntime:
    """Runtime for executing GLSL ES 3.0 shaders via Sokol graphics library."""

    def __init__(self, sokol_harness_path: Optional[Path] = None):
        """Initialize Sokol runtime.

        Args:
            sokol_harness_path: Path to compiled glsl_sokol_harness executable.
                               If None, will look in shader_harness/glsl_sokol_build/
        """
        if sokol_harness_path is None:
            # Default to shader_harness/glsl_sokol_build/glsl_sokol_harness
            script_dir = Path(__file__).parent.absolute()
            sokol_harness_path = script_dir.parent / "shader_harness" / "glsl_sokol_build" / "glsl_sokol_harness"

        self.sokol_harness_path = Path(sokol_harness_path)
        self._ensure_harness_built()

    def _ensure_harness_built(self):
        """Ensure Sokol harness is built and ready."""
        if not self.sokol_harness_path.exists():
            raise FileNotFoundError(
                f"Sokol harness executable not found at {self.sokol_harness_path}\n"
                f"Please build it first using:\n"
                f"  cd shader_harness/glsl_sokol_src\n"
                f"  ./build.sh\n"
                f"See GLSL_SOKOL_INSTALL.md for setup instructions."
            )

        # Verify it's executable
        if not os.access(self.sokol_harness_path, os.X_OK):
            raise PermissionError(
                f"Sokol harness at {self.sokol_harness_path} is not executable.\n"
                f"Run: chmod +x {self.sokol_harness_path}"
            )

    def compile_and_render(
        self,
        shader_path: Path,
        output_path: Path,
        width: int = 1600,
        height: int = 1600,
        time: float = 0.0
    ) -> Tuple[bool, str]:
        """Compile and render GLSL ES 3.0 shader using Sokol backend.

        Args:
            shader_path: Path to .glsl shader file
            output_path: Path to output PNG file
            width: Output image width in pixels
            height: Output image height in pixels
            time: Animation time value (for uniform float time)

        Returns:
            Tuple of (success: bool, message: str)
            - If successful: (True, "Rendered successfully")
            - If failed: (False, error_message_from_compiler)
        """
        if not shader_path.exists():
            return False, f"Shader file not found: {shader_path}"

        # Build command
        cmd = [
            str(self.sokol_harness_path),
            "--shader", str(shader_path.resolve()),
            "--output", str(output_path.resolve()),
            "--width", str(width),
            "--height", str(height),
            "--time", str(time)
        ]

        try:
            result = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                timeout=60
            )

            if result.returncode == 0:
                # Success - check output file was created
                if output_path.exists():
                    return True, f"Rendered successfully: {output_path}"
                else:
                    return False, f"Execution succeeded but output file not found: {output_path}"
            else:
                # Compilation or runtime error
                error_msg = result.stderr if result.stderr else result.stdout
                return False, error_msg

        except subprocess.TimeoutExpired:
            return False, "Shader execution timed out (60s limit)"
        except Exception as e:
            return False, f"Runtime error: {str(e)}"

    def parse_compilation_error(self, error_output: str) -> Optional[str]:
        """Parse OpenGL shader compilation error for repair hints.

        Args:
            error_output: Error message from OpenGL shader compiler

        Returns:
            Parsed error message or None if no error detected
        """
        # Common OpenGL ES 3.0 shader compiler error patterns
        error_patterns = [
            "ERROR: 0:",           # Generic shader error
            "ERROR: ",             # Generic error prefix
            "undeclared identifier",
            "syntax error",
            "type mismatch",
            "redefinition of",
            "undefined function",
        ]

        for pattern in error_patterns:
            if pattern in error_output:
                return error_output

        return None

    def test_installation(self) -> bool:
        """Test if Sokol harness is properly installed and functional.

        Returns:
            True if installation is working, False otherwise
        """
        try:
            # Run with --version flag
            result = subprocess.run(
                [str(self.sokol_harness_path), "--help"],
                capture_output=True,
                text=True,
                timeout=5
            )
            return result.returncode == 0
        except Exception as e:
            print(f"Installation test failed: {e}")
            return False


def build_sokol_harness(shader_harness_path: Path) -> Tuple[bool, str]:
    """Build the Sokol harness executable from source.

    This function compiles the C harness using the provided build script.

    Args:
        shader_harness_path: Path to shader_harness directory

    Returns:
        Tuple of (success: bool, message: str)
    """
    glsl_sokol_src = shader_harness_path / "glsl_sokol_src"
    build_script = glsl_sokol_src / "build.sh"

    if not build_script.exists():
        return False, f"Build script not found: {build_script}"

    try:
        # Make build script executable
        os.chmod(build_script, 0o755)

        # Run build script
        result = subprocess.run(
            ["bash", str(build_script)],
            cwd=glsl_sokol_src,
            capture_output=True,
            text=True,
            timeout=180
        )

        if result.returncode == 0:
            return True, "Sokol harness built successfully"
        else:
            return False, f"Build failed:\n{result.stderr}"

    except subprocess.TimeoutExpired:
        return False, "Build timed out (180s limit)"
    except Exception as e:
        return False, f"Build error: {str(e)}"


# Example usage
if __name__ == "__main__":
    import sys

    if len(sys.argv) < 3:
        print("Usage: python glsl_sokol_runtime.py <shader.glsl> <output.png>")
        sys.exit(1)

    runtime = GLSLSokolRuntime()

    shader_path = Path(sys.argv[1])
    output_path = Path(sys.argv[2])

    success, message = runtime.compile_and_render(shader_path, output_path)

    if success:
        print(f"✅ {message}")
        sys.exit(0)
    else:
        print(f"❌ {message}")
        sys.exit(1)
