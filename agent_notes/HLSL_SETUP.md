# HLSL Unity Shader Pipeline Setup Guide

This guide provides step-by-step instructions for setting up the HLSL Unity shader pipeline on macOS.

## Overview

The HLSL Unity pipeline enables shader benchmark to test LLM shader generation using Unity HLSL format, which is prevalent in LLM training data due to Unity's widespread adoption.

### Compilation Pipeline

```
Unity HLSL Shader
    ↓
Extract Fragment Shader (Python)
    ↓
Add Unity Built-in Stubs (Python)
    ↓
DXC Compiler (HLSL → SPIR-V)
    ↓
spirv-cross (SPIR-V → Metal)
    ↓
Swift/Metal Harness (Execute + Render)
    ↓
PNG Output (1600x1600)
```

## Prerequisites

### System Requirements

- **macOS**: 10.15 (Catalina) or later
- **Xcode Command Line Tools**: For Swift compiler and Metal framework
- **Homebrew**: Package manager for installing DXC and spirv-cross

### Check Existing Tools

```bash
# Check if Xcode Command Line Tools are installed
xcode-select --version

# Check if Homebrew is installed
brew --version

# Check Swift compiler
swiftc --version
```

## Installation Steps

### 1. Install Xcode Command Line Tools

If not already installed:

```bash
xcode-select --install
```

This provides:
- Swift compiler (`swiftc`)
- Metal framework (GPU acceleration)
- System headers and libraries

**Verification:**
```bash
swiftc --version
# Should output: Apple Swift version 5.x or later
```

### 2. Install Homebrew

If not already installed:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

Follow the post-installation instructions to add Homebrew to your PATH.

**Verification:**
```bash
brew --version
# Should output: Homebrew 4.x or later
```

### 3. Install DXC (DirectX Shader Compiler)

DXC is Microsoft's open-source HLSL compiler that outputs SPIR-V.

```bash
brew install directx-shader-compiler
```

**Verification:**
```bash
dxc --version
# Should output: dxc version 1.x (SPIR-V)

# Check location
which dxc
# Typical output: /opt/homebrew/bin/dxc (Apple Silicon)
#            or: /usr/local/bin/dxc (Intel)
```

**Alternative Installation (if Homebrew fails):**

Download pre-built binaries from Microsoft:
1. Visit: https://github.com/microsoft/DirectXShaderCompiler/releases
2. Download latest macOS release (e.g., `dxc_macos.zip`)
3. Extract and move `dxc` to `/usr/local/bin/`
4. Make executable: `chmod +x /usr/local/bin/dxc`

### 4. Install spirv-cross

spirv-cross translates SPIR-V intermediate representation to Metal Shading Language.

```bash
brew install spirv-cross
```

**Verification:**
```bash
spirv-cross --version
# Should output: spirv-cross version info

# Check location
which spirv-cross
# Typical output: /opt/homebrew/bin/spirv-cross (Apple Silicon)
#            or: /usr/local/bin/spirv-cross (Intel)
```

**Alternative Installation (if Homebrew fails):**

Build from source:
```bash
git clone https://github.com/KhronosGroup/SPIRV-Cross.git
cd SPIRV-Cross
mkdir build && cd build
cmake ..
make
sudo make install
```

### 5. Verify Complete Toolchain

Run the built-in toolchain check:

```bash
cd /Users/nicholasbardy/git/shader_benchmark/llm_harness
python3 -c "from hlsl_runtime import check_hlsl_toolchain; print(check_hlsl_toolchain()[1])"
```

**Expected output:**
```
HLSL toolchain ready
```

**If you see errors:**
- DXC not found: Re-run `brew install directx-shader-compiler`
- spirv-cross not found: Re-run `brew install spirv-cross`
- swiftc not found: Re-run `xcode-select --install`

## Usage

### Basic Test Command

Test HLSL pipeline with a single problem:

