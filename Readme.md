# Shader Benchmark: Evaluating LLM Visual Programming Capabilities

A comprehensive benchmark for measuring large language model performance on shader generation tasks, featuring 101 mathematical visualization challenges spanning classical geometry to advanced topology.

## Motivation

Vision-language models excel at **image → text** tasks (VQA, captioning, OCR), yet the inverse problem—**text → image generation through code**—remains largely unexplored as a rigorous benchmark. This creates a critical gap: LLMs increasingly serve as programming assistants, but we lack systematic evaluation of their ability to synthesize visual algorithms from mathematical specifications.

**Key observations:**
- Modern LLMs demonstrate surprising capability for shader programming when given iterative human feedback ([Shadertoy examples](https://www.shadertoy.com/user/nbardy/sort=newest))
- Zero-shot performance remains weak, but rapid improvement suggests tractable research problems
- No standardized benchmark exists for shader synthesis or mathematical visualization programming

This benchmark provides infrastructure for rigorous evaluation of LLM visual programming abilities, targeting the research question: *Can language models learn to generate mathematically correct, visually compelling graphics code from natural language specifications?*

## Architecture

**Problem Set:** 101 mathematical visualization challenges (Platonic solids → Calabi-Yau manifolds)
**Execution Engine:** Rust WGPU shader harness with WGSL compilation
**Evaluation:** Multi-criteria scoring (5 categories × 100-point scale) using LLM-as-judge
**Pipeline:** Specification → LLM generation → Compilation → Rendering → Structured evaluation

### Repository Structure
```
shader_benchmark/
├── problems/base_set/        # 101 problem specifications (request.txt + critic.txt)
├── llm_harness/              # Python evaluation pipeline
├── shader_harness/           # Rust WGPU rendering engine
└── claude_code/              # Technical documentation
```

## Quick Start

### Prerequisites
```bash
# Rust toolchain (shader compilation)
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source ~/.cargo/env

# Python environment (evaluation harness)
cd llm_harness
python3 -m venv venv && source venv/bin/activate
pip install -r requirements.txt

# API configuration
echo "OPENROUTER_API_KEY=your_key" > .env
```

### Single Problem Test (~90 seconds)
```bash
cd llm_harness
source venv/bin/activate
python benchmark_harness.py \
  --model "anthropic/claude-3.5-sonnet-20241022" \
  --problems geometric_cube
```

### Full Benchmark (101 problems, ~3-4 hours)
```bash
cd llm_harness
source venv/bin/activate
python benchmark_harness.py \
  --model "anthropic/claude-3.5-sonnet-20241022" \
  --problems $(ls ../problems/base_set)
```

See [`BENCHMARK_QUICKSTART.md`](BENCHMARK_QUICKSTART.md) for detailed usage patterns.

## Evaluation Methodology

### Scoring System
Each problem evaluated across **5 dimensions** (100 points each, 500 total):

**Generic Criteria (Same for All Problems):**
- **S1 — Mathematical Accuracy:** Overall correctness of mathematical/geometric implementation
- **S2 — Visual Quality:** Rendering fidelity, anti-aliasing, materials, lighting, aesthetics

**Problem-Specific Criteria (Defined per Problem in `critic.txt`):**
- **S3 — Mathematical Accuracy (Detailed):** Problem-specific mathematical requirements
  - Example (Klein Bottle): Topology verification, self-intersection geometry, parametric precision
  - Example (Mandelbrot): Escape-time algorithm, iteration depth, boundary detection
- **S4 — Visual Implementation (Detailed):** Problem-specific rendering requirements
  - Example (Klein Bottle): Curvature color mapping, lighting for topology visibility
  - Example (Mandelbrot): Color gradient mapping, zoom level detail, fractal smoothness
- **S5 — Completeness:** Problem-specific requirement fulfillment
  - Example (Klein Bottle): Non-orientable surface properties, measurement tolerances
  - Example (Mandelbrot): Iteration limits, coordinate range, color scheme adherence

**Judge Model:** GPT-4o evaluates rendered output against problem-specific rubrics
**Output Format:** `<scores><S1>85</S1><S2>72</S2><S3>91</S3><S4>67</S4><S5>88</S5></scores>`

### Problem Categories
- **Classical Geometry** (Platonic solids, polyhedra, parameterized surfaces)
- **Fractals & Recursion** (Mandelbrot, Menger sponge, L-systems)
- **Differential Geometry** (Minimal surfaces, Gaussian curvature, geodesics)
- **Topology** (Klein bottles, Möbius strips, fiber bundles)
- **Physics Simulations** (Reaction-diffusion, gravitational lensing, wave equations)
- **Historical Mathematics** (Archimedes' spiral, Apollonian gasket, al-Khwarizmi's algebra)

## Technical Details

### Shader Constraints
- **Language:** WGSL (WebGPU Shading Language)
- **API:** WGPU 0.20 (Rust bindgen)
- **Limitations:** No variable array indexing, manual vertex expansion, 256-byte texture alignment
- **Format:** Vertex + fragment shader with SDF/ray-marching techniques

### Pipeline Components
1. **`llm_harness/benchmark_harness.py`** — Multi-problem orchestration
2. **`llm_harness/judge.py`** — GPT-4o evaluation with template system
3. **`shader_harness/`** — WGPU rendering engine with PNG export
4. **`problems/base_set/*/critic.txt`** — Structured evaluation rubrics

### Output Structure
```
llm_harness/harness_MODEL_TIMESTAMP/
├── harness_report_MODEL_TIMESTAMP.md     # Aggregate results
└── test_TIMESTAMP_UUID_results/
    ├── result.png                         # 1600×1600 render
    ├── shader.wgsl                        # Generated code
    ├── results.json                       # 5-category scores
    └── response.txt                       # Full LLM output
```

## Example Problems

**Beginner:** Platonic solids (cube, tetrahedron), parametric curves (Archimedean spiral)
**Intermediate:** Fractals (Sierpiński, Apollonian gasket), polyhedra (truncated icosahedron)
**Advanced:** Hopf fibration, Calabi-Yau manifolds, Lorenz attractor, Klein bottles

Full catalog: [`problems/readme.md`](problems/readme.md)

## Performance Baselines

Current model performance (preliminary observations):
- **Claude 3.5 Sonnet:** ~19% avg score (95/500 on geometric_cube)
- **Zero-shot challenges:** WGSL syntax, mathematical correctness, coordinate systems
- **Common failure modes:** Incorrect SDF functions, missing ray-marching, lighting errors

*Systematic benchmark results pending full evaluation runs.*

## Research Applications

This benchmark enables investigation of:
- **Code synthesis:** Multi-modal program generation from specifications
- **Mathematical reasoning:** Translating formal descriptions to algorithms
- **Iterative refinement:** Few-shot learning with visual feedback
- **Domain adaptation:** Transfer learning from 2D to 3D graphics domains

## Citation

```bibtex
@misc{shader_benchmark_2025,
  title={Shader Benchmark: Evaluating LLM Visual Programming Capabilities},
  author={Nicholas Bardy},
  year={2025},
  url={https://github.com/nbardy/shader_benchmark}
}
```

## Documentation

- **[BENCHMARK_QUICKSTART.md](BENCHMARK_QUICKSTART.md)** — Installation and usage guide
- **[claude_code/scoring_system_technical.md](claude_code/scoring_system_technical.md)** — Evaluation methodology
- **[claude_code/testing_guide.md](claude_code/testing_guide.md)** — Development and troubleshooting
- **[llm_harness/README.md](llm_harness/README.md)** — Harness architecture details

## License

MIT — See [LICENSE](LICENSE) for details.

