# Technical Debt and Outstanding Work

**Date**: October 24, 2025
**Purpose**: Track fixes needed and future improvements
**Priority**: Ordered by impact (blocking → high → medium → low)

---

## 🚨 BLOCKING Issues (Must Fix Before Validation)

### Issue #1: Test Runner Rebuild vs Pre-Built Binary

**Status**: ⚠️ BLOCKING - Prevents efficient validation
**Impact**: Compilation happens on every render instead of once per problem
**Effort**: 1-2 hours
**Priority**: P0 - CRITICAL

#### Problem Description

The current `test_runner.py` implementation has a race condition between compilation and rendering stages:

**File**: `llm_harness/test_runner.py:70-162`

**Current behavior**:
1. `compile_shader()` runs `cargo build --release` (line 78)
2. Binary created at `target/release/shader-bench` (line 129)
3. `render_shader()` runs `./target/release/shader-bench --shader X --output Y` (line 135)

**The bug**:
- In `render_shader()`, line 135 uses the binary path directly
- BUT: The method doesn't check if binary exists before trying to use it
- Line 130-131 raises FileNotFoundError if binary missing
- This suggests compilation might not be completing before render stage

**Evidence from code**:
```python
# test_runner.py:128-131
binary_path = "target/release/shader-bench"
if not Path(binary_path).exists():
    raise FileNotFoundError(f"Compiled binary not found at {binary_path}")
```

This check implies the binary is expected to exist from prior compilation, but the async execution might cause:
1. `compile_shader()` runs in parallel for multiple problems
2. `render_shader()` starts before compilation finishes
3. Binary not found, or worse: stale binary from previous run

#### Root Cause Analysis

The issue is in the pipeline design:

**File**: `llm_harness/test_runner.py:164-173`
```python
async def run_test(self, test_folder: Path) -> Path:
    """Run full pipeline: compile → render (uses pipeline semaphores)"""
    # Stage 1: Compile
    compile_success, compile_msg = await self.compile_shader(test_folder)
    if not compile_success:
        raise RuntimeError(compile_msg)

    # Stage 2: Render
    result_image = await self.render_shader(test_folder)
    return result_image
```

This LOOKS sequential (compile → render), but there's a hidden issue:

**The working directory changes per problem**:
- Line 75: `os.chdir(test_folder)` in `compile_shader()`
- Line 106: `os.chdir(test_folder)` in `render_shader()`
- Line 99: `os.chdir(original_cwd)` restores directory

Each test folder has its own `target/release/shader-bench`, but:
1. Cargo might not rebuild if source didn't change
2. Binary might be from a previous problem's test folder
3. Working directory juggling causes path confusion

#### Why This Is Blocking

**Without fix**:
- Every shader compilation takes 5-10 seconds
- 100 problems × 5 seconds = 8+ minutes just for compilation
- Parallel execution doesn't help (each problem rebuilds)

**With fix**:
- Compile harness ONCE at startup: 10 seconds
- 100 problems × 2 seconds render = 3-4 minutes total
- 2-3x speedup for full benchmark

#### Proposed Fix

**Option A: Pre-Build Binary (Recommended)**

