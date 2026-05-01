# Ablation Study: Shader Benchmark Factor Analysis

**Status**: Infrastructure complete, ready for execution
**Last Updated**: October 24, 2025
**Purpose**: Systematic measurement of which factors contribute to shader generation success

---

## Overview

This directory contains the infrastructure and configuration for 5 systematic ablation experiments designed to measure the impact of different architectural choices on shader benchmark success rates.

### What is Ablation Testing?

Ablation testing systematically varies **one factor at a time** while holding all others constant to measure its isolated contribution to overall performance. This allows us to:

1. **Validate hypotheses** about what makes the system work
2. **Quantify tradeoffs** between different design choices
3. **Identify opportunities** for optimization
4. **Build intuition** about failure modes and success patterns

### Core Research Question

**Which factors matter most for LLM shader generation success?**

Candidates:
- Training data volume (WGSL vs GLSL)
- Constraint specification (minimal vs standard vs strict)
- Prompt engineering (zero-shot vs one-shot vs few-shot)
- Output format (resolution, color space)
- Validation strategy (LLM judge vs metrics)

---

## Experiment Overview

| ID | Name | Primary Factor | Expected Impact | Priority | Effort |
|----|------|----------------|-----------------|----------|--------|
| 1 | Language Swap | WGSL → GLSL | High (validates migration) | 1 | 6h |
| 2 | Constraint Tightness | Standard → Minimal | High (validates constraints) | 2 | 3h |
| 3 | Output Format | 1600x → 512x | Low (performance data) | 4 | 2h |
| 4 | Validator Strategy | LLM → Metrics | Medium (ground truth) | 5 | 8h |
| 5 | Prompt Engineering | One-shot → Few-shot | Medium (ROI analysis) | 3 | 7h |

**Total effort**: ~26 hours (3-4 days)
**Estimated cost**: ~$250 in LLM API calls

---

## Experiment Summaries

### Experiment 1: Language Swap (WGSL → GLSL)

**Hypothesis**: WGSL constraints compensate for training data scarcity

**Test**: Compare WGSL (3 years training data + strict constraints) vs GLSL (20+ years training data + loose constraints)

**Key Metrics**:
- Compile rate difference
- Success rate comparison
- S1 (mathematical accuracy) similarity

**Success Criteria**:
- If GLSL >> WGSL: Training data dominates, migration questionable
- If GLSL ≈ WGSL: Constraints work, migration validated
- If GLSL << WGSL: Constraints are extremely valuable

**Why It Matters**: This validates the entire premise of the WGSL migration. If it fails, we may need to reconsider the approach.

📁 [Full Documentation](exp_1_language_swap/README.md)

---

### Experiment 2: Constraint Tightness (Standard → Minimal)

**Hypothesis**: Explicit type constraints prevent errors and improve compile rates

**Test**: Compare standard constraints (vec2<f32>, explicit types) vs minimal constraints (vec2, implicit conversions)

**Key Metrics**:
- Compile rate change
- Error frequency by type
- Code quality metrics

**Success Criteria**:
- If Minimal ≈ Standard: Constraints are unnecessary overhead
- If Minimal < Standard: Constraints provide value
- If Minimal << Standard: Constraints are critical

**Why It Matters**: Constraints add verbosity and token usage. If they don't prevent errors, we should simplify prompts.

📁 [Full Documentation](exp_2_constraint_tightness/README.md)

---

### Experiment 3: Output Format (1600x → 512x Resolution)

**Hypothesis**: Resolution affects visual scores (S2, S4) but not mathematical scores (S1, S3, S5)

**Test**: Compare 1600x1600 (baseline) vs 512x512 (fast) rendering

**Key Metrics**:
- Score distribution by category
- Render time reduction
- Quality/performance tradeoff

**Success Criteria**:
- S1/S3/S5 unchanged (±3 points)
- S2/S4 reduced by 10-20 points
- Render time reduced by 10-15x

**Why It Matters**: Provides data for optimizing the development workflow (use 512x for fast iteration, 1600x for official benchmarks).

📁 [Full Documentation](exp_3_output_format/README.md)

---

### Experiment 4: Validator Strategy (LLM Judge → Metrics)

**Hypothesis**: LLM judges are biased; metrics provide objective ground truth

