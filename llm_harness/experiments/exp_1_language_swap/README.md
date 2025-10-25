# Experiment 1: Language Swap (WGSL → GLSL)

## Overview

This experiment tests the core hypothesis that motivated the WGSL migration: **constraint-based prompting can overcome training data scarcity**.

## Hypothesis

WGSL (3 years of training data) with explicit constraints will perform comparably to GLSL (20+ years of training data) with looser constraints. If GLSL substantially outperforms WGSL, it suggests training data volume matters more than constraint clarity.

## Experimental Design

### Control (Baseline)
- Language: WGSL
- Constraints: Standard (explicit types, strict ABI)
- Prompt: One-shot with main.rs example
- Expected success rate: 50-70%

### Treatment
- Language: **GLSL** (Shadertoy format)
- Constraints: Standard GLSL rules
- Prompt: One-shot with Shadertoy example
- Expected success rate: 40-60% (lower due to syntax differences)

### Variables Held Constant
- Model: claude-3.5-sonnet-20241022
- Judge: claude-3.5-haiku
- Resolution: 1600x1600
- Test problems: 10 representative problems
- Validation: LLM judge with 5-score system

## Implementation Requirements

### 1. Shader Harness Modifications

**File**: `shader_harness/Cargo.toml`
```toml
[dependencies]
shaderc = "0.8"  # GLSL → SPIR-V compiler
```

**File**: `shader_harness/src/main.rs`
```rust
use shaderc::{Compiler, ShaderKind};

// Detect file extension and compile appropriately
let source = if opts.shader.extension().map_or(false, |ext| ext == "glsl") {
    let mut compiler = Compiler::new()?;
    let spirv = compiler.compile_into_spirv(
        &shader_code,
        ShaderKind::Fragment,
        "shader.glsl",
        "main",
        None
    )?;
    wgpu::ShaderSource::SpirV(Cow::Owned(spirv.as_binary().to_vec()))
} else {
    wgpu::ShaderSource::Wgsl(Cow::Owned(shader_code))
};
```

### 2. GLSL Prompt Template

Create `glsl_constraints.txt` (this directory) with Shadertoy format specification:

```glsl
void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    // Available uniforms:
    // uniform vec2 iResolution;  // viewport resolution
    // uniform float iTime;       // shader playback time

    vec2 uv = fragCoord / iResolution.xy;
    fragColor = vec4(uv, 0.5, 1.0);
}
```

### 3. Shader Parser Updates

**File**: `llm_harness/shader_parser.py`
```python
def _wrap_glsl_fragment(self, fragment_code: str) -> str:
    """Wrap Shadertoy fragment in full GLSL shader"""
    return f"""
#version 450

layout(location = 0) in vec2 fragCoord;
layout(location = 0) out vec4 fragColor;

uniform vec2 iResolution;
uniform float iTime;

{fragment_code}

void main() {{
    mainImage(fragColor, fragCoord * iResolution);
}}
"""
```

## Expected Results

### Quantitative Metrics

| Metric | WGSL Baseline | GLSL Variant | Interpretation |
|--------|---------------|--------------|----------------|
| Compile rate | 60-80% | 30-50% | GLSL syntax differences |
| Success rate (compiled) | 50-70% | 40-60% | Training data vs constraints |
| Avg S1 (Math) | 70-80 | 65-75 | Mathematical accuracy similar |
| Avg S2 (Visual) | 65-75 | 60-70 | Visual quality similar |
| Avg Total | 300-350/500 | 250-300/500 | Overall comparison |

### Qualitative Observations

**If GLSL >> WGSL** (success rate +20%):
- Training data volume is dominant factor
- WGSL migration may have been premature
- Consider hybrid approach or GLSL baseline

**If GLSL ≈ WGSL** (success rate ±5%):
- Constraints compensate for training data gap
- WGSL migration is validated
- Explicit type system provides value

**If GLSL << WGSL** (success rate -20%):
- Constraints are extremely valuable
- WGSL strict typing prevents common errors
- Migration was correct decision

## Error Analysis

Expected error categories for GLSL:

1. **Syntax errors**: Missing semicolons, type mismatches
2. **Uniform errors**: Incorrect iResolution/iTime usage
3. **Type conversion errors**: Implicit conversions that fail
4. **Wrapper errors**: mainImage() signature mistakes

Track error frequency to identify if GLSL's implicit conversions cause more runtime errors despite easier syntax.

## Running the Experiment

### Single Run

```bash
cd llm_harness/experiments
python experiment_runner.py --config exp_1_language_swap/config.yaml
```

### With Baseline Comparison

```bash
cd llm_harness/experiments
python experiment_runner.py \
  --experiment-dir . \
  --model "anthropic/claude-3.5-sonnet-20241022" \
  --max-parallel 2
```

### Results Location

Results will be saved to:
- `experiment_results/exp_1_language_swap_results.json`
- `experiment_results/comparative_report_TIMESTAMP.md`

## Success Criteria

Experiment is successful if:

1. ✅ **Technical**: GLSL compilation path works correctly
2. ✅ **Reproducible**: Can run multiple times with similar results (±5%)
3. ✅ **Measurable**: Clear difference in at least one metric
4. ✅ **Interpretable**: Results support or refute hypothesis clearly

## Timeline

- **Implementation**: 4-6 hours (shader harness + prompt template)
- **Execution**: 0.8 hours (10 problems)
- **Analysis**: 1-2 hours (comparative report)
- **Total**: 1 workday

## Dependencies

- Rust: shaderc crate for GLSL compilation
- Python: No additional dependencies
- Reference: GLSL constraint specification (glsl_constraints.txt)

## Related Documents

- [ABLATION_EXPERIMENTS.md](../../../ABLATION_EXPERIMENTS.md) - Overall experiment plan
- [WGSL_CONSTRAINT_SPEC.md](../../WGSL_CONSTRAINT_SPEC.md) - WGSL baseline spec
- [glsl_constraints.txt](glsl_constraints.txt) - GLSL variant spec

## Notes

This is the **highest priority** ablation experiment as it validates the fundamental assumption of the WGSL migration. All other experiments assume WGSL is the correct baseline choice.

If GLSL significantly outperforms WGSL, it may be necessary to reconsider the entire approach and potentially revert to GLSL with improved constraints rather than WGSL with current constraints.