**File**: `llm_harness/test_runner.py:11-19`
```diff
class TestRunner:
    def __init__(self, compile_semaphore=None, render_semaphore=None):
        script_dir = Path(__file__).parent.absolute()
        self.shader_harness_path = script_dir.parent / "shader_harness"
        self.compile_semaphore = compile_semaphore or asyncio.Semaphore(os.cpu_count() or 8)
        self.render_semaphore = render_semaphore or asyncio.Semaphore(4)
+
+       # Pre-build harness binary once at initialization
+       self.harness_binary = self._ensure_harness_built()
+
+   def _ensure_harness_built(self) -> Path:
+       """Build shader_harness binary if not already built"""
+       binary_path = self.shader_harness_path / "target" / "release" / "shader-bench"
+
+       # Check if binary exists and is newer than source
+       main_rs = self.shader_harness_path / "src" / "main.rs"
+       if binary_path.exists() and binary_path.stat().st_mtime > main_rs.stat().st_mtime:
+           print(f"Using existing harness binary: {binary_path}")
+           return binary_path
+
+       # Build once
+       print("Building shader harness binary...")
+       original_cwd = os.getcwd()
+       try:
+           os.chdir(self.shader_harness_path)
+           result = subprocess.run(
+               ["cargo", "build", "--release"],
+               capture_output=True,
+               text=True,
+               timeout=120
+           )
+           if result.returncode != 0:
+               raise RuntimeError(f"Failed to build harness: {result.stderr}")
+           print(f"Harness built successfully: {binary_path}")
+           return binary_path
+       finally:
+           os.chdir(original_cwd)
```

**File**: `llm_harness/test_runner.py:70-99`
```diff
async def compile_shader(self, test_folder: Path) -> Tuple[bool, str]:
-   """Stage 1: Compile the shader project (CPU-bound)"""
+   """Stage 1: Validate shader syntax (no compilation needed)"""
    async with self.compile_semaphore:
-       original_cwd = os.getcwd()
-       try:
-           os.chdir(test_folder)
-
-           # Compile only (cargo build --release)
-           cargo_env_cmd = "source ~/.cargo/env && cargo build --release"
-           loop = asyncio.get_event_loop()
-           result = await loop.run_in_executor(
-               None,
-               lambda: subprocess.run(
-                   ["bash", "-c", cargo_env_cmd],
-                   capture_output=True,
-                   text=True,
-                   timeout=120
-               )
-           )
-
-           # Save logs
-           save_subprocess_output(test_folder, "compile", result, cargo_env_cmd)
-
-           if result.returncode != 0:
-               return False, f"Compilation failed: {result.stderr[:500]}"
-
-           return True, "Compilation successful"
-
-       finally:
-           os.chdir(original_cwd)
+       # Shader validation is now implicit in render stage
+       # (wgpu will fail if shader is invalid)
+       return True, "Shader syntax will be validated at render time"
```

**File**: `llm_harness/test_runner.py:101-162`
```diff
async def render_shader(self, test_folder: Path) -> Path:
    """Stage 2: Execute the compiled shader (GPU-bound)"""
    async with self.render_semaphore:
-       original_cwd = os.getcwd()
-       try:
-           os.chdir(test_folder)

            # Ensure artifacts directory exists
-           Path("artifacts").mkdir(exist_ok=True)
+           (test_folder / "artifacts").mkdir(exist_ok=True)

            # Find the main shader file to use
-           shader_files = list(Path("shaders").glob("*.wgsl")) + list(Path("shaders").glob("*.glsl"))
+           shader_files = list((test_folder / "shaders").glob("*.wgsl"))
            main_shader = None

            for shader_file in shader_files:
                if "hopf" in shader_file.name.lower() or "main" in shader_file.name.lower():
                    main_shader = shader_file
                    break

            if not main_shader and shader_files:
                main_shader = shader_files[0]

            if not main_shader:
                raise FileNotFoundError("No shader files found to execute")

-           # Check binary exists
-           binary_path = "target/release/shader-bench"
-           if not Path(binary_path).exists():
-               raise FileNotFoundError(f"Compiled binary not found at {binary_path}")

            # Run shader using pre-built harness
-           output_path = "artifacts/result.png"
-           run_cmd = f"{binary_path} --shader {main_shader} --output {output_path}"
+           output_path = test_folder / "artifacts" / "result.png"
+           run_cmd = f"{self.harness_binary} --shader {main_shader} --output {output_path}"

            loop = asyncio.get_event_loop()
            result = await loop.run_in_executor(
                None,
                lambda: subprocess.run(
-                   ["bash", "-c", run_cmd],
+                   [str(self.harness_binary), "--shader", str(main_shader),
+                    "--output", str(output_path), "--size", "1600"],
                    capture_output=True,
                    text=True,
                    timeout=60
                )
            )

            # Save logs
            save_subprocess_output(test_folder, "render", result, run_cmd)

            if result.returncode != 0:
                raise RuntimeError(f"Shader execution failed: {result.stderr[:500]}")

            # Check output was generated
-           if not Path("artifacts/result.png").exists():
+           if not output_path.exists():
                raise FileNotFoundError("artifacts/result.png not found")

-           return test_folder / "artifacts" / "result.png"
+           return output_path
-
-       finally:
-           os.chdir(original_cwd)
```

