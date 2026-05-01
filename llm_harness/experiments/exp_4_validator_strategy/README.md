# Experiment 4: Validator Strategy (LLM Judge → Metric-Based)

## Overview

This experiment tests whether LLM judges are biased by visual aesthetics and provides objective ground truth through image similarity metrics (SSIM, MSE).

## Hypothesis

LLM judges may assign high visual quality scores to aesthetically pleasing but mathematically incorrect outputs. Metric-based validation (SSIM/MSE against reference images) provides unbiased ground truth for visual quality (S2, S4) but cannot evaluate mathematical correctness (S1, S3, S5).

**Expected outcomes**:
- SSIM scores more consistent (lower variance)
- LLM scores may be inflated for "pretty but wrong" outputs
- Hybrid approach optimal (metrics for S2/S4, LLM for S1/S3/S5)

## Experimental Design

### Control (Baseline)
- Validator: LLM Judge (claude-3.5-haiku)
- Evaluation: All 5 scores (S1-S5)
- Subjectivity: Moderate (judge interpretation varies)

### Treatment
- Validator: **Metric-based** (SSIM, MSE)
- Evaluation: S2, S4 only (visual quality)
- Subjectivity: None (deterministic metrics)

### Variables Held Constant
- Language: WGSL
- Constraints: Standard
- Model: claude-3.5-sonnet-20241022
- Test problems: 8 problems with verified reference images

## Implementation Requirements

### 1. Reference Image Generation

Create hand-verified correct shaders and render reference images:

```bash
cd problems/base_set

# For each test problem
for problem in geometric_cube sphere_wireframe torus_knot mandelbrot_set; do
    # 1. Write correct reference shader (manually verified)
    # 2. Render reference image
    cd ../../shader_harness
    cargo run -- --shader ../problems/base_set/$problem/reference.wgsl \
                 --output ../problems/base_set/$problem/reference.png \
                 --size 1600
done
```

### 2. Metric Validator Implementation

Create `llm_harness/metric_validator.py`:

```python
from skimage.metrics import structural_similarity as ssim
from PIL import Image
import numpy as np

class MetricValidator:
    def evaluate_ssim(self, reference_path, result_path):
        """Compute structural similarity (perceptual quality)"""
        ref = np.array(Image.open(reference_path).convert('RGB'))
        res = np.array(Image.open(result_path).convert('RGB'))

        score = ssim(ref, res, channel_axis=2, data_range=255)
        return score * 100  # Convert to 0-100 scale

    def evaluate_mse(self, reference_path, result_path):
        """Compute mean squared error (pixel accuracy)"""
        ref = np.array(Image.open(reference_path).convert('RGB'))
        res = np.array(Image.open(result_path).convert('RGB'))

        mse = np.mean((ref.astype(float) - res.astype(float)) ** 2)
        # Invert and scale: lower MSE = higher score
        return max(0, 100 - (mse / 100))

    def evaluate_psnr(self, reference_path, result_path):
        """Compute peak signal-to-noise ratio"""
        ref = np.array(Image.open(reference_path).convert('RGB'))
        res = np.array(Image.open(result_path).convert('RGB'))

        mse = np.mean((ref - res) ** 2)
        if mse == 0:
            return 100
        max_pixel = 255.0
        psnr = 20 * np.log10(max_pixel / np.sqrt(mse))
        return min(100, psnr)  # Cap at 100
```

### 3. Judge Integration

Modify `llm_harness/judge.py` to support metric-based validation:

```python
from metric_validator import MetricValidator

class Judge:
    def evaluate_with_metrics(self, reference_image, result_image):
        """Use image metrics instead of LLM evaluation"""
        validator = MetricValidator()
        ssim_score = validator.evaluate_ssim(reference_image, result_image)
        mse_score = validator.evaluate_mse(reference_image, result_image)

        # Map to 5-score format
        return {
            's1': 0,  # Cannot evaluate mathematical accuracy
            's2': ssim_score,  # Structural similarity (visual quality)
            's3': 0,  # Cannot evaluate problem-specific criteria
            's4': mse_score,  # Pixel accuracy (visual implementation)
            's5': 0   # Cannot evaluate completeness
        }
```

## Expected Results

### Quantitative Metrics

| Validator | S1 | S2 | S3 | S4 | S5 | Total | Variance |
|-----------|----|----|----|----|----|----|----------|
| LLM Judge | 75 | 70 | 68 | 72 | 80 | 365/500 | High (±12) |
| SSIM Metric | 0 | 85 | 0 | 80 | 0 | 165/500 | Low (±3) |

### Correlation Analysis

Compute correlation between LLM S2/S4 and metric scores:

```python
import scipy.stats

# Correlation between LLM S2 and SSIM
correlation_s2_ssim, p_value = scipy.stats.pearsonr(llm_s2_scores, ssim_scores)

# Correlation between LLM S4 and MSE
correlation_s4_mse, p_value = scipy.stats.pearsonr(llm_s4_scores, mse_scores)
```

