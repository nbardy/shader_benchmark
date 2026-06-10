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
The runtime provides EXACTLY this uniform struct — these are the only
values that exist. Do NOT add other fields; they would silently read
garbage (the buffer is raw bytes with no field-name checking).

@group(0) @binding(0) var<uniform> params: Params;

struct Params {
    resolution: vec2<f32>,  // render target size in pixels (square)
    time: f32,              // always 0.0 — you are rendering ONE static frame
    aspect: f32,            // width/height — always 1.0 (square target)
};

You may declare a shorter prefix of this struct (e.g. resolution only),
but never reorder fields or invent new ones. Design for a static image:
animation driven by `time` will be frozen at t=0.

TYPE REQUIREMENTS:
---------------------------------------------
- Use explicit types: vec2<f32>, vec3<f32>, vec4<f32>, NOT vec2, vec3, vec4
- Use i32, u32, f32 for scalars (NOT int, uint, float)
- NO implicit type conversions
- Array indexing ONLY with integer expressions: array[u32(expr)]
- Use var<function> for function-local variables
- Use let for immutable bindings

CRITICAL NUMERIC LIMITS (⚠️ COMPILATION FAILURES):
---------------------------------------------
⚠️ f32 maximum value: 3.4e38 (DO NOT exceed this!)
⚠️ For extremely large mathematical values, use logarithmic scales
⚠️ Example: For Ackermann(3,8) ≈ 10^154, visualize log(value) NOT the raw value
⚠️ NEVER hardcode literals > 1e38 - shader will fail to compile

CRITICAL WGSL OPERATORS (⚠️ COMPILATION FAILURES):
---------------------------------------------
⚠️ MODULO: Use % operator, NOT mod() function!
   ✅ CORRECT:   let remainder = x % 5.0;
   ❌ WRONG:     let remainder = mod(x, 5.0);  // mod() does not exist in WGSL!

⚠️ TERNARY: Use select() function, NOT if/else expressions
   ✅ CORRECT:   let value = select(false_val, true_val, condition);
   ❌ WRONG:     let value = if (condition) { true_val } else { false_val };

⚠️ RUNTIME ARRAY INDEXING: an array you index with a loop variable or any
   runtime value MUST be declared as `var`, NOT `let`/`const` — naga fails
   with "may only be indexed by a constant" otherwise.
   ✅ CORRECT:   var seeds: array<vec2<f32>, 8> = array<vec2<f32>, 8>(...);
                 let d = length(uv - seeds[i]);
   ❌ WRONG:     let seeds = array<vec2<f32>, 8>(...);   // ← compile error
                 let d = length(uv - seeds[i]);          //   when i is runtime

WGSL RESERVED KEYWORDS (⚠️ DO NOT USE AS VARIABLE NAMES):
---------------------------------------------
⚠️ WGSL reserves MANY ordinary English words. These have all caused real
   compile failures: target, active, pass, module, macro, handle, filter,
   common, final, new, type, set, get, self, this, import, export, match,
   ref, union, static, std, meta, demote, resource, attribute, layout,
   precise, smooth, shared, public, mod
   Use suffixed alternatives: target_pos, active_flag, pass_idx, module_id,
   filter_w, set_v, type_id, etc. When in doubt, suffix with _v.

⚠️ NEVER use underscore as identifier:
   ❌ WRONG:     let _ = some_function();
   ✅ CORRECT:   let _unused = some_function();

SYNTAX YOU MUST NOT USE:
---------------------------------------------
❌ @vertex, @fragment in function bodies (only as attributes)
❌ var without address space (e.g., var x: f32; is WRONG)
❌ Implicit casts (e.g., f32(1) where 1 is i32)
❌ gl_* variables
❌ #ifdef, #define, or any preprocessor
❌ uniform keyword (use @group/@binding instead)
❌ @attribute decorators inside structs (decoration goes on struct field)
❌ mod() function (use % operator)
❌ if/else expressions as values (use select() function)