**Test**: Compare LLM evaluation vs SSIM/MSE metrics against reference images

**Key Metrics**:
- Correlation between LLM and metric scores
- Bias detection (pretty but wrong)
- Score consistency (variance)

**Success Criteria**:
- Identify correlation strength
- Detect specific bias patterns
- Propose hybrid validation strategy

**Why It Matters**: Provides ground truth for calibrating LLM judges and detecting when they're unreliable.

📁 [Full Documentation](exp_4_validator_strategy/README.md)

---

### Experiment 5: Prompt Engineering (One-Shot → Few-Shot)

**Hypothesis**: Few-shot examples improve success at cost of increased token usage

**Test**: Compare one-shot (1 example) vs few-shot (3 examples) prompting

**Key Metrics**:
- Success rate improvement
- Token usage increase
- ROI (improvement / cost)
- Code diversity (template copying)

**Success Criteria**:
- Quantify improvement vs cost
- Calculate ROI threshold
- Recommend strategy by use case

**Why It Matters**: Examples clearly help, but do they justify 3x token cost? Determines optimal prompting strategy.

📁 [Full Documentation](exp_5_prompt_engineering/README.md)

---

## Infrastructure

### Configuration System

All experiments are defined via YAML configuration files using a common schema:

```yaml
experiment_id: exp_1_language_swap
name: "Language Swap (WGSL → GLSL)"
description: "Tests whether constraints compensate for training data scarcity"
hypothesis: "WGSL with constraints ≈ GLSL despite less training data"

# Experimental parameters
language_spec: glsl  # VARIATION
constraint_level: standard
prompt_strategy: one-shot
validator_strategy: llm_judge
output_format:
  resolution: 1600
  format: png

# Test scope
problems_to_test: [...]
expected_runtime_hours: 0.8
success_criteria: "..."
```

### Runner Orchestration

The `experiment_runner.py` script orchestrates experiment execution:

```python
from experiments import ExperimentRunner, ExperimentConfig

# Run single experiment
runner = ExperimentRunner()
config = ExperimentConfig.load_from_yaml("exp_1_language_swap/config.yaml")
results = await runner.run_experiment(config)

# Run all experiments with baseline
configs = [load_config(exp) for exp in all_experiments]
report = await runner.run_all_experiments(configs, include_baseline=True)
```

### Results Format

Each experiment produces:

1. **JSON results file**: Structured data with all metrics
2. **Comparative report**: Markdown analysis vs baseline
3. **Raw outputs**: Generated shaders, images, logs

Example results structure:

```json
{
  "experiment_id": "exp_1_language_swap",
  "success_rate": 65.0,
  "average_scores": {
    "s1": 72.5,
    "s2": 68.3,
    "s3": 70.1,
    "s4": 66.8,
    "s5": 74.2,
    "total": 351.9
  },
  "problem_results": [...],
  "errors_by_stage": {...},
  "performance_metrics": {...}
}
```

---

## Running Experiments

### Quick Start

```bash
cd llm_harness/experiments

# Run single experiment
python experiment_runner.py --config exp_1_language_swap/config.yaml

# Run all experiments
python experiment_runner.py --experiment-dir . --model "anthropic/claude-3.5-sonnet-20241022"

# Force rerun (ignore existing results)
python experiment_runner.py --config exp_1_language_swap/config.yaml --force-rerun
```

### Advanced Usage

```bash
# Use different models
python experiment_runner.py \
  --experiment-dir . \
  --model "anthropic/claude-3.5-sonnet-20241022" \
  --judge-model "anthropic/claude-3.5-haiku"

# Control parallelism
python experiment_runner.py \
  --config exp_1_language_swap/config.yaml \
  --max-parallel 4

# Skip baseline run
python experiment_runner.py \
  --experiment-dir . \
  --no-baseline
```

### Batch Execution

For running all experiments overnight:

```bash
#!/bin/bash
# run_all_experiments.sh

experiments=(
  "exp_1_language_swap"
  "exp_2_constraint_tightness"
  "exp_3_output_format"
  "exp_4_validator_strategy"
  "exp_5_prompt_engineering"
)

for exp in "${experiments[@]}"; do
  echo "Running $exp..."
  python experiment_runner.py --config "$exp/config.yaml"
  echo "✅ Completed $exp"
done

# Generate final comparative report
python experiment_runner.py --experiment-dir . --no-baseline
```

