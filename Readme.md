# Visual Programming Benchmark

## Getting Started

### Running a Single Shader

To test a single shader with the harness:

```bash
cd shader_harness
cargo run
```

This will compile and run the default shader with WGPU, generating a PNG output.

### Running the Full Test Harness

To run the complete benchmark suite:

```bash
cd llm_harness
pip install -r requirements.txt
python main.py
```

This will:
- Load all problem prompts from the problems directory
- Generate shaders using the configured LLM
- Compile and test each shader
- Generate visual outputs and evaluation reports

Currently all vision LLM benchmarks are focused on visual analysis (Give an image return fact X). No one is focusing on the opposite. Given X, make me an image! This benchmark fixes that with a set of challenging visual programming problems and a benchmark to judge them. Current models perform very poorly on these problems in a zero-shot setting, but can be incredibly capable when paired with a human. Current models have become incredibly capable at visual programming and have gone from basic to WOW!. For evidence check out my recent shadertoy collection (https://www.shadertoy.com/user/nbardy/sort=newest) all created with chatgpt and friends. Most of these are made by me passing back and forth rendering of each result and building up a long chain of context and critique until the model can get it right, as well as copy and pasting wikipedia articles in context. You **CAN** get LLMs to do advanced shader math and geometry, but it's a **LOT** of time and work. This shows a spark of generalization and with the current rapid pace of LLM development a spark of generalization turns into Expertise within months. All you need is a benchmark to motivate researchers. This benchmark aims to give LLM Researchers a platform to train and test their models in visual programming tasks. Sets out the ambitious goal of lowering the bar for advanced visual programming to the masses. Soon you can just ask ChatGPT for a demo reel!

Each problem has a prompt to ask the model for a shader.
Evaluates the shader
And uses a VLLM as a judge to test the success of the results across a rubric.

## Problems

For a complete list of all benchmark problems, see [problems/readme.md](problems/readme.md).

