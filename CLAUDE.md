# Claude Instructions for Shader Benchmark

This document contains important setup instructions and context for working with the shader benchmark repository.

## Repository Structure

```
shader_benchmark/
├── problems/base_set/          # 100+ mathematical visualization problems
│   ├── problem_name/
│   │   ├── request.txt         # Problem specification
│   │   └── critic.txt          # Evaluation criteria (structured format)
├── llm_harness/                # LLM testing infrastructure
├── shader_harness/             # Rust WGPU shader runner
├── research/                   # Development archives and analysis
├── claude_code/                # Technical documentation
│   ├── progress_and_goals.md   # Project progress and objectives
│   ├── scoring_system_technical.md  # Technical implementation details
│   └── testing_guide.md        # Comprehensive testing procedures
└── README.md                   # Project documentation
```

## Python Environment Setup

**⚠️ IMPORTANT**: The `llm_harness` requires Python dependencies. Set up environment before running:

### Option 1: uv (Recommended - Fast & Modern)
```bash
# Install uv if not already installed
curl -LsSf https://astral.sh/uv/install.sh | sh

# Navigate to llm_harness and setup environment
cd llm_harness
uv sync                                    # Creates venv and installs dependencies
uv run python main.py --model MODEL --prompt-folder FOLDER
```

### Option 2: pyenv + pip (Version Management)
```bash
# Install specific Python version
pyenv install 3.11
pyenv local 3.11

# Navigate to llm_harness and install dependencies
cd llm_harness
pip install -r requirements.txt
python main.py --model MODEL --prompt-folder FOLDER
```

### Option 3: System Python + venv (Basic)
```bash
cd llm_harness
python3 -m venv venv
source venv/bin/activate          # On Windows: venv\Scripts\activate
pip install -r requirements.txt
python main.py --model MODEL --prompt-folder FOLDER
```

### Required Dependencies
Key packages that must be installed:
- `aiohttp` - Async HTTP client for OpenRouter API
- `python-dotenv` - Environment variable management
- `pathlib` - Path handling (usually built-in)

## Cargo/Rust PATH Configuration

**⚠️ CRITICAL**: The LLM harness subprocess calls need `cargo` in PATH.

### Current Setup Status
- ✅ **Rust installed**: `~/.cargo/env` exists and functional
- ✅ **Profile configured**: `~/.profile` sources `~/.cargo/env`
- ❌ **Subprocess PATH**: Python subprocess doesn't inherit shell environment

### Shell Configuration
```bash
# ~/.profile (already configured)
. "$HOME/.cargo/env"

# ~/.zshrc (already configured) 
source ~/.profile
```

### Problem: Non-Interactive Subprocess
When Python runs `subprocess.run(["cargo", "run"])`, it uses a minimal environment that doesn't source shell profiles.

### Solution Applied
The `test_runner.py` explicitly sources cargo environment:
```python
# In test_runner.py run_test() method
cargo_env_cmd = "source ~/.cargo/env && cargo run -- --shader {} --output result.png --size 1600".format(str(main_shader))
result = subprocess.run(
    ["bash", "-c", cargo_env_cmd],  # Explicit bash with cargo env
    capture_output=True,
    text=True,
    timeout=120
)
```

### Verification Commands
```bash
# Check current shell has cargo
source ~/.cargo/env && which cargo  # Should show: /Users/username/.cargo/bin/cargo

# Check subprocess will work
bash -c "source ~/.cargo/env && which cargo"  # Should show same path
```

## Scoring System Architecture

### Current State: Multi-Criteria Structured Evaluation

Each problem uses a **5-score system (1-100 scale each)**:

1. **S1: Problem Accuracy** (Generic) - Mathematical correctness
2. **S2: Visual Quality** (Generic) - Rendering quality and aesthetics  
3. **S3: [Section 1]** - Problem-specific mathematical criteria
4. **S4: [Section 2]** - Problem-specific visual/technical criteria
5. **S5: [Section 3]** - Problem-specific completeness criteria

### Critic File Format

Each `critic.txt` uses **structured sections** (NOT single questions):

```
__MATHEMATICAL_ACCURACY__
[Multiple detailed mathematical criteria]
- Sub-criterion 1: Specific mathematical property
- Sub-criterion 2: Algorithm implementation  
- Sub-criterion 3: Mathematical relationships
[Additional criteria as needed]

__VISUAL_IMPLEMENTATION__
[Multiple visual/technical criteria]
- Sub-criterion 1: Resolution, anti-aliasing
- Sub-criterion 2: Materials, lighting, shading
- Sub-criterion 3: Color accuracy, effects
[Additional criteria as needed]

__COMPLETENESS_AND_SPECIFICATIONS__  
[Multiple requirement fulfillment criteria]
- Sub-criterion 1: Required elements present
- Sub-criterion 2: Reference objects, legends
- Sub-criterion 3: Composition, backgrounds
[Additional criteria as needed]
```

### Scoring Philosophy

**⚠️ PRESERVE INFORMATION DENSITY**: 
- Original critics contained rich rubrics, detailed scoring tables, mathematical formulas
- New format **organizes but doesn't simplify** this comprehensive content
- Each section contains **multiple related criteria** (typically 3-8 sub-criteria)
- Each section receives **single 1-100 score** based on fulfilling **ALL criteria** within