EXAMPLE MINIMAL SHADER:
---------------------------------------------
@vertex
fn vs_main(@builtin(vertex_index) vertex_index: u32) -> @builtin(position) vec4<f32> {
    let vertex_id = vertex_index % 3u;
    let x = f32(i32(vertex_id & 1u) << 2u) - 1.0;
    let y = f32(i32((vertex_id >> 1u) & 1u) << 2u) - 1.0;
    return vec4<f32>(x, y, 0.0, 1.0);
}

@group(0) @binding(0) var<uniform> params: Params;

struct Params {
    resolution: vec2<f32>,
};

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let uv = pos.xy / params.resolution;
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
    elif language_name_lower == 'shadertoy':
        return ShadertoySpec()
    elif language_name_lower == 'hlsl_unity':
        return HLSLUnitySpec()
    else:
        raise ValueError(
            f"Unknown language: {language_name}. "
            f"Supported languages: 'wgsl', 'glsl', 'shadertoy', 'hlsl_unity'"
        )


class ShadertoySpec(ShaderLanguageSpec):
    """Shadertoy GLSL specification.

    Shadertoy is a popular web-based shader creation platform with 50K+ shaders.
    This spec leverages Shadertoy's well-known format for better LLM success rates.

    Key characteristics:
    - mainImage(out vec4, in vec2) entrypoint signature
    - Built-in uniforms: iTime, iResolution, iMouse, iChannel0-3
    - Multi-buffer rendering support (BufferA-D for feedback loops)
    - GLSL ES 3.0 syntax (implicit types, simpler than WGSL)
    - Massive training corpus (50K+ public shaders on shadertoy.com)

    ABI Contract:
    - Entry: void mainImage(out vec4 fragColor, in vec2 fragCoord)
    - Uniforms: iTime (float), iResolution (vec3), iMouse (vec4)
    - Channels: iChannel0-3 (sampler2D for textures/buffers)
    - Multi-pass: BufferA-D for feedback loops and complex effects
    """

    @property
    def name(self) -> str:
        return "Shadertoy"

    @property
    def description(self) -> str:
        return "Shadertoy GLSL - Web-based shader format with 50K+ training examples"

    @property
    def file_extension(self) -> str:
        return ".glsl"

    @property
    def fallback_filename(self) -> str:
        return "shadertoy.glsl"

    @property
    def constraint_prompt(self) -> str:
        """Shadertoy constraint prompt - LEVERAGE 50K+ TRAINING EXAMPLES.

        This prompt defines the Shadertoy format that LLMs have seen extensively
        during training, potentially yielding higher success rates than WGSL.
        """
        return """🎨 SHADERTOY FORMAT - LEVERAGE 50K+ TRAINING EXAMPLES
============================================

You MUST generate valid Shadertoy-compatible GLSL fragment shader code.
Shadertoy is a popular web platform - LLMs have seen thousands of examples!

ENTRYPOINT SIGNATURE (MANDATORY):
---------------------------------------------
void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    // Your shader code here
    // fragCoord: pixel coordinates (0,0) to iResolution.xy
    // fragColor: output color (RGBA, 0-1 range)
}

BUILT-IN UNIFORMS (AUTOMATICALLY PROVIDED):
---------------------------------------------
uniform vec3 iResolution;   // Viewport resolution (width, height, pixel aspect ratio)
uniform float iTime;        // Shader playback time (seconds since start)
uniform float iTimeDelta;   // Time since last frame (seconds)
uniform int iFrame;         // Frame number (starts at 0)
uniform vec4 iMouse;        // Mouse coordinates (xy = current, zw = click)
uniform vec4 iDate;         // (year, month, day, time in seconds)
uniform float iSampleRate;  // Audio sample rate (44100 Hz typically)

TEXTURE/BUFFER CHANNELS (OPTIONAL):
---------------------------------------------
uniform sampler2D iChannel0;  // Texture/buffer input channel 0
uniform sampler2D iChannel1;  // Texture/buffer input channel 1
uniform sampler2D iChannel2;  // Texture/buffer input channel 2
uniform sampler2D iChannel3;  // Texture/buffer input channel 3

COORDINATE SYSTEMS:
---------------------------------------------
// Normalize coordinates to [0, 1]
vec2 uv = fragCoord / iResolution.xy;

// Center coordinates to [-1, 1] with aspect correction
vec2 uv = (fragCoord - 0.5 * iResolution.xy) / iResolution.y;

TYPE SYSTEM (GLSL ES 3.0):
---------------------------------------------
- Implicit types: vec2, vec3, vec4 (simpler than WGSL!)
- Scalars: int, float (no need for i32/u32/f32)
- Implicit conversions allowed (int → float automatic)
- Variable array indexing WORKS (unlike WGSL)
- Standard math: sin, cos, length, dot, cross, mix, smoothstep, etc.

COMMON PATTERNS:
---------------------------------------------
// Time-based animation
float t = iTime;
vec3 color = 0.5 + 0.5 * cos(t + uv.xyx + vec3(0, 2, 4));

// Feedback loop (previous frame)
vec4 prev = texture(iChannel0, uv);  // iChannel0 = BufferA output

// Distance field rendering
float dist = length(uv) - 0.5;
vec3 color = vec3(smoothstep(0.0, 0.01, abs(dist)));

EXAMPLE MINIMAL SHADER:
---------------------------------------------
void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    // Normalized coordinates
    vec2 uv = fragCoord / iResolution.xy;

    // Animated gradient
    vec3 col = 0.5 + 0.5 * cos(iTime + uv.xyx + vec3(0, 2, 4));

    // Output
    fragColor = vec4(col, 1.0);
}

SYNTAX YOU CAN USE:
---------------------------------------------
✅ Standard GLSL ES 3.0 functions (sin, cos, length, dot, normalize, etc.)
✅ Variable array indexing: array[variable_index]
✅ Implicit conversions: int to float works automatically
✅ Swizzling: color.rgb, uv.xy, pos.yzx
✅ Built-in constants: PI not defined (use 3.14159265 or define it)

WHAT NOT TO USE:
---------------------------------------------
❌ #version directive (automatically injected)
❌ precision qualifiers (automatically set)
❌ out vec4 fragColor declaration (automatically provided)
❌ Custom uniforms (use built-ins: iTime, iResolution, etc.)
❌ gl_FragCoord (use fragCoord parameter instead)

REFERENCE:
---------------------------------------------
Official Shadertoy documentation: https://shadertoy.com/howto
50K+ public shaders: https://shadertoy.com/browse
Common techniques: https://iquilezles.org/articles/"""

    def validate_syntax(self, shader_content: str) -> bool:
        """Validate Shadertoy syntax by checking for mainImage entrypoint.

        Checks for:
        - void mainImage signature (required entrypoint)
        - Proper parameter signature (out vec4, in vec2)

        Returns:
            True if shader appears to be valid Shadertoy format
        """
        # Check for Shadertoy mainImage entrypoint
        if 'void mainImage' in shader_content:
            return True

        # Also accept variations with different spacing/formatting
        import re
        if re.search(r'void\s+mainImage\s*\(', shader_content):
            return True

        return False

    def get_reference_examples(self, shader_harness_path: str) -> List[str]:
        """Load Shadertoy reference examples from shader_harness.

        Loads:
        1. *.shadertoy.glsl files - Shadertoy-format shader examples
        2. shadertoy_examples/ directory - Curated reference shaders

        Args:
            shader_harness_path: Path to shader_harness directory

        Returns:
            List of formatted example strings
        """
        from pathlib import Path

        example_files = []
        shader_harness = Path(shader_harness_path)

        # Load Shadertoy reference shaders from shaders/ directory
        shaders_path = shader_harness / "shaders"
        if shaders_path.exists():
            for shader_file in sorted(shaders_path.iterdir()):
                if shader_file.suffix == '.glsl' and 'shadertoy' in shader_file.name.lower():
                    with open(shader_file, 'r') as f:
                        shader_content = f.read()
                        example_files.append(
                            f"SHADERTOY_EXAMPLE ({shader_file.name}):\n```glsl\n{shader_content}\n```"
                        )

        # Load from dedicated shadertoy_examples/ directory if it exists
        shadertoy_examples_path = shader_harness / "shadertoy_examples"
        if shadertoy_examples_path.exists():
            for shader_file in sorted(shadertoy_examples_path.iterdir()):
                if shader_file.suffix == '.glsl':
                    with open(shader_file, 'r') as f:
                        shader_content = f.read()
                        example_files.append(
                            f"SHADERTOY_REFERENCE ({shader_file.name}):\n```glsl\n{shader_content}\n```"
                        )

        return example_files