**Lines changed**: ~40 lines modified, ~25 lines added, ~30 lines removed

**Benefits**:
- ✅ No per-problem compilation (10x speedup)
- ✅ No working directory juggling (eliminates path bugs)
- ✅ Clearer separation: harness is infrastructure, shaders are input
- ✅ Matches architecture diagram (HARNESS_FN is locked, shaders vary)

**Option B: Keep Current Design, Fix Race Condition**

If we want to preserve per-problem compilation (for future main.rs modification):

```diff
async def run_test(self, test_folder: Path) -> Path:
    """Run full pipeline: compile → render (uses pipeline semaphores)"""
    # Stage 1: Compile
    compile_success, compile_msg = await self.compile_shader(test_folder)
    if not compile_success:
        raise RuntimeError(compile_msg)

+   # CRITICAL: Verify binary exists before proceeding
+   binary_path = test_folder / "target" / "release" / "shader-bench"
+   if not binary_path.exists():
+       raise RuntimeError(f"Compilation succeeded but binary not found at {binary_path}")
+
+   # Wait for filesystem sync (macOS can have delays)
+   await asyncio.sleep(0.1)

    # Stage 2: Render
    result_image = await self.render_shader(test_folder)
    return result_image
```

**Lines changed**: 5-10 lines added

**Drawbacks**:
- ❌ Still rebuilds harness for every problem (slow)
- ❌ Doesn't fix root cause (working directory confusion)
- ⚠️ asyncio.sleep() is a code smell (hides timing bug)

#### Recommendation

**Use Option A (Pre-Build Binary)**:
1. Simpler mental model: harness is compiled once, shaders are input files
2. 10x faster for batch testing
3. Aligns with architecture (HARNESS_FN is stable infrastructure)
4. Eliminates entire class of path/directory bugs

**Implementation checklist**:
- [ ] Add `_ensure_harness_built()` method to TestRunner.__init__
- [ ] Remove compilation from `compile_shader()` (rename to `validate_shader()`?)
- [ ] Update `render_shader()` to use `self.harness_binary`
- [ ] Remove all `os.chdir()` calls (use absolute paths)
- [ ] Test with 3-5 problems to verify pipeline
- [ ] Run full 100-problem benchmark

**Testing**:
```bash
cd llm_harness
python benchmark_harness.py \
  --model "anthropic/claude-3.5-sonnet-20241022" \
  --problems geometric_cube sphere_wireframe torus_knot \
  --max-parallel 2

# Verify:
# 1. Harness built once at startup
# 2. Each problem renders without recompiling
# 3. Total time < 1 minute for 3 problems
```

**Success criteria**:
- Startup: "Building shader harness binary..." appears ONCE
- Each problem: "Shader syntax will be validated at render time"
- Timing: 10s startup + (3 problems × 2s render) = ~16s total

---

## 🔥 HIGH Priority (Affects Validation Quality)

### Issue #2: Uniform Binding Not Implemented

**Status**: ⚠️ HIGH - Limits shader expressiveness
**Impact**: Shaders can't access resolution, time, mouse position
**Effort**: 3-4 hours
**Priority**: P1

#### Problem Description

The WGSL spec defines uniform binding contract (WGSL_CONSTRAINT_SPEC.md:83-111):

