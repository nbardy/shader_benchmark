# WGSL Migration Architecture Notes

**Date**: October 24, 2025
**Status**: Migration Complete, Validation Pending
**Purpose**: Document the clean separation of concerns in the shader benchmark system

---

## Executive Summary

The shader benchmark has been fully migrated to a **WGSL-only architecture** with clear separation between:
- **LANGUAGE_SPEC**: Fixed ABI contract (WGSL)
- **COMPILER**: wgpu native WGSL loader (no shaderc translation)
- **HARNESS_FN**: Rust binary that renders shaders

This document explains the architecture, what's locked vs swappable, and how to extend the system.

---

## Architectural Overview

### Three-Layer Separation

```
┌─────────────────────────────────────────────────────────────┐
│                      LANGUAGE_SPEC                          │
│  (WGSL_CONSTRAINT_SPEC.md + prompt_template.txt)           │
│  - ABI Contract: vs_main, fs_main signatures               │
│  - Uniform bindings: @group(0) @binding(0)                 │
│  - Type system: vec3<f32>, explicit types only             │
│  - Forbidden patterns: No gl_*, no preprocessor            │
│  STATUS: 🔒 LOCKED - Non-negotiable interface              │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│                        COMPILER                              │
│  (shader_harness/src/main.rs:42-44)                        │
│  - Direct WGSL loading: ShaderSource::Wgsl(code)           │
│  - No translation layer (shaderc removed)                  │
│  - Native wgpu compilation to Metal/Vulkan/D3D12          │
│  STATUS: ✅ SWAPPABLE (for ablation experiments)           │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│                      HARNESS_FN                             │
│  (shader_harness/src/main.rs:19-229)                       │
│  - GPU initialization (wgpu instance, adapter, device)     │
│  - Render pipeline setup                                    │
│  - PNG output generation                                    │
│  - Timing measurements (CPU + GPU)                         │
│  STATUS: ✅ STABLE - Infrastructure layer                  │
└─────────────────────────────────────────────────────────────┘
```

---

## Data Flow Diagram

```
┌──────────────────┐
│  LLM Request     │ ← problems/base_set/{problem}/request.txt
│  (Problem Spec)  │
└────────┬─────────┘
         │
         ↓
┌──────────────────────────────────────────────────────────┐
│  Prompt Construction (llm_client.py:94-103)             │
│  - Loads prompt_template.txt (LANGUAGE_SPEC)            │
│  - Inserts problem specification                        │
│  - Includes main.rs as ABI reference                    │
│  OUTPUT: Full LLM prompt with WGSL constraints          │
└────────┬─────────────────────────────────────────────────┘
         │
         ↓
┌──────────────────┐
│  LLM Generation  │ → Claude/GPT generates WGSL shader
│  (OpenRouter)    │
└────────┬─────────┘
         │
         ↓ <shader file="shader.wgsl">...</shader>
┌──────────────────────────────────────────────────────────┐
│  XML Parsing (shader_parser.py:16-40)                   │
│  - Extracts shader code from <shader> tags              │
│  - Validates file extension (.wgsl)                     │
│  OUTPUT: {filename: wgsl_code} dict                     │
└────────┬─────────────────────────────────────────────────┘
         │
         ↓
┌──────────────────────────────────────────────────────────┐
│  Test Environment Setup (test_runner.py:35-68)          │
│  - Creates isolated test_UUID_results/ directory        │
│  - Copies Cargo.toml, src/main.rs                       │
│  - Writes shader to shaders/shader.wgsl                 │
└────────┬─────────────────────────────────────────────────┘
         │
         ↓
┌──────────────────────────────────────────────────────────┐
│  Stage 1: Compilation (test_runner.py:70-99)            │
│  - Runs: cargo build --release                          │
│  - Produces: target/release/shader-bench binary         │
│  - Logs: compile_output.log / error_log (if failed)    │
│  - Semaphore: compile_semaphore (CPU-bound)             │
└────────┬─────────────────────────────────────────────────┘
         │
         ↓
┌──────────────────────────────────────────────────────────┐
│  Stage 2: Rendering (test_runner.py:101-162)            │
│  - Runs: ./shader-bench --shader X --output result.png  │
│  - GPU renders 1600x1600 RGBA PNG                       │
│  - Logs: render_output.log / error_log (if failed)     │
│  - Semaphore: render_semaphore (GPU-bound)              │
│  OUTPUT: artifacts/result.png                           │
└────────┬─────────────────────────────────────────────────┘
         │
         ↓
┌──────────────────────────────────────────────────────────┐
│  Stage 3: Evaluation (judge.py:evaluate_with_template)  │
│  - Loads critic.txt (structured evaluation criteria)    │
│  - Passes result.png + criteria to judge LLM            │
│  - Parses XML: <scores><S1>X</S1>...<S5>Y</S5></scores> │
│  OUTPUT: [S1, S2, S3, S4, S5] scores (1-100 each)       │
└────────┬─────────────────────────────────────────────────┘
         │
         ↓
┌──────────────────┐
│  results.json    │ ← Saved to test folder
│  report.md       │ ← Generated summary
└──────────────────┘
```

