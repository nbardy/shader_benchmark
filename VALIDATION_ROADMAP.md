# Validation Roadmap: Proving Constraint-Based LLM Shader Generation

**Date:** October 24, 2025
**Status:** Migration Complete, Validation Pending
**Hypothesis:** Explicit constraints + structured prompting beats training-data volume
**Baseline:** 20% success rate (previous WGSL attempts)

---

## 1. Strategic Validation Plan (Why We're Doing This)

### The Core Research Question

**Can constraint-based prompting overcome training data limitations?**

The shader benchmark represents a critical test case:
- **GLSL:** 20+ years of training data, massive GitHub corpus, Shadertoy ubiquity
- **WGSL:** 3 years of training data, minimal LLM exposure, strict hardware constraints
- **Thesis:** Explicit ABI contracts + structured prompts > implicit pattern recognition

### Success Criteria Definition

We consider validation successful if we achieve **>35% success rate** on 100-problem benchmark.

| Success Rate | Interpretation | Next Action |
|--------------|----------------|-------------|
| 0-15% | Complete failure | Abort, investigate shader generation fundamentals |
| 16-25% | Marginal improvement | Tighten constraints, add examples |
| 26-35% | Modest success | Proceed to ablations, measure effect size |
| 36-50% | Strong validation | Publish results, optimize pipeline |
| 51%+ | Breakthrough | Scale to production, explore compute shaders |

**Why 35%?** Represents 75% improvement over 20% baseline - statistically significant signal that constraints work.

### Risk Mitigation Strategy

**Risk 1: Early total failure (Phase 1 shows 0% success)**
- **Detection:** All 10 test problems fail compilation or render black screens
- **Mitigation:** Emergency prompt audit, check if LLMs generating WGSL vs GLSL
- **Escape hatch:** Fall back to GLSL-only mode (see ABLATION_EXPERIMENTS.md)

**Risk 2: Inconsistent results (success rate varies 10-90%)**
- **Detection:** High variance across problem categories (geometry works, fractals fail)
- **Mitigation:** Stratified sampling by problem difficulty, category-specific prompts
- **Learning:** Identify which constraint classes work best

**Risk 3: Compilation succeeds but renders are wrong (black screens, GPU errors)**
- **Detection:** Phase 1 shows compiles but low judge scores (<30/500)
- **Mitigation:** Manual inspection of generated shaders, check for off-by-one errors
- **Fix:** Add visual debugging examples to prompt (grid patterns, test shaders)

**Risk 4: Resource exhaustion (timeout/memory issues at scale)**
- **Detection:** Phase 2 hangs or kills processes
- **Mitigation:** Reduce parallelism from 4 to 1, increase timeout from 5min to 10min
- **Optimization:** Profile GPU usage, implement batching for judge evaluations

---

## 2. Validation Phases (Execution Plan)

### Phase 1: Quick Smoke Test (10 Problems, 30 Minutes)

**Goal:** Confirm pipeline works end-to-end, get early failure signal

**Resource Requirements:**
- 1 engineer (monitoring execution)
- OpenRouter API budget: ~$2-3 (10 problems × $0.20/problem)
- GPU: Single Mac/Linux workstation with Metal/Vulkan

**Problem Selection Strategy:**
```bash
# Stratified sample: 2 problems per difficulty tier
EASY="geometric_cube regular_tetrahedron"
MEDIUM="torus_donut_parametric apollonian_gasket"
HARD="klein_bottle mandelbrot_set"
VERY_HARD="hopf_fibration lorenz_attractor"
EXTREME="calabi_yau_manifold schwarzschild_black_hole"
```

**Execution Command:**
```bash
cd llm_harness
source venv/bin/activate
python benchmark_harness.py \
  --model "anthropic/claude-3.5-sonnet-20241022" \
  --problems $EASY $MEDIUM $HARD $VERY_HARD $EXTREME \
  --max-parallel 2
```

**Success Metrics:**
- **Compilation rate:** X/10 shaders compile successfully
- **Render rate:** Y/10 produce non-black output images
- **Judge scores:** Average score per category (S1-S5)
- **Time per problem:** Actual vs expected (60-160s baseline)

**Exit Criteria:**

```
IF compilation_rate == 0:
    → ABORT Phase 2
    → Run emergency diagnostic (check LLM generating WGSL vs GLSL)
    → Manual inspection of 3 failed shaders

ELIF compilation_rate >= 1 AND compilation_rate <= 3:
    → CONDITIONAL PROCEED to Phase 2
    → Flag as "high risk" - prepare fallback to GLSL

ELIF compilation_rate >= 4:
    → PROCEED to Phase 2
    → Validation looks promising

# Additional check: Are renders meaningful?
IF render_rate > 0 AND avg_judge_score < 100/500:
    → WARNING: Compiling but producing garbage
    → Add visual debugging step before Phase 2
```

