# Ablation Experiment Planning

**Date**: October 24, 2025
**Purpose**: Document systematic variations for measuring impact of architectural choices
**Status**: Planning complete, ready for execution

---

## Overview

The WGSL migration creates a clean baseline for controlled experiments. Each ablation tests one variable while holding others constant.

### Baseline Configuration

- **Language**: WGSL with strict ABI contract
- **Compiler**: wgpu native WGSL loader (no translation)
- **Constraints**: Explicit types, forbidden patterns enforced
- **Validation**: LLM judge with 5-score structured evaluation (1-100 scale)
- **Output**: 1600x1600 PNG, sRGB color space
- **Success Metric**: % of problems with S1+S2+S3+S4+S5 ≥ 250/500

---

## Experiment 1: Language Swap (WGSL → GLSL)

### Hypothesis
GLSL has 20+ years of training data vs WGSL's 3 years. If training data matters more than constraints, GLSL should outperform WGSL.

### Implementation

#### Step 1: Add GLSL Compiler Support

**File**: `shader_harness/Cargo.toml`
```diff
[dependencies]
wgpu        = "0.20"
pollster    = "0.3"
bytemuck   = "1.0"
futures-intrusive = "0.5"
image       = { version = "0.25", default-features = false, features = ["png"] }
clap        = { version = "4.5", features = ["derive"] }
+ shaderc    = "0.8"  # GLSL → SPIR-V compiler
```

**File**: `shader_harness/src/main.rs:42-44`
```diff
+ use shaderc::{Compiler, ShaderKind};
+
fn main() {
    let shader_code = fs::read_to_string(&opts.shader).expect("failed to read shader file");
+
+   // Detect file extension to choose compilation path
+   let source = if opts.shader.extension().map_or(false, |ext| ext == "glsl") {
+       // Compile GLSL to SPIR-V
+       let mut compiler = Compiler::new().expect("Failed to create GLSL compiler");
+       let spirv = compiler.compile_into_spirv(
+           &shader_code,
+           ShaderKind::Fragment,  // Assume fragment shader
+           "shader.glsl",
+           "main",
+           None
+       ).expect("GLSL compilation failed");
+       wgpu::ShaderSource::SpirV(Cow::Owned(spirv.as_binary().to_vec()))
+   } else {
+       // Native WGSL
-       wgpu::ShaderSource::Wgsl(Cow::Owned(shader_code))
+       wgpu::ShaderSource::Wgsl(Cow::Owned(shader_code))
+   };

    let shader = device.create_shader_module(wgpu::ShaderModuleDescriptor {
        label: Some("user_shader"),
-       source: wgpu::ShaderSource::Wgsl(Cow::Owned(shader_code)),
+       source,
    });
}
```

**Lines changed**: 3-4 in Cargo.toml, 10-15 in main.rs

#### Step 2: Create GLSL Prompt Template

**File**: `llm_harness/prompt_template_glsl.txt` (new file)
```glsl
🎨 SHADERTOY GLSL FORMAT - STANDARD SPECIFICATION
==================================================

You MUST generate valid GLSL code compatible with Shadertoy.

ENTRY POINT (DO NOT MODIFY):
---------------------------------------------
void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    // Your fragment logic here
    // MUST set fragColor = vec4(r, g, b, a)
}

AVAILABLE UNIFORMS:
---------------------------------------------
uniform vec2 iResolution;   // Viewport resolution (in pixels)
uniform float iTime;        // Shader playback time (in seconds)
// Note: iTime not yet supported in harness, will be 0.0

TYPE REQUIREMENTS:
---------------------------------------------
- Use standard GLSL types: vec2, vec3, vec4, float, int
- No explicit type suffixes needed (unlike WGSL)
- Implicit type conversions allowed

COMMON PATTERNS:
---------------------------------------------
// Normalize coordinates
vec2 uv = fragCoord / iResolution.xy;

// Distance calculations
float d = length(uv - vec2(0.5));

// Output color
fragColor = vec4(color, 1.0);

OUTPUT FORMAT:
---------------------------------------------
<shader file="shader.glsl">
void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    fragColor = vec4(uv, 0.5, 1.0);
}
</shader>
```

**Lines changed**: 0 (new file), ~60 lines

#### Step 3: Update LLM Client

