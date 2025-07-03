# LLM Shader Harness

This harness tests LLM shader generation capabilities by:

1. Loading prompts from a specified folder
2. Calling an OpenRouter model to generate shader code 
3. Parsing the response for shader files and main.rs
4. Creating a test environment based on the shader_harness template
5. Running the shader with `cargo run` to generate result.png
6. Using GPT-4o via OpenRouter as a judge to evaluate the output
7. Parsing and saving standardized scores (5 integers 1-10)

## Setup

1. Install dependencies:
```bash
pip install -r requirements.txt
```

2. API key is already configured in `.env/.env` file

## Usage

```bash
python main.py --model "anthropic/claude-3-sonnet" --prompt-folder "../tests/problem_1"
```

## Expected Response Format

The LLM should respond with XML blocks:

```xml
<shader file="vertex.wgsl">
@vertex
fn main(@builtin(vertex_index) vertex_index: u32) -> @builtin(position) vec4<f32> {
    // shader code
}
</shader>

<shader file="fragment.wgsl">
@fragment  
fn main() -> @location(0) vec4<f32> {
    // shader code
}
</shader>

<main_rs>
use std::fs;
// Rust code that uses the shaders
</main_rs>
```

## Judge Output Format

The judge must end responses with:
```
SCORES: [X, X, X, X, X]
```

Where each X is an integer from 1-10.

## Output

Results are saved in `test_[uuid]_results/` folders containing:
- Generated shader files
- main.rs
- result.png (shader output)
- results.json (scores and metadata)