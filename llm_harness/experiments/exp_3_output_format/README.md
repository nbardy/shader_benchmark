# Experiment 3: Output Format (1600x → 512x Resolution)

## Overview

This experiment tests whether resolution affects visual quality scores independently of mathematical correctness, providing data for performance/quality tradeoffs.

## Hypothesis

Resolution affects visual quality scores (S2, S4) but not mathematical accuracy scores (S1, S3, S5). Lower resolution reduces render time quadratically while maintaining code correctness.

**Expected impact**:
- S1/S3/S5: No change (±3 points)
- S2/S4: 10-15 points lower
- Render time: 16x faster (1600² → 512²)

## Experimental Design

### Control (Baseline)
- Resolution: 1600x1600
- Render time: ~2 seconds/problem
- Expected S2 score: 70-75/100

### Treatment
- Resolution: **512x512**
- Render time: ~0.125 seconds/problem (16x faster)
- Expected S2 score: 55-65/100 (10-15 points lower)

### Variables Held Constant
- Language: WGSL
- Constraints: Standard
- Model: claude-3.5-sonnet-20241022
- Judge: claude-3.5-haiku
- Test problems: 10 visually complex problems

## Implementation Requirements

### 1. Shader Harness Configuration

Already supported via `--size` flag:

```bash
cargo run -- --shader shader.wgsl --output result.png --size 512
```

### 2. Benchmark Harness Integration

Modify `test_runner.py` to pass resolution:

```python
def run_test(self, shader_path: Path, resolution: int = 1600):
    cmd = f"source ~/.cargo/env && cargo run -- --shader {shader_path} --output result.png --size {resolution}"
    # ...
```

### 3. Judge Context

Optionally provide resolution context to judge for fair evaluation:

```python
# In judge prompt
f"Note: Image rendered at {resolution}x{resolution} resolution"
```

## Expected Results

### Quantitative Metrics

| Metric | 1600x (Baseline) | 512x (Low-Res) | Δ |
|--------|------------------|----------------|---|
| S1 (Math) | 72 ± 8 | 71 ± 8 | -1 (no change) |
| S2 (Visual) | 70 ± 10 | 58 ± 12 | -12 (visual degraded) |
| S3 (Problem-specific) | 68 ± 12 | 67 ± 12 | -1 (no change) |
| S4 (Implementation) | 72 ± 10 | 60 ± 12 | -12 (visual degraded) |
| S5 (Completeness) | 75 ± 10 | 74 ± 10 | -1 (no change) |
| Total Score | 357/500 | 330/500 | -27 |
| Render Time | 2.0s | 0.125s | -93.75% |
| Compile Rate | 65% | 65% | 0% (no change) |

### Score Distribution Analysis

Plot score distributions to verify:
- S1, S3, S5: Overlapping distributions (mathematical scores unchanged)
- S2, S4: Shifted left (visual scores degraded)

## Performance Optimization Data

This experiment provides data for optimizing the benchmark pipeline:

### Use Cases for Lower Resolution

**512x512 - Fast Iteration**:
- Use case: Development, quick validation
- Speed: 16x faster rendering
- Quality: Good enough for correctness checks
- Recommendation: Use for compile rate testing

**1600x1600 - Production Baseline**:
- Use case: Official benchmarks, paper results
- Speed: Standard (2s/problem)
- Quality: High detail, fair visual evaluation
- Recommendation: Use for final scoring

**4096x4096 - High Quality (Optional)**:
- Use case: Publication figures, detailed analysis
- Speed: 4x slower rendering
- Quality: Maximum detail
- Recommendation: Use selectively for showcase

## Running the Experiment

### Single Run (512x)

```bash
cd llm_harness/experiments
python experiment_runner.py --config exp_3_output_format/config.yaml
```

### Multi-Resolution Comparison

```bash
# Run baseline (1600x)
python experiment_runner.py --config baseline/config.yaml

# Run low-res (512x)
python experiment_runner.py --config exp_3_output_format/config.yaml

# Compare
python analyze_resolution_impact.py \
  --baseline experiment_results/baseline_results.json \
  --variant experiment_results/exp_3_output_format_results.json
```

### Results Location

Results will be saved to:
- `experiment_results/exp_3_output_format_results.json`
- `experiment_results/resolution_analysis.md`

## Success Criteria

Experiment is successful if:

1. ✅ **Score independence verified**: S1/S3/S5 unchanged (±3 pts)
2. ✅ **Visual impact quantified**: S2/S4 decrease by 10-20 pts
3. ✅ **Performance gain measured**: Render time reduced by 10-15x
4. ✅ **Compile rate unchanged**: Resolution doesn't affect code quality

## Interpretation Guide

### If S1/S3/S5 Change Significantly (>5 points)
**Problem**: Resolution affecting mathematical evaluation
**Cause**: Judge may be using visual cues for math scores
**Action**: Revise judge prompts to separate visual from mathematical

### If S2/S4 Unchanged (<5 points difference)
**Problem**: Resolution not affecting visual scores
**Cause**: Judge not sensitive to resolution differences
**Action**: Recalibrate judge or use metric-based validation

### If Expected Pattern (S2/S4 down, S1/S3/S5 stable)
**Success**: Resolution impact is isolated to visual quality
**Action**: Document tradeoffs, provide resolution recommendations

## Timeline

- **Implementation**: 1 hour (minimal - just config changes)
- **Execution**: 0.3 hours (10 problems, fast render)
- **Analysis**: 1 hour (plot distributions, verify hypothesis)
- **Total**: 2-3 hours

## Dependencies

- No new dependencies (uses existing pipeline)
- Shader harness already supports `--size` flag

## Extended Variants

### High Resolution Test (4096x4096)

Test if higher resolution improves scores:
- Expected S2/S4: +5-10 points vs baseline
- Render time: +400% vs baseline
- Diminishing returns analysis

### HDR Format Test

Test HDR vs LDR color space:
- Format: Rgba16Float vs Rgba8UnormSrgb
- Expected impact: Minimal (most problems don't need HDR)
- Use case: High dynamic range scenes

## Related Documents

- [ABLATION_EXPERIMENTS.md](../../../agent_notes/ABLATION_EXPERIMENTS.md) - Overall experiment plan
- Shader harness documentation - `--size` flag usage

## Notes

This is a **quick win** experiment - minimal implementation effort, clear performance/quality tradeoff data.

The results will inform:
1. **Development workflow**: Use 512x for fast iteration
2. **CI/CD**: Use 512x for quick validation checks
3. **Production**: Use 1600x for official benchmarks
4. **Publication**: Use 4096x for high-quality figures

Resolution independence of S1/S3/S5 also validates that the judge is correctly separating mathematical correctness from visual quality.
