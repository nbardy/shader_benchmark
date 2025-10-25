# Language Specification - Quick Start Guide

## Overview

The LLM harness now supports multiple shader languages (WGSL, GLSL) through a clean abstraction layer. This enables rapid ablation experiments to compare language impact on LLM success rates.

## Basic Usage

### Default Behavior (WGSL)

No changes needed - existing code works as before:

```bash
# Current production workflow (WGSL by default)
cd llm_harness
python main.py \
  --model "anthropic/claude-3.5-sonnet" \
  --prompt-folder "../problems/base_set/geometric_cube"
```

### Explicit Language Selection

Use `--language-spec` to choose language:

```bash
# WGSL (explicit)
python main.py \
  --model "anthropic/claude-3.5-sonnet" \
  --prompt-folder "../problems/base_set/geometric_cube" \
  --language-spec wgsl

# GLSL (ablation experiment)
python main.py \
  --model "anthropic/claude-3.5-sonnet" \
  --prompt-folder "../problems/base_set/geometric_cube" \
  --language-spec glsl
```

## Ablation Experiment Example

Compare WGSL vs GLSL success rates on a problem:

```bash
# Test 1: WGSL (current production)
python main.py \
  --model "anthropic/claude-3.5-sonnet" \
  --prompt-folder "../problems/base_set/hopf_fibration" \
  --language-spec wgsl

# Test 2: GLSL (ablation)
python main.py \
  --model "anthropic/claude-3.5-sonnet" \
  --prompt-folder "../problems/base_set/hopf_fibration" \
  --language-spec glsl

# Compare results
# - Check compilation success rate
# - Check visual quality scores
# - Analyze failure modes
```

## Programmatic Usage

### Using Language Specs in Python

```python
from language_specs import get_language_spec, WGSLSpec, GLSLSpec
from shader_parser import ShaderParser
from llm_client import LLMClient

# Option 1: Factory function
spec = get_language_spec('wgsl')
parser = ShaderParser(language_spec=spec)
client = LLMClient(language_spec=spec)

# Option 2: Direct instantiation
wgsl_spec = WGSLSpec()
parser = ShaderParser(language_spec=wgsl_spec)
client = LLMClient(language_spec=wgsl_spec)

# Option 3: Backward compatible (defaults to WGSL)
parser = ShaderParser()  # Uses WGSLSpec() internally
client = LLMClient()     # Uses WGSLSpec() internally
```

### Custom Validation

```python
from language_specs import WGSLSpec, GLSLSpec

wgsl = WGSLSpec()
glsl = GLSLSpec()

# Validate WGSL shader
wgsl_code = "@vertex fn vs_main() -> vec4<f32> {}"
is_valid = wgsl.validate_syntax(wgsl_code)  # True

# Validate GLSL shader
glsl_code = "void main() { gl_FragColor = vec4(1.0); }"
is_valid = glsl.validate_syntax(glsl_code)  # True
```

## Language Specifications

### WGSL (Default)

**What it is:** WebGPU Shading Language - modern GPU shader language

**Use when:**
- Production deployments
- WebGPU target platform
- Need strict type checking

**Key features:**
- Explicit types: `vec2<f32>` not `vec2`
- Address spaces: `var<function>`, `var<uniform>`
- Stage attributes: `@vertex`, `@fragment`
- NO variable array indexing
- NO implicit conversions

**Example:**
```wgsl
@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let uv = pos.xy / vec2<f32>(800.0, 600.0);
    return vec4<f32>(uv, 0.5, 1.0);
}
```

### GLSL

**What it is:** OpenGL Shading Language - traditional GPU shader language

**Use when:**
- Ablation experiments
- Comparing language impact on LLM success
- Need permissive syntax (variable array indexing, implicit conversions)

**Key features:**
- Implicit types: `vec2`, `vec3`, `vec4`
- Built-in variables: `gl_FragCoord`, `gl_FragColor`
- Preprocessor: `#version`, `#ifdef`, `#define`
- Variable array indexing WORKS
- Implicit conversions allowed