---

## Experimental Protocol

### Standard Procedure

Every experiment follows this protocol:

1. **Define configuration**: YAML file with all parameters
2. **Validate files**: Ensure all referenced files exist
3. **Run baseline**: Execute with standard configuration
4. **Run variant**: Change ONE variable, keep others constant
5. **Compare metrics**: Success rate, scores, performance
6. **Document findings**: What changed, why, should we adopt it?

### Reproducibility Checklist

- [ ] Fixed test problem set (same across experiments)
- [ ] Fixed model version (e.g., claude-3.5-sonnet-20241022)
- [ ] Fixed random seed (if supported by model)
- [ ] Same judge model for all evaluations
- [ ] Same hardware (GPU affects render times)
- [ ] Documented environment (Python, Rust, OS versions)

### Metrics to Track

**Performance Metrics**:
- Success rate (% of problems with total ≥ 250/500)
- Compile rate (% of problems that compile)
- Average scores (S1, S2, S3, S4, S5, total)
- Duration (compile time, render time, total time)

**Quality Metrics**:
- Error frequency by stage (generate, compile, render, judge)
- Error types (syntax, type, runtime, logic)
- Code patterns (antipatterns, best practices)
- Visual quality (if applicable)

**Cost Metrics**:
- Token usage (prompt + completion)
- API cost per problem
- Total cost for experiment
- Cost per successful result

---

## Analysis and Reporting

### Comparative Reports

The runner generates comparative markdown reports:

```markdown
# Ablation Experiment Comparative Report

## Executive Summary

| Experiment | Success Rate | Avg Score | Duration | Status |
|------------|--------------|-----------|----------|--------|
| baseline | 60.0% | 315/500 | 1.2h | ✅ Complete |
| exp_1_language_swap | 55.0% | 290/500 | 1.5h | ✅ Complete |
| exp_2_constraint_tightness | 50.0% | 280/500 | 1.0h | ✅ Complete |

## Key Insights

1. Language swap (WGSL→GLSL) resulted in 5% lower success rate
2. Minimal constraints decreased compile rate by 15%
3. Lower resolution reduced render time by 16x with minimal S1/S3/S5 impact

## Recommendations

1. Continue using WGSL - constraints compensate for training data gap
2. Keep standard constraints - prevent 15% of errors
3. Use 512x resolution for development, 1600x for production
```

### Visualization

Generate plots for key metrics:

```python
import matplotlib.pyplot as plt

# Success rate comparison
experiments = ['Baseline', 'GLSL', 'Minimal', '512x', 'Few-shot']
success_rates = [60.0, 55.0, 50.0, 60.0, 68.0]

plt.bar(experiments, success_rates)
plt.ylabel('Success Rate (%)')
plt.title('Ablation Experiment Results')
plt.axhline(y=60.0, color='r', linestyle='--', label='Baseline')
plt.legend()
plt.savefig('ablation_results.png')
```

---

## Expected Outcomes

### Hypothesis Validation Matrix

| Experiment | Hypothesis | Expected Outcome | Impact if Confirmed | Impact if Rejected |
|------------|------------|------------------|---------------------|---------------------|
| Language Swap | Constraints compensate for training data | WGSL ≈ GLSL | Migration validated | Reconsider WGSL |
| Constraints | Explicit types prevent errors | Minimal < Standard | Keep constraints | Simplify prompts |
| Resolution | Visual scores scale with resolution | S2/S4 down, S1/S3/S5 stable | Use 512x for dev | Judge calibration issue |
| Validator | LLM judges biased | Moderate correlation | Use hybrid | LLM judges reliable |
| Prompting | Examples improve success | Few-shot > One-shot | ROI-based strategy | Stick with one-shot |

### Decision Framework

For each experiment, outcomes guide concrete actions:

**High Impact + Confirmed Hypothesis**:
- Adopt change immediately
- Update documentation
- Modify baseline configuration

**High Impact + Rejected Hypothesis**:
- Investigate further
- Consider reverting previous decisions
- Run extended validation

