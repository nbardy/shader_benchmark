# LLM Shader Harness

This harness tests LLM shader generation capabilities with complete test isolation and comprehensive reporting.

## Features

- **Individual Test Mode**: Run single problems with isolated UUID directories
- **Harness Mode**: Run multiple problems with consolidated reporting  
- **True Isolation**: Each test run creates `test_YYYYMMDD_HHMMSS_UUID_results/` directory
- **Structured Evaluation**: 5-category scoring system (1-100 scale each)
- **WGSL Support**: Full WGPU shader pipeline with guides and constraints
- **Judge Integration**: GPT-4o evaluation with XML score parsing

## Architecture

### Core Components
- `main.py` - Single test runner with isolated reporting
- `benchmark_harness.py` - Multi-test harness with consolidated reports
- `generate_report.py` - Unified report generator (individual & batch modes)
- `judge.py` - GPT-4o evaluation system with template support
- `test_runner.py` - Test isolation and WGPU execution
- `llm_client.py` - OpenRouter API interface

### Support Systems  
- `critic_template.py` - Structured evaluation template parser
- `shader_parser.py` - LLM XML response parser
- `prompt_loader.py` - Problem specification loader

## Setup

### Environment Setup
```bash
# Option 1: uv (recommended)
curl -LsSf https://astral.sh/uv/install.sh | sh
cd llm_harness
uv sync

# Option 2: Traditional venv
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

### API Configuration
Create `.env` file:
```bash
OPENROUTER_API_KEY=your_api_key_here
```

## Usage

### Single Test Mode
```bash
# With uv
uv run python main.py --model "anthropic/claude-3.5-sonnet-20241022" --prompt-folder "../problems/base_set/geometric_cube"

# With venv
source venv/bin/activate
python main.py --model "anthropic/claude-3.5-sonnet-20241022" --prompt-folder "../problems/base_set/geometric_cube"
```

**Output**: `test_YYYYMMDD_HHMMSS_UUID_results/` with individual report

### Harness Mode (Multiple Tests)
```bash
python benchmark_harness.py --model "anthropic/claude-3.5-sonnet-20241022" --problems geometric_cube five_pointed_star_polygon mandala_circles
```

**Output**: `harness_MODEL_TIMESTAMP/` with consolidated report

## LLM Response Format

Expected XML structure:
```xml
<shader file="shader_name.wgsl">
@vertex
fn main_vs(@builtin(vertex_index) vid: u32) -> @builtin(position) vec4<f32> {
    // WGSL vertex shader code
}

@fragment  
fn main_fs(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    // WGSL fragment shader code
}
</shader>

<main_rs>
use wgpu;
// Rust WGPU harness code
</main_rs>
```

## Judge Evaluation System

### Scoring Categories (1-100 each)
1. **Mathematical Accuracy** - Correctness of mathematical implementation
2. **Visual Quality** - Rendering quality and aesthetics  
3. **Problem-Specific Category 3** - Varies by problem type
4. **Problem-Specific Category 4** - Varies by problem type
5. **Problem-Specific Category 5** - Varies by problem type

### Expected Judge Output
```xml
<scores><S1>85</S1><S2>72</S2><S3>91</S3><S4>67</S4><S5>88</S5></scores>
```

## Output Structure

### Individual Test
```
test_20250805_143022_a1b2c3d4-e5f6-7890-abcd-ef1234567890_results/
├── artifacts/result.png          # Rendered output
├── shaders/problem_name.wgsl     # Generated shader
├── src/main.rs                   # Generated Rust code
├── results.json                  # Scores and metadata
├── current_results_report.md     # Individual test report
└── images/UUID_result.png        # Report image copy
```

### Harness Report  
```
harness_MODEL_TIMESTAMP/
└── harness_report_MODEL_TIMESTAMP.md  # Consolidated multi-test report
```

## WGSL Constraints

The system includes comprehensive guides for:
- **WGSL Constraints**: Variable array indexing limitations, manual vertex expansion
- **WGPU API**: Texture alignment (256-byte boundary), compilation options
- **Rust Integration**: Proper WGPU 0.20 API usage patterns

## Testing

```bash
# Test single component
python -c "from critic_template import CriticTemplate; print('Template system OK')"

# Test full pipeline
python main.py --model "anthropic/claude-3.5-sonnet-20241022" --prompt-folder "../problems/base_set/geometric_cube"
```