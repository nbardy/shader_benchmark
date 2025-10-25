"""
Shader Language Specifications - Abstraction layer for WGSL vs GLSL

This module defines a clean separation between language-specific concerns and
core generation logic, enabling rapid ablation experiments (WGSL vs GLSL).

Architecture:
- ShaderLanguageSpec: Abstract base class defining the interface
- WGSLSpec: WebGPU Shading Language specification (current production)
- GLSLSpec: OpenGL Shading Language specification (future ablations)

Each spec encapsulates:
1. Language name and metadata (file extension, versioning)
2. Constraint prompts (what format to generate)
3. Syntax validators (how to verify output)
4. Reference examples (what context to provide LLM)

Usage:
    wgsl_spec = WGSLSpec()
    parser = ShaderParser(language_spec=wgsl_spec)
    client = LLMClient(language_spec=wgsl_spec)

    # For ablation experiments:
    glsl_spec = GLSLSpec()
    parser_glsl = ShaderParser(language_spec=glsl_spec)
"""

from abc import ABC, abstractmethod
from typing import Callable, List, Optional
import re


class ShaderLanguageSpec(ABC):
    """Abstract base class for shader language specifications.

    Defines the interface that all language specs must implement.
    This ensures swappable language specifications with consistent API.
    """

    @property
    @abstractmethod
    def name(self) -> str:
        """Language name (e.g., 'WGSL', 'GLSL')"""
        pass

    @property
    @abstractmethod
    def description(self) -> str:
        """Human-readable description of the language"""
        pass

    @property
    @abstractmethod
    def file_extension(self) -> str:
        """File extension for this language (e.g., '.wgsl', '.glsl')"""
        pass

    @property
    @abstractmethod
    def constraint_prompt(self) -> str:
        """Language-specific constraint prompt for LLM generation.

        This is the core prompt that tells the LLM what format to use,
        what syntax is valid, and what the ABI contract is.
        """
        pass

    @abstractmethod
    def validate_syntax(self, shader_content: str) -> bool:
        """Validate that shader content conforms to language syntax.

        Args:
            shader_content: The shader source code to validate

        Returns:
            True if syntax appears valid, False otherwise
        """
        pass

    @abstractmethod
    def get_reference_examples(self, shader_harness_path: str) -> List[str]:
        """Get language-specific reference examples from shader_harness.

        Args:
            shader_harness_path: Path to shader_harness directory

        Returns:
            List of formatted reference examples (strings)
        """
        pass

    @property
    @abstractmethod
    def fallback_filename(self) -> str:
        """Default filename for generated shaders (e.g., 'shader.wgsl')"""
        pass