### Output Format
LLM judges must respond with:
```
<scores><S1>85</S1><S2>72</S2><S3>91</S3><S4>67</S4><S5>88</S5></scores>
```

## Key Commands

### Running Single Problem Test
```bash
cd llm_harness
source venv/bin/activate  # If using venv method
python main.py --model "anthropic/claude-3.5-sonnet-20241022" --prompt-folder "../problems/base_set/geometric_cube"

# Or with uv:
uv run python main.py --model "anthropic/claude-3.5-sonnet-20241022" --prompt-folder "../problems/base_set/geometric_cube"
```

### Running Batch Tests  
```bash
cd llm_harness
source venv/bin/activate  # If using venv method
python judge_existing.py  # Re-evaluate existing results with new scoring system

# Or with uv:
uv run python judge_existing.py
```

### Generating Reports
```bash
cd llm_harness
source venv/bin/activate  # If using venv method
python generate_report.py --model "claude-3.5-sonnet" --output test_report.md

# Or with uv:
uv run python generate_report.py --model "claude-3.5-sonnet" --output test_report.md
```

### Testing Components (Development)
```bash
cd llm_harness
source venv/bin/activate

# Test template system
python -c "from critic_template import CriticTemplate; print('Template system OK')"

# Test judge scoring (requires API key)
python -c "
import asyncio
from dotenv import load_dotenv
from judge import Judge
from pathlib import Path
load_dotenv()
async def test(): 
    judge = Judge()
    scores = await judge.evaluate_with_template(
        Path('../problems/base_set/geometric_cube/critic.txt'),
        Path('../problems/base_set/geometric_cube/request.txt'), 
        Path('test_result.png')  # Use existing test image
    )
    print(f'Scores: {scores}')
asyncio.run(test())
"
```

### Testing Single Shader
```bash
cd shader_harness
cargo run
```

## Rust Environment Setup

**⚠️ IMPORTANT**: The `shader_harness` requires Rust/Cargo. Set up environment before running shaders:

### Install Rust (if not already installed)
```bash
# Install Rust toolchain
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y

# Source cargo environment (or restart shell)
source ~/.cargo/env
```

### Verify Installation
```bash
# Check if cargo is available
which cargo
cargo --version

# If "cargo not found", source the environment:
source ~/.cargo/env
```

### Environment Integration
The Rust installer should automatically add this line to `~/.profile`:
```bash
. "$HOME/.cargo/env"
```

And your `~/.zshrc` should source the profile:
```bash
source ~/.profile
```

### Common Issues
- **"cargo not found"**: Run `source ~/.cargo/env` in your current shell
- **Path not persisting**: Check that `~/.profile` contains the cargo env line
- **Shell integration**: Restart terminal or run `source ~/.zshrc`

## Environment Variables

Create `.env` file in `llm_harness/`:
```bash
OPENROUTER_API_KEY=your_api_key_here
```

## Important Notes for Development

### When Modifying Critic Files:
1. **Preserve complexity**: Don't oversimplify detailed evaluation criteria
2. **Organize, don't reduce**: Group related criteria into sections
3. **Test template**: Use `test_critic_template.py` to verify parsing
4. **Validate format**: Sections must be properly named and structured

### When Adding New Problems:
1. Create `problem_name/` directory in `problems/base_set/`
2. Add `request.txt` with problem specification
3. Add `critic.txt` with structured evaluation criteria
4. Follow existing naming conventions

### Common Issues:
- **Import errors**: Always setup Python environment first
- **API errors**: Verify `OPENROUTER_API_KEY` is set correctly
- **Parsing errors**: Validate critic.txt format with test script
- **Path errors**: Use absolute paths or ensure correct working directory

## Technical Documentation

### Comprehensive Guides
- **[Progress and Goals](claude_code/progress_and_goals.md)** - Project overview, accomplishments, and roadmap
- **[Scoring System Technical](claude_code/scoring_system_technical.md)** - Detailed implementation of 5-score system
- **[Testing Guide](claude_code/testing_guide.md)** - Complete testing procedures and troubleshooting

### Development History
- **July 2025**: Complete scoring system overhaul implemented
  - Migrated from 1-10 to 1-100 scale (10x granularity improvement)
  - Converted 100 critic files to structured format using parallel processing
  - Implemented XML parsing with `<scores><S1>X</S1>...</scores>` format
  - Created template-based evaluation system preserving mathematical complexity
- **Previous**: Original system used 1-10 scale with inconsistent formats

## Quick Reference

### New Scoring System Summary
- **Scale**: 1-100 per category (500 total possible)
- **Categories**: 5 scores (2 generic + 3 problem-specific)
- **Format**: XML output `<scores><S1>85</S1><S2>72</S2>...</scores>`
- **Critics**: Structured sections with preserved mathematical detail
- **Reports**: Display "/100" and "/500" totals instead of "/10" and "/50"

### Testing Checklist
1. ✅ **Environment Setup**: Python venv/uv with dependencies installed
2. ✅ **API Configuration**: `.env` file with `OPENROUTER_API_KEY`
3. ✅ **Template System**: `critic_template.py` imports successfully
4. ✅ **Judge Integration**: XML score parsing functional
5. ✅ **Report Generation**: 1-100 scale display working
6. ✅ **End-to-End**: Full pipeline test with real problem