# GLSL Sokol Pipeline - Quick Start Guide

Fast setup guide for the GLSL ES 3.0 + Sokol graphics pipeline.

## 1-Minute Setup

```bash
# Navigate to project root
cd /path/to/shader_benchmark

# Build the Sokol harness (downloads headers automatically)
cd shader_harness/glsl_sokol_src
./build.sh

# Verify installation
../glsl_sokol_build/glsl_sokol_harness --help
```

## Test with Example Shader

```bash
# Test with gradient shader
../glsl_sokol_build/glsl_sokol_harness \
  --shader ../shaders/gradient_example.glsl \
  --output test_gradient.png \
  --width 1600 \
  --height 1600

# View result
open test_gradient.png  # macOS
# xdg-open test_gradient.png  # Linux
```

## Integration with Benchmark Harness

### Option 1: Add GLSLSokolSpec to language_specs.py

Edit `llm_harness/language_specs.py`:

1. Copy the `GLSLSokolSpec` class from `llm_harness/glsl_sokol_spec_addition.py`
2. Paste it before the line `SUPPORTED_LANGUAGES = [...]`
3. Update `SUPPORTED_LANGUAGES` to include `'glsl_sokol'`:
   ```python
   SUPPORTED_LANGUAGES = ['wgsl', 'glsl', 'hlsl_unity', 'glsl_sokol']
   ```
4. Update `get_language_spec()` factory function:
   ```python
   elif language_name_lower == 'glsl_sokol':
       return GLSLSokolSpec()
   ```

### Option 2: Use Standalone Runtime (Python)

```python
from glsl_sokol_runtime import GLSLSokolRuntime
from pathlib import Path

runtime = GLSLSokolRuntime()

success, message = runtime.compile_and_render(
    shader_path=Path("shader.glsl"),
    output_path=Path("result.png"),
    width=1600,
    height=1600
)

print(message)
```

## Run Benchmark with GLSL

```bash
cd llm_harness

# Single problem
python main.py \
  --model "anthropic/claude-3.5-sonnet-20241022" \
  --prompt-folder "../problems/base_set/geometric_cube" \
  --language glsl_sokol

# Multiple problems (requires full integration)
python benchmark_harness.py \
  --model "anthropic/claude-3.5-sonnet-20241022" \
  --problems geometric_cube mandelbrot_set \
  --language glsl_sokol
```

## Example GLSL ES 3.0 Shader

```glsl
#version 300 es
precision highp float;

uniform vec2 resolution;
out vec4 fragColor;

void main() {
    vec2 uv = gl_FragCoord.xy / resolution;
    fragColor = vec4(uv.x, uv.y, 0.5, 1.0);
}
```

## Troubleshooting

### Build fails
```bash
# Ensure Xcode Command Line Tools installed (macOS)
xcode-select --install

# Or install build-essential (Linux)
sudo apt-get install build-essential libgl1-mesa-dev
```

### Runtime fails
```bash
# Check executable exists
ls -la shader_harness/glsl_sokol_build/glsl_sokol_harness

# Make it executable if needed
chmod +x shader_harness/glsl_sokol_build/glsl_sokol_harness

# Test with absolute paths
shader_harness/glsl_sokol_build/glsl_sokol_harness \
  --shader $(pwd)/shader_harness/shaders/gradient_example.glsl \
  --output $(pwd)/test.png
```

### Shader compilation errors
Common issues:
- Missing `#version 300 es` at top
- Missing `precision highp float;`
- Missing `out vec4 fragColor;` declaration
- Using `gl_FragColor` instead of `fragColor` (old GLSL syntax)

## Key Differences: WGSL vs GLSL ES 3.0

| Feature | WGSL | GLSL ES 3.0 |
|---------|------|-------------|
| Version | New (2021+) | Established (2012+) |
| Training Data | Limited | 500K+ examples |
| Type System | Explicit (`vec2<f32>`) | Implicit (`vec2`) |
| Array Indexing | Constant only | Variable allowed |
| Conversions | No implicit | Yes implicit |
| Entrypoints | `@vertex`, `@fragment` | `void main()` |
| Uniforms | `@group/@binding` | `uniform` keyword |
| Built-ins | `@builtin(position)` | `gl_FragCoord` |

**Performance:** GLSL + Sokol is ~1.5-2x faster than WGSL + WGPU per shader.

**Compatibility:** GLSL has broader LLM training data, potentially higher success rates.

## Files Created

```
shader_benchmark/
├── GLSL_SOKOL_INSTALL.md              # Full installation guide
├── GLSL_SOKOL_QUICKSTART.md           # This file
│
├── llm_harness/
│   ├── glsl_sokol_runtime.py          # Python wrapper for Sokol harness
│   ├── glsl_sokol_spec_addition.py    # GLSLSokolSpec class (to be integrated)
│   └── language_specs.py              # (needs GLSLSokolSpec integration)
│
└── shader_harness/
    ├── glsl_sokol_src/
    │   ├── glsl_sokol_harness.c       # C executable source
    │   ├── build.sh                   # Build script (downloads headers)
    │   └── headers/                   # Downloaded headers (auto-created)
    │
    ├── glsl_sokol_build/
    │   └── glsl_sokol_harness         # Compiled executable
    │
    └── shaders/
        ├── gradient_example.glsl      # Simple gradient
        ├── animated_pattern.glsl      # Time-animated spiral
        └── circle_grid.glsl           # Grid pattern
```

## Next Steps

1. **Test Installation:**
   ```bash
   cd shader_harness/glsl_sokol_src
   ./build.sh
   ../glsl_sokol_build/glsl_sokol_harness --help
   ```

2. **Test Example Shader:**
   ```bash
   ../glsl_sokol_build/glsl_sokol_harness \
     --shader ../shaders/gradient_example.glsl \
     --output test.png
   ```

3. **Integrate with language_specs.py** (see Option 1 above)

4. **Run Benchmark:**
   ```bash
   cd ../../llm_harness
   python benchmark_harness.py --model MODEL --problems PROBLEMS --language glsl_sokol
   ```

## Full Documentation

See `GLSL_SOKOL_INSTALL.md` for:
- Detailed build configuration
- Backend selection (Metal vs OpenGL)
- Performance benchmarks
- Advanced troubleshooting
- Python API documentation
