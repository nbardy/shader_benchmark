# Benchmark Quickstart Guide

Complete reference for running shader benchmark evaluations on LLM models.

## Prerequisites Checklist

- ✅ **Rust toolchain** — `cargo --version` succeeds
- ✅ **Python 3.11+** — `python3 --version` shows 3.11+
- ✅ **API access** — OpenRouter API key for model inference
- ✅ **Disk space** — ~500MB for full benchmark outputs

## Quick Start Commands

### Validation Run (Single Problem, ~90 sec)
```bash
cd llm_harness
source venv/bin/activate
python benchmark_harness.py \
  --model "anthropic/claude-3.5-sonnet-20241022" \
  --problems geometric_cube
```

### Small Evaluation (5 Problems, ~8 min)
```bash
cd llm_harness
source venv/bin/activate
python benchmark_harness.py \
  --model "anthropic/claude-3.5-sonnet-20241022" \
  --problems geometric_cube regular_tetrahedron regular_octahedron rounded_box torus_donut_parametric
```

### Representative Sample (20 Problems, ~35 min)
```bash
cd llm_harness
source venv/bin/activate
python benchmark_harness.py \
  --model "anthropic/claude-3.5-sonnet-20241022" \
  --problems \
    geometric_cube regular_tetrahedron regular_octahedron rounded_box torus_donut_parametric \
    apollonian_gasket archimedean_spiral_galaxy butterfly_curve cardioid_limacon_collection \
    complex_analysis_stained_glass compound_polyhedra_stella_octangula dragon_curve_fractal \
    fibonacci_spiral_golden_rectangle geodesic_sphere hilbert_curve_fractal \
    hyperbolic_geometry_poincare_disk klein_bottle lorenz_attractor mandelbrot_set menger_sponge
```

### Complete Benchmark (101 Problems, ~3.5 hours)
```bash
cd llm_harness
source venv/bin/activate
python benchmark_harness.py \
  --model "anthropic/claude-3.5-sonnet-20241022" \
  --problems $(ls ../problems/base_set)
```

## Environment Setup

### Standard Configuration (Python venv)
```bash
cd llm_harness
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt

# Configure API access
echo "OPENROUTER_API_KEY=sk-or-v1-..." > .env
```

### Alternative: uv Package Manager
```bash
cd llm_harness
uv venv
source .venv/bin/activate
uv pip install -r requirements.txt
echo "OPENROUTER_API_KEY=sk-or-v1-..." > .env
```

**Dependencies:** `aiohttp` (async HTTP), `python-dotenv` (env management), `requests` (OpenRouter API)

## Model Support

Benchmark tested with OpenRouter API models:

| Model | Identifier | Notes |
|-------|-----------|-------|
| Claude 3.5 Sonnet | `anthropic/claude-3.5-sonnet-20241022` | Baseline reference |
| Claude Sonnet 4 | `anthropic/claude-sonnet-4` | Latest Anthropic |
| OpenAI o3 | `openai/o3` | Reasoning-focused |
| Qwen3 Coder | `qwen/qwen3-coder` | Code-specialized |
| Kimi VL | `moonshotai/kimi-vl-a3b-thinking` | Vision-language |

## Output Artifacts

Each benchmark run generates:
```
llm_harness/harness_MODEL_TIMESTAMP/
├── harness_report_MODEL_TIMESTAMP.md     # Aggregate analysis
└── test_TIMESTAMP_UUID_results/          # Per-problem results
    ├── result.png                         # 1600×1600 render
    ├── shader.wgsl                        # Generated shader code
    ├── results.json                       # {"scores": [S1, S2, S3, S4, S5]}
    └── response.txt                       # Full LLM output with XML
```

## Evaluation Scoring