class HLSLUnitySpec(ShaderLanguageSpec):
    """HLSL with Unity shader conventions.

    HLSL (High-Level Shading Language) is Microsoft's shader language for DirectX.
    Unity uses HLSL with custom conventions including Surface Shaders, Properties blocks,
    and built-in variables like _Time, _ScreenParams, etc.

    Key characteristics:
    - Unity Surface Shader or fragment shader format
    - Properties block for material parameters
    - SubShader/Pass structure
    - Built-in Unity variables (_Time, _ScreenParams, UNITY_MATRIX_MVP)
    - HLSL semantics (POSITION, SV_Target, TEXCOORD0)
    - float4, float3, float2 types (not vec4/vec3/vec2)

    Compilation Pipeline:
    - HLSL -> DXC (DirectX Shader Compiler) -> SPIR-V
    - SPIR-V -> spirv-cross -> Metal (macOS execution)
    - Metal execution via Swift/Metal harness

    ABI Contract:
    - Vertex shader: v2f vert(appdata v) with POSITION semantic
    - Fragment shader: float4 frag(v2f i) : SV_Target
    - Properties: _MainTex, _Color, custom parameters
    """

    @property
    def name(self) -> str:
        return "HLSL_Unity"

    @property
    def description(self) -> str:
        return "HLSL with Unity shader conventions - Common format in LLM training data"

    @property
    def file_extension(self) -> str:
        return ".hlsl"

    @property
    def fallback_filename(self) -> str:
        return "shader.hlsl"

    @property
    def constraint_prompt(self) -> str:
        """HLSL Unity constraint prompt - Unity Surface Shader or fragment shader format."""
        return """🔒 HLSL UNITY SHADER FORMAT
============================================

You MUST generate valid HLSL code using Unity shader conventions.

SHADER STRUCTURE (REQUIRED):
---------------------------------------------
Shader "Custom/ShaderName" {
    Properties {
        _MainTex ("Texture", 2D) = "white" {}
        _Color ("Color", Color) = (1,1,1,1)
        // Add your properties here
    }

    SubShader {
        Tags { "RenderType"="Opaque" }
        Pass {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"

            struct appdata {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
            };

            // Declare properties
            sampler2D _MainTex;
            float4 _MainTex_ST;
            float4 _Color;

            v2f vert (appdata v) {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                return o;
            }

            float4 frag (v2f i) : SV_Target {
                // Your fragment shader logic here
                return _Color;
            }
            ENDCG
        }
    }
}

UNITY BUILT-IN VARIABLES:
---------------------------------------------
- _Time: float4 (t/20, t, t*2, t*3) - Time since level load
- _SinTime: float4 (t/8, t/4, t/2, t) - Sine of time
- _CosTime: float4 (t/8, t/4, t/2, t) - Cosine of time
- _ScreenParams: float4 (width, height, 1+1/width, 1+1/height)
- _WorldSpaceCameraPos: float3 - Camera position in world space
- unity_OrthoParams: float4 - Orthographic camera parameters

UNITY BUILT-IN FUNCTIONS:
---------------------------------------------
- UnityObjectToClipPos(float4 vertex) - Transform object space to clip space
- UnityObjectToWorldPos(float4 vertex) - Transform object space to world space
- UnityWorldToClipPos(float4 vertex) - Transform world space to clip space
- TRANSFORM_TEX(uv, tex) - Apply texture tiling/offset
- tex2D(sampler, uv) - Sample 2D texture
- lerp(a, b, t) - Linear interpolation
- saturate(x) - Clamp to [0,1]

TYPE SYSTEM:
---------------------------------------------
- Use HLSL types: float4, float3, float2, float (NOT vec4, vec3, vec2)
- Use int, uint for integers
- Use sampler2D, sampler3D, samplerCUBE for textures
- Use half4, half3, half2 for lower precision (mobile optimization)

SEMANTICS (REQUIRED):
---------------------------------------------
Vertex shader input:
- POSITION - Vertex position
- TEXCOORD0, TEXCOORD1 - Texture coordinates
- NORMAL - Vertex normal
- TANGENT - Vertex tangent
- COLOR - Vertex color

Vertex shader output / Fragment shader input:
- SV_POSITION - Clip space position (required for vertex output)
- TEXCOORD0-7 - Interpolated data
- COLOR - Interpolated color

Fragment shader output:
- SV_Target - Render target output (required)

EXAMPLE MINIMAL SHADER:
---------------------------------------------
Shader "Custom/MinimalShader" {
    Properties {
        _Color ("Main Color", Color) = (1,1,1,1)
    }
    SubShader {
        Pass {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"

            struct appdata {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
            };

            float4 _Color;

            v2f vert (appdata v) {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                return o;
            }

            float4 frag (v2f i) : SV_Target {
                float2 uv = i.uv;
                return float4(uv.x, uv.y, 0.5, 1.0) * _Color;
            }
            ENDCG
        }
    }
}

SYNTAX YOU MUST NOT USE:
---------------------------------------------
❌ GLSL types (vec2, vec3, vec4)
❌ WGSL syntax (@vertex, @fragment, fn)
❌ OpenGL built-ins (gl_FragCoord, gl_Position)
❌ Missing semantics on struct fields
❌ Missing CGPROGRAM/ENDCG blocks
❌ Missing #pragma vertex/fragment directives
"""

    def validate_syntax(self, shader_content: str) -> bool:
        """Validate HLSL Unity syntax by checking for required patterns.

        Checks for:
        - Shader declaration
        - CGPROGRAM/ENDCG blocks
        - #pragma vertex/fragment directives
        - HLSL function signatures with semantics

        Returns:
            True if shader appears to be valid HLSL Unity format
        """
        # Check for Unity shader structure
        if 'Shader "' in shader_content or 'Shader\'' in shader_content:
            return True

        # Check for CGPROGRAM/ENDCG blocks
        if 'CGPROGRAM' in shader_content and 'ENDCG' in shader_content:
            return True

        # Check for HLSL semantics
        if 'SV_Target' in shader_content or 'SV_POSITION' in shader_content:
            return True

        # Check for HLSL function with semantics
        if ': SV_Target' in shader_content or ': POSITION' in shader_content:
            return True

        return False

    def get_reference_examples(self, shader_harness_path: str) -> List[str]:
        """Load HLSL Unity reference examples from shader_harness.

        Loads:
        1. *.hlsl files - Working Unity HLSL shader examples
        2. Unity shader documentation snippets

        Args:
            shader_harness_path: Path to shader_harness directory

        Returns:
            List of formatted example strings
        """
        from pathlib import Path

        example_files = []
        shader_harness = Path(shader_harness_path)

        # Load HLSL reference shaders
        shaders_path = shader_harness / "shaders"
        if shaders_path.exists():
            for shader_file in sorted(shaders_path.iterdir()):
                if shader_file.suffix == '.hlsl':
                    with open(shader_file, 'r') as f:
                        shader_content = f.read()
                        example_files.append(
                            f"HLSL_UNITY_EXAMPLE ({shader_file.name}):\n```hlsl\n{shader_content}\n```"
                        )

        return example_files


# Supported languages registry
SUPPORTED_LANGUAGES = ['wgsl', 'glsl', 'shadertoy', 'hlsl_unity']