**Deliverable:** `phase1_smoke_test_report.md` with:
- Compilation success breakdown
- Sample rendered images (best, worst, median)
- Error analysis (compilation vs runtime vs judge evaluation)
- Go/no-go recommendation for Phase 2

---

### Phase 2: Full Validation (100 Problems, 3-4 Hours)

**Goal:** Measure success rate with statistical confidence, identify failure modes

**Resource Requirements:**
- 1 engineer (monitoring, can context-switch during execution)
- OpenRouter API budget: ~$25-30 (100 problems × $0.25/problem)
- GPU: Single workstation (can run overnight if needed)
- Disk: ~2GB for results (100 × 20MB per test)

**Execution Command:**
```bash
cd llm_harness
source venv/bin/activate

# Run all 101 problems in base_set
python benchmark_harness.py \
  --model "anthropic/claude-3.5-sonnet-20241022" \
  --problems $(ls ../problems/base_set) \
  --max-parallel 3 \
  --timeout 300
```

**Monitoring During Execution:**
```bash
# Watch execution summary (live updates)
tail -f harness_*/logs/execution_summary.log

# Check for compilation failures
grep -r "STAGE START: compile" harness_*/logs/*.log | wc -l  # Should be 100

# Monitor GPU usage (if on Linux)
watch -n 5 nvidia-smi  # or watch -n 5 'ps aux | grep shader-bench'
```

**Success Metrics:**

**Primary Metric: Success Rate**
- **Definition:** Problem succeeds if ALL conditions met:
  1. Shader compiles (cargo build succeeds)
  2. Renders without timeout (shader-bench completes)
  3. Average judge score ≥ 150/500 (30% threshold per criterion)

- **Calculation:** `success_rate = successful_problems / 100`

**Secondary Metrics:**
- **Compilation failure rate:** Problems that fail cargo build
- **Runtime failure rate:** Problems that compile but crash/timeout during render
- **Low-quality rate:** Problems that render but score <150/500 (judges say "wrong")

**Tertiary Metrics:**
- **Average scores by category:**
  - S1 (Mathematical Accuracy): Mean, median, std dev
  - S2 (Visual Quality): Mean, median, std dev
  - S3-S5 (Problem-specific): Mean, median, std dev
- **Performance:**
  - Average compilation time (should be 10-30s)
  - Average render time (should be 5-20s)
  - Average judge evaluation time (should be 20-40s)

**Exit Criteria Decision Tree:**

```
                    Phase 2 Complete
                           │
                           ▼
              ┌────────────────────────┐
              │  success_rate < 25%   │
              └────────┬───────────────┘
                       │ YES
                       ▼
         ┌──────────────────────────────┐
         │ INVESTIGATE CONSTRAINTS      │
         │ - Too strict?                │
         │ - Missing examples?          │
         │ - Wrong format guidance?     │
         │ ACTION: Run Ablation Exp 2   │
         └──────────────────────────────┘
                       │ NO
                       ▼
              ┌────────────────────────┐
              │  success_rate 25-40%  │
              └────────┬───────────────┘
                       │ YES
                       ▼
         ┌──────────────────────────────┐
         │ PARTIAL SUCCESS              │
         │ - Hypothesis validated       │
         │ - Room for optimization      │
         │ ACTION: Run Ablation Exp 1   │
         │         (GLSL comparison)    │
         └──────────────────────────────┘
                       │ NO
                       ▼
              ┌────────────────────────┐
              │  success_rate > 40%   │
              └────────┬───────────────┘
                       │ YES
                       ▼
         ┌──────────────────────────────┐
         │ STRONG VALIDATION            │
         │ - Constraints clearly work   │
         │ - Publish results            │
         │ ACTION: Scale to production  │
         │         Consider 500-problem │
         │         extended benchmark   │
         └──────────────────────────────┘
```

**Deliverable:** `phase2_full_validation_report.md` with:
- Executive summary (success rate, comparison to baseline)
- Detailed metrics breakdown (compilation, render, judge scores)
- Category analysis (which problem types work best?)
- Failure mode taxonomy (common error patterns)
- Recommendation for next steps (ablations, optimizations, publication)

---

### Phase 3: Extended Scale Test (500 Problems, Optional)

**Goal:** Test robustness at production scale, gather data for research publication

**Resource Requirements:**
- 1 engineer (setup, then automated)
- OpenRouter API budget: ~$125-150 (500 × $0.25/problem)
- GPU: Can run overnight/weekend (15-20 hours)
- Disk: ~10GB for results