---

## What's Locked (ABI Contract)

### 🔒 IMMUTABLE Components

These components are **non-negotiable** and define the interface contract:

#### 1. WGSL Entry Points (WGSL_CONSTRAINT_SPEC.md:28-81)

```wgsl
@vertex
fn vs_main(@builtin(vertex_index) vertex_index: u32) -> @builtin(position) vec4<f32> {
    // LOCKED: Function name, parameters, return type
    let vertex_id = vertex_index % 3u;
    let x = f32(i32(vertex_id & 1u) << 2u) - 1.0;
    let y = f32(i32((vertex_id >> 1u) & 1u) << 2u) - 1.0;
    return vec4<f32>(x, y, 0.0, 1.0);
}

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    // LOCKED: Function name, parameter, return type
    // VARIABLE: Fragment logic (LLM generates this)
}
```

**Why locked**: The harness expects these exact names (main.rs:61, 67)

#### 2. Uniform Binding Layout (WGSL_CONSTRAINT_SPEC.md:83-111)

```wgsl
@group(0) @binding(0) var<uniform> Params: Params;

struct Params {
    resolution: vec2<f32>,  // LOCKED: Always provided
    // VARIABLE: Additional fields as needed
};
```

**Why locked**: Harness doesn't pass any bind groups yet (main.rs:48-53), but the structure is reserved for future uniform support.

#### 3. Type System Constraints (WGSL_CONSTRAINT_SPEC.md:113-180)

- **REQUIRED**: Explicit type generics (`vec3<f32>`, not `vec3`)
- **REQUIRED**: Scalar suffixes (`1.0` for f32, `1u` for u32, `1` for i32)
- **FORBIDDEN**: Implicit type conversions
- **FORBIDDEN**: GLSL syntax (`gl_*`, `uniform`, `in`/`out`, preprocessor)

**Why locked**: WGSL compiler rejects incomplete types and GLSL patterns.

---

## What's Swappable (Ablation Surface)

### ✅ VARIABLE Components

These can be modified for experiments:

#### 1. Language Specification (LANGUAGE_SPEC ablation)

**Current**: WGSL-only
**Alternate**: GLSL Shadertoy format

To swap to GLSL:
```diff
File: shader_harness/src/main.rs:42-44
- source: wgpu::ShaderSource::Wgsl(Cow::Owned(shader_code)),
+ // Option 1: Use shaderc to compile GLSL to SPIR-V
+ // Requires: Add shaderc dependency to Cargo.toml
+ let spirv = compile_glsl_to_spirv(&shader_code)?;
+ source: wgpu::ShaderSource::SpirV(Cow::Owned(spirv)),

File: llm_harness/prompt_template.txt:1-108
- Replace entire template with Shadertoy GLSL specification
- Change output format: <shader file="shader.glsl">
```

**Effort**: 2-3 hours (add shaderc, update prompt, test 5 problems)

#### 2. Constraint Tightness (VALIDATION ablation)

**Current**: Strict WGSL validation (no dynamic array indexing, explicit types)
**Alternate**: Relaxed constraints (allow more WGSL features)

To relax constraints:
```diff
File: WGSL_CONSTRAINT_SPEC.md:209-222
- Remove forbidden patterns section (allow dynamic indexing)

File: llm_harness/prompt_template.txt:39-56
- Remove or reduce type requirements
- Remove syntax restrictions
```

**Effort**: 1 hour (edit specs, run batch test)

#### 3. Output Format (RENDERING ablation)

**Current**: 1600x1600 RGBA PNG, sRGB color space
**Alternate**: Different resolution, HDR format, video output

To change output:
```diff
File: shader_harness/src/main.rs:15-16
- default_value_t = 1024
+ default_value_t = 2048  // 2K resolution

File: shader_harness/src/main.rs:69
- format: wgpu::TextureFormat::Rgba8UnormSrgb,
+ format: wgpu::TextureFormat::Rgba16Float,  // HDR

File: shader_harness/src/main.rs:12-13
- PNG file to write
+ // Add --format flag for MP4/WebM video output
```

**Effort**: 3-5 hours (video encoding requires ffmpeg integration)

#### 4. Validator Strategy (SCORING ablation)

**Current**: LLM judge with 5-score structured evaluation (1-100 scale)
**Alternate**: Image similarity metrics, perceptual hash, SSIM/MSE