class WGSLSpec(ShaderLanguageSpec):
    """WebGPU Shading Language (WGSL) specification.

    WGSL is the shader language for WebGPU, designed for modern graphics APIs.
    This is the current production language used by shader_benchmark.

    Key characteristics:
    - Explicit types (vec2<f32> not vec2)
    - Address spaces required (var<function>, var<uniform>)
    - @vertex, @fragment, @compute stage attributes
    - @group/@binding for resource bindings
    - Strict type checking (no implicit conversions)

    ABI Contract:
    - Vertex shader: vs_main(@builtin(vertex_index) u32) -> @builtin(position) vec4<f32>
    - Fragment shader: fs_main(@builtin(position) vec4<f32>) -> @location(0) vec4<f32>
    - Uniforms: @group(0) @binding(0) var<uniform> Params: Params
    """

    @property
    def name(self) -> str:
        return "WGSL"

    @property
    def description(self) -> str:
        return "WebGPU Shading Language - Modern GPU shader language with explicit types and strict ABI"

    @property
    def file_extension(self) -> str:
        return ".wgsl"

    @property
    def fallback_filename(self) -> str:
        return "shader.wgsl"

    @property
    def constraint_prompt(self) -> str:
        """WGSL constraint prompt - STRICT ABI CONTRACT.

        This prompt defines the exact ABI contract that shader_harness expects.
        DO NOT modify entrypoint signatures or bind group layout.
        """
        return """🔒 WGSL FORMAT LOCK - STRICT ABI CONTRACT
============================================

You MUST generate ONLY valid WGSL code. This is NOT a negotiable suggestion—it is the mandatory format.

ENTRYPOINT SIGNATURES (DO NOT MODIFY):
---------------------------------------------
@vertex
fn vs_main(@builtin(vertex_index) vertex_index: u32) -> @builtin(position) vec4<f32> {
    // You may customize the vertex logic, but signature is fixed.
    // Full-screen triangle generation expected.
    let vertex_id = vertex_index % 3u;
    let x = f32(i32(vertex_id & 1u) << 2u) - 1.0;
    let y = f32(i32((vertex_id >> 1u) & 1u) << 2u) - 1.0;
    return vec4<f32>(x, y, 0.0, 1.0);
}

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    // Your fragment logic here
    // MUST return vec4<f32>
}

BIND GROUP CONTRACT:
---------------------------------------------
All uniforms must use this structure (modify contents, not layout):

@group(0) @binding(0) var<uniform> Params: Params;

struct Params {
    // Add your float32 fields here
    // Example:
    // time: f32,
    // aspect: f32,
    // resolution: vec2<f32>,
};

TYPE REQUIREMENTS:
---------------------------------------------
- Use explicit types: vec2<f32>, vec3<f32>, vec4<f32>, NOT vec2, vec3, vec4
- Use i32, u32, f32 for scalars (NOT int, uint, float)
- NO implicit type conversions
- Array indexing ONLY with integer expressions: array[u32(expr)]
- Use var<function> for function-local variables
- Use let for immutable bindings

SYNTAX YOU MUST NOT USE:
---------------------------------------------
❌ @vertex, @fragment in function bodies (only as attributes)
❌ var without address space (e.g., var x: f32; is WRONG)
❌ Implicit casts (e.g., f32(1) where 1 is i32)
❌ gl_* variables
❌ #ifdef, #define, or any preprocessor
❌ uniform keyword (use @group/@binding instead)
❌ @attribute decorators inside structs (decoration goes on struct field)

EXAMPLE MINIMAL SHADER:
---------------------------------------------
@vertex
fn vs_main(@builtin(vertex_index) vertex_index: u32) -> @builtin(position) vec4<f32> {
    let vertex_id = vertex_index % 3u;
    let x = f32(i32(vertex_id & 1u) << 2u) - 1.0;
    let y = f32(i32((vertex_id >> 1u) & 1u) << 2u) - 1.0;
    return vec4<f32>(x, y, 0.0, 1.0);
}

@group(0) @binding(0) var<uniform> Params: Params;

struct Params {
    resolution: vec2<f32>,
};

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let uv = pos.xy / Params.resolution;
    return vec4<f32>(uv, 0.5, 1.0);
}"""

    def validate_syntax(self, shader_content: str) -> bool:
        """Validate WGSL syntax by checking for required patterns.

        Checks for:
        - Stage attributes (@vertex, @fragment, @compute)
        - Function definitions (fn keyword)

        Returns:
            True if shader appears to be valid WGSL
        """
        # Check for WGSL-specific stage attributes
        if '@vertex' in shader_content or '@fragment' in shader_content or '@compute' in shader_content:
            return True

        # Check for WGSL function definitions
        if 'fn ' in shader_content:
            return True

        return False

    def get_reference_examples(self, shader_harness_path: str) -> List[str]:
        """Load WGSL reference examples from shader_harness.

        Loads:
        1. main.rs - PRIMARY reference for WGSL ABI contract (entrypoints, bind groups)
        2. Cargo.toml - Project dependencies and context
        3. *.wgsl files - Working shader examples

        Args:
            shader_harness_path: Path to shader_harness directory

        Returns:
            List of formatted example strings
        """
        import os
        from pathlib import Path

        example_files = []
        shader_harness = Path(shader_harness_path)

        # Load main.rs - PRIMARY reference for WGSL ABI contract
        main_rs_path = shader_harness / "src" / "main.rs"
        if main_rs_path.exists():
            with open(main_rs_path, 'r') as f:
                main_content = f.read()
                example_files.append(
                    f"WGSL_ABI_REFERENCE (shader_harness/src/main.rs):\n```rust\n{main_content}\n```"
                )

        # Load Cargo.toml for project context
        cargo_toml_path = shader_harness / "Cargo.toml"
        if cargo_toml_path.exists():
            with open(cargo_toml_path, 'r') as f:
                cargo_content = f.read()
                example_files.append(
                    f"Cargo.toml (Project Dependencies):\n```toml\n{cargo_content}\n```"
                )

        # Load WGSL reference shaders
        shaders_path = shader_harness / "shaders"
        if shaders_path.exists():
            for shader_file in sorted(shaders_path.iterdir()):
                if shader_file.suffix == '.wgsl':
                    with open(shader_file, 'r') as f:
                        shader_content = f.read()
                        example_files.append(
                            f"WGSL_EXAMPLE ({shader_file.name}):\n```wgsl\n{shader_content}\n```"
                        )

        return example_files