**File**: `llm_harness/llm_client.py:94-103`
```diff
def _format_prompt_template(self, problem_prompt: str, shader_harness_example: str, language: str = "wgsl") -> str:
    """Load and format the prompt template with the problem and example"""
+   template_file = f"prompt_template_{language}.txt" if language != "wgsl" else "prompt_template.txt"
    try:
-       with open("prompt_template.txt", 'r') as f:
+       with open(template_file, 'r') as f:
            template = f.read()

        template = template.replace("{problem_prompt}", problem_prompt)
        template = template.replace("{shader_harness_example}", shader_harness_example)
        return template
```

**Lines changed**: 2-3

#### Step 4: Update Shader Parser

**File**: `llm_harness/shader_parser.py:16-40`
```diff
def parse_response(self, llm_response: str) -> tuple[Dict[str, str], str]:
    """Parse LLM response to extract shader files"""
    shaders = {}

    # Extract shader blocks
    shader_pattern = r'<shader file="([^"]+)">(.*?)</shader>'
    matches = re.findall(shader_pattern, llm_response, re.DOTALL)

    for filename, content in matches:
        shaders[filename] = content.strip()
+
+       # For GLSL, wrap mainImage in full-screen quad vertex shader
+       if filename.endswith('.glsl'):
+           shaders[filename] = self._wrap_glsl_fragment(content.strip())

    return shaders, ""  # No main.rs modifications needed
+
+ def _wrap_glsl_fragment(self, fragment_code: str) -> str:
+     """Wrap Shadertoy fragment in full shader"""
+     return f"""
+ #version 450
+
+ layout(location = 0) in vec2 fragCoord;
+ layout(location = 0) out vec4 fragColor;
+
+ uniform vec2 iResolution;
+ uniform float iTime;
+
+ {fragment_code}
+
+ void main() {{
+     mainImage(fragColor, fragCoord * iResolution);
+ }}
+ """
```

**Lines changed**: 5-6 + 15-30 new method

### Execution

```bash
cd llm_harness

# Run WGSL baseline (10 problems)
python benchmark_harness.py \
  --model "anthropic/claude-3.5-sonnet-20241022" \
  --problems geometric_cube sphere_wireframe torus_knot rotating_cube mandelbrot_set \
            julia_set sierpinski_triangle koch_snowflake dragon_curve hilbert_curve \
  --max-parallel 2 \
  --language wgsl

# Run GLSL variant (same 10 problems)
python benchmark_harness.py \
  --model "anthropic/claude-3.5-sonnet-20241022" \
  --problems geometric_cube sphere_wireframe torus_knot rotating_cube mandelbrot_set \
            julia_set sierpinski_triangle koch_snowflake dragon_curve hilbert_curve \
  --max-parallel 2 \
  --language glsl

# Compare results
python analyze_results.py --compare wgsl vs glsl
```

### Expected Results

| Metric | WGSL Baseline | GLSL Variant | Interpretation |
|--------|---------------|--------------|----------------|
| Success rate | 50-70% | ? | If GLSL > WGSL: Training data wins |
| Avg score | 250-350/500 | ? | If GLSL ≈ WGSL: Constraints work |
| Compile time | 2-3s | 3-5s | GLSL adds shaderc overhead |

**Estimated effort**: 4-6 hours (implementation + testing)

---

## Experiment 2: Constraint Tightness

### Hypothesis
Explicit type constraints reduce LLM errors. Relaxing constraints should decrease success rate.

### Implementation

#### Variant A: Relaxed Types (Allow Implicit Conversions)

**File**: `llm_harness/prompt_template_relaxed.txt`
```diff
TYPE REQUIREMENTS:
---------------------------------------------
- Use explicit types: vec2<f32>, vec3<f32>, vec4<f32>, NOT vec2, vec3, vec4
- Use i32, u32, f32 for scalars (NOT int, uint, float)
- NO implicit type conversions
+ ✅ RELAXED: Implicit conversions allowed
+ ✅ RELAXED: Type inference permitted for local variables
- Array indexing ONLY with integer expressions: array[u32(expr)]
+ ✅ RELAXED: Array indexing with any integer type
```

**Lines changed**: 3-5 in prompt template

#### Variant B: Ultra-Strict (Forbid Dynamic Loops)