**When to Run Phase 3:**
```
IF Phase 2 success_rate > 40%:
    → Run Phase 3 for publication-quality results

IF Phase 2 success_rate 25-40%:
    → SKIP Phase 3 initially
    → Run ablations first to improve
    → Then run Phase 3 with optimized configuration

IF Phase 2 success_rate < 25%:
    → SKIP Phase 3
    → Focus on fixing fundamentals
```

**Problem Set Expansion:**
```bash
# Add 400 additional problems from research/ directory
# OR create synthetic variations:
#   - Rotations (cube → rotated cube × 8 orientations)
#   - Color schemes (mandelbrot × 5 color maps)
#   - Resolution tests (1024×1024, 2048×2048, 4096×4096)
```

**Success Metrics:**
- **Stability:** Success rate variance < 5% across batches
- **Consistency:** Per-category scores stable across problem variations
- **Performance:** No degradation in compilation/render times at scale

**Deliverable:** `phase3_production_scale_report.md` + research paper draft

---

## 3. Success Metrics Definition (How to Interpret Results)

### Primary Metric: Success Rate

**Formula:**
```python
def is_successful(problem_result):
    compiled = problem_result['compilation_status'] == 'success'
    rendered = problem_result['render_status'] == 'success'
    avg_score = sum(problem_result['scores']) / 5
    meaningful = avg_score >= 150  # 30% threshold

    return compiled and rendered and meaningful

success_rate = sum(is_successful(r) for r in results) / len(results)
```

**Interpretation Rubric:**

| Success Rate | Label | Meaning | Next Action |
|--------------|-------|---------|-------------|
| 0-10% | Critical Failure | LLMs not generating valid shaders | Emergency diagnostic |
| 11-20% | Baseline Match | No improvement over previous attempts | Investigate constraints |
| 21-30% | Marginal Gain | Slight improvement, not statistically significant | Tighten prompts |
| 31-40% | Modest Success | 50%+ improvement, promising signal | Run ablations |
| 41-55% | Strong Success | 2x improvement, clear validation | Optimize and scale |
| 56-70% | Exceptional | 3x improvement, publishable | Write paper |
| 71%+ | Breakthrough | 3.5x+ improvement, state-of-the-art | Industry impact |

### Secondary Metrics: Failure Mode Analysis

**Compilation Failures:**
```python
compilation_failure_rate = (
    problems_that_failed_cargo_build / total_problems
)

# Target: <30% (meaning 70%+ compile successfully)
# If >50%: LLMs not understanding WGSL syntax
```

**Runtime Failures:**
```python
runtime_failure_rate = (
    (problems_compiled - problems_rendered) / total_problems
)

# Target: <10% (most compiled shaders should render)
# If >20%: GPU errors, timeout issues, harness bugs
```

**Low-Quality Renders:**
```python
low_quality_rate = (
    problems_with_avg_score_below_150 / total_problems
)

# Target: <40% (60%+ should produce "correct-ish" visuals)
# If >60%: Shaders compile but don't match problem specs
```

### Tertiary Metrics: Judge Score Distribution

**Expected Score Distribution (Based on Problem Difficulty):**

```
Category S1 (Mathematical Accuracy):
  Easy problems (geometric_cube):      Target 70-90/100
  Medium (torus, fractals):            Target 50-70/100
  Hard (klein_bottle, mandelbrot):     Target 40-60/100
  Extreme (hopf_fibration, calabi_yau): Target 20-40/100

Category S2 (Visual Quality):
  Should track S1 closely (±10 points)

Categories S3-S5 (Problem-Specific):
  More variance expected (problem-dependent rubrics)
  Look for consistency within problem families
```

**Red Flags in Score Distribution:**
```python
# Red Flag 1: Bimodal distribution (all 0-20 or 80-100, nothing in middle)
# → Judge is being too binary, or problems have no gradient of difficulty

# Red Flag 2: All scores uniform (everything 50±5)
# → Judge not discriminating, or all problems equally hard

# Red Flag 3: S2 >> S1 (visuals good but math wrong)
# → LLMs making "pretty" shaders that don't solve the problem

# Red Flag 4: S1 >> S2 (math right but looks bad)
# → Missing lighting, materials, anti-aliasing (easily fixable)
```

### Performance Metrics (Tertiary)

**Time per Problem Breakdown:**
```
Expected timing (90th percentile):
  - LLM generation:     30-90s  (depends on model, prompt length)
  - Shader compilation: 10-30s  (cargo build --release)
  - GPU rendering:      5-20s   (WGPU render pass + PNG encode)
  - Judge evaluation:   20-40s  (GPT-4o vision analysis)
  ────────────────────────────
  Total per problem:    65-180s

Batch of 100 problems with parallelism=3:
  - Ideal time:  100/3 × 120s = 4000s = 67 minutes
  - Realistic:   Add 20% overhead = 80 minutes
  - Worst case:  Timeouts, retries = 180 minutes (3 hours)
```

