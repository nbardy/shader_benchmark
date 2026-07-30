# LLM Shader Harness — Evaluation Pipeline

Automated pipeline for testing LLM shader generation capabilities with isolated execution, WGPU rendering, and multi-criteria evaluation.

## Core Features

- **Isolated Test Execution** — UUID-stamped directories prevent result contamination
- **Multi-Problem Orchestration** — Batch evaluation with consolidated reporting
- **WGSL Compilation** — Full WGPU 0.20 pipeline with Rust shader harness
- **Structured Evaluation** — GPT-4o judge with 5-category scoring (500-point scale)
- **Extensible Architecture** — Template-based evaluation system for custom rubrics

## Architecture

### Execution Pipeline
```
Problem Spec → LLM Generation → Shader Compilation → Rendering → Evaluation → Report
    ↓               ↓                  ↓                  ↓            ↓          ↓
request.txt   llm_client.py      shader_harness/    WGPU 0.20    judge.py   MD/JSON
critic.txt   (OpenRouter API)    (Rust + WGSL)      (PNG out)    (GPT-4o)   outputs
```

### Module Responsibilities

| Module | Purpose |
|--------|---------|
| `main.py` | Single-problem CLI with isolated test directories |
| `benchmark_harness.py` | Multi-problem orchestration with batch reporting |
| `debug_logger.py` | Thread-safe logging with immediate flush for parallel execution |
| `judge.py` | GPT-4o evaluation via structured rubric templates |
| `test_runner.py` | Subprocess management for WGPU shader execution |
| `llm_client.py` | OpenRouter API interface with async HTTP |
| `generate_report.py` | Markdown report generation with embedded results |
| `critic_template.py` | Structured rubric parser (3-section format) |
| `shader_parser.py` | XML extraction from LLM responses |
| `prompt_loader.py` | Problem specification file loader |

## Setup

### Installation
```bash
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt  # aiohttp, python-dotenv, requests
echo "OPENROUTER_API_KEY=sk-or-v1-..." > .env
```

### Prerequisites
- **Python 3.11+** with `venv` module
- **Rust/Cargo** in `$PATH` (for WGSL shader compilation subprocess)
- **Playwright + Chromium** (for Shadertoy shader execution - see below)
- **OpenRouter API key** with model access

### Shadertoy Runtime Setup (Optional)

To use Shadertoy-format shaders (GLSL with `mainImage` entrypoint):

```bash
# Install Playwright library
pip install playwright

# Install Chromium browser driver
python -m playwright install chromium

# Test Shadertoy runtime
python shadertoy_runtime.py
```

**Why Shadertoy?**
- **50K+ training examples** on shadertoy.com provide extensive LLM training data
- **Simpler syntax** than WGSL (implicit types, variable array indexing)
- **Web-based execution** via WebGL (no Rust compilation required)
- **Multi-buffer support** for feedback loops and complex effects

**Dependencies:**
- `playwright` - Async browser automation library
- Chromium browser driver (200MB download)

**Usage:**
```bash
python benchmark_harness.py \
  --model "anthropic/claude-3.5-sonnet-20241022" \
  --language shadertoy \
  --problems geometric_cube
```

## Supported Shader Languages

The benchmark supports multiple shader language specifications for ablation experiments:

| Language | File Extension | Runtime | Training Data | Status |
|----------|---------------|---------|---------------|--------|
| **WGSL** | `.wgsl` | WGPU/Rust harness | Limited (new spec) | Production |
| **Shadertoy** | `.glsl` | WebGL/Playwright | 50K+ examples | Production |
| **GLSL** | `.glsl` | WGPU/Rust harness | Extensive | Future |
| **HLSL Unity** | `.hlsl` | Metal/Swift harness | Extensive | Future |

**Language Selection:**
```bash
# WGSL (default) - Modern WebGPU standard
python benchmark_harness.py --language wgsl --model MODEL --problems PROBLEMS

# Shadertoy - Leverage 50K+ training examples
python benchmark_harness.py --language shadertoy --model MODEL --problems PROBLEMS

# GLSL - Traditional OpenGL shaders
python benchmark_harness.py --language glsl --model MODEL --problems PROBLEMS
```

**Architecture:**
- `language_specs.py` - Abstract interface for language specifications
- Each spec defines: constraint prompts, syntax validators, reference examples
- Test runner routes to appropriate backend (WGPU, WebGL, Metal)

