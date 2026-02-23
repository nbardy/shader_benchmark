"""
GLSLSokolSpec class to be added to language_specs.py

This file contains the complete GLSLSokolSpec class implementation.
Copy this into language_specs.py before the SUPPORTED_LANGUAGES line.
"""

from language_specs import ShaderLanguageSpec
from typing import List


class GLSLSokolSpec(ShaderLanguageSpec):
    """GLSL ES 3.0 specification with Sokol graphics library backend.

    GLSL ES 3.0 is OpenGL ES Shading Language version 3.0, the most widely supported
    shader language with 500K+ training examples. This spec uses Sokol for execution,
    providing a lightweight, native rendering backend.

    Key characteristics:
    - Version: GLSL ES 3.0 (#version 300 es)
    - Precision qualifiers required (precision highp float;)
    - Explicit output variables (out vec4 fragColor;)
    - Built-in gl_FragCoord for pixel coordinates
    - Implicit type conversions and variable array indexing
    - Compatible with OpenGL ES 3.0 / WebGL 2.0

    Sokol backend advantages:
    - Header-only C library (minimal dependencies)
    - Cross-platform (macOS, Linux, Windows)
    - Metal/OpenGL/D3D11 backends
    - FBO support for multi-pass rendering
    """

    @property
    def name(self) -> str:
        return "GLSL_Sokol"

    @property
    def description(self) -> str:
        return "GLSL ES 3.0 with Sokol graphics backend - Widely supported shader language with extensive training data"

    @property
    def file_extension(self) -> str:
        return ".glsl"

    @property
    def fallback_filename(self) -> str:
        return "shader.glsl"

    @property
    def constraint_prompt(self) -> str:
        """GLSL ES 3.0 constraint prompt for Sokol backend.

        This prompt defines the exact format that Sokol runtime expects.
        Compatible with WebGL 2.0 / OpenGL ES 3.0 standards.
        """
        return """🔒 GLSL ES 3.0 FORMAT - FRAGMENT SHADER
============================================

You MUST generate ONLY valid GLSL ES 3.0 fragment shader code.

VERSION DECLARATION (REQUIRED):
---------------------------------------------
#version 300 es
precision highp float;

UNIFORM INPUTS (Available):
---------------------------------------------
uniform float time;          // Animation time in seconds
uniform vec2 resolution;     // Screen resolution in pixels (e.g., 1600.0, 1600.0)

OUTPUT VARIABLE (REQUIRED):
---------------------------------------------
out vec4 fragColor;         // Output color (RGBA, 0.0-1.0)

BUILT-IN VARIABLES:
---------------------------------------------
gl_FragCoord.xy             // Pixel coordinates (e.g., 0.0 to 1600.0)
gl_FragCoord.z              // Depth value
gl_FragCoord.w              // 1/w for perspective

ENTRYPOINT SIGNATURE:
---------------------------------------------
void main() {
    // Your fragment shader logic here
    // Normalize coordinates: vec2 uv = gl_FragCoord.xy / resolution;
    // Set output color: fragColor = vec4(r, g, b, a);
}

TYPE SYSTEM (Simplified vs WGSL):
---------------------------------------------
- Implicit types: vec2, vec3, vec4 (NO type parameters like <f32>)
- Scalars: int, uint, float (simpler than WGSL's i32/u32/f32)
- Implicit type conversions allowed: float x = 1; // int->float works
- Variable array indexing WORKS: vec3 colors[3]; colors[i]; // dynamic indexing OK

FEATURES YOU CAN USE:
---------------------------------------------
✅ Variable array indexing: arr[dynamicIndex]
✅ Implicit conversions: float x = 1;
✅ Math functions: sin, cos, tan, length, dot, cross, normalize, mix, smoothstep, etc.
✅ Matrix operations: mat2, mat3, mat4 with multiplication
✅ Texture sampling (if texture uniforms provided)
✅ For loops, conditionals, functions

FEATURES TO AVOID:
---------------------------------------------
❌ @vertex, @fragment attributes (WGSL syntax, not GLSL)
❌ var<uniform> declarations (WGSL syntax)
❌ Explicit type parameters: vec2<f32> (use vec2)
❌ WGSL-specific builtins

EXAMPLE MINIMAL SHADER:
---------------------------------------------
#version 300 es
precision highp float;

uniform vec2 resolution;
out vec4 fragColor;

void main() {
    // Normalize pixel coordinates to 0.0-1.0
    vec2 uv = gl_FragCoord.xy / resolution;

    // Create gradient from bottom-left (black) to top-right (cyan)
    fragColor = vec4(uv.x, uv.y, 0.5, 1.0);
}

EXAMPLE ANIMATED SHADER:
---------------------------------------------
#version 300 es
precision highp float;

uniform float time;
uniform vec2 resolution;
out vec4 fragColor;

void main() {
    vec2 uv = gl_FragCoord.xy / resolution;
    vec2 centered = (uv - 0.5) * 2.0; // -1 to 1

    // Rotating colors
    float r = 0.5 + 0.5 * sin(time + length(centered) * 3.0);
    float g = 0.5 + 0.5 * cos(time * 1.3 + centered.x * 2.0);
    float b = 0.5 + 0.5 * sin(time * 0.7 + centered.y * 2.0);

    fragColor = vec4(r, g, b, 1.0);
}

COORDINATE SYSTEM NOTES:
---------------------------------------------
- gl_FragCoord.xy: Bottom-left is (0, 0), top-right is (resolution.x, resolution.y)
- Normalized UVs: Divide by resolution to get 0.0-1.0 range
- Centered coords: (uv - 0.5) * 2.0 gives -1.0 to 1.0 range
- Aspect ratio: float aspect = resolution.x / resolution.y;"""

    def validate_syntax(self, shader_content: str) -> bool:
        """Validate GLSL ES 3.0 syntax by checking for required patterns.

        Checks for:
        - #version 300 es declaration
        - void main() entrypoint
        - precision qualifier

        Returns:
            True if shader appears to be valid GLSL ES 3.0
        """
        has_version = '#version 300 es' in shader_content
        has_main = 'void main()' in shader_content or 'void main(' in shader_content
        has_precision = 'precision' in shader_content

        return has_version and has_main and has_precision

    def get_reference_examples(self, shader_harness_path: str) -> List[str]:
        """Load GLSL ES 3.0 reference examples from shader_harness.

        Loads:
        1. *.glsl files - Working GLSL ES 3.0 shader examples
        2. glsl_guide.txt - Documentation for GLSL ES 3.0

        Args:
            shader_harness_path: Path to shader_harness directory

        Returns:
            List of formatted example strings
        """
        from pathlib import Path

        example_files = []
        shader_harness = Path(shader_harness_path)

        # Load GLSL guide if available
        glsl_guide_path = shader_harness / "glsl_guide.txt"
        if glsl_guide_path.exists():
            with open(glsl_guide_path, 'r') as f:
                guide_content = f.read()
                example_files.append(
                    f"GLSL_ES_3.0_GUIDE:\n```\n{guide_content}\n```"
                )

        # Load GLSL reference shaders
        shaders_path = shader_harness / "shaders"
        if shaders_path.exists():
            for shader_file in sorted(shaders_path.iterdir()):
                if shader_file.suffix == '.glsl' and shader_file.name != 'simple_cube.glsl':
                    with open(shader_file, 'r') as f:
                        shader_content = f.read()
                        # Check if this is GLSL ES 3.0 format
                        if '#version 300 es' in shader_content or '#version 320 es' in shader_content:
                            example_files.append(
                                f"GLSL_ES_3.0_EXAMPLE ({shader_file.name}):\n```glsl\n{shader_content}\n```"
                            )

        return example_files