```bash
cd llm_harness
source venv/bin/activate  # Or: uv run

python main.py \
    --model "anthropic/claude-3.5-sonnet-20241022" \
    --prompt-folder "../problems/base_set/geometric_cube" \
    --language-spec hlsl_unity
```

### Batch Testing

Run multiple problems with HLSL:

```bash
cd llm_harness
source venv/bin/activate  # Or: uv run

python benchmark_harness.py \
    --language hlsl_unity \
    --model "anthropic/claude-3.5-sonnet-20241022" \
    --problems geometric_cube hopf_fibration mandelbrot_set
```

### Example Shaders

Reference Unity HLSL shaders are provided in:
```
shader_harness/shaders/unity_simple_gradient.hlsl
shader_harness/shaders/unity_circle_pattern.hlsl
shader_harness/shaders/unity_mandelbrot.hlsl
```

View an example:
```bash
cat shader_harness/shaders/unity_simple_gradient.hlsl
```

## Architecture Details

### HLSLUnitySpec Class

Located in: `llm_harness/language_specs.py`

Key features:
- `name`: "HLSL_Unity"
- `file_extension`: ".hlsl"
- `constraint_prompt`: Defines Unity shader format with Properties, SubShader, Pass structure
- `validate_syntax()`: Checks for Unity shader structure (CGPROGRAM blocks, semantics)
- `get_reference_examples()`: Loads example Unity HLSL shaders

### HLSLRuntime Class

Located in: `llm_harness/hlsl_runtime.py`

Key methods:
- `extract_hlsl_fragment()`: Parses Unity shader to extract HLSL fragment code
- `create_standalone_hlsl()`: Adds Unity built-in stubs (UnityObjectToClipPos, TRANSFORM_TEX, etc.)
- `compile_hlsl_to_spirv()`: DXC compilation (HLSL → SPIR-V)
- `compile_spirv_to_metal()`: spirv-cross translation (SPIR-V → Metal)
- `create_metal_harness()`: Generates Swift/Metal execution harness
- `execute_metal_shader()`: Compiles Swift and renders PNG output
- `compile_and_execute()`: Full pipeline orchestration

### Unity Built-in Stubs

The runtime provides stub implementations for Unity built-in functions:

```hlsl
// Unity built-in variables (via cbuffer)
float4 _Time;              // (t/20, t, t*2, t*3)
float4 _SinTime;           // (t/8, t/4, t/2, t)
float4 _CosTime;           // (t/8, t/4, t/2, t)
float4 _ScreenParams;      // (width, height, 1+1/width, 1+1/height)
float3 _WorldSpaceCameraPos;
float4 unity_OrthoParams;

// Unity built-in functions (stub implementations)
float4 UnityObjectToClipPos(float4 vertex);
float4 UnityObjectToWorldPos(float4 vertex);
float4 UnityWorldToClipPos(float4 vertex);
float2 TRANSFORM_TEX(float2 uv, sampler2D tex);
float4 tex2D(sampler2D samp, float2 uv);
```

These stubs allow Unity HLSL shaders to compile without the full Unity engine.

## Troubleshooting

### DXC Compilation Errors

**Error: "DXC compilation failed: entry point 'frag' not found"**

Solution:
- Ensure your fragment shader function is named `frag`
- Check that it has the `SV_Target` semantic: `float4 frag(v2f i) : SV_Target`

**Error: "undefined identifier 'UnityObjectToClipPos'"**

Solution:
- The Unity built-in stub should be automatically added
- Check that `hlsl_runtime.py` `create_standalone_hlsl()` is being called
- Verify the function is defined in the Unity stubs section

### spirv-cross Errors

**Error: "spirv-cross compilation failed: unsupported SPIR-V feature"**

Solution:
- Update spirv-cross: `brew upgrade spirv-cross`
- Check DXC is targeting Vulkan 1.1: `-fspv-target-env=vulkan1.1`