**5-dimensional assessment** (500 points total):
- **S1 — Mathematical Accuracy:** Geometric correctness, algorithmic fidelity
- **S2 — Visual Quality:** Rendering quality, anti-aliasing, materials, lighting
- **S3 — Problem-Specific Mathematical:** Domain-dependent criteria (e.g., symmetry properties)
- **S4 — Problem-Specific Visual/Technical:** Technical requirements (e.g., ray-marching correctness)
- **S5 — Completeness:** Fulfillment of all specification requirements

**Judge:** GPT-4o with structured rubrics (XML output: `<scores><S1>85</S1>...</scores>`)

## Performance Profile

| Configuration | Problems | Duration | Use Case |
|---------------|----------|----------|----------|
| Validation | 1 | 90 sec | Installation check |
| Small | 5 | 8 min | Model comparison |
| Representative | 20 | 35 min | Capability assessment |
| Thorough | 50 | 90 min | Publication results |
| Complete | 101 | 3.5 hrs | Full benchmark |

## Problem Catalog (Subset)

**Geometry:** `geometric_cube`, `regular_tetrahedron`, `regular_octahedron`, `rounded_box`, `torus_donut_parametric`
**Fractals:** `apollonian_gasket`, `dragon_curve_fractal`, `hilbert_curve_fractal`, `mandelbrot_set`, `menger_sponge`, `sierpinski_triangle`
**Physics:** `lorenz_attractor`, `reaction_diffusion_patterns`, `schwarzschild_black_hole`
**Topology:** `klein_bottle`, `mobius_strip`, `trefoil_knot`, `hopf_fibration`
**Classical:** `archimedes_spiral`, `butterfly_curve`, `fibonacci_spiral_golden_rectangle`

See `problems/base_set/` for complete list (101 problems).

## Troubleshooting

| Issue | Solution |
|-------|----------|
| `cargo: command not found` | `source ~/.cargo/env` or install Rust toolchain |
| `ModuleNotFoundError: aiohttp` | Activate venv, run `pip install -r requirements.txt` |
| `OPENROUTER_API_KEY not set` | Create `.env` in `llm_harness/` with API key |
| Timeout errors | Expected for complex problems; default 5min/problem |
| Shader compilation fails | Check WGSL syntax in generated code |

**Typical pipeline timing:**
- Shader compilation: 10-30s
- LLM generation: 30-90s
- Judge evaluation: 20-40s
- **Total per problem:** 60-160s

## Advanced Usage

### Multi-Model Comparison
```bash
cd llm_harness
source venv/bin/activate

# Compare models on same problem set
for model in "anthropic/claude-3.5-sonnet-20241022" "openai/o3" "qwen/qwen3-coder"; do
  python benchmark_harness.py --model "$model" \
    --problems geometric_cube regular_tetrahedron mandelbrot_set
  sleep 5  # Rate limiting courtesy
done
```

### Custom Problem Sets
```bash
# Geometry-focused evaluation
python benchmark_harness.py --model "anthropic/claude-sonnet-4" \
  --problems geometric_cube regular_tetrahedron regular_octahedron \
    dodecahedron icosahedron truncated_icosahedron geodesic_sphere

# Fractal-focused evaluation
python benchmark_harness.py --model "anthropic/claude-sonnet-4" \
  --problems mandelbrot_set julia_set sierpinski_triangle \
    dragon_curve_fractal hilbert_curve_fractal apollonian_gasket
```

### Batch Processing with Problem List File
```bash
# Create curated problem list
cat > research_problems.txt <<EOF
geometric_cube
klein_bottle
hopf_fibration
lorenz_attractor
mandelbrot_set
EOF

# Execute benchmark
python benchmark_harness.py --model "anthropic/claude-sonnet-4" \
  --problems $(cat research_problems.txt)
```

## Research Workflow

1. **Validation** — Single problem test to verify environment
2. **Pilot Study** — Small benchmark (5 problems) for initial model assessment
3. **Representative Evaluation** — 20-problem sample for capability profiling
4. **Publication Results** — 50+ problems for comprehensive analysis
5. **Full Benchmark** — Complete 101-problem suite for definitive comparison