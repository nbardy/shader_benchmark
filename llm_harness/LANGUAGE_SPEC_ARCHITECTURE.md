# Language Specification Architecture

## Overview

The LLM generation pipeline has been refactored to enable swappable language specifications (WGSL vs GLSL). This enables rapid ablation experiments to measure the impact of shader language choice on LLM success rates.

## Architecture Goals

1. **Clean Separation of Concerns**: Separate language-specific rules from core generation logic
2. **Swappable Specifications**: Easy switching between WGSL, GLSL, and future languages
3. **Backward Compatibility**: Existing code continues to work with default WGSL spec
4. **Rapid Ablation**: Compare WGSL vs GLSL success rates with minimal code changes

## Core Components

### 1. `language_specs.py` - Language Abstraction Layer

Defines the `ShaderLanguageSpec` abstract base class and concrete implementations:

```python
from language_specs import get_language_spec

# Get WGSL specification (production default)
wgsl_spec = get_language_spec('wgsl')

# Get GLSL specification (for ablations)
glsl_spec = get_language_spec('glsl')
```

**ShaderLanguageSpec Interface:**

| Property/Method | Purpose |
|----------------|---------|
| `name` | Language name ("WGSL", "GLSL") |
| `description` | Human-readable description |
| `file_extension` | File extension (".wgsl", ".glsl") |
| `constraint_prompt` | Language-specific LLM constraints |
| `fallback_filename` | Default shader filename |
| `validate_syntax(content)` | Validate shader syntax |
| `get_reference_examples(path)` | Load language-specific examples |

### 2. Modified `shader_parser.py` - Spec-Based Parsing

**Before:**
```python
parser = ShaderParser()
shaders, main_rs = parser.parse_response(llm_response)
```

**After:**
```python
from language_specs import WGSLSpec

parser = ShaderParser(language_spec=WGSLSpec())
shaders, main_rs = parser.parse_response(llm_response)
```

**Changes:**
- `__init__(language_spec)` - Accepts language specification
- `parse_response()` - Uses `language_spec.file_extension` for fallback filenames
- `validate_shader_syntax()` - Delegates to `language_spec.validate_syntax()`

### 3. Modified `llm_client.py` - Spec-Based Prompts

**Before:**
```python
client = LLMClient()
response = await client.generate_shaders(model, prompt)
```

**After:**
```python
from language_specs import GLSLSpec

client = LLMClient(language_spec=GLSLSpec())
response = await client.generate_shaders(model, prompt)
```

**Changes:**
- `__init__(language_spec)` - Accepts language specification
- `_get_shader_harness_example()` - Uses `language_spec.get_reference_examples()`
- `_format_prompt_template()` - Uses `language_spec.constraint_prompt` as fallback

### 4. Modified `main.py` - CLI Integration

**New Command-Line Parameter:**
```bash
# WGSL (default, production)
python main.py --model "claude-3.5-sonnet" --prompt-folder "../problems/base_set/geometric_cube"

# GLSL (ablation experiment)
python main.py --model "claude-3.5-sonnet" --prompt-folder "../problems/base_set/geometric_cube" --language-spec glsl
```

## Ablation Experiment Workflow

### Example: WGSL vs GLSL Success Rate Comparison

```bash
# 1. Test with WGSL (current production)
cd llm_harness
python main.py \
  --model "anthropic/claude-3.5-sonnet" \
  --prompt-folder "../problems/base_set/geometric_cube" \
  --language-spec wgsl

# 2. Test with GLSL (ablation)
python main.py \
  --model "anthropic/claude-3.5-sonnet" \
  --prompt-folder "../problems/base_set/geometric_cube" \
  --language-spec glsl

# 3. Compare results
python generate_report.py --compare-languages wgsl glsl
```

## Language Specifications

### WGSL (WebGPU Shading Language)

**Current Production Language**

