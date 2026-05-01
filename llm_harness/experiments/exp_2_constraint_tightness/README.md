# Experiment 2: Constraint Tightness (Standard → Minimal)

## Overview

This experiment tests whether explicit type constraints reduce LLM errors or just add unnecessary verbosity to prompts.

## Hypothesis

Explicit type constraints (vec2<f32>, address spaces, no implicit conversions) prevent common errors and improve compile rates by 10-20%. Relaxing constraints should increase error rates as LLMs make more type and conversion mistakes.

## Experimental Design

### Control (Baseline)
- Constraints: Standard (explicit <f32>, no implicit conversions)
- Example: `let pos: vec2<f32> = vec2<f32>(0.0, 0.0);`
- Expected compile rate: 60-80%

### Treatment
- Constraints: **Minimal** (allow vec2, implicit conversions)
- Example: `let pos = vec2(0.0, 0.0);`
- Expected compile rate: 40-60% (10-20% drop)

### Variables Held Constant
- Language: WGSL
- Model: claude-3.5-sonnet-20241022
- Judge: claude-3.5-haiku
- Prompt strategy: one-shot
- Test problems: 10 problems with type complexity

## Implementation Requirements

### 1. Minimal Constraints Template

Create `minimal_constraints.txt` (this directory) with relaxed rules:

```
TYPE REQUIREMENTS (RELAXED):
---------------------------------------------
✅ ALLOWED: vec2, vec3, vec4 (type parameter optional)
✅ ALLOWED: float, int (aliases for f32, i32)
✅ ALLOWED: Implicit type conversions
✅ ALLOWED: Type inference for local variables
✅ ALLOWED: Flexible array indexing

SIMPLIFIED RULES:
- Use let for immutables (type inference allowed)
- Use var for mutables (type inference allowed)
- Standard WGSL syntax otherwise
```

### 2. Prompt Template Modifications

The minimal template removes strict type requirements:

**Standard (baseline)**:
```wgsl
❌ Use explicit types: vec2<f32>, NOT vec2
❌ NO implicit type conversions
❌ Array indexing ONLY with integer expressions: array[u32(expr)]
```

**Minimal (variant)**:
```wgsl
✅ vec2, vec3, vec4 allowed (type parameter optional)
✅ Implicit conversions allowed where safe
✅ Flexible array indexing
```

## Expected Results

### Quantitative Metrics

| Metric | Standard Constraints | Minimal Constraints | Δ |
|--------|---------------------|---------------------|---|
| Compile rate | 60-80% | 40-60% | -10-20% |
| Type errors/problem | 0.3 | 0.8 | +167% |
| Success rate | 50-70% | 30-50% | -20% |
| Avg score (compiled) | 300/500 | 280/500 | -20pts |

### Error Categories

Expected increase in these error types:

1. **Type mismatch errors**: `vec2 vs vec2<f32>` confusion
2. **Implicit conversion failures**: `f32(1)` where `1` is `i32`
3. **Array indexing errors**: Wrong type in `array[i]`
4. **Address space errors**: `var x` without `<function>`

Track error frequency to identify which constraints are most valuable.

## Error Analysis Protocol

For each failed compilation:

1. Extract error message from compiler
2. Classify error type (type mismatch, conversion, indexing, etc.)
3. Determine if error would be prevented by standard constraints
4. Calculate "constraint value" = errors prevented / verbosity added

### Constraint Value Scoring

- **High value**: Constraint prevents >50% of errors
- **Medium value**: Constraint prevents 20-50% of errors
- **Low value**: Constraint prevents <20% of errors
- **Negative value**: Constraint adds complexity without preventing errors

## Running the Experiment

### Single Run

```bash
cd llm_harness/experiments
python experiment_runner.py --config exp_2_constraint_tightness/config.yaml
```

### With Error Analysis

```bash
cd llm_harness/experiments
python experiment_runner.py \
  --config exp_2_constraint_tightness/config.yaml \
  --analyze-errors
```

### Results Location

Results will be saved to:
- `experiment_results/exp_2_constraint_tightness_results.json`
- `experiment_results/error_analysis_exp2.md`

## Success Criteria

Experiment is successful if:

1. ✅ **Measurable difference**: Compile rate differs by ≥10%
2. ✅ **Error classification**: >80% of errors categorized correctly
3. ✅ **Constraint value identified**: Know which constraints matter most
4. ✅ **Actionable**: Clear recommendation to keep/modify/remove constraints

## Interpretation Guide

### If Minimal ≈ Standard (compile rate within 5%)
**Interpretation**: Constraints are unnecessary cognitive overhead
**Action**: Simplify WGSL_CONSTRAINT_SPEC.md to minimal version
**Impact**: Clearer prompts, less token usage, same results

### If Minimal < Standard (compile rate 10-20% lower)
**Interpretation**: Constraints provide moderate value
**Action**: Keep current constraints, document their purpose
**Impact**: Validates current approach

### If Minimal << Standard (compile rate >20% lower)
**Interpretation**: Constraints are critical for preventing errors
**Action**: Strengthen constraints, add more examples
**Impact**: Consider even stricter constraints (ultra-strict variant)

## Timeline

- **Implementation**: 2-3 hours (create minimal_constraints.txt)
- **Execution**: 0.6 hours (10 problems)
- **Analysis**: 2-3 hours (error classification and reporting)
- **Total**: 5-6 hours

## Dependencies

- No new dependencies (uses existing WGSL pipeline)
- Reference: minimal_constraints.txt (to be created)

## Future Variants

### Ultra-Strict Constraints

Test even tighter constraints:
- ❌ Dynamic loops (loop bounds must be compile-time constants)
- ❌ Dynamic array indexing
- ❌ Conditionals on uniforms

This creates a spectrum: **Minimal < Standard < Ultra-Strict**

## Related Documents

- [WGSL_CONSTRAINT_SPEC.md](../../../agent_notes/WGSL_CONSTRAINT_SPEC.md) - Current standard constraints
- [ABLATION_EXPERIMENTS.md](../../../agent_notes/ABLATION_EXPERIMENTS.md) - Overall experiment plan

## Notes

This experiment directly validates the verbosity tradeoff in WGSL_CONSTRAINT_SPEC.md. If minimal constraints work just as well, we can significantly simplify prompts and reduce token usage.

The error classification data will be valuable for future constraint optimization regardless of the outcome.