**If Performance Degrades:**
```python
if avg_time_per_problem > 240s:  # 4 minutes
    # Check for:
    # - API rate limiting (LLM generation hanging)
    # - GPU contention (parallel renders fighting)
    # - Disk I/O bottleneck (logs, PNG writes)
    # Fix: Reduce parallelism, increase timeout, optimize I/O
```

---

## 4. Go/No-Go Decision Tree (Phase Transitions)

### ASCII Decision Tree

```
                         START VALIDATION
                                │
                                ▼
                  ┌─────────────────────────┐
                  │   PHASE 1: SMOKE TEST   │
                  │   (10 problems, 30 min) │
                  └────────────┬────────────┘
                               │
                ┌──────────────┴──────────────┐
                │                             │
                ▼                             ▼
    ┌───────────────────────┐    ┌───────────────────────┐
    │ Compile rate = 0/10   │    │ Compile rate ≥ 1/10   │
    │ (Complete failure)    │    │ (Partial success)     │
    └───────────┬───────────┘    └───────────┬───────────┘
                │                             │
                ▼                             │
    ┌───────────────────────────┐            │
    │ ABORT VALIDATION          │            │
    │ ────────────────          │            │
    │ Actions:                  │            │
    │ 1. Check LLM output       │            │
    │    (WGSL vs GLSL?)        │            │
    │ 2. Manual shader inspect  │            │
    │ 3. Verify prompt loaded   │            │
    │ 4. Test single shader     │            │
    │    manually in harness    │            │
    │                           │            │
    │ Decision:                 │            │
    │ - Fix prompts → Retry P1  │            │
    │ - OR switch to GLSL mode  │            │
    └───────────────────────────┘            │
                                              ▼
                               ┌──────────────────────────┐
                               │   PHASE 2: FULL (100)    │
                               │   (3-4 hours)            │
                               └────────────┬─────────────┘
                                            │
                  ┌─────────────────────────┼─────────────────────────┐
                  │                         │                         │
                  ▼                         ▼                         ▼
      ┌─────────────────────┐  ┌──────────────────────┐  ┌─────────────────────┐
      │ Success < 25%       │  │ Success 25-40%       │  │ Success > 40%       │
      │ (Below threshold)   │  │ (Modest win)         │  │ (Strong validation) │
      └──────────┬──────────┘  └──────────┬───────────┘  └──────────┬──────────┘
                 │                        │                         │
                 ▼                        ▼                         ▼
    ┌──────────────────────┐  ┌──────────────────────┐  ┌──────────────────────┐
    │ INVESTIGATE          │  │ RUN ABLATIONS        │  │ DECLARE VICTORY      │
    │ ────────────         │  │ ────────────         │  │ ───────────         │
    │ Hypothesis:          │  │ Goal: Measure effect │  │ Results:            │
    │ - Constraints too    │  │ size of constraints  │  │ - 2x improvement    │
    │   strict?            │  │                      │  │ - Publish findings  │
    │ - Missing examples?  │  │ Run Ablation Exp 1:  │  │ - Scale to prod     │
    │ - Wrong prompt eng?  │  │ - GLSL vs WGSL       │  │                     │
    │                      │  │ - Expect GLSL +10%?  │  │ Next:               │
    │ Actions:             │  │                      │  │ - Phase 3 (500 probs)
    │ 1. Run Ablation 2    │  │ Run Ablation 2:      │  │ - Optimize pipeline │
    │    (Constraint-)     │  │ - Remove constraints │  │ - Write paper       │
    │ 2. Add few-shot      │  │ - Expect -20%?       │  │                     │
    │    examples          │  │                      │  │                     │
    │ 3. Manual prompt     │  │ Outcome:             │  │                     │
    │    refinement        │  │ - Quantify gains     │  │                     │
    │                      │  │ - Justify approach   │  │                     │
    └──────────────────────┘  └──────────────────────┘  └──────────────────────┘
```

### Detailed Decision Logic

**After Phase 1 (10-problem smoke test):**