To add metric validation:
```diff
File: llm_harness/judge.py:create new method
+ def evaluate_with_metrics(self, reference_image, result_image):
+     # Compute SSIM, MSE, perceptual hash
+     # Return numerical scores instead of LLM evaluation

File: llm_harness/main.py:60-66
- scores = await judge.evaluate_with_template(...)
+ scores = judge.evaluate_with_metrics(reference_img, result_img)
```

**Effort**: 4-6 hours (integrate opencv/pillow, define metrics, calibrate thresholds)

---

## File Organization

### Configuration Files (LANGUAGE_SPEC layer)

| File | Purpose | Status |
|------|---------|--------|
| `WGSL_CONSTRAINT_SPEC.md` | Authoritative ABI contract | 🔒 Locked |
| `llm_harness/prompt_template.txt` | LLM prompt with constraints | 🔒 Locked (for WGSL) |
| `problems/base_set/{problem}/request.txt` | Problem specifications | ✅ Per-problem |
| `problems/base_set/{problem}/critic.txt` | Evaluation criteria | ✅ Per-problem |

### Infrastructure Files (HARNESS_FN layer)

| File | Purpose | Status |
|------|---------|--------|
| `shader_harness/src/main.rs` | Rust GPU harness | ✅ Stable |
| `shader_harness/Cargo.toml` | Dependencies (wgpu only) | ✅ Stable |
| `llm_harness/test_runner.py` | Compilation + rendering | ✅ Stable |
| `llm_harness/llm_client.py` | LLM API integration | ✅ Stable |
| `llm_harness/shader_parser.py` | XML extraction | ✅ Stable |
| `llm_harness/judge.py` | Evaluation scoring | ✅ Stable |

### Execution Logs (Runtime artifacts)

| File | Purpose | Location |
|------|---------|----------|
| `compile_output.log` | Cargo build logs | `test_UUID_results/` |
| `render_output.log` | Shader execution logs | `test_UUID_results/` |
| `error_log` | Failure diagnostics | `test_UUID_results/` (only on failure) |
| `results.json` | Scores + metadata | `test_UUID_results/` |

---

## Extension Guide

### Adding a New Language (e.g., HLSL, Metal)

1. **Create language spec**: `HLSL_CONSTRAINT_SPEC.md`
2. **Update harness**: Modify `main.rs:42-44` to support HLSL compilation
3. **Create prompt template**: `prompt_template_hlsl.txt`
4. **Add compiler dependency**: Update `Cargo.toml` (e.g., `hassle-rs` for HLSL)
5. **Test**: Run 5-10 problems to validate pipeline

**Estimated effort**: 1-2 days

### Adding Uniform Support (time, mouse position)

Currently, the harness doesn't pass uniforms (main.rs:48-53 creates empty bind group layout).

To add uniforms:

```diff
File: shader_harness/src/main.rs:48-53
+ // Create uniform buffer with time, resolution
+ let uniform_buffer = device.create_buffer_init(&wgpu::util::BufferInitDescriptor {
+     label: Some("uniforms"),
+     contents: bytemuck::cast_slice(&[time_f32, resolution_x, resolution_y]),
+     usage: wgpu::BufferUsages::UNIFORM | wgpu::BufferUsages::COPY_DST,
+ });
+
+ let bind_group_layout = device.create_bind_group_layout(&wgpu::BindGroupLayoutDescriptor {
+     entries: &[wgpu::BindGroupLayoutEntry {
+         binding: 0,
+         visibility: wgpu::ShaderStages::FRAGMENT,
+         ty: wgpu::BindingType::Buffer {
+             ty: wgpu::BufferBindingType::Uniform,
+             has_dynamic_offset: false,
+             min_binding_size: None,
+         },
+         count: None,
+     }],
+     label: None,
+ });

File: shader_harness/src/main.rs:63-64
+ pass.set_bind_group(0, &bind_group, &[]);

File: WGSL_CONSTRAINT_SPEC.md:88-111
+ Update Params struct to guarantee time: f32, resolution: vec2<f32>
```

**Estimated effort**: 3-4 hours

### Adding Compute Shader Support

WGSL natively supports compute shaders. To extend:

```diff
File: WGSL_CONSTRAINT_SPEC.md:Add new section
+ ## Compute Shader Contract
+ @compute @workgroup_size(8, 8, 1)
+ fn compute_main(@builtin(global_invocation_id) id: vec3<u32>) {
+     // Write to storage buffer
+ }

File: shader_harness/src/main.rs:Add compute pipeline
+ let compute_pipeline = device.create_compute_pipeline(&wgpu::ComputePipelineDescriptor {
+     module: &shader,
+     entry_point: "compute_main",
+     ...
+ });
```

