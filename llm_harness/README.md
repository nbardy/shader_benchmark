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
- **Rust/Cargo** in `$PATH` (for shader compilation subprocess)
- **OpenRouter API key** with model access

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

**Generates:** `harness_MODEL_TIMESTAMP/harness_report_MODEL_TIMESTAMP.md` with aggregate analysis

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

### Batch Harness Output
```
harness_anthropic_claude-3.5-sonnet-20241022_YYYYMMDD_HHMMSS/
├── harness_report_MODEL_TIMESTAMP.md  # Aggregate results with statistics
├── logs/
│   ├── execution_summary.log          # Master timeline of all START/END events
│   ├── problem_000_name.log           # Detailed execution trace for problem 0
│   └── problem_001_name.log           # Detailed execution trace for problem 1
├── checkpoints/
│   ├── manifest.json                  # Run metadata and problem list
│   ├── problem_000.json              # Problem 0 checkpoint for resume
│   └── problem_001.json              # Problem 1 checkpoint for resume
└── [test_TIMESTAMP_UUID_results/...]  # Individual test directories
```

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