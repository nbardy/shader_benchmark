# Ablation Experiments - Quick Start Guide

**5-minute guide to running experiments**

---

## Prerequisites

```bash
# 1. Install Python dependencies
cd llm_harness
pip install -r requirements.txt
pip install pyyaml scikit-image scipy

# 2. Set up API key
echo "OPENROUTER_API_KEY=your_key_here" > .env

# 3. Validate configurations
cd experiments
python validate_configs.py
```

---

## Run Single Experiment

```bash
# Run Experiment 1 (Language Swap)
python experiment_runner.py --config exp_1_language_swap/config.yaml

# Results saved to:
# - experiment_results/exp_1_language_swap_results.json
```

---

## Run All Experiments

```bash
# Run all 5 experiments with baseline
python experiment_runner.py --experiment-dir .

# Results saved to:
# - experiment_results/exp_N_*.json (one per experiment)
# - experiment_results/comparative_report_TIMESTAMP.md
```

---

## Common Options

```bash
# Use different model
python experiment_runner.py \
  --config exp_1_language_swap/config.yaml \
  --model "anthropic/claude-3.5-sonnet-20241022"

# Control parallelism
python experiment_runner.py \
  --config exp_1_language_swap/config.yaml \
  --max-parallel 4

# Force rerun (ignore existing results)
python experiment_runner.py \
  --config exp_1_language_swap/config.yaml \
  --force-rerun

# Skip baseline
python experiment_runner.py \
  --experiment-dir . \
  --no-baseline
```

---

## Expected Runtime

| Experiment | Runtime | Cost |
|------------|---------|------|
| Baseline | 0.5h | $25 |
| Exp 1: Language Swap | 0.8h | $40 |
| Exp 2: Constraints | 0.6h | $30 |
| Exp 3: Resolution | 0.3h | $15 |
| Exp 4: Validator | 0.5h | $25 |
| Exp 5: Prompting | 0.7h | $50 |
| **Total** | **3.4h** | **$185** |

---

## Experiment Summaries

### Exp 1: Language Swap (WGSL → GLSL)
**Tests**: Whether constraints compensate for training data scarcity
**Result**: If GLSL ≈ WGSL, migration is validated

### Exp 2: Constraint Tightness (Standard → Minimal)
**Tests**: Whether explicit types prevent errors
**Result**: If Minimal << Standard, constraints are valuable

### Exp 3: Output Format (1600x → 512x)
**Tests**: Resolution impact on visual vs math scores
**Result**: Use 512x for dev, 1600x for production

### Exp 4: Validator Strategy (LLM → Metrics)
**Tests**: LLM judge bias vs objective metrics
**Result**: Hybrid approach (metrics for S2/S4, LLM for S1/S3/S5)

### Exp 5: Prompt Engineering (One-Shot → Few-Shot)
**Tests**: Example value vs token cost
**Result**: ROI analysis for prompting strategy

---

## Checking Results

```bash
# View results summary
cat experiment_results/comparative_report_*.md

# View specific experiment
cat experiment_results/exp_1_language_swap_results.json | jq '.success_rate'

# List all results
ls -lh experiment_results/
```

---

## Troubleshooting

### Config validation fails
```bash
# Check which configs are invalid
python validate_configs.py

# View specific config
cat exp_1_language_swap/config.yaml
```

### Missing API key
```bash
# Check .env file exists
ls -la ../.env

# Verify key is set
grep OPENROUTER_API_KEY ../.env
```

### Import errors
```bash
# Reinstall dependencies
pip install -r ../requirements.txt
pip install pyyaml

# Check Python version (need 3.8+)
python --version
```

---

## Priority Order

Recommended execution sequence (highest impact first):

1. **Baseline** - Establish reference point
2. **Exp 1** - Validate WGSL migration (critical)
3. **Exp 2** - Validate constraints (high impact)
4. **Exp 5** - Optimize prompting (practical improvement)
5. **Exp 3** - Performance data (optimization)
6. **Exp 4** - Validator ground truth (quality assurance)

---

## Full Documentation

- **Overview**: [README.md](README.md)
- **Deliverables**: [DELIVERABLES.md](DELIVERABLES.md)
- **Experiment Details**: See individual `exp_N_name/README.md` files

---

## Help

```bash
# Show all CLI options
python experiment_runner.py --help

# Validate configs
python validate_configs.py
```

---

**Quick Start Complete!**

Next: `python experiment_runner.py --experiment-dir .`