**Estimated effort**: 1 day (requires storage buffers, dispatch logic)

---

## Comments Added for Future Maintainers

### Critical Comments (Search for these markers)

1. **WGSL_ABI_REFERENCE** (llm_client.py:63-68)
   Explains why main.rs is loaded into LLM prompt

2. **CRITICAL FIX** (test_runner.py:13-16, benchmark_harness.py:205-208, llm_client.py:54-58)
   Documents absolute path resolution fixes (see TECHNICAL_DEBT.md)

3. **WGSL only: locked format** (main.rs:5)
   Marks the WGSL-only decision point

4. **🔒 WGSL FORMAT LOCK** (prompt_template.txt:1-10)
   Indicates non-negotiable constraints in prompt

### Code Navigation Tips

- **To modify ABI contract**: Start at `WGSL_CONSTRAINT_SPEC.md:28-111`
- **To change compiler**: Edit `shader_harness/src/main.rs:42-44`
- **To adjust constraints**: Edit `prompt_template.txt:39-56`
- **To add scoring criteria**: Edit `problems/base_set/{problem}/critic.txt`
- **To debug failures**: Check `test_UUID_results/error_log`

---

## Naming Convention Improvements (Recommended)

Current naming is inconsistent. Suggested improvements:

### Language Spec Files

```
Current: WGSL_CONSTRAINT_SPEC.md
Proposed: constraint_spec.wgsl.md (for WGSL)
          constraint_spec.glsl.md (for GLSL)
          constraint_spec.hlsl.md (for HLSL)
```

**Rationale**: Extension-based naming makes it clear which language the spec applies to.

### Prompt Templates

```
Current: prompt_template.txt
Proposed: prompt_template.wgsl.txt
          prompt_template.glsl.txt
          prompt_template.hlsl.txt
```

**Rationale**: Enables multi-language support with clear file selection.

### Harness Variants

```
Current: shader_harness/ (single implementation)
Proposed: shader_harness_wgpu/ (current wgpu implementation)
          shader_harness_opengl/ (future OpenGL variant)
          shader_harness_vulkan/ (future native Vulkan)
```

**Rationale**: Allows A/B testing of different rendering backends.

---

## Testing the Architecture

### Verify Separation of Concerns

1. **Test LANGUAGE_SPEC swap**: Replace prompt_template.txt with GLSL version, verify compiler fails (expected)
2. **Test COMPILER swap**: Modify main.rs to use SPIR-V source, verify it compiles
3. **Test HARNESS_FN stability**: Change output resolution, verify PNG dimensions change

### Validation Checklist

- [ ] LLM generates WGSL with correct entry points
- [ ] Cargo compilation succeeds for valid WGSL
- [ ] Binary renders PNG to correct dimensions
- [ ] Judge evaluation produces 5 scores (1-100 scale)
- [ ] Path resolution works from any working directory

---

## Migration Completion Status

### ✅ Completed

- [x] Remove GLSL/Shadertoy support
- [x] Lock WGSL-only pipeline
- [x] Create authoritative ABI contract (WGSL_CONSTRAINT_SPEC.md)
- [x] Update prompt template with constraints
- [x] Fix path resolution bugs (3 critical fixes)
- [x] Document architecture (this file)

### ⚠️ Pending Validation

- [ ] Run full 100-problem benchmark to verify migration
- [ ] Test compilation issue (see TECHNICAL_DEBT.md)
- [ ] Validate LLM compliance with constraints
- [ ] Measure success rate vs GLSL baseline

### 🔮 Future Work (Optional)

- [ ] Add uniform support (time, mouse, resolution)
- [ ] Implement compute shader support
- [ ] Add GLSL compatibility layer for ablation experiments
- [ ] Create reference image library for metric validation
- [ ] Implement video output for animated shaders

---

## Key Lessons Learned

1. **Constraints beat training data**: Strict WGSL specification is more effective than relying on LLM's familiarity with GLSL

2. **Absolute paths prevent async bugs**: All three path resolution bugs had the same root cause (relative paths in async contexts)

3. **Structured evaluation scales**: The 5-score system (S1-S5, 1-100 each) provides granular feedback without overwhelming judges

4. **ABI contracts enable swapping**: Clean separation between LANGUAGE_SPEC, COMPILER, and HARNESS_FN makes ablation experiments tractable

5. **Comments are documentation**: Critical decisions marked with 🔒, CRITICAL FIX, and WGSL_ABI_REFERENCE make the codebase self-documenting

---

**Last Updated**: October 24, 2025
**Maintainer**: See CLAUDE.md for project context
**Related Docs**: TECHNICAL_DEBT.md, ABLATION_EXPERIMENTS.md, WGSL_CONSTRAINT_SPEC.md