class GLSLSpec(ShaderLanguageSpec):
    """OpenGL Shading Language (GLSL) specification.

    GLSL is the traditional shader language for OpenGL/WebGL.
    This spec is provided for future ablation experiments comparing WGSL vs GLSL.

    Key characteristics:
    - Implicit types (vec2, vec3, vec4 without type parameters)
    - Built-in variables (gl_FragCoord, gl_Position)
    - Preprocessor support (#version, #ifdef, #define)
    - Variable array indexing (works in GLSL, not WGSL)
    - Implicit type conversions

    Supported formats:
    - Standard GLSL ES 3.2 (mobile-compatible)
    - Shadertoy-style fragment shaders (mainImage entrypoint)

    NOTE: This is currently a placeholder for future ablation experiments.
    The shader_harness may need modifications to support GLSL compilation/execution.
    """

    @property
    def name(self) -> str:
        return "GLSL"

    @property
    def description(self) -> str:
        return "OpenGL Shading Language - Traditional GPU shader language with implicit types"

    @property
    def file_extension(self) -> str:
        return ".glsl"

    @property
    def fallback_filename(self) -> str:
        return "shader.glsl"

    @property
    def constraint_prompt(self) -> str:
        """GLSL constraint prompt - FRAGMENT SHADER FORMAT.

        This prompt defines GLSL ES 3.2 format for fragment shaders.
        Supports both standard GLSL and Shadertoy-style mainImage.

        NOTE: This is a future ablation target. Current shader_harness
        expects WGSL format. Use this spec to measure impact of language
        choice on LLM success rates.
        """
        return """🔒 GLSL ES 3.2 FORMAT - FRAGMENT SHADER
============================================

You MUST generate valid GLSL ES 3.2 fragment shader code.

VERSION DECLARATION (REQUIRED):
---------------------------------------------
#version 320 es
precision highp float;

ENTRYPOINT SIGNATURE:
---------------------------------------------
Option 1 (Standard GLSL):
void main() {
    // Your fragment logic here
    // Output to gl_FragColor or declared out variable
}

Option 2 (Shadertoy-style):
void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    // Your fragment logic here
    // Set fragColor output
}

OUTPUT VARIABLE:
---------------------------------------------
out vec4 fragColor;  // Declare at top level

BUILT-IN VARIABLES:
---------------------------------------------
- gl_FragCoord: vec4 (pixel coordinates, w component for perspective)
- gl_Position: vec4 (only in vertex shaders)

TYPE SYSTEM:
---------------------------------------------
- Implicit types: vec2, vec3, vec4 (no type parameters)
- Scalars: int, uint, float (simpler than WGSL)
- Implicit type conversions allowed
- Variable array indexing WORKS in GLSL (unlike WGSL)

EXAMPLE FEATURES THAT WORK IN GLSL:
---------------------------------------------
// Variable array indexing (FORBIDDEN in WGSL)
vec3 vertices[8] = vec3[](
    vec3(-1.0, -1.0, -1.0),
    vec3(1.0, -1.0, -1.0),
    // ... more vertices
);
for (int i = 0; i < 8; i++) {
    vec3 v = vertices[i];  // Variable indexing works!
}

// Implicit conversions
float x = 1;  // int -> float conversion works
vec3 color = vec3(x);  // Scalar expansion works

SYNTAX YOU CAN USE (vs WGSL):
---------------------------------------------
✅ Preprocessor: #version, #ifdef, #define
✅ Built-ins: gl_FragCoord, gl_Position
✅ Variable array indexing: array[variable_index]
✅ Implicit conversions: int to float, scalar expansion
✅ Standard math: sin, cos, length, dot, cross, mix, etc.

EXAMPLE MINIMAL SHADER:
---------------------------------------------
#version 320 es
precision highp float;

out vec4 fragColor;

void main() {
    vec2 uv = gl_FragCoord.xy / 512.0;
    fragColor = vec4(uv, 0.5, 1.0);
}"""

    def validate_syntax(self, shader_content: str) -> bool:
        """Validate GLSL syntax by checking for required patterns.

        Checks for:
        - Shadertoy mainImage entrypoint
        - Standard GLSL main() entrypoint
        - GLSL function definitions (void keyword)

        Returns:
            True if shader appears to be valid GLSL
        """
        # Check for Shadertoy GLSL format
        if 'void mainImage' in shader_content:
            return True

        # Check for standard GLSL main entrypoint
        if 'void main()' in shader_content:
            return True

        # Check for GLSL function definitions
        if 'void ' in shader_content:
            return True

        return False

    def get_reference_examples(self, shader_harness_path: str) -> List[str]:
        """Load GLSL reference examples from shader_harness.

        Loads:
        1. *.glsl files - Working GLSL shader examples

        Args:
            shader_harness_path: Path to shader_harness directory

        Returns:
            List of formatted example strings
        """
        from pathlib import Path

        example_files = []
        shader_harness = Path(shader_harness_path)

        # Load GLSL reference shaders
        shaders_path = shader_harness / "shaders"
        if shaders_path.exists():
            for shader_file in sorted(shaders_path.iterdir()):
                if shader_file.suffix == '.glsl':
                    with open(shader_file, 'r') as f:
                        shader_content = f.read()
                        example_files.append(
                            f"GLSL_EXAMPLE ({shader_file.name}):\n```glsl\n{shader_content}\n```"
                        )

        return example_files


# Factory function for easy spec instantiation
def get_language_spec(language_name: str) -> ShaderLanguageSpec:
    """Factory function to instantiate language specs by name.

    Args:
        language_name: Language name ('wgsl', 'glsl', case-insensitive)

    Returns:
        Appropriate ShaderLanguageSpec instance

    Raises:
        ValueError: If language_name is not recognized

    Example:
        spec = get_language_spec('wgsl')
        parser = ShaderParser(language_spec=spec)
    """
    language_name_lower = language_name.lower()

    if language_name_lower == 'wgsl':
        return WGSLSpec()
    elif language_name_lower == 'glsl':
        return GLSLSpec()
    else:
        raise ValueError(
            f"Unknown language: {language_name}. "
            f"Supported languages: 'wgsl', 'glsl'"
        )


# Supported languages registry
SUPPORTED_LANGUAGES = ['wgsl', 'glsl']