**File**: `llm_harness/prompt_template_strict.txt`
```diff
SYNTAX YOU MUST NOT USE:
---------------------------------------------
❌ @vertex, @fragment in function bodies (only as attributes)
❌ var without address space (e.g., var x: f32; is WRONG)
❌ Implicit casts (e.g., f32(1) where 1 is i32)
❌ gl_* variables
❌ #ifdef, #define, or any preprocessor
❌ uniform keyword (use @group/@binding instead)
+ ❌ Dynamic loops (loop bounds must be compile-time constants)
+ ❌ Dynamic array indexing (array[i] where i is runtime variable)
+ ❌ Conditionals based on uniforms (if statements on time/resolution)
```

**Lines changed**: 3 additional restrictions

### Execution

```bash
# Baseline (current constraints)
python benchmark_harness.py --problems {10_problems} --constraint-level standard

# Relaxed constraints
python benchmark_harness.py --problems {10_problems} --constraint-level relaxed

# Ultra-strict constraints
python benchmark_harness.py --problems {10_problems} --constraint-level strict
```

### Expected Results

| Constraint Level | Success Rate | Avg Compile Errors |
|------------------|--------------|---------------------|
| Relaxed | 40-60% (↓) | 0.5/problem |
| Standard (baseline) | 50-70% | 0.3/problem |
| Strict | 30-50% (↓) | 0.2/problem |

**Interpretation**:
- If Relaxed < Standard: Explicit constraints prevent errors
- If Strict < Standard: Over-constraining limits LLM expressiveness

**Estimated effort**: 2-3 hours (edit prompts, run tests)

---

## Experiment 3: Output Format Variations

### Hypothesis
Higher resolution improves visual quality scores (S2, S4) but doesn't affect mathematical accuracy (S1, S3).

### Implementation

#### Variant A: Resolution Scaling

**File**: `shader_harness/src/main.rs:15-16`
```diff
#[arg(short = 'z', long, default_value_t = 1024)]
- size: u32,
+ size: u32,  // Now configurable via CLI

# Test configurations:
# - Low: 512x512 (faster, lower quality)
# - Medium: 1600x1600 (baseline)
# - High: 4096x4096 (slower, higher quality)
```

**Lines changed**: 0 (already configurable via --size flag)

#### Variant B: HDR vs LDR

**File**: `shader_harness/src/main.rs:69`
```diff
fragment: Some(wgpu::FragmentState {
    module: &shader,
    entry_point: "fs_main",
    targets: &[Some(wgpu::ColorTargetState {
-       format: wgpu::TextureFormat::Rgba8UnormSrgb,
+       format: wgpu::TextureFormat::Rgba16Float,  // HDR mode
        blend: None,
        write_mask: wgpu::ColorWrites::ALL,
    })],
```

**Lines changed**: 1

### Execution

```bash
# Low resolution (512x512)
python benchmark_harness.py --problems {10_problems} --size 512

# Medium resolution (1600x1600) - baseline
python benchmark_harness.py --problems {10_problems} --size 1600

# High resolution (4096x4096)
python benchmark_harness.py --problems {10_problems} --size 4096

# HDR format (requires format flag)
python benchmark_harness.py --problems {10_problems} --format hdr
```

### Expected Results

| Configuration | S1 (Math) | S2 (Visual) | Render Time |
|---------------|-----------|-------------|-------------|
| 512x512 LDR | 75±10 | 60±15 | 0.5s |
| 1600x1600 LDR (baseline) | 75±10 | 75±12 | 2.0s |
| 4096x4096 LDR | 75±10 | 85±10 | 15s |
| 1600x1600 HDR | 75±10 | 78±12 | 2.5s |

**Interpretation**:
- S1 invariant to resolution: Math accuracy is independent of pixels
- S2 scales with resolution: Visual quality improves with detail
- HDR minimal impact: Most problems don't need extended range

**Estimated effort**: 1-2 hours (run tests, analyze)

---

## Experiment 4: Validator Strategy

### Hypothesis
LLM judges are biased by visual aesthetics. Metric-based validation provides objective ground truth.

### Implementation

#### Variant A: Reference Image Comparison (SSIM)