**Expected correlations**:
- LLM S2 ↔ SSIM: r = 0.7-0.9 (high correlation)
- LLM S4 ↔ MSE: r = 0.6-0.8 (moderate correlation)
- Outliers: "Pretty but wrong" outputs (high LLM, low metric)

## Bias Detection

### Identifying Judge Bias

Look for outputs where:
- LLM S2 > 70 AND SSIM < 50: **Aesthetic bias** (judge likes pretty errors)
- LLM S2 < 50 AND SSIM > 70: **Correctness bias** (judge penalizes correct but plain)

### Bias Categories

1. **Color Bias**: Judge prefers vibrant colors over accurate colors
2. **Complexity Bias**: Judge prefers complex patterns over simple correct answers
3. **Aesthetic Bias**: Judge rewards visual appeal over mathematical accuracy

## Running the Experiment

### Step 1: Generate Reference Images

```bash
cd llm_harness/experiments/exp_4_validator_strategy
./generate_references.sh  # Creates reference images for test problems
```

### Step 2: Run Metric Validation

```bash
cd llm_harness/experiments
python experiment_runner.py --config exp_4_validator_strategy/config.yaml
```

### Step 3: Compare with LLM Judge

```bash
# Run baseline with LLM judge
python experiment_runner.py --config baseline/config.yaml

# Analyze correlation
python analyze_judge_correlation.py \
  --llm-results experiment_results/baseline_results.json \
  --metric-results experiment_results/exp_4_validator_strategy_results.json
```

### Results Location

Results will be saved to:
- `experiment_results/exp_4_validator_strategy_results.json`
- `experiment_results/judge_correlation_analysis.md`
- `experiment_results/bias_outliers.csv`

## Success Criteria

Experiment is successful if:

1. ✅ **Metrics computed**: SSIM/MSE for all test problems
2. ✅ **Correlation measured**: Quantify LLM ↔ metric agreement
3. ✅ **Bias identified**: Find specific cases where LLM is biased
4. ✅ **Hybrid strategy proposed**: Recommend optimal validation approach

## Interpretation Guide

### If Correlation High (r > 0.8)
**Interpretation**: LLM judge is reliable for visual quality
**Action**: Continue using LLM judge, metrics not needed
**Impact**: Validates current approach

### If Correlation Moderate (r = 0.5-0.8)
**Interpretation**: LLM judge is somewhat reliable but has bias
**Action**: Use hybrid approach (metrics for S2/S4, LLM for S1/S3/S5)
**Impact**: Improved accuracy for visual scores

### If Correlation Low (r < 0.5)
**Interpretation**: LLM judge is unreliable for visual quality
**Action**: Replace LLM S2/S4 with metrics entirely
**Impact**: Significant architecture change needed

## Hybrid Validation Strategy

Optimal approach based on expected results:

| Score | Validator | Rationale |
|-------|-----------|-----------|
| S1 (Math) | LLM | Requires semantic understanding |
| S2 (Visual) | **SSIM Metric** | Objective perceptual quality |
| S3 (Problem) | LLM | Problem-specific semantic criteria |
| S4 (Implementation) | **MSE Metric** | Objective pixel accuracy |
| S5 (Completeness) | LLM | Requires understanding of requirements |

This hybrid approach provides:
- **Objective S2/S4**: Metrics eliminate aesthetic bias
- **Semantic S1/S3/S5**: LLM evaluates correctness and completeness
- **Best of both**: Determinism + understanding

## Timeline

- **Reference generation**: 2-3 hours (create and verify correct shaders)
- **Metric implementation**: 2-3 hours (SSIM/MSE/PSNR)
- **Execution**: 0.5 hours (8 problems)
- **Analysis**: 2-3 hours (correlation, bias detection)
- **Total**: 7-9 hours

## Dependencies

New Python dependencies:
```bash
pip install scikit-image pillow numpy scipy
```

## Future Extensions

### Perceptual Metrics

Add advanced perceptual metrics:
- **LPIPS** (Learned Perceptual Image Patch Similarity)
- **DSSIM** (Structural Dissimilarity)
- **Frechet Distance**: For distribution similarity

### Semantic Metrics

Combine metrics with semantic understanding:
- Use CLIP embeddings for semantic similarity
- Detect specific mathematical features (fractals, symmetry)
- Multi-scale analysis (local + global correctness)

## Related Documents

- [ABLATION_EXPERIMENTS.md](../../../agent_notes/ABLATION_EXPERIMENTS.md) - Overall experiment plan
- [scoring_system_technical.md](../../../claude_code/scoring_system_technical.md) - Current scoring system

## Notes

This experiment provides **ground truth** for validating and calibrating LLM judges. Even if we continue using LLM judges for convenience, knowing their bias patterns allows us to:

1. **Calibrate prompts**: Adjust judge prompts to reduce bias
2. **Identify outliers**: Flag suspicious scores for manual review
3. **Validate improvements**: Ensure judge updates improve accuracy

The metric validator will also be valuable for **regression testing** - ensuring that pipeline changes don't degrade output quality.