**Example:**
```glsl
#version 320 es
precision highp float;

out vec4 fragColor;

void main() {
    vec2 uv = gl_FragCoord.xy / 800.0;
    fragColor = vec4(uv, 0.5, 1.0);
}
```

## Testing

### Run Test Suite

```bash
cd llm_harness
python3 test_language_specs.py
```

**Tests verify:**
- Language spec implementations (WGSL, GLSL)
- Syntax validation
- ShaderParser integration
- Backward compatibility
- Reference example loading

### Expected Output

```
============================================================
Language Specification Architecture - Test Suite
============================================================

=== Testing WGSLSpec ===
✓ WGSLSpec properties correct
✓ WGSLSpec validation working

=== Testing GLSLSpec ===
✓ GLSLSpec properties correct
✓ GLSLSpec validation working

...

============================================================
✓ ALL TESTS PASSED
============================================================
```

## Supported Languages

| Language | Status | File Extension | Production Ready |
|----------|--------|----------------|------------------|
| WGSL | ✅ Implemented | `.wgsl` | Yes (default) |
| GLSL | ✅ Implemented | `.glsl` | Parsing only* |

*GLSL shaders parse correctly but may not compile/execute without shader_harness modifications.

## Common Issues

### Issue: "Unknown language: X"

**Solution:** Check supported languages with:
```python
from language_specs import SUPPORTED_LANGUAGES
print(SUPPORTED_LANGUAGES)  # ['wgsl', 'glsl']
```

### Issue: GLSL shaders don't execute

**Status:** Expected. shader_harness currently only supports WGSL compilation.

**Workaround:** Use GLSL for LLM generation experiments, analyze parse/syntax success rates.

**Future:** Phase 2 will add GLSL compilation support to shader_harness.

### Issue: Backward compatibility broken

**Solution:** All components default to WGSLSpec() if no language_spec provided. Check that you're not accidentally passing None.

```python
# ❌ Wrong
parser = ShaderParser(language_spec=None)

# ✅ Correct (backward compatible)
parser = ShaderParser()  # Defaults to WGSLSpec()

# ✅ Correct (explicit)
parser = ShaderParser(language_spec=WGSLSpec())
```

## Files Modified

| File | Changes |
|------|---------|
| `language_specs.py` | NEW - Abstraction layer (500+ lines) |
| `shader_parser.py` | Modified - Accepts language_spec parameter |
| `llm_client.py` | Modified - Accepts language_spec parameter |
| `main.py` | Modified - Added `--language-spec` CLI parameter |
| `test_language_specs.py` | NEW - Test suite (300+ lines) |

## Next Steps

### For Production Use

Current setup is production-ready for WGSL:

```bash
# Production workflow (unchanged)
python main.py --model "claude-3.5-sonnet" --prompt-folder "../problems/base_set/geometric_cube"
```

### For Ablation Experiments

1. **Run WGSL baseline:**
```bash
python main.py --model MODEL --prompt-folder FOLDER --language-spec wgsl
```

2. **Run GLSL comparison:**
```bash
python main.py --model MODEL --prompt-folder FOLDER --language-spec glsl
```

3. **Analyze results:**
- Compare parse success rates
- Compare syntax validation rates
- Analyze error messages
- Identify language-specific failure modes

### For Future Development

See `LANGUAGE_SPEC_ARCHITECTURE.md` for:
- Adding new languages (HLSL, Metal, SPIR-V)
- Implementing GLSL execution support
- Running batch ablation experiments
- Advanced customization

## See Also

- **LANGUAGE_SPEC_ARCHITECTURE.md** - Detailed architecture documentation
- **language_specs.py** - Implementation source code
- **test_language_specs.py** - Test suite
- **CLAUDE.md** - Project-wide setup and conventions
