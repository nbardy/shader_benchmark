# Experiment 5: Prompt Engineering (One-Shot → Few-Shot)

## Overview

This experiment tests whether providing multiple diverse examples improves LLM output quality more than constraint specification alone, and whether the improvement justifies the increased token usage.

## Hypothesis

Few-shot examples (3 diverse shaders) will improve success rate by 10-20% by providing pattern templates for the LLM to learn from. However, this comes at the cost of 2-3x token usage and potential overfitting to example patterns.

**Expected tradeoffs**:
- Success rate: +10-15%
- Code quality: Better (fewer antipatterns)
- Token usage: +200-300%
- Creativity: Lower (template copying)

## Experimental Design

### Control (Baseline)
- Prompt: One-shot (single main.rs example)
- Token usage: ~2,000 tokens/request
- Expected success rate: 50-70%
- Pattern diversity: High (LLM generates creative solutions)

### Treatment
- Prompt: **Few-shot** (3 diverse shader examples)
- Token usage: ~6,000 tokens/request (+300%)
- Expected success rate: 60-80% (+10-15%)
- Pattern diversity: Lower (may copy example patterns)

### Variables Held Constant
- Language: WGSL
- Constraints: Standard
- Model: claude-3.5-sonnet-20241022
- Judge: claude-3.5-haiku
- Test problems: 10 diverse problems

## Implementation Requirements

### 1. Example Selection

Choose 3 diverse examples that demonstrate different shader techniques:

#### Example 1: Simple Geometry (geometric_cube.wgsl)
**Demonstrates**: Basic vertex/fragment pipeline, simple transformations

```wgsl
@vertex
fn vs_main(@builtin(vertex_index) vertex_index: u32) -> @builtin(position) vec4<f32> {
    // Full-screen triangle generation
    let vertex_id = vertex_index % 3u;
    let x = f32(i32(vertex_id & 1u) << 2u) - 1.0;
    let y = f32(i32((vertex_id >> 1u) & 1u) << 2u) - 1.0;
    return vec4<f32>(x, y, 0.0, 1.0);
}

@group(0) @binding(0) var<uniform> Params: Params;
struct Params {
    resolution: vec2<f32>,
}

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let uv = pos.xy / Params.resolution;
    let centered = (uv - vec2<f32>(0.5, 0.5)) * 2.0;

    // Simple cube visualization
    let edge = max(abs(centered.x), abs(centered.y));
    let color = vec3<f32>(edge, 0.5, 1.0 - edge);

    return vec4<f32>(color, 1.0);
}
```

#### Example 2: Mathematical Iteration (mandelbrot_set.wgsl)
**Demonstrates**: Complex iteration, parameter usage, mathematical computation

```wgsl
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
}

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let uv = pos.xy / Params.resolution;
    let c = (uv - vec2<f32>(0.5, 0.5)) * vec2<f32>(3.5, 2.0);

    var z = vec2<f32>(0.0, 0.0);
    var i = 0u;

    for (; i < 100u; i = i + 1u) {
        if (dot(z, z) > 4.0) {
            break;
        }
        z = vec2<f32>(z.x * z.x - z.y * z.y, 2.0 * z.x * z.y) + c;
    }

    let color = f32(i) / 100.0;
    return vec4<f32>(vec3<f32>(color), 1.0);
}
```

#### Example 3: Raymarching (sphere_wireframe.wgsl)
**Demonstrates**: Signed distance functions, raymarching, 3D rendering

```wgsl
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
}

fn sdf_sphere(p: vec3<f32>, radius: f32) -> f32 {
    return length(p) - radius;
}

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let uv = (pos.xy / Params.resolution - vec2<f32>(0.5, 0.5)) * 2.0;
    let aspect = Params.resolution.x / Params.resolution.y;

    let ro = vec3<f32>(0.0, 0.0, -3.0);
    let rd = normalize(vec3<f32>(uv.x * aspect, uv.y, 1.0));

    var t = 0.0;
    for (var i = 0u; i < 64u; i = i + 1u) {
        let p = ro + rd * t;
        let d = sdf_sphere(p, 1.0);
        if (d < 0.01) {
            return vec4<f32>(vec3<f32>(1.0), 1.0);
        }
        t = t + d;
        if (t > 10.0) {
            break;
        }
    }

    return vec4<f32>(vec3<f32>(0.0), 1.0);
}
```

### 2. Few-Shot Template Creation

Create `few_shot_prompt_template.txt`:

```
🔒 WGSL FORMAT LOCK - STRICT ABI CONTRACT
============================================

REFERENCE EXAMPLES (Study these patterns):
---------------------------------------------

Example 1: Simple Geometry (Cube)
[Full geometric_cube.wgsl code]

Example 2: Mathematical Iteration (Mandelbrot Set)
[Full mandelbrot_set.wgsl code]

Example 3: Raymarching (Sphere SDF)
[Full sphere_wireframe.wgsl code]

[Rest of constraint specification]
```

### 3. Token Usage Tracking

Modify `llm_client.py` to track token usage:

```python
class LLMClient:
    def __init__(self):
        self.token_usage = {
            'prompt_tokens': 0,
            'completion_tokens': 0,
            'total_tokens': 0
        }

    async def generate_shader(self, problem_prompt: str):
        response = await self._call_api(prompt)

        # Track usage (OpenRouter provides this)
        self.token_usage['prompt_tokens'] += response.get('usage', {}).get('prompt_tokens', 0)
        self.token_usage['completion_tokens'] += response.get('usage', {}).get('completion_tokens', 0)
        self.token_usage['total_tokens'] += response.get('usage', {}).get('total_tokens', 0)
```