## Usage

### Single Problem Evaluation
```bash
source venv/bin/activate
python main.py \
  --model "anthropic/claude-3.5-sonnet-20241022" \
  --prompt-folder "../problems/base_set/geometric_cube"
```

**Generates:** `test_YYYYMMDD_HHMMSS_UUID_results/` containing:
- `result.png` — 1600×1600 rendered output
- `shader.wgsl` — Generated WGSL code
- `results.json` — 5-category scores
- `current_results_report.md` — Individual test report

### Multi-Problem Benchmark
```bash
source venv/bin/activate
python benchmark_harness.py \
  --model "anthropic/claude-3.5-sonnet-20241022" \
  --problems geometric_cube mandelbrot_set klein_bottle
```

**Generates:** `benchmark_run_output/UUID_MODEL_TIMESTAMP/benchmark_report.md` with aggregate analysis

### ChatGPT + Shader Harness prompt experiment

These launchers use the same generator model, compiler, renderer, and judges as
the baseline. They change only the recorded generation prompt profile.
`scratchpad_shader_harness.py` adds the technical design brief;
`chatgpt_shader_harness.py` adds the separate art-direction guide before that
brief.

```bash
python chatgpt_shader_harness.py \
  --model "cli/codex:gpt-5.6-sol:medium" \
  --judge-model "cli/codex:gpt-5.5:high" \
  --problems reproduce_image_andrew_pons \
  --max-parallel 1 \
  --new
```

Equivalent advanced usage:

```bash
python benchmark_harness.py \
  --prompt-profile chatgpt-shader-harness-v1 \
  --model "cli/codex:gpt-5.6-sol:medium" \
  --problems reproduce_image_andrew_pons
```

The profile is stored in `config.json` and included in new run directory names,
preventing auto-resume from mixing profile and baseline generations.

For a controlled three-arm prompt ablation, use the same model, problems, and
judge with:

1. `baseline` — original shader prompt only.
2. `scratchpad-v1` — public technical production plan, then WGSL.
3. `scratchpad-art-direction-v1` — a separate
   `<artistic_subtleties_and_elegance>` guide, the same technical plan, then
   WGSL. The art guide focuses on emotional hierarchy and controlled departures
   from mathematically perfect repetition.

```bash
python benchmark_harness.py --prompt-profile baseline ...
python benchmark_harness.py --prompt-profile scratchpad-v1 ...
python benchmark_harness.py --prompt-profile scratchpad-art-direction-v1 ...
```

### Ambitious true-3D profile

`ambitious-3d-v1` makes genuine 3D the default for volumetric subjects. It
requires a 3D camera ray, ray-marched or analytic geometry, computed normals,
depth-aware lighting and occlusion, and a bounded performance budget. The
primary subject cannot fall back to layered 2.5D merely because full-detail 3D
would be expensive; the model must simplify the 3D scene instead.

```bash
python ambitious_3d_shader_harness.py \
  --model "cli/codex:gpt-5.6-sol:medium" \
  --judge-model "cli/codex:gpt-5.5:high" \
  --problems reproduce_image_andrew_pons \
  --max-parallel 1 \
  --new
```

### Domain-expert profile

`domain-expert-v1` combines the strongest art-direction and true-3D guidance
with three production-shader disciplines that the parrot ablation exposed:

- object-level spatial cells using `floor`/`fract`, neighbor searches, stable
  per-instance hashes, clustered occupancy, and bounded repetition of geometry
  rather than wallpaper-like texture stamps;
- a named palette ladder and commented color helpers that preserve deliberate
  hue, value, chroma, temperature, and area relationships;
- material-specific normals, albedo, roughness/specular response, Fresnel,
  shadow/occlusion, and lighting so procedural detail changes the surface
  response instead of decorating a uniformly shiny primitive.

The profile also asks for IQ-inspired production architecture—coarse bounds,
hybrid analytic/ray-marched geometry, multi-scale fields, and explicit work
budgets—without importing the reference kernel or any external textures.

```bash
python domain_expert_shader_harness.py \
  --model "cli/codex:gpt-5.6-sol:medium" \
  --judge-model "cli/codex:gpt-5.5:high" \
  --problems reproduce_image_andrew_pons \
  --max-parallel 1 \
  --new
```

It can also be combined with the N-round harness:

```bash
python iterative_shader_harness.py \
  --model "cli/codex:gpt-5.6-sol:medium" \
  --judge-model "cli/codex:gpt-5.5:high" \
  --prompt-profile domain-expert-v1 \
  --problems reproduce_image_andrew_pons \
  --rounds 3
```

To append the profile to an existing matrix without regenerating completed
arms:

```bash
python prompt_matrix_harness.py \
  --resume EXISTING_MATRIX_RUN_ID \
  --profiles domain-expert-v1 \
  --max-parallel 3
```

The sequential IQ-inspired development profiles are also available for focused
experiments:

| Profile | Measured intervention |
|---|---|
| `domain-expert-v2` | Lean, mechanically verifiable true-3D gate |
| `domain-expert-v3` | Surface-flow plumage plus sparse hero feathers |
| `domain-expert-v4` | Multi-scale plumage geometry/material coupling |
| `domain-expert-v5` | Exact parent-shell containment and designed variation |

These are development treatments, not a claimed quality ladder. On the parrot
run, v3 had the highest final judge score of the four while none achieved the
desired human visual bar. See
`research/parrot_prompt_ablation_blog_notes_2026-07-30.md` for the trajectories
and visual findings.

### N-round visual revision harness

The iterative harness generates a complete shader, renders and judges it, then
supplies the next round with:

- the actual executed WGSL, including any mechanical WGSL repairs;
- a labeled contact sheet containing the target reference and current render;
- any render failure that must be fixed;
- an explicit requirement to return a complete replacement shader.

Every round is stored separately and scored, so progression is visible and an
interrupted run can resume.

```bash
python iterative_shader_harness.py \
  --model "cli/codex:gpt-5.6-sol:medium" \
  --judge-model "cli/codex:gpt-5.5:high" \
  --prompt-profile ambitious-3d-v1 \
  --problems reproduce_image_andrew_pons \
  --rounds 3
```

Resume or extend a run:

```bash
python iterative_shader_harness.py \
  --resume RUN_DIRECTORY_NAME \
  --rounds 5
```

`--prompt-profile` works with every iterative run, including `baseline`, so
the prompt-profile effect and the visual-revision effect can be measured
independently.

### Persistent agent render-tool harness

`agentic_shader_harness.py` is a different experiment from the N-round
orchestrator. It gives one persistent Codex session four fixed-path MCP tools:

- `write_shader` replaces the complete working WGSL file;
- `render_shader` compiles it with a `study` or `final` stage and returns the
  actual PNG image plus compiler feedback;
- `record_study` records visible comparison evidence, the selected A–F atlas
  cell, and the implementation details that must carry into the final scene;
- `submit_final` freezes the current revision, but only if that exact revision
  rendered successfully.

The model decides when to edit, render again, or finish. A server-side
`--render-budget` is enforced even when compilation fails. The tool server
never accepts a path, so it cannot use the tools to inspect other benchmark
runs, judges, or contestants. Codex itself runs in a fresh temporary directory
with user config and repository rules disabled and a read-only sandbox.

```bash
python agentic_shader_harness.py \
  --model "cli/codex:gpt-5.6-sol:medium" \
  --problem reproduce_image_andrew_pons \
  --prompt-profile baseline \
  --render-budget 3 \
  --min-successful-revisions 2 \
  --judge-model "cli/codex:gpt-5.5:high"
```

This costs one persistent model call with up to three tool renders, unlike
`iterative_shader_harness.py --rounds 3`, which costs three independent model
calls. Each run saves `agent_trace.jsonl`, every shader revision, every render
and compiler log, `submission.json`, and a visual HTML report. A response that
does not call `submit_final` is a failed run.

The optional `sketchbook-3x2-v1` workflow makes component exploration
mechanical instead of advisory. Before any final-scene render, the agent must:

1. choose three subject-specific, high-risk core elements;
2. render each as a 3×2 atlas of six materially different variants;
3. inspect the atlas and record the winning A–F cell with visible evidence;
4. name the functions, coordinate frame, parameters, and aesthetic properties
   that must be reused in the final shader.

The three studies normally cover macro silhouette/scene architecture, a
signature meso-scale shape plus its surface-following distribution, and
material/palette/light response. These are roles, not hardcoded subjects, so
the same workflow can study feathers, foliage, clouds, lettering, plotted
marks, architectural modules, or abstract motifs. Placement studies explicitly
compare parent-surface frames, curvature-following orientation, overlap,
low-frequency fBm/domain warp, correlated jitter, density drift, and sparse
exceptions. Noise must modulate designed structure rather than replace it.