```python
if phase1_compile_rate == 0:
    print("CRITICAL: Zero shaders compiled")
    print("DO NOT PROCEED to Phase 2")
    print("")
    print("Emergency Diagnostic Steps:")
    print("1. Check last 3 LLM responses:")
    print("   grep -A 50 '<shader' test_*/response.txt | head -n 200")
    print("2. Verify WGSL syntax (not GLSL leak):")
    print("   grep -E '@vertex|@fragment|fn vs_main|fn fs_main' test_*/shader.*")
    print("3. Check prompt template loaded:")
    print("   ls -lah llm_harness/prompt_template.txt")
    print("4. Test harness manually:")
    print("   cd shader_harness && cargo run -- --shader test.wgsl")
    print("")
    print("DECISION: Fix fundamental issue before Phase 2")

elif phase1_compile_rate >= 1 and phase1_compile_rate <= 3:
    print("WARNING: Low compilation rate (1-3/10)")
    print("CONDITIONAL GO for Phase 2")
    print("")
    print("Risk Assessment:")
    print(f"- Compilation: {phase1_compile_rate}/10 ({phase1_compile_rate*10}%)")
    print(f"- Projected Phase 2: ~{phase1_compile_rate*10}% success")
    print("")
    if phase1_compile_rate * 10 < 20:  # Projected <20%
        print("RECOMMENDATION: High risk, consider GLSL fallback")
        print("              OR add few-shot examples to prompt")
    else:
        print("RECOMMENDATION: Proceed but monitor closely")
        print("              Prepare to abort if P2 trends worse")

else:  # compile_rate >= 4
    print(f"GO: {phase1_compile_rate}/10 compiled ({phase1_compile_rate*10}%)")
    print("Validation looks promising, proceed to Phase 2")
    print("")
    print(f"Projected 100-problem success rate: ~{phase1_compile_rate*10 - 5}%")
```

**After Phase 2 (100-problem validation):**

```python
if phase2_success_rate < 0.15:
    print("RESULT: Critical Failure (<15%)")
    print("CONCLUSION: Constraints not working, major issues")
    print("")
    print("Root Cause Analysis Required:")
    print("1. Category breakdown:")
    print("   - What % failed compile? (syntax errors)")
    print("   - What % failed render? (GPU/harness bugs)")
    print("   - What % scored low? (wrong visuals)")
    print("2. Manual inspection of 10 random failures")
    print("3. Compare to original 20% baseline")
    print("")
    print("DO NOT RUN PHASE 3")
    print("DECISION: Pivot to GLSL-only OR redesign prompts")

elif phase2_success_rate >= 0.15 and phase2_success_rate < 0.25:
    print(f"RESULT: Marginal Improvement ({phase2_success_rate*100:.1f}%)")
    print("CONCLUSION: Slight gain over 20% baseline, not compelling")
    print("")
    print("Next Steps:")
    print("1. Run Ablation Experiment 2 (Constraint Tightness)")
    print("   - Test if removing constraints hurts or helps")
    print("2. Add few-shot examples to prompt_template.txt")
    print("   - Include 2-3 complete working shaders")
    print("3. Analyze failure modes by category")
    print("   - Are fractals failing? Geometry working?")
    print("")
    print("SKIP PHASE 3 for now")
    print("DECISION: Optimize first, then re-validate")

elif phase2_success_rate >= 0.25 and phase2_success_rate <= 0.40:
    print(f"RESULT: Modest Success ({phase2_success_rate*100:.1f}%)")
    print(f"CONCLUSION: {(phase2_success_rate/0.20 - 1)*100:.0f}% improvement over baseline")
    print("")
    print("Hypothesis PARTIALLY validated - constraints help")
    print("")
    print("High-Value Next Steps:")
    print("1. Run Ablation Experiment 1 (GLSL vs WGSL)")
    print("   - Critical test: Does GLSL do BETTER?")
    print("   - If GLSL +15%: Training data matters more")
    print("   - If GLSL ±5%: Constraints are key factor")
    print("2. Measure effect size of each constraint")
    print("3. Category-specific prompt engineering")
    print("")
    print("CONDITIONAL PHASE 3:")
    print("- If ablations show improvement → Run Phase 3 optimized")
    print("- If ablations flat → Publish Phase 2 results as-is")

else:  # success_rate > 0.40
    print(f"RESULT: Strong Validation ({phase2_success_rate*100:.1f}%)")
    print(f"CONCLUSION: {(phase2_success_rate/0.20)*100:.0f}% of baseline performance!")
    print("")
    print("HYPOTHESIS VALIDATED:")
    print("- Constraint-based prompting WORKS")
    print("- 2x+ improvement is statistically significant")
    print("- Ready for publication-quality results")
    print("")
    print("Recommended Actions:")
    print("1. RUN PHASE 3 (500 problems for publication)")
    print("2. Write research paper draft")
    print("3. Optimize pipeline for production use")
    print("4. Ablations still valuable for paper:")
    print("   - Quantify contribution of each constraint")
    print("   - Compare to GLSL to prove approach generality")
    print("")
    print("DECISION: Scale to production, document findings")
```