**File**: `llm_harness/metric_validator.py` (new file)
```python
from skimage.metrics import structural_similarity as ssim
from PIL import Image
import numpy as np

class MetricValidator:
    def evaluate_ssim(self, reference_path, result_path):
        """Compute structural similarity between images"""
        ref = np.array(Image.open(reference_path).convert('RGB'))
        res = np.array(Image.open(result_path).convert('RGB'))

        # Compute SSIM per channel
        score = ssim(ref, res, channel_axis=2, data_range=255)
        return score * 100  # Convert to 0-100 scale

    def evaluate_mse(self, reference_path, result_path):
        """Compute mean squared error"""
        ref = np.array(Image.open(reference_path).convert('RGB'))
        res = np.array(Image.open(result_path).convert('RGB'))

        mse = np.mean((ref.astype(float) - res.astype(float)) ** 2)
        # Invert and scale: lower MSE = higher score
        return max(0, 100 - (mse / 100))
```

**Lines changed**: 0 (new file), ~30 lines

**File**: `llm_harness/judge.py:add method`
```diff
+ from metric_validator import MetricValidator
+
class Judge:
+   def evaluate_with_metrics(self, reference_image, result_image):
+       """Use image metrics instead of LLM evaluation"""
+       validator = MetricValidator()
+       ssim_score = validator.evaluate_ssim(reference_image, result_image)
+       mse_score = validator.evaluate_mse(reference_image, result_image)
+
+       # Map to 5-score format (treat as visual quality only)
+       return [
+           0,  # S1: Math accuracy (metrics can't evaluate)
+           ssim_score,  # S2: Visual quality (structural similarity)
+           0,  # S3: Problem-specific (metrics can't evaluate)
+           mse_score,  # S4: Visual implementation (pixel accuracy)
+           0   # S5: Completeness (metrics can't evaluate)
+       ]
```

**Lines changed**: 15-20

### Execution

```bash
# First, generate reference images with human-verified shaders
cd shader_harness
for problem in geometric_cube sphere_wireframe torus_knot; do
    cargo run -- --shader reference/$problem.wgsl --output reference/$problem.png
done

# Run LLM judge (baseline)
python benchmark_harness.py --problems geometric_cube sphere_wireframe torus_knot --validator llm

# Run metric validator
python benchmark_harness.py --problems geometric_cube sphere_wireframe torus_knot --validator metrics

# Compare
python analyze_results.py --compare llm vs metrics
```

### Expected Results

| Validator | S1 | S2 | S3 | S4 | S5 | Total |
|-----------|----|----|----|----|----|----|
| LLM Judge | 75 | 70 | 68 | 72 | 80 | 365/500 |
| SSIM Metric | 0 | 85 | 0 | 80 | 0 | 165/500 |

**Interpretation**:
- Metrics provide objective S2/S4 scores
- LLM judges necessary for S1/S3/S5 (semantic understanding)
- Hybrid approach: Metrics for visual, LLM for math/completeness

**Estimated effort**: 4-6 hours (implement metrics, create references, test)

---

## Experiment 5: Prompt Engineering

### Hypothesis
Few-shot examples improve LLM output quality more than constraint specification.

### Implementation

#### Variant A: Zero-Shot (Constraints Only)

**File**: `llm_harness/prompt_template_zeroshot.txt`
```diff
REFERENCE EXAMPLES:
---------------------------------------------
- {shader_harness_example}
+ (no examples provided)
```

**Lines changed**: Remove example injection

#### Variant B: Few-Shot (3 Examples)

**File**: `llm_harness/prompt_template_fewshot.txt`
```diff
REFERENCE EXAMPLES:
---------------------------------------------
+ Example 1: Geometric Cube (Simple)
+ <shader file="cube.wgsl">
+ [full working shader code]
+ </shader>
+
+ Example 2: Mandelbrot Set (Mathematical)
+ <shader file="mandelbrot.wgsl">
+ [full working shader code]
+ </shader>
+
+ Example 3: Sphere Wireframe (Raymarching)
+ <shader file="sphere.wgsl">
+ [full working shader code]
+ </shader>
```

**Lines changed**: Add 3 complete examples (~200 lines)

### Execution

```bash
# Zero-shot (constraints only)
python benchmark_harness.py --problems {20_problems} --prompt-style zeroshot

# One-shot (current: main.rs reference)
python benchmark_harness.py --problems {20_problems} --prompt-style oneshot

# Few-shot (3 examples)
python benchmark_harness.py --problems {20_problems} --prompt-style fewshot
```

### Expected Results

| Prompt Style | Success Rate | Avg Score | Token Usage |
|--------------|--------------|-----------|-------------|
| Zero-shot | 30-50% | 200/500 | 2K tokens |
| One-shot (baseline) | 50-70% | 300/500 | 4K tokens |
| Few-shot | 60-80% | 350/500 | 8K tokens |