**Low Impact + Any Outcome**:
- Document for reference
- No immediate action needed
- Useful for optimization later

---

## Directory Structure

```
experiments/
├── README.md                       # This file
├── __init__.py                     # Python package
├── experiment_config.py            # Configuration dataclass
├── experiment_runner.py            # Orchestration script
│
├── exp_1_language_swap/
│   ├── config.yaml                 # Experiment configuration
│   ├── README.md                   # Detailed documentation
│   ├── glsl_constraints.txt        # GLSL constraint spec
│   └── (results generated here)
│
├── exp_2_constraint_tightness/
│   ├── config.yaml
│   ├── README.md
│   ├── minimal_constraints.txt     # Relaxed constraint spec
│   └── (results generated here)
│
├── exp_3_output_format/
│   ├── config.yaml
│   ├── README.md
│   └── (results generated here)
│
├── exp_4_validator_strategy/
│   ├── config.yaml
│   ├── README.md
│   ├── metric_validator_config.json
│   └── (results generated here)
│
└── exp_5_prompt_engineering/
    ├── config.yaml
    ├── README.md
    ├── few_shot_prompt_template.txt
    └── (results generated here)
```

---

## Timeline and Resources

### Execution Schedule

Recommended order (highest impact first):

| Week | Days 1-2 | Days 3-4 | Day 5 |
|------|----------|----------|-------|
| 1 | Exp 1: Language Swap | Exp 2: Constraints | Analysis |
| 2 | Exp 5: Prompting | Exp 3: Resolution | Analysis |
| 3 | Exp 4: Validator | Extended analysis | Final report |

### Resource Requirements

**Compute**:
- GPU: Any modern GPU (shader rendering is fast)
- CPU: 8+ cores recommended for parallel compilation
- RAM: 16GB sufficient
- Storage: ~5GB per experiment (code + images + logs)

**API Credits**:
- Estimated $50 per experiment
- Total ~$250 for all 5 experiments
- Plus ~$50 for baseline runs

**Human Time**:
- Implementation: 20-30 hours (one-time setup)
- Execution: 5 hours (mostly automated)
- Analysis: 10-15 hours (interpretation + writeup)
- Total: ~40 hours (1 week)

---

## Success Criteria

The ablation study is successful if:

1. ✅ **All experiments complete**: Technical execution works
2. ✅ **Results reproducible**: Can rerun with similar outcomes (±5%)
3. ✅ **Hypotheses tested**: Clear confirmation or rejection
4. ✅ **Insights actionable**: Concrete recommendations produced
5. ✅ **Documentation complete**: Full writeup for publication

---

## Related Documents

- [ABLATION_EXPERIMENTS.md](../../agent_notes/ABLATION_EXPERIMENTS.md) - Original experiment planning
- [WGSL_CONSTRAINT_SPEC.md](../../agent_notes/WGSL_CONSTRAINT_SPEC.md) - Current constraint specification
- [scoring_system_technical.md](../../claude_code/scoring_system_technical.md) - Evaluation system
- [benchmark_harness.py](../benchmark_harness.py) - Pipeline orchestration

---

## Contributing

To add a new experiment:

1. Create directory: `experiments/exp_N_experiment_name/`
2. Write config: `config.yaml` with all parameters
3. Document: `README.md` explaining hypothesis and expected results
4. Add specs: Create any variant specification files (constraints, templates, etc.)
5. Register: Add to this README and update experiment runner
6. Test: Run on small problem set to validate configuration
7. Execute: Run full experiment and analyze results

---

## Notes

This ablation study infrastructure is designed to be:

- **Reusable**: Easy to add new experiments
- **Reproducible**: Deterministic execution with clear documentation
- **Scalable**: Parallel execution of multiple experiments
- **Analyzable**: Structured results for comparative analysis

The infrastructure will remain valuable beyond these 5 experiments for:
- **Future optimizations**: Testing new prompting strategies
- **Model comparisons**: Evaluating different LLMs
- **Constraint evolution**: Testing refined constraint specifications
- **Regression testing**: Ensuring changes don't degrade quality

---

**Status**: Infrastructure complete and tested
**Next Steps**: Execute experiments in priority order
**Owner**: Shader Benchmark Team
**Last Updated**: October 24, 2025