---

## 5. Parallel Work Plan (While Validation Runs)

### Engineering Team Activities During Phase 2 (3-4 Hours)

**Validation runs are mostly automated** - engineer should context-switch to non-blocking work:

#### Task 1: Pipeline Refactoring (2-3 hours)

**Goal:** Prepare codebase for production scale

**Non-Blocking Tasks:**
```python
# File: llm_harness/pipeline.py (NEW)
"""
Refactor benchmark_harness.py into Pipeline class:
  - Cleaner separation of concerns
  - Easier to add hooks for monitoring
  - Prepares for multi-model comparison
"""

class ShaderBenchmarkPipeline:
    def __init__(self, model, problems, config):
        self.model = model
        self.problems = problems
        self.config = config

    def run(self):
        # Current benchmark_harness.py logic
        pass

    def run_with_checkpoints(self):
        # Add checkpoint/resume support
        pass

    def run_multi_model(self, models):
        # Future: Compare multiple LLMs
        pass
```

**Why Non-Blocking:**
- Creates new file, doesn't modify existing harness
- Can develop in parallel, merge after validation
- If validation fails, still useful for fixes

#### Task 2: Ablation Experiment Planning (1 hour)

**Goal:** Prepare experiment configurations based on Phase 1 results

**Pre-Work:**
```bash
# Create ablation configurations (won't run yet)
mkdir -p llm_harness/ablation_configs

# Config 1: GLSL variant (Ablation Exp 1)
cat > llm_harness/ablation_configs/glsl_variant.json <<EOF
{
  "name": "GLSL Language Swap",
  "model": "anthropic/claude-3.5-sonnet-20241022",
  "prompt_template": "prompt_template_glsl.txt",
  "shader_extension": ".glsl",
  "compiler": "shaderc",
  "expected_outcome": "If GLSL > WGSL by >10%, training data dominates"
}
EOF

# Config 2: Relaxed constraints (Ablation Exp 2)
cat > llm_harness/ablation_configs/relaxed_constraints.json <<EOF
{
  "name": "Remove Dynamic Indexing Constraint",
  "model": "anthropic/claude-3.5-sonnet-20241022",
  "prompt_template": "prompt_template_relaxed.txt",
  "constraints_removed": ["no_dynamic_arrays", "no_loops"],
  "expected_outcome": "If success drops, constraints are necessary"
}
EOF
```

**Deliverable:** Ablation configs ready to run based on Phase 2 decision tree

#### Task 3: Failure Mode Taxonomy (30 minutes)

**Goal:** Create systematic classification for errors

```python
# File: llm_harness/failure_taxonomy.py (NEW)
"""
Categorize failures for root cause analysis
"""

class FailureMode(Enum):
    COMPILE_SYNTAX_ERROR = "Compilation failed: WGSL syntax error"
    COMPILE_TYPE_ERROR = "Compilation failed: Type mismatch"
    RENDER_TIMEOUT = "Render exceeded 5min timeout"
    RENDER_GPU_ERROR = "GPU error during render pass"
    JUDGE_LOW_SCORE_MATH = "Compiled & rendered, but S1 < 30/100"
    JUDGE_LOW_SCORE_VISUAL = "Compiled & rendered, but S2 < 30/100"
    JUDGE_BLACK_SCREEN = "Rendered black/blank output"

def classify_failure(test_result):
    """
    Returns (FailureMode, explanation_string)
    """
    if not test_result['compiled']:
        # Parse error_log for syntax vs type error
        pass
    elif not test_result['rendered']:
        # Parse render_output.log for timeout vs GPU crash
        pass
    else:
        # Analyze judge scores
        pass
```

**Why Useful:**
- Enables quick triage of 100-problem results
- Identifies if failures cluster (all type errors → prompt issue)
- Guides post-validation improvements

#### Task 4: Visualization Dashboard Planning (1 hour)

**Goal:** Design interactive results viewer (implement later)

```bash
# Sketch dashboard features (don't implement yet)
cat > llm_harness/dashboard_spec.md <<EOF
# Results Dashboard Design

## Features
1. Success rate heatmap by problem category
2. Score distribution histograms (S1-S5)
3. Compilation failure word cloud (error messages)
4. Image gallery: best/worst/median renders per category
5. Performance timeline (time per problem over 100-run batch)

## Tech Stack (TBD)
- Option 1: Static HTML + Chart.js (simple, no server)
- Option 2: Streamlit (interactive, Python-native)
- Option 3: Observable Plot (modern, D3-based)

## Data Source
- Input: harness_*/results.json files
- Aggregation: Python script → dashboard_data.json
EOF
```

### Engineering Activities During Phase 3 (Optional, 15-20 Hours)

