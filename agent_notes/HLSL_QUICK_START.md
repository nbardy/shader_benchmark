# HLSL Unity Pipeline - Quick Start Guide

## 5-Minute Setup

### 1. Install Dependencies (One-Time)

```bash
cd /Users/nicholasbardy/git/shader_benchmark
./install_hlsl.sh
```

This installs:
- Xcode Command Line Tools (Swift + Metal)
- Homebrew (if not installed)
- DXC (DirectX Shader Compiler)
- spirv-cross (SPIR-V to Metal translator)

### 2. Verify Installation

```bash
cd llm_harness
python3 -c "from hlsl_runtime import check_hlsl_toolchain; print(check_hlsl_toolchain()[1])"
```

**Expected output:** `HLSL toolchain ready`

### 3. Run Your First HLSL Test

```bash
cd llm_harness

# Option A: Using uv (recommended)
uv run python main.py \
    --model "anthropic/claude-3.5-sonnet-20241022" \
    --prompt-folder "../problems/base_set/geometric_cube" \
    --language-spec hlsl_unity

# Option B: Using venv
source venv/bin/activate
python main.py \
    --model "anthropic/claude-3.5-sonnet-20241022" \
    --prompt-folder "../problems/base_set/geometric_cube" \
    --language-spec hlsl_unity
```

That's it! Your shader will compile through DXC → SPIR-V → Metal and render a 1600x1600 PNG.

## What Just Happened?

```
LLM generates Unity HLSL
         ↓
Extract fragment shader (Python)
         ↓
Add Unity built-in stubs (Python)
         ↓
DXC compiles to SPIR-V
         ↓
spirv-cross translates to Metal
         ↓
Swift/Metal harness executes shader
         ↓
PNG output saved (1600x1600)
```

## Example Shaders

View the example Unity HLSL shaders:

```bash
# Simple animated gradient
cat shader_harness/shaders/unity_simple_gradient.hlsl

# Circle pattern with distance fields
cat shader_harness/shaders/unity_circle_pattern.hlsl

# Mandelbrot fractal
cat shader_harness/shaders/unity_mandelbrot.hlsl
```

## Troubleshooting

### "DXC not found"
```bash
brew install directx-shader-compiler
```

### "spirv-cross not found"
```bash
brew install spirv-cross
```

### "swiftc not found"
```bash
xcode-select --install
```

### "HLSL toolchain ready" but tests fail
Check detailed logs in test folder:
```bash
ls -la test_*_results/
cat test_*_results/render_error_log.txt
```

## Next Steps

- **Full Documentation**: Read `HLSL_SETUP.md` for comprehensive guide
- **Implementation Details**: See `HLSL_IMPLEMENTATION_SUMMARY.md`
- **Example Shaders**: Explore `shader_harness/shaders/unity_*.hlsl`

## Command Quick Reference

```bash
# Install toolchain
./install_hlsl.sh

# Verify toolchain
cd llm_harness && python3 -c "from hlsl_runtime import check_hlsl_toolchain; print(check_hlsl_toolchain()[1])"

# Run single test
cd llm_harness && uv run python main.py --model "MODEL" --prompt-folder "FOLDER" --language-spec hlsl_unity

# View example shader
cat shader_harness/shaders/unity_simple_gradient.hlsl
```

## Key Files

- `llm_harness/language_specs.py` - HLSLUnitySpec class
- `llm_harness/hlsl_runtime.py` - DXC → SPIR-V → Metal pipeline
- `shader_harness/shaders/unity_*.hlsl` - Example Unity shaders
- `HLSL_SETUP.md` - Comprehensive setup guide
- `install_hlsl.sh` - Automated installer

## What's Different from WGSL?

| Feature | WGSL | HLSL Unity |
|---------|------|------------|
| Format | `@vertex fn vs_main()` | `CGPROGRAM ... ENDCG` |
| Types | `vec3<f32>` | `float3` |
| Structure | Minimal | `Shader { Properties { SubShader { Pass { ... } } } }` |
| Built-ins | None | `_Time`, `_ScreenParams`, `UnityObjectToClipPos()` |
| LLM Training Data | Limited | Extensive (Unity docs) |
| Execution | WGPU Rust binary | DXC → Metal pipeline |

## Why HLSL Unity?

**Hypothesis:** Unity HLSL is prevalent in LLM training data (Unity documentation, tutorials, forums), potentially yielding higher shader generation success rates than WGSL.

**Test it:**
```bash
# Run same problem with both languages
cd llm_harness

# WGSL (baseline)
uv run python main.py --model "MODEL" --prompt-folder "PROBLEM" --language-spec wgsl

# HLSL Unity (test)
uv run python main.py --model "MODEL" --prompt-folder "PROBLEM" --language-spec hlsl_unity

# Compare success rates and scores
```

## Support

- Issues? Check `HLSL_SETUP.md` troubleshooting section
- Questions? Read `HLSL_IMPLEMENTATION_SUMMARY.md` for architecture details
- Bugs? Review code comments in `hlsl_runtime.py` and `language_specs.py`