```bash
python agentic_shader_harness.py \
  --model "cli/codex:gpt-5.6-sol:medium" \
  --problem reproduce_image_andrew_pons \
  --prompt-profile domain-expert-v5 \
  --workflow sketchbook-3x2-v1 \
  --render-budget 10 \
  --min-successful-revisions 2 \
  --judge-model "cli/codex:gpt-5.5:high"
```

The server rejects final renders until all three studies are successfully
rendered and recorded. Study renders do not count toward
`--min-successful-revisions`, and only final-stage renders are sent to the
benchmark judge.

Four stricter workflows isolate failures found by the first parrot trial:

- `sketchbook-curved-elements-v2` separates the individual signature-element
  shape study from its parent-surface placement study, runs studies in order,
  and requires an explicit A–F construction inventory.
- `sketchbook-continuous-elements-v3` additionally forbids building one organic
  element from a smooth-unioned chain of spheres, ellipsoids, or capsules. It
  supplies an inverse-bend implicit-profile scaffold with independent
  centerline, width, thickness, camber, shoulder, and taper functions.
- `sketchbook-progressive-application-v4` requires four dependent studies:
  primitive, assembly/sheet, parent-surface integration, and relationships at
  seams/layer transitions. Every study needs a broad A–F pass and a second
  refinement pass before it can be recorded. Each render must predeclare its
  six constructions, and a local 3×2 cell-difference check rejects visually
  near-duplicate atlases even when they compile.
- `sketchbook-hierarchical-wide-search-v5` starts from a rooted dependency
  graph and requires six studies: scaffold, primary volume, attached form,
  local element, overlapping sheet, and hierarchical integration. Each study
  renders two disjoint six-family surveys and one six-family synthesis—18
  candidates per topic. The server validates structured A–F manifests and
  rejects both internally uniform atlases and whole-atlas reuse across passes
  or study topics.

V5 is the strongest process experiment for repeated detail attached through a
geometry hierarchy. It is generic: body→wing→feather can become
trunk→branch→leaf, building frame→facade→panel, terrain→riverbed→water detail,
or curve→transported mark.

```bash
python agentic_shader_harness.py \
  --model "cli/codex:gpt-5.6-sol:medium" \
  --problem reproduce_image_andrew_pons \
  --prompt-profile domain-expert-v2 \
  --workflow sketchbook-hierarchical-wide-search-v5 \
  --render-budget 28 \
  --min-successful-revisions 2 \
  --judge-model "cli/codex:gpt-5.5:high"
```

The diversity check is deliberately a cheap local guard, not a semantic judge.
It detects low pixel separation between atlas cells; the predeclared A–F
manifest and recorded comparison make the intended conceptual differences
auditable. V5 additionally checks whole-atlas separation from every accepted
pass and prior topic, preventing a model from relabeling one reusable atlas.
Passing these gates does not prove that variants are artistically good, nor
that the final shader preserved their full density and fidelity.

The loop strategy is independently selectable:

- `latest-v1` reproduces the original experiment: target + immediately prior
  render, plus the latest executed shader.
- `history-critique-v2` supplies a score-blind history sheet containing the
  target and up to four prior renders. It still carries only the latest
  executed shader, then requires a compact `<revision_critique>` identifying
  the strongest prior round, features to preserve, at most three concrete
  changes, and regression checks before the replacement shader.
- `history-code-critique-v3` keeps that visual/critique contract and also
  supplies up to three exact prior executed shaders. If an older render is
  stronger, the model can branch from its actual implementation instead of
  trying to reconstruct it from the newest code.

```bash
python iterative_shader_harness.py \
  --model "cli/codex:gpt-5.6-sol:medium" \
  --judge-model "cli/codex:gpt-5.5:high" \
  --prompt-profile baseline \
  --loop-strategy history-critique-v2 \
  --problems reproduce_image_andrew_pons \
  --rounds 3
```

Judge scores and prose are deliberately excluded from the generation loop.
This keeps `history-critique-v2` a self-critique treatment instead of allowing
the generator to optimize against its grader.

### Repeated prompt-ablation matrix

`prompt_matrix_harness.py` separates independent stochastic repeats from
visual revision rounds:

- a **trial** starts a fresh CLI/model session and creates a fresh round-1
  shader;
- a **round** is a dependent rewrite that receives the prior shader and a
  target-vs-current contact sheet.

The default matrix includes baseline, scratchpad, scratchpad + art direction,
scratchpad + ambitious 3D, and scratchpad + art direction + ambitious 3D:

```bash
python prompt_matrix_harness.py \
  --model "cli/codex:gpt-5.6-sol:medium" \
  --problems reproduce_image_andrew_pons \
  --trials 3 \
  --rounds 3 \
  --max-parallel 3 \
  --judge-model "cli/codex:gpt-5.5:high"
```

That command performs `5 profiles × 3 trials × 3 rounds = 45` generations.
Every child run is independently resumable. The matrix report shows each
round trajectory plus final-round and best-round mean ± sample standard
deviation.

### Local-context isolation

CLI generator and judge calls run from fresh temporary working directories.
Only the explicitly supplied reference or feedback images are staged there.
Codex runs ephemerally with user configuration and discovered rules ignored;
Claude runs in bare mode. Every run records the isolation protocol in
`config.json`.

This prevents accidental loading of repository `AGENTS.md`/`CLAUDE.md` files
and prior benchmark artifacts. It is practical benchmark isolation, not a
container-level guarantee against a model guessing and reading an unrelated
absolute path; use an OS sandbox or container for that stronger threat model.

**Output Location Example:**
```
benchmark_run_output/97fe1f08_anthropic_claude-3.5-sonnet-20241022_20251026_154624/
├── benchmark_report.md        # Your results are here!
├── config.json
├── results/
│   ├── 000_geometric_cube/
│   ├── 001_mandelbrot_set/
│   └── 002_klein_bottle/
└── images/
```

## Data Formats

### LLM Response (Input to Pipeline)
Models must return XML-wrapped WGSL + Rust code:
```xml
<shader file="problem_name.wgsl">
@vertex
fn vs_main(@builtin(vertex_index) vid: u32) -> @builtin(position) vec4<f32> {
    // WGSL vertex shader
}

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    // WGSL fragment shader with SDF/ray-marching
}
</shader>

<main_rs>
// Optional: Rust WGPU harness modifications (rarely needed)
</main_rs>
```

### Judge Evaluation (Output from Pipeline)
GPT-4o evaluates rendered output against structured rubric:
```xml
<scores><S1>85</S1><S2>72</S2><S3>91</S3><S4>67</S4><S5>88</S5></scores>
```

**Scoring dimensions** (100 points each):
- **S1 — Mathematical Accuracy:** Geometric correctness, algorithm fidelity
- **S2 — Visual Quality:** Rendering quality, materials, lighting, anti-aliasing
- **S3 — Problem-Specific Mathematical:** Domain-dependent (e.g., symmetry properties)
- **S4 — Problem-Specific Visual/Technical:** Technical requirements (e.g., SDF correctness)
- **S5 — Completeness:** Fulfillment of all specification requirements

## Output Structure

### Single Test Result Directory
```
test_YYYYMMDD_HHMMSS_UUID_results/
├── result.png                    # 1600×1600 rendered output
├── shader.wgsl                   # Generated WGSL code
├── results.json                  # {"scores": [S1, S2, S3, S4, S5], "metadata": {...}}
├── response.txt                  # Full LLM output with XML
└── current_results_report.md     # Individual evaluation report
```

### Batch Harness Output (New Structure)
```
benchmark_run_output/
└── UUID_MODEL_YYYYMMDD_HHMMSS/             # e.g., 97fe1f08_anthropic_claude-haiku-4.5_20251026_154624
    ├── config.json                         # Launch configuration (model, problems, timestamps)
    ├── benchmark_report.md                 # Aggregate results with statistics and embedded images
    ├── logs/
    │   ├── execution_summary.log           # Master timeline of all START/END events
    │   ├── problem_000_geometric_cube.log  # Detailed execution trace for problem 0
    │   └── problem_001_mandelbrot.log      # Detailed execution trace for problem 1
    ├── checkpoints/
    │   ├── manifest.json                   # Run metadata and problem list
    │   ├── problem_000.json                # Problem 0 checkpoint for resume
    │   └── problem_001.json                # Problem 1 checkpoint for resume
    ├── results/
    │   ├── 000_geometric_cube/             # Test results for problem 0
    │   │   ├── llm_request.txt             # Prompt sent to LLM
    │   │   ├── llm_response.txt            # Full LLM response with XML
    │   │   ├── shaders/
    │   │   │   └── shader_0.wgsl           # Generated shader code
    │   │   ├── artifacts/
    │   │   │   └── result.png              # 1600×1600 rendered output
    │   │   ├── results.json                # {"scores": [S1, S2, S3, S4, S5], "has_image": true, ...}
    │   │   └── judge_response.txt          # Full judge evaluation with reasoning
    │   └── 001_mandelbrot/                 # Test results for problem 1
    │       └── ...
    └── images/                             # Copies of PNGs for markdown embedding
        ├── 000_geometric_cube_result.png
        └── 001_mandelbrot_result.png
```