**If Phase 3 runs overnight/weekend:**

#### Long-Running Tasks
1. **Multi-Model Comparison:**
   - Run Phase 2 (100 problems) with 3 different models in parallel
   - Models: Claude Sonnet 4, OpenAI o3, Qwen3 Coder
   - Identify which models respond best to constraints

2. **Prompt Optimization Loop:**
   - A/B test prompt variations
   - Test impact of few-shot examples (0, 1, 3, 5 examples)
   - Measure effect on success rate

3. **Reference Image Library:**
   - Manually create "gold standard" renders for 20 problems
   - Implement SSIM/MSE metrics for automatic comparison
   - Validate judge scores against human ratings

4. **Documentation:**
   - Write research paper draft (Introduction, Methods, Results outline)
   - Create tutorial videos for using the benchmark
   - Document lessons learned in CLAUDE.md

---

## 6. Metrics Collection & Analysis

### Automated Metrics (Captured During Validation)

**Per-Problem Metrics (Stored in `results.json`):**
```json
{
  "problem_name": "geometric_cube",
  "model": "anthropic/claude-3.5-sonnet-20241022",
  "timestamp": "2025-10-24T21:30:00Z",
  "compilation": {
    "status": "success",
    "time_seconds": 18.3,
    "warnings": 0
  },
  "rendering": {
    "status": "success",
    "time_seconds": 7.2,
    "gpu_time_ms": 234.5
  },
  "evaluation": {
    "scores": [85, 72, 91, 67, 88],
    "total": 403,
    "time_seconds": 32.1
  },
  "failure_mode": null
}
```

**Aggregate Metrics (Generated in Report):**
```python
# Success rates
overall_success_rate = successful / total
compile_success_rate = compiled / total
render_success_rate = rendered / compiled

# Score statistics
mean_scores = [mean(S1), mean(S2), mean(S3), mean(S4), mean(S5)]
median_scores = [median(S1), ...]
stddev_scores = [std(S1), ...]

# Performance
avg_time_per_problem = mean(total_time)
p95_time = percentile(total_time, 95)

# Failure analysis
failure_counts = Counter(failure_mode for r in results)
```

### Manual Analysis Checklist (Post-Validation)

**Within 1 Hour of Completion:**
- [ ] Scan `execution_summary.log` for unexpected patterns
- [ ] Open 3 random successful renders, verify they look correct
- [ ] Open 3 random failed renders, classify failure mode
- [ ] Check if any problem category has 0% success (all fail)
- [ ] Compare Phase 2 results to Phase 1 projections (±10% expected)

**Within 1 Day of Completion:**
- [ ] Generate comparison table: WGSL current vs 20% baseline
- [ ] Create scatter plot: S1 (math) vs S2 (visual) scores
- [ ] Identify outliers: Problems that scored unexpectedly high/low
- [ ] Category breakdown: Success rate by problem difficulty tier
- [ ] Write 1-page executive summary for stakeholders