### Metal Execution Errors

**Error: "Metal is not supported on this device"**

Solution:
- Ensure you're running on macOS 10.15+ with Metal-capable GPU
- Check Metal support: `system_profiler SPDisplaysDataType | grep Metal`

**Error: "Fragment function not found in Metal library"**

Solution:
- The spirv-cross output may use a different entry point name (e.g., `main0` instead of `frag`)
- Check the `.metal` file in the temporary directory (add debug logging to `hlsl_runtime.py`)

### Performance Issues

**Slow compilation (>30 seconds per shader)**

Solution:
- DXC compilation can be slow on first run (shader cache warmup)
- Consider reducing shader complexity for faster iteration
- Pre-compile common shaders and cache SPIR-V output

## Known Limitations

### Multi-Pass Rendering

**Status:** Not yet implemented

Unity's multi-pass rendering (RenderTexture, GrabPass) is not currently supported. Single-pass shaders only.

**Future Work:**
- Implement RenderTexture equivalents using Metal MTLTexture
- Support multi-pass pipeline in `hlsl_runtime.py`
- Enable feedback loops and post-processing effects

### Unity Built-in Functions

**Status:** Partial implementation

Stub implementations provided for common built-ins:
- ✅ `UnityObjectToClipPos`
- ✅ `_Time`, `_ScreenParams` variables
- ❌ `tex2D` (requires texture binding refactor)
- ❌ `UNITY_MATRIX_MVP` (matrix transformations)
- ❌ Surface Shaders (require code generation)

**Workaround:**
- Use fragment shaders instead of Surface Shaders
- Avoid texture sampling (`tex2D`) for now
- Implement custom transformations instead of matrix built-ins

### Properties to Uniform Buffers

**Status:** Placeholder implementation

Unity Properties are currently stubbed but not bound to actual uniform buffers.

**Future Work:**
- Parse Properties block
- Generate Metal uniform buffer structure
- Bind property values from Python harness

## Advanced Usage

### Custom Unity Built-ins

To add custom Unity built-in functions, edit `hlsl_runtime.py`:

```python
def create_standalone_hlsl(self, hlsl_code: str, properties: dict) -> str:
    unity_stubs = """
    // Add your custom built-in here
    float4 MyCustomFunction(float4 input) {
        return input * 2.0;
    }
    """
    # ... rest of function
```

### Debug Intermediate Outputs

To inspect intermediate compilation stages:

```python
# In hlsl_runtime.py, modify compile_and_execute():

# Save intermediate HLSL
with open("debug_standalone.hlsl", "w") as f:
    f.write(standalone_hlsl)

# Save SPIR-V
# (automatically saved to tmpdir/shader.spv)

# Save Metal output
# (automatically saved to tmpdir/shader.metal)
```

### Integration with Test Runner

The HLSL runtime is designed to integrate with the existing `test_runner.py` architecture.

**Future Integration:**
- Add `hlsl_runtime` as alternative to `shader_harness` Rust binary
- Detect language spec and route to appropriate runtime
- Support side-by-side WGSL vs HLSL benchmarking

## Support

### Documentation

- Unity HLSL Reference: https://docs.unity3d.com/Manual/SL-Reference.html
- DXC Documentation: https://github.com/microsoft/DirectXShaderCompiler
- spirv-cross: https://github.com/KhronosGroup/SPIRV-Cross
- Metal Shading Language: https://developer.apple.com/metal/Metal-Shading-Language-Specification.pdf

### Common Issues

- Check GitHub issues for shader_benchmark repository
- Review DXC release notes for breaking changes
- Consult Metal programming guide for execution issues

### Contact

For questions or issues specific to this implementation:
1. Check existing GitHub issues
2. Review code comments in `hlsl_runtime.py` and `language_specs.py`
3. Test with reference shaders in `shader_harness/shaders/unity_*.hlsl`