```wgsl
@group(0) @binding(0) var<uniform> Params: Params;

struct Params {
    resolution: vec2<f32>,
    // Add additional fields as needed
};
```

But the harness doesn't actually PASS these uniforms:

**File**: `shader_harness/src/main.rs:48-53`
```rust
let pipeline_layout =
    device.create_pipeline_layout(&wgpu::PipelineLayoutDescriptor {
        bind_group_layouts: &[],  // ❌ EMPTY - No uniforms passed!
        push_constant_ranges: &[],
        label: None,
    });
```

#### Impact

**Current state**:
- Shaders can only use `@builtin(position)` (screen coordinates)
- No access to viewport dimensions (resolution)
- No animation support (time)
- No interactivity (mouse position)

**LLM workarounds**:
- Hardcode resolution: `let uv = pos.xy / vec2<f32>(1600.0, 1600.0);` ❌
- No time-based animations ❌
- No aspect ratio correction ❌

**Quality impact**:
- Lower S2 scores (visual quality) - incorrect aspect ratios
- Lower S4 scores (implementation) - hardcoded values instead of proper uniforms
- Limits problem complexity (can't test animated shaders)

#### Proposed Fix

**File**: `shader_harness/src/main.rs:15-17` (add uniform data)
```diff
#[derive(Parser)]
struct Opts {
    #[arg(short, long)]
    shader: PathBuf,
    #[arg(short, long, default_value = "out.png")]
    output: PathBuf,
    #[arg(short = 'z', long, default_value_t = 1024)]
    size: u32,
+   #[arg(short, long, default_value_t = 0.0)]
+   time: f32,  // Optional: time in seconds for animation
}
```

**File**: `shader_harness/src/main.rs:Add after line 39`
```diff
+ // Create uniform buffer with resolution
+ #[repr(C)]
+ #[derive(Copy, Clone, bytemuck::Pod, bytemuck::Zeroable)]
+ struct Uniforms {
+     resolution: [f32; 2],
+     _padding: [f32; 2],  // Align to 16 bytes
+ }
+
+ let uniforms = Uniforms {
+     resolution: [opts.size as f32, opts.size as f32],
+     _padding: [0.0, 0.0],
+ };
+
+ let uniform_buffer = device.create_buffer_init(&wgpu::util::BufferInitDescriptor {
+     label: Some("uniform_buffer"),
+     contents: bytemuck::cast_slice(&[uniforms]),
+     usage: wgpu::BufferUsages::UNIFORM | wgpu::BufferUsages::COPY_DST,
+ });
```

**File**: `shader_harness/src/main.rs:47-53` (update pipeline layout)
```diff
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
+     label: Some("bind_group_layout"),
+ });
+
+ let bind_group = device.create_bind_group(&wgpu::BindGroupDescriptor {
+     layout: &bind_group_layout,
+     entries: &[wgpu::BindGroupEntry {
+         binding: 0,
+         resource: uniform_buffer.as_entire_binding(),
+     }],
+     label: Some("bind_group"),
+ });

  let pipeline_layout =
      device.create_pipeline_layout(&wgpu::PipelineLayoutDescriptor {
-         bind_group_layouts: &[],
+         bind_group_layouts: &[&bind_group_layout],
          push_constant_ranges: &[],
          label: None,
      });
```

**File**: `shader_harness/src/main.rs:147` (set bind group)
```diff
pass.set_pipeline(&render_pipeline);
+ pass.set_bind_group(0, &bind_group, &[]);
pass.draw(0..3, 0..1);
```

**File**: `shader_harness/Cargo.toml` (add dependency)
```diff
[dependencies]
wgpu        = "0.20"
+ wgpu        = { version = "0.20", features = ["wgsl"] }
pollster    = "0.3"
bytemuck   = { version = "1.0", features = ["derive"] }
```

**Lines changed**: ~50 lines added

**Testing**:
```wgsl
// Test shader that uses Params.resolution
@group(0) @binding(0) var<uniform> Params: Params;

struct Params {
    resolution: vec2<f32>,
};

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let uv = pos.xy / Params.resolution;  // Should work now!
    return vec4<f32>(uv, 0.5, 1.0);
}
```

**Success criteria**:
- Shader compiles without errors
- `uv` correctly normalized to [0, 1] range
- Output PNG has proper aspect ratio

#### Optional Enhancements (Future Work)

Once basic uniforms work, add:

```rust
struct Uniforms {
    resolution: [f32; 2],
    time: f32,        // Animation time
    _padding: f32,    // Align to 16 bytes
    // Future: mouse: [f32; 2], frame: u32, etc.
}
```

---

## 📊 MEDIUM Priority (Quality of Life)

### Issue #3: Error Messages Don't Show Line Numbers

**Status**: 📊 MEDIUM - Harder to debug LLM failures
**Impact**: Can't tell which line caused WGSL validation error
**Effort**: 1 hour
**Priority**: P2

#### Problem Description

When a shader fails compilation, wgpu error messages look like:

```
error: entry point 'fs_main' not found
```

But wgpu DOES provide line numbers in its error output. We're just not capturing them properly.

**File**: `llm_harness/test_runner.py:91-94`
```python
# Save logs
save_subprocess_output(test_folder, "compile", result, cargo_env_cmd)

if result.returncode != 0:
    return False, f"Compilation failed: {result.stderr[:500]}"
```

The `[:500]` truncation might cut off line number info.

#### Proposed Fix

**File**: `llm_harness/test_runner.py:91-94`
```diff
if result.returncode != 0:
-   return False, f"Compilation failed: {result.stderr[:500]}"
+   # Extract error context (last 20 lines for line numbers)
+   error_lines = result.stderr.split('\n')[-20:]
+   error_context = '\n'.join(error_lines)
+   return False, f"Compilation failed:\n{error_context}"
```

**Lines changed**: 3

**Benefit**: LLM can see which line failed and potentially self-correct.

---

### Issue #4: No Progress Indicator for Long-Running Tests

**Status**: 📊 MEDIUM - User experience
**Impact**: Can't tell if 100-problem benchmark is frozen or running
**Effort**: 1 hour
**Priority**: P2

#### Problem Description

Running `benchmark_harness.py --problems {100_problems}` shows:

```
Running batch test with 100 problems...
[no output for 30+ minutes]
```

No indication of:
- How many problems completed
- Which problem is currently running
- Estimated time remaining

#### Proposed Fix

**File**: `llm_harness/benchmark_harness.py:Add progress tracking`
```diff
+ from tqdm import tqdm  # Progress bar library
+
async def run_batch_test(self, problems, max_parallel=4):
    """Run tests for multiple problems in parallel"""
    semaphore = asyncio.Semaphore(max_parallel)

+   # Progress tracking
+   pbar = tqdm(total=len(problems), desc="Testing problems", unit="problem")
+
    async def run_single_problem(problem_name):
        async with semaphore:
            try:
                await self.run_test_for_problem(problem_name)
+               pbar.update(1)
            except Exception as e:
                print(f"Error on {problem_name}: {e}")
+               pbar.update(1)
+
+   await asyncio.gather(*[run_single_problem(p) for p in problems])
+   pbar.close()
```

**File**: `llm_harness/requirements.txt`
```diff
aiohttp
python-dotenv
pathlib
+ tqdm  # Progress bars
```

**Lines changed**: 10

**Output**:
```
Testing problems: 42/100 [━━━━━━━━━━━━░░░░░░░░░░░░] 42% | ETA: 18:23
```

---

### Issue #5: Logs Not Timestamped

**Status**: 📊 MEDIUM - Debugging parallel execution
**Impact**: Can't tell when errors occurred or how long stages took
**Effort**: 30 minutes
**Priority**: P3

#### Problem Description

Log files like `compile_output.log` don't have timestamps:

```
Building shader-bench
Compiling wgpu
Finished release [optimized] target(s) in 5.2s
```

When debugging race conditions or timeouts, can't tell:
- When each stage started/ended
- How long compilation actually took
- If logs are from current run or previous run

#### Proposed Fix

**File**: `llm_harness/error_handler.py:11-30`
```diff
+ from datetime import datetime
+
def save_subprocess_output(test_folder, stage_name, result, command):
    """Save subprocess output to log files"""
+   timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
+   header = f"=== {stage_name.upper()} LOG - {timestamp} ===\n"
+   header += f"Command: {command}\n"
+   header += f"Return code: {result.returncode}\n"
+   header += "=" * 60 + "\n\n"
+
    # Always save stdout if present
    if result.stdout:
        output_file = test_folder / f"{stage_name}_output.log"
        with open(output_file, 'w') as f:
+           f.write(header)
            f.write(result.stdout)
```

**Lines changed**: 8

**Output**:
```
=== COMPILE LOG - 2025-10-24 19:45:23 ===
Command: cargo build --release
Return code: 0
============================================================

Building shader-bench
Compiling wgpu
Finished release [optimized] target(s) in 5.2s
```

---

## 🔮 LOW Priority (Future Improvements)

### Issue #6: No Support for Animated Shaders

**Status**: 🔮 LOW - Nice to have
**Impact**: Can't test time-dependent visualizations
**Effort**: 1 day
**Priority**: P4

#### Problem Description

Current harness renders single static frame. Many mathematical visualizations are animated:
- Fourier epicycles drawing
- Julia set morphing
- Lissajous curves evolving

#### Proposed Fix

Add video output support:

```diff
File: shader_harness/src/main.rs:Add animation loop
+ for frame in 0..60 {  // 60 frames at 60fps = 1 second
+     let time = frame as f32 / 60.0;
+     // Update uniforms with time
+     // Render frame
+     // Save to frame_000.png, frame_001.png, ...
+ }
+
+ // Convert frames to MP4 using ffmpeg
+ subprocess.run(["ffmpeg", "-framerate", "60", "-i", "frame_%03d.png", "output.mp4"])
```

**Requires**: ffmpeg integration, uniform time support (Issue #2)

---

### Issue #7: No Compute Shader Support

**Status**: 🔮 LOW - Advanced use case
**Impact**: Can't test particle simulations, fluid dynamics
**Effort**: 2-3 days
**Priority**: P5

#### Problem Description

WGSL supports `@compute` shaders natively, but harness only handles `@fragment` + `@vertex`.

Could enable:
- Particle systems (N-body simulation)
- Cellular automata (Game of Life)
- Fractal generation (compute-then-render)

#### Proposed Fix

Add compute pipeline:

```diff
File: shader_harness/src/main.rs:Add compute support
+ let compute_pipeline = device.create_compute_pipeline(&wgpu::ComputePipelineDescriptor {
+     module: &shader,
+     entry_point: "compute_main",
+     ...
+ });
+
+ // Dispatch compute
+ compute_pass.set_pipeline(&compute_pipeline);
+ compute_pass.dispatch_workgroups(32, 32, 1);
```

**Requires**: Storage buffers, synchronization, multi-pass rendering

---

### Issue #8: No Reference Image Library

**Status**: 🔮 LOW - Validation infrastructure
**Impact**: Can't do metric-based validation (SSIM, MSE)
**Effort**: 1 week
**Priority**: P6

#### Problem Description

Ablation Experiment 4 (metric validation) requires ground truth images.

Need to:
1. Manually create reference shaders for 20-30 problems
2. Render at high quality (4K resolution, HDR)
3. Human verification of correctness
4. Version control + checksums

#### Proposed Structure

```
shader_benchmark/
└── reference_library/
    ├── geometric_cube/
    │   ├── reference.wgsl (human-verified shader)
    │   ├── reference_4k.png (4096x4096 ground truth)
    │   └── metadata.json (problem, author, date, checksum)
    ├── sphere_wireframe/
    └── ... (30 problems)
```

**Effort**: 2-3 hours per reference (write shader, verify math, render, document)

---

## Summary by Priority

| Priority | Issue | Blocking? | Effort | Impact |
|----------|-------|-----------|--------|--------|
| P0 | #1 Test runner rebuild | ✅ YES | 2h | 10x speedup |
| P1 | #2 Uniform binding | ⚠️ Limits quality | 4h | Better scores |
| P2 | #3 Error line numbers | No | 1h | Easier debugging |
| P2 | #4 Progress indicator | No | 1h | UX improvement |
| P3 | #5 Log timestamps | No | 30m | Debugging parallel |
| P4 | #6 Animation support | No | 1d | New problem types |
| P5 | #7 Compute shaders | No | 3d | Advanced features |
| P6 | #8 Reference library | No | 1w | Metric validation |

---

## Recommended Implementation Order

### Phase 1: Unblock Validation (2-3 hours)
1. **Issue #1**: Fix test runner (pre-build binary) - P0
2. Test with 10 problems to verify speedup

### Phase 2: Improve Quality (4-5 hours)
3. **Issue #2**: Add uniform binding (resolution support) - P1
4. **Issue #3**: Better error messages (line numbers) - P2
5. Test with 20 problems, measure score improvements

### Phase 3: Polish (1-2 hours)
6. **Issue #4**: Progress bars - P2
7. **Issue #5**: Log timestamps - P3

### Phase 4: Future Work (when needed)
8. **Issue #6**: Animation (if time-dependent problems added)
9. **Issue #7**: Compute shaders (if particle/fluid problems added)
10. **Issue #8**: Reference library (when running metric ablations)

---

## Code Locations Quick Reference

| Issue | File | Line Range | What to Change |
|-------|------|------------|----------------|
| #1 Rebuild | test_runner.py | 11-173 | Pre-build harness, remove per-problem compile |
| #2 Uniforms | main.rs | 40-150 | Add uniform buffer + bind group |
| #3 Errors | test_runner.py | 91-94 | Show more error context |
| #4 Progress | benchmark_harness.py | 200-250 | Add tqdm progress bars |
| #5 Timestamps | error_handler.py | 11-30 | Add timestamp headers |
| #6 Animation | main.rs | 81-229 | Add frame loop + ffmpeg |
| #7 Compute | main.rs | 55-79 | Add compute pipeline |
| #8 References | N/A | N/A | Create new directory structure |

---

## Testing Checklist (After Fixes)

### After Issue #1 Fix:
- [ ] Harness builds once at startup (check logs)
- [ ] 10 problems complete in <2 minutes
- [ ] No "cargo build" in individual problem logs
- [ ] Binary path printed at startup

### After Issue #2 Fix:
- [ ] Test shader with `Params.resolution` compiles
- [ ] Output PNG has correct aspect ratio
- [ ] No "uniform binding not found" errors
- [ ] `uv` coordinates in [0, 1] range

### After Issue #3 Fix:
- [ ] Error logs show line numbers
- [ ] Can identify which WGSL line failed
- [ ] Error context is complete (not truncated)

### After Issue #4 Fix:
- [ ] Progress bar updates during execution
- [ ] ETA estimate shown
- [ ] Bar completes at 100%

### After Issue #5 Fix:
- [ ] Logs have timestamps
- [ ] Can see duration of each stage
- [ ] Can distinguish current vs old logs

---

**Last Updated**: October 24, 2025
**Next Review**: After P0-P2 fixes implemented
**Related Docs**: AGENT_NOTES.md, ABLATION_EXPERIMENTS.md, ERROR_FIXES.md