## Expected Results

### Quantitative Metrics

| Metric | One-Shot (Baseline) | Few-Shot | Δ | Cost Impact |
|--------|---------------------|----------|---|-------------|
| Success rate | 50-70% | 60-80% | +10-15% | Worth it? |
| Avg total score | 300/500 | 340/500 | +40pts | +13% |
| Compile rate | 65% | 75% | +10% | Fewer errors |
| Prompt tokens | 2,000 | 6,000 | +300% | 3x cost |
| Completion tokens | 800 | 900 | +12% | Template copying |
| Total cost/problem | $0.02 | $0.06 | +300% | Expensive |

### Quality Metrics

| Metric | One-Shot | Few-Shot | Interpretation |
|--------|----------|----------|----------------|
| Pattern diversity | High | Low | Copying examples |
| Code originality | 90% | 60% | Less creative |
| Error variety | High | Low | Fewer novel errors |
| Antipattern frequency | 0.3/problem | 0.1/problem | Better quality |

## Cost-Benefit Analysis

### ROI Calculation

```
Improvement = (Success_few_shot - Success_one_shot) / Success_one_shot
Cost_increase = (Cost_few_shot - Cost_one_shot) / Cost_one_shot

ROI = Improvement / Cost_increase

Expected:
Improvement = (65% - 60%) / 60% = 8.3%
Cost_increase = ($0.06 - $0.02) / $0.02 = 300%
ROI = 8.3% / 300% = 0.028 (poor ROI)
```

**Interpretation**:
- If ROI > 0.5: Few-shot is worth the cost
- If ROI < 0.5: One-shot is more cost-effective
- Expected ROI ~0.03: **Not worth the cost** for routine benchmarking

### Use Case Recommendations

| Scenario | Strategy | Rationale |
|----------|----------|-----------|
| Development/iteration | One-shot | Cost-effective, fast |
| High-stakes problems | Few-shot | Higher success critical |
| Benchmark suite | One-shot | Cost at scale matters |
| Novel problem types | Few-shot | Need diverse patterns |

## Running the Experiment

### Single Run

```bash
cd llm_harness/experiments
python experiment_runner.py --config exp_5_prompt_engineering/config.yaml
```

### Compare with Baseline

```bash
# Baseline (one-shot)
python experiment_runner.py --config baseline/config.yaml

# Few-shot
python experiment_runner.py --config exp_5_prompt_engineering/config.yaml

# Analyze
python analyze_prompt_engineering.py \
  --baseline experiment_results/baseline_results.json \
  --fewshot experiment_results/exp_5_prompt_engineering_results.json \
  --track-tokens
```

### Results Location

Results will be saved to:
- `experiment_results/exp_5_prompt_engineering_results.json`
- `experiment_results/prompt_engineering_analysis.md`
- `experiment_results/token_usage_comparison.csv`

## Success Criteria

Experiment is successful if:

1. ✅ **Success rate improvement**: Few-shot improves by ≥10%
2. ✅ **Quality improvement**: Fewer antipatterns, better code
3. ✅ **Cost quantified**: Token usage tracked accurately
4. ✅ **ROI calculated**: Clear recommendation on cost-effectiveness

## Interpretation Guide

### If Improvement < 5%
**Interpretation**: Examples don't help beyond constraints
**Action**: Stick with one-shot prompting
**Impact**: Save 300% token cost with minimal quality loss

### If Improvement 5-15%
**Interpretation**: Moderate benefit, poor ROI
**Action**: Use few-shot selectively (hard problems only)
**Impact**: Hybrid strategy based on problem difficulty

### If Improvement > 15%
**Interpretation**: Examples are critical for success
**Action**: Adopt few-shot as default
**Impact**: Accept 3x cost for substantial quality gain

## Timeline

- **Example curation**: 2-3 hours (select and verify examples)
- **Template creation**: 1 hour (create few_shot_prompt_template.txt)
- **Token tracking**: 1 hour (modify llm_client.py)
- **Execution**: 0.7 hours (10 problems)
- **Analysis**: 2 hours (ROI, quality metrics)
- **Total**: 6-8 hours

## Dependencies

- No new dependencies (uses existing pipeline)
- Reference: few_shot_prompt_template.txt (to be created)

## Future Variants

### Zero-Shot Testing

Also test with NO examples (constraints only):

```
Zero-shot < One-shot < Few-shot
(constraints only) (1 example) (3 examples)
```

This provides the full spectrum of prompting strategies.

### Dynamic Example Selection

Experiment with adaptive few-shot:
- Select examples based on problem category
- Retrieve similar examples from successful runs
- Use retrieval-augmented generation (RAG)

## Related Documents

- [prompt_template.txt](../../prompt_template.txt) - Current one-shot template
- [ABLATION_EXPERIMENTS.md](../../../agent_notes/ABLATION_EXPERIMENTS.md) - Overall experiment plan

## Notes

This experiment tests the **diminishing returns of example-based prompting**. While examples clearly help, the question is whether the benefit justifies the 3x cost increase.

Expected outcome: **One-shot is optimal** for cost-effectiveness, few-shot reserved for high-stakes scenarios.

The pattern copying behavior (lower diversity) is also interesting - it suggests that LLMs may be overfitting to examples rather than learning general principles from them. This validates the constraint-based approach over example-based prompting.