**Key Characteristics:**
- Explicit types: `vec2<f32>`, not `vec2`
- Address spaces required: `var<function>`, `var<uniform>`
- Stage attributes: `@vertex`, `@fragment`, `@compute`
- Strict type checking (no implicit conversions)
- NO variable array indexing (must use compile-time constants)

**ABI Contract:**
```wgsl
@vertex
fn vs_main(@builtin(vertex_index) vertex_index: u32) -> @builtin(position) vec4<f32>

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32>

@group(0) @binding(0) var<uniform> Params: Params;
```

**Constraint Prompt Location:**
- Defined in: `language_specs.py:WGSLSpec.constraint_prompt`
- Fallback: `prompt_template.txt` (for backward compatibility)

**Reference Examples:**
- `shader_harness/src/main.rs` - ABI contract reference
- `shader_harness/Cargo.toml` - Project dependencies
- `shader_harness/shaders/*.wgsl` - Working examples

### GLSL (OpenGL Shading Language)

**Future Ablation Target**

**Key Characteristics:**
- Implicit types: `vec2`, `vec3`, `vec4`
- Built-in variables: `gl_FragCoord`, `gl_Position`
- Preprocessor support: `#version`, `#ifdef`, `#define`
- Variable array indexing WORKS (unlike WGSL)
- Implicit type conversions allowed

**Entrypoints:**
```glsl
#version 320 es
precision highp float;

void main() {
    // Standard GLSL
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    // Shadertoy-style
}
```

**Constraint Prompt Location:**
- Defined in: `language_specs.py:GLSLSpec.constraint_prompt`

**Reference Examples:**
- `shader_harness/shaders/*.glsl` - Working examples

**NOTE:** shader_harness currently expects WGSL. GLSL support requires harness modifications for compilation/execution.

## Adding New Language Specifications

### Example: Adding HLSL (DirectX)

```python
# In language_specs.py

class HLSLSpec(ShaderLanguageSpec):
    @property
    def name(self) -> str:
        return "HLSL"

    @property
    def description(self) -> str:
        return "High-Level Shading Language - DirectX shader language"

    @property
    def file_extension(self) -> str:
        return ".hlsl"

    @property
    def fallback_filename(self) -> str:
        return "shader.hlsl"

    @property
    def constraint_prompt(self) -> str:
        return """<Your HLSL constraint prompt here>"""

    def validate_syntax(self, shader_content: str) -> bool:
        # Check for HLSL-specific patterns
        if 'float4 main' in shader_content:
            return True
        return False

    def get_reference_examples(self, shader_harness_path: str) -> List[str]:
        # Load HLSL examples from shader_harness
        from pathlib import Path
        examples = []
        shaders_path = Path(shader_harness_path) / "shaders"
        for shader_file in shaders_path.glob("*.hlsl"):
            with open(shader_file) as f:
                examples.append(f"HLSL_EXAMPLE ({shader_file.name}):\n```hlsl\n{f.read()}\n```")
        return examples

# Update factory function
def get_language_spec(language_name: str) -> ShaderLanguageSpec:
    language_name_lower = language_name.lower()
    if language_name_lower == 'wgsl':
        return WGSLSpec()
    elif language_name_lower == 'glsl':
        return GLSLSpec()
    elif language_name_lower == 'hlsl':
        return HLSLSpec()
    else:
        raise ValueError(f"Unknown language: {language_name}")

# Update registry
SUPPORTED_LANGUAGES = ['wgsl', 'glsl', 'hlsl']
```

## Testing

### Unit Testing Language Specs

```python
# test_language_specs.py
from language_specs import WGSLSpec, GLSLSpec

def test_wgsl_validation():
    spec = WGSLSpec()

    # Valid WGSL
    assert spec.validate_syntax("@vertex fn vs_main() -> vec4<f32> { }")
    assert spec.validate_syntax("fn helper() -> f32 { return 1.0; }")

    # Invalid WGSL
    assert not spec.validate_syntax("void main() { }")

def test_glsl_validation():
    spec = GLSLSpec()

    # Valid GLSL
    assert spec.validate_syntax("void main() { }")
    assert spec.validate_syntax("void mainImage(out vec4 fragColor, in vec2 fragCoord) { }")

    # Invalid GLSL
    assert not spec.validate_syntax("@vertex fn vs_main() { }")
```