**Directory Structure Benefits:**
- **UUID prefix** prevents accidental overwrite of concurrent runs
- **Self-contained** all outputs for one benchmark run in a single directory
- **Report-friendly** images/ directory mirrors results/ for markdown embedding
- **Resumable** checkpoints support `--run-id UUID` to continue interrupted runs
- **Traceable** config.json captures exact launch parameters

**Legacy Structure (Still Supported):**
```
harness_anthropic_claude-3.5-sonnet-20241022_YYYYMMDD_HHMMSS/
├── harness_report_MODEL_TIMESTAMP.md
├── logs/ checkpoints/
└── [test_TIMESTAMP_UUID_results/...]     # Individual test directories mixed in
```

Analysis tools (e.g., `analyze_results.py`) support both directory patterns.

## Technical Constraints

### WGSL/WGPU Limitations
- **No variable array indexing** — All array accesses must use constant indices
- **Manual vertex expansion** — No dynamic vertex generation in shaders
- **256-byte texture alignment** — Row padding required for framebuffer transfers
- **WGPU 0.20 API** — Binding group layout specifications required

See `../shader_harness/wgsl_constraints_guide.txt` for complete reference.

## Development

### Component Testing
```bash
# Verify template parser
python -c "from critic_template import CriticTemplate; print('OK')"

# Test shader XML extraction
python -c "from shader_parser import extract_shader; print('OK')"

# Validate end-to-end pipeline
python main.py --model "anthropic/claude-3.5-sonnet-20241022" \
  --prompt-folder "../problems/base_set/geometric_cube"
```

### Adding New Problems
1. Create `problems/base_set/problem_name/`
2. Add `request.txt` — Natural language specification
3. Add `critic.txt` — Structured rubric (3-section format):
   ```
   __MATHEMATICAL_ACCURACY__
   [Detailed mathematical criteria]

   __VISUAL_IMPLEMENTATION__
   [Visual/technical criteria]

   __COMPLETENESS_AND_SPECIFICATIONS__
   [Requirement fulfillment criteria]
   ```

## Debugging

### Logging System

The harness includes comprehensive logging to debug failures in parallel execution. See **[LOGGING_GUIDE.md](LOGGING_GUIDE.md)** for complete documentation.

**Quick debugging workflow:**

1. **Check execution summary** for high-level timeline:
   ```bash
   cat harness_*/logs/execution_summary.log
   ```

2. **Read detailed problem logs** for failures:
   ```bash
   cat harness_*/logs/problem_001_problem_name.log
   ```

3. **Check shader compilation errors**:
   ```bash
   cat test_*/render_error.log
   ```

**Common log patterns:**
- **Problem never started** - Check for error before `START problem_NNN` entry
- **Fast failure (< 1s)** - Look for `EXCEPTION` marker in problem log
- **Compilation failure** - Check `STAGE START: compile` followed by exception
- **Render timeout** - Look for `TimeoutExpired` in render stage

## Troubleshooting

| Issue | Root Cause | Solution |
|-------|-----------|----------|
| `cargo: command not found` | Rust not in subprocess PATH | Add `source ~/.cargo/env` to shell profile |
| Judge returns `[0,0,0,0,0]` | XML parsing failure | Check GPT-4o response format |
| Shader compilation fails | WGSL syntax error | Validate against WGSL spec constraints |
| Timeout errors | Complex ray-marching | Increase timeout in `benchmark_harness.py:51` |
| Tests show 100% but 0% success | Progress bar counts failures too | Check `logs/execution_summary.log` for actual status |
| No logs for failed problem | Failed before logger initialized | Check console output for early errors |