**Before Running Ablations:**
- [ ] Document "control" configuration (WGSL, current prompts)
- [ ] Archive Phase 2 results (don't overwrite with ablation runs)
- [ ] Define success criteria for ablations (what % change is meaningful?)
- [ ] Plan sample size (10 problems sufficient? or 100 again?)

---

## 7. Validation Checklist

### Pre-Flight Checks (Before Phase 1)

```bash
# Environment
[ ] Python venv activated (source venv/bin/activate)
[ ] Dependencies installed (pip list | grep aiohttp)
[ ] Rust toolchain working (cargo --version)
[ ] GPU available (cargo run in shader_harness)

# Configuration
[ ] .env file exists (OPENROUTER_API_KEY set)
[ ] prompt_template.txt present in llm_harness/
[ ] WGSL_CONSTRAINT_SPEC.md present (referenced by prompts)
[ ] 101 problems exist in ../problems/base_set/

# Disk Space
[ ] At least 5GB free (df -h .)
[ ] /tmp/ has space for shader compilation (2GB)

# Monitoring Setup
[ ] Terminal 1: Running benchmark_harness.py
[ ] Terminal 2: tail -f execution_summary.log
[ ] Terminal 3: Available for emergency diagnostics
```

### Post-Flight Checks (After Each Phase)

```bash
# Verify Outputs
[ ] harness_MODEL_TIMESTAMP/ directory exists
[ ] harness_report_*.md generated
[ ] 10 (or 100) test_*_results/ subdirectories present
[ ] Each test dir has: result.png, shader.wgsl, results.json

# Sanity Checks
[ ] No test directory is empty (0 files)
[ ] All result.png files >1KB (not blank)
[ ] results.json files parse as valid JSON
[ ] No shaders generated as .glsl (should be .wgsl)

# Error Review
[ ] Read top 5 error_log files (understand failure modes)
[ ] Check for recurring compilation errors (same issue?)
[ ] Verify judge responses parsed correctly (no [0,0,0,0,0])
```

---

## 8. Emergency Procedures

### If Validation Hangs (No Progress for 10+ Minutes)

```bash
# 1. Check if processes are alive
ps aux | grep python
ps aux | grep cargo
ps aux | grep shader-bench

# 2. Check execution_summary.log
tail -50 harness_*/logs/execution_summary.log
# Look for last "START problem_XXX" entry

# 3. Identify stuck problem
# If last log entry was "START problem_042", that's the stuck one

# 4. Kill stuck processes
pkill -9 -f shader-bench  # Kill GPU process
pkill -9 -f "cargo run"   # Kill compilation

# 5. Resume from checkpoint (if implemented)
# OR restart with --skip-completed flag
```

### If GPU Crashes (Display Driver Reset)

```bash
# 1. Verify GPU is recoverable
# Mac: Check Activity Monitor → GPU History
# Linux: nvidia-smi (should show processes)

# 2. Reduce parallelism to 1
python benchmark_harness.py --max-parallel 1 ...

# 3. Add delays between renders
# Edit test_runner.py: time.sleep(5) after each render

# 4. Check for specific problem causing crash
# Disable problem, run rest of suite
```

### If API Rate Limit Hit (429 Errors)

```bash
# 1. Check OpenRouter dashboard for usage
# https://openrouter.ai/dashboard

# 2. Add exponential backoff
# Edit llm_client.py: Increase retry_delay

# 3. Reduce parallelism (fewer concurrent API calls)
python benchmark_harness.py --max-parallel 1 ...

# 4. Switch to different model (if one is rate-limited)
--model "anthropic/claude-sonnet-4"
```

---

## Appendix A: Command Quick Reference

```bash
# Phase 1: Smoke Test (10 problems)
cd llm_harness && source venv/bin/activate
python benchmark_harness.py \
  --model "anthropic/claude-3.5-sonnet-20241022" \
  --problems geometric_cube regular_tetrahedron torus_donut_parametric \
    apollonian_gasket klein_bottle mandelbrot_set hopf_fibration \
    lorenz_attractor calabi_yau_manifold schwarzschild_black_hole \
  --max-parallel 2

# Phase 2: Full Validation (100 problems)
python benchmark_harness.py \
  --model "anthropic/claude-3.5-sonnet-20241022" \
  --problems $(ls ../problems/base_set) \
  --max-parallel 3

# Monitor live progress
tail -f harness_*/logs/execution_summary.log

# Quick stats after completion
cd harness_*
grep "SUCCESS" logs/execution_summary.log | wc -l  # Count successes
grep "FAILURE" logs/execution_summary.log | wc -l  # Count failures

# Generate report
python generate_report.py \
  --model "anthropic/claude-3.5-sonnet-20241022" \
  --output validation_results.md
```

---

## Appendix B: Success Rate Calculation Examples

**Example 1: Phase 1 Results (10 Problems)**
```
Compiled successfully: 7/10
Rendered successfully: 6/10 (1 timeout)
Average scores: [65, 58, 72, 54, 61] (avg 310/500)

Meaningful renders (avg ≥ 150): 6/10

SUCCESS RATE = 6/10 = 60%

INTERPRETATION: Strong signal, proceed to Phase 2
PROJECTION: 100-problem run should achieve 55-65%
```

**Example 2: Phase 2 Results (100 Problems)**
```
Compiled successfully: 68/100
Rendered successfully: 64/100 (4 timeouts)
Meaningful renders (avg ≥ 150): 42/100

SUCCESS RATE = 42/100 = 42%

IMPROVEMENT OVER BASELINE = (42 - 20) / 20 = 110% improvement

INTERPRETATION: Strong validation, constraints work!
DECISION: Proceed to ablations + Phase 3
```

**Example 3: Below Threshold (100 Problems)**
```
Compiled successfully: 35/100
Rendered successfully: 30/100
Meaningful renders (avg ≥ 150): 18/100

SUCCESS RATE = 18/100 = 18%

IMPROVEMENT OVER BASELINE = (18 - 20) / 20 = -10% (WORSE)

INTERPRETATION: Constraints not helping, investigate
DECISION: Abort Phase 3, run emergency diagnostics
```

---

**Document Status:** Ready for Execution
**Next Update:** After Phase 1 completion
**Owner:** CTO / Research Lead
**Related Docs:** AGENT_NOTES.md, ABLATION_EXPERIMENTS.md, TECHNICAL_DEBT.md