**Interpretation**:
- Examples improve success at cost of token usage
- Diminishing returns after 1-2 examples
- Constraints necessary baseline, examples enhance

**Estimated effort**: 3-4 hours (curate examples, test)

---

## Experimental Protocol

### Standard Procedure for All Ablations

1. **Select test set**: 10-20 problems spanning difficulty levels
   - Easy: geometric_cube, sphere_wireframe
   - Medium: mandelbrot_set, julia_set, torus_knot
   - Hard: hopf_fibration_4d, klein_bottle, fractal_loxodromic

2. **Run baseline**: Execute with standard configuration
   - Record: success rate, scores, compile/render times
   - Save: results.json, logs, generated code

3. **Run variant**: Change ONE variable, keep others constant
   - Use SAME test set and SAME model
   - Same random seed (if applicable)

4. **Compare metrics**:
   - Success rate (% with total score ≥ 250/500)
   - Score breakdown (S1, S2, S3, S4, S5 averages)
   - Performance (compile time, render time)
   - Error patterns (syntax, runtime, validation)

5. **Document findings**:
   - What changed? (code diffs)
   - Why did it change? (hypothesis validation)
   - Should we adopt it? (recommendation)

### Reproducibility Checklist

- [ ] Fixed test problem set (same problems for all experiments)
- [ ] Fixed model version (e.g., claude-3.5-sonnet-20241022)
- [ ] Fixed random seed (if LLM supports it)
- [ ] Same judge model for all evaluations
- [ ] Same hardware (GPU can affect render times)
- [ ] Documented environment (Python version, Rust version, OS)

---

## Combined Experiments (Interaction Effects)

### Experiment 6: GLSL + Relaxed Constraints
Test if GLSL's training data allows relaxed constraints to work.

**Expected**: GLSL benefits less from constraints than WGSL (more robust to ambiguity)

### Experiment 7: High Resolution + HDR + Metrics
Test if metric validation works better at high fidelity.

**Expected**: SSIM scores increase with resolution, HDR has minimal effect

### Experiment 8: Few-Shot + Strict Constraints
Test if examples compensate for over-strict constraints.

**Expected**: Examples reduce impact of strict constraints (LLM learns patterns)

**Estimated effort per combined experiment**: 2-3 hours

---

## Priority Order (Impact vs Effort)

| Rank | Experiment | Impact | Effort | ROI |
|------|------------|--------|--------|-----|
| 1 | Language Swap (WGSL → GLSL) | High | 6h | Critical baseline |
| 2 | Constraint Tightness | High | 3h | Validates core hypothesis |
| 3 | Prompt Engineering | Medium | 4h | Practical improvement |
| 4 | Output Format | Low | 2h | Quick win |
| 5 | Validator Strategy | Medium | 6h | Long-term infrastructure |

**Recommended sequence**: 1 → 2 → 3 (validates migration), then 4 → 5 (optimizes pipeline)

---

## Budget and Timeline

### Compute Resources

- **LLM API costs**: ~$0.50/problem × 100 problems × 5 experiments = $250
- **GPU time**: Negligible (renders take 2-3s each)
- **Storage**: ~500MB per experiment (code + images + logs)

### Time Estimates

| Phase | Duration | Deliverable |
|-------|----------|-------------|
| Experiment 1 (Language) | 1 day | WGSL vs GLSL comparison |
| Experiment 2 (Constraints) | 0.5 day | Constraint impact analysis |
| Experiment 3 (Output) | 0.5 day | Resolution/format study |
| Experiment 4 (Validator) | 1 day | Metric vs LLM comparison |
| Experiment 5 (Prompts) | 0.5 day | Few-shot analysis |
| Analysis & writeup | 0.5 day | Final ablation report |
| **Total** | **4 days** | **Complete ablation study** |

---

## Success Criteria

An experiment is considered successful if:

1. **Reproducible**: Can re-run and get similar results (±5% variance)
2. **Measurable**: Clear numeric difference in at least one metric
3. **Interpretable**: Can explain why the difference occurred
4. **Actionable**: Provides clear recommendation (adopt, reject, investigate further)

---

**Last Updated**: October 24, 2025
**Status**: Ready for execution pending validation of baseline
**Related Docs**: AGENT_NOTES.md, TECHNICAL_DEBT.md, WGSL_CONSTRAINT_SPEC.md