### End-to-End Testing

```bash
# Test WGSL pipeline (backward compatibility)
cd llm_harness
python main.py \
  --model "anthropic/claude-3.5-sonnet" \
  --prompt-folder "../problems/base_set/geometric_cube" \
  --language-spec wgsl \
  --no-judge

# Verify:
# - Shaders generated with .wgsl extension
# - WGSL constraint prompt used
# - WGSL reference examples loaded
# - Shader compiles and renders
```

## Backward Compatibility

The refactor maintains full backward compatibility:

1. **Default Behavior**: All components default to `WGSLSpec()` if no language_spec provided
2. **prompt_template.txt**: Still loaded if present (takes precedence over language_spec)
3. **Existing Tests**: Continue to work without modification
4. **CLI**: `--language-spec` parameter is optional (defaults to 'wgsl')

## Known Limitations

1. **GLSL Execution**: shader_harness currently expects WGSL format. GLSL shaders will parse but may not compile/execute without harness modifications.

2. **Mixed Language Projects**: Pipeline assumes single language per test run. Multi-language projects not currently supported.

3. **Prompt Template Override**: If `prompt_template.txt` exists, it takes precedence over `language_spec.constraint_prompt`. Delete/rename template to use language_spec prompts.

## Future Work

### Phase 1: GLSL Harness Support (COMPLETED - Refactoring)
- ✅ Create language_specs.py abstraction
- ✅ Modify shader_parser.py for language_spec
- ✅ Modify llm_client.py for language_spec
- ✅ Add --language-spec CLI parameter
- ✅ Test WGSL backward compatibility

### Phase 2: GLSL Execution (Future)
- [ ] Add GLSL compilation to shader_harness (Rust GLSL compiler)
- [ ] Update test_runner.py to detect language from file extension
- [ ] Add GLSL-specific reference examples
- [ ] Test GLSL end-to-end pipeline

### Phase 3: Ablation Experiments (Future)
- [ ] Run batch tests with WGSL vs GLSL on 100 problems
- [ ] Compare success rates (compilation, rendering, judging)
- [ ] Analyze failure modes (syntax errors, semantic errors, visual quality)
- [ ] Document findings in research/ablation_results.md

### Phase 4: Additional Languages (Future)
- [ ] Metal Shading Language (MSL) for Apple devices
- [ ] HLSL (DirectX) for Windows
- [ ] SPIR-V assembly (for low-level experiments)

## Questions & Answers

**Q: Why not just use GLSL everywhere if it's more permissive?**

A: WGSL is the target language for WebGPU, which is the modern standard. The goal is to measure whether GLSL's more permissive syntax improves LLM success rates, then potentially adapt WGSL prompts based on insights.

**Q: Can I use both WGSL and GLSL in the same test run?**

A: No, currently the pipeline assumes a single language per test run. Use `--language-spec` to choose one.

**Q: Will GLSL shaders actually execute?**

A: Not yet. The current shader_harness only supports WGSL compilation. GLSL parsing works, but execution requires harness modifications (Phase 2).

**Q: How do I add a new language?**

A: See "Adding New Language Specifications" section above. Create a new `*Spec` class, implement the abstract methods, and register in `get_language_spec()`.

**Q: Does this break existing code?**

A: No. All components default to `WGSLSpec()` for full backward compatibility. Existing tests, scripts, and workflows continue to work unchanged.

## See Also

- **language_specs.py** - Language specification implementations
- **shader_parser.py** - Spec-based parsing logic
- **llm_client.py** - Spec-based prompt generation
- **main.py** - CLI integration with --language-spec parameter
- **CLAUDE.md** - Project-wide instructions and setup
