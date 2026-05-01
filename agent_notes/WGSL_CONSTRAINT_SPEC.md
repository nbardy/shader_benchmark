# WGSL ABI Contract Specification

**Date:** October 24, 2025
**Status:** Locked Format - Non-negotiable
**Purpose:** Define the strict interface contract for LLM-generated WGSL shaders

---

## 1. Strategic Rationale

After evaluating both GLSL (Shadertoy format) and WGSL for LLM shader generation, the project has committed exclusively to **WGSL with strict constraint-based prompting**. This decision was informed by:

### Why WGSL Over GLSL
- **Native Integration:** WGSL is the native target for wgpu (the harness runtime). GLSL requires shaderc translation layer.
- **Deterministic Bindings:** WGSL's `@group/@binding` syntax maps directly to Rust's `BindGroupLayoutEntry`, eliminating impedance mismatch.
- **Structured Error Messages:** wgpu provides actionable, structured error feedback that enables better LLM iteration loops.
- **Cross-Platform Guarantees:** WGSL compiles to identical behavior across Metal, Vulkan, and Direct3D 12.
- **Future-Proof:** WGSL is the WebGPU standard; compute shaders and advanced features are native.

### Why Constraints Beat Training Data
- Initial hypothesis: GLSL has 20+ years of training data; WGSL has only 3 years
- **Lesson learned:** Training data advantage doesn't overcome inability to specify output format strictly
- **Solution:** Lock WGSL with explicit ABI contract that LLMs must comply with
- **Principle:** "Compliance beats familiarity once you lock a format" (expert validation)

---

## 2. Fixed ABI Contract

The following interface is **NON-NEGOTIABLE** and must appear in every generated shader:

### 2.1 Vertex Shader Signature

```wgsl
@vertex
fn vs_main(@builtin(vertex_index) vertex_index: u32) -> @builtin(position) vec4<f32> {
    let vertex_id = vertex_index % 3u;
    let x = f32(i32(vertex_id & 1u) << 2u) - 1.0;
    let y = f32(i32((vertex_id >> 1u) & 1u) << 2u) - 1.0;
    return vec4<f32>(x, y, 0.0, 1.0);
}
```

**Invariants:**
- Function name: **MUST be** `vs_main` (exactly)
- Attribute: **MUST be** `@vertex` (not `@compute`, not `@fragment`)
- Parameter: **MUST be** `@builtin(vertex_index) vertex_index: u32` (exactly)
- Return type: **MUST be** `@builtin(position) vec4<f32>` (exactly)
- Logic: Generates full-screen triangle (3 vertices from vertex_index)

**Why this works:**
- The harness calls `draw(0..3, 0..1)` which provides 3 vertex invocations
- The modulo-3 loop ensures vertices map to the 3 vertices of a full-screen triangle
- The bit-shift math computes x,y in NDC space: (-1,-1), (3,-1), (-1,3)
- This single triangle covers the entire viewport

---

### 2.2 Fragment Shader Signature

```wgsl
@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    // Your fragment logic here
    // MUST return vec4<f32>
}
```

**Invariants:**
- Function name: **MUST be** `fs_main` (exactly)
- Attribute: **MUST be** `@fragment` (not `@compute`, not other)
- Parameter: **MUST be** `@builtin(position) pos: vec4<f32>` (exactly)
- Return type: **MUST be** `@location(0) vec4<f32>` (exactly)
- Content: LLM implements the actual visualization logic here

**Coordinate System:**
- Input `pos` has `.xy` in screen space: (0,0) to (viewport_width, viewport_height)
- Normalize as needed: `let uv = pos.xy / iResolution.xy;` (if using Params)
- Return RGBA color in range [0, 1]

---

### 2.3 Uniform Binding Contract

```wgsl
@group(0) @binding(0) var<uniform> Params: Params;

struct Params {
    resolution: vec2<f32>,
    // Add additional fields as needed
    // All fields MUST be f32, vec2<f32>, vec3<f32>, or vec4<f32>
}
```

**Invariants:**
- Group: **MUST be** `@group(0)`
- Binding: **MUST be** `@binding(0)`
- Variable name: **MUST be** `Params`
- Type name: **MUST be** `Params`
- Field types: **MUST be** explicit (`f32`, `vec2<f32>`, `vec3<f32>`, `vec4<f32>`)

**Guaranteed Fields:**
- `resolution: vec2<f32>` - Viewport dimensions in pixels (always provided by harness)

**How to Use:**
```wgsl
let uv = pos.xy / Params.resolution;
let color = vec3<f32>(uv, 0.5);
fragColor = vec4<f32>(color, 1.0);
```

---

## 3. Type Requirements (CRITICAL)

### 3.1 Explicit Type Syntax

All types **MUST** use explicit generic parameters. No implicit conversions.

**CORRECT:**
```wgsl
let color: vec3<f32> = vec3<f32>(0.5, 0.5, 0.5);
let a: f32 = 1.0;
let b: i32 = 1;
let c: u32 = 1u;
```

**INCORRECT:**
```wgsl
let color: vec3 = vec3(0.5, 0.5, 0.5);      // ❌ vec3 is incomplete
let a = 1.0;                                  // ❌ implicit type
let b = 1;                                    // ❌ no suffix
let c = 1;                                    // ❌ ambiguous integer type
```

### 3.2 Scalar Types

- Floating-point: Use **`f32`** (not `float`)
- Signed integers: Use **`i32`** (not `int`)
- Unsigned integers: Use **`u32`** (not `uint`)

**Examples:**
```wgsl
let x: f32 = 1.5;
let count: i32 = -5;
let index: u32 = 10u;
let negative: i32 = -1;
```

### 3.3 Vector Types

- `vec2<f32>`, `vec3<f32>`, `vec4<f32>` for floats
- `vec2<i32>`, `vec3<i32>`, `vec4<i32>` for signed integers
- `vec2<u32>`, `vec3<u32>`, `vec4<u32>` for unsigned integers

**Examples:**
```wgsl
let v: vec3<f32> = vec3<f32>(1.0, 2.0, 3.0);
let idx: vec2<u32> = vec2<u32>(0u, 1u);
let offset: vec3<i32> = vec3<i32>(-1, 0, 1);
```

### 3.4 Array Indexing

Array indexing **MUST** use explicit integer expressions:

**CORRECT:**
```wgsl
let arr: array<f32, 4> = array<f32, 4>(1.0, 2.0, 3.0, 4.0);
let idx: u32 = 2u;
let value = arr[idx];
let computed = arr[u32(i)];  // Cast explicitly
```

**INCORRECT:**
```wgsl
let value = arr[2];           // ❌ 2 is i32, needs u32
let value = arr[some_float];  // ❌ Cannot index with float
```

---

## 4. Address Spaces (CRITICAL)

WGSL is strict about address spaces. All variable declarations **MUST** include the address space.

### 4.1 Local Variables

```wgsl
var<function> x: f32 = 0.0;  // Function-local mutable
let y: f32 = 1.0;             // Function-local immutable (preferred)
```

**INCORRECT:**
```wgsl
var x: f32 = 0.0;  // ❌ Address space missing! Must be var<function>
```

### 4.2 Uniform Variables

Already defined in ABI contract:
```wgsl
@group(0) @binding(0) var<uniform> Params: Params;
```

---

## 5. Syntax You MUST NOT Use

The following WGSL features/GLSL patterns are **FORBIDDEN**:

| Feature | Why | Example |
|---------|-----|---------|
| `@vertex` in function body | Decorators only go on function declarations | ❌ `fn test() { @vertex }` |
| `@fragment` in function body | Same as above | ❌ `fn test() { @fragment }` |
| `var without address space` | WGSL requires explicit address space | ❌ `var x: f32 = 1.0;` |
| Implicit type conversions | WGSL is strict about types | ❌ `f32(1)` where 1 is i32 |
| `gl_*` variables | GLSL syntax - not valid in WGSL | ❌ `gl_FragCoord`, `gl_Position` |
| Preprocessor directives | WGSL has no preprocessor | ❌ `#ifdef`, `#define`, `#include` |
| `uniform` keyword | Use `@group/@binding` instead | ❌ `uniform vec3 color;` |
| `in`/`out` keywords | Use function parameters and return types | ❌ `in vec3 position;` |
| `void` keyword | Use no return type or explicit type | ❌ `fn test() -> void` |

---

## 6. Syntax You MUST Use

| Feature | When | Example |
|---------|------|---------|
| `@vertex` | Vertex shader entry point | ✅ `@vertex fn vs_main(...) {...}` |
| `@fragment` | Fragment shader entry point | ✅ `@fragment fn fs_main(...) {...}` |
| `@builtin(vertex_index)` | Vertex index in vertex shader | ✅ `@builtin(vertex_index) vertex_index: u32` |
| `@builtin(position)` | Fragment position in fragment shader | ✅ `@builtin(position) pos: vec4<f32>` |
| `@location(0)` | Output color target 0 | ✅ `@location(0) vec4<f32>` |
| `@group(0) @binding(0)` | Uniform binding | ✅ `@group(0) @binding(0) var<uniform>` |
| `var<function>` | Local mutable variables | ✅ `var<function> x: f32 = 0.0;` |
| `let` | Local immutable bindings | ✅ `let y = 1.0;` |
| `fn` keyword | Function declarations | ✅ `fn compute_color(...) {...}` |
| Explicit types | Type safety | ✅ `let x: f32 = 1.0;` |

---

## 7. Common Patterns for LLMs

### 7.1 Normalize Coordinates

```wgsl
let uv = pos.xy / Params.resolution;
```

### 7.2 Color Output

```wgsl
let color: vec3<f32> = vec3<f32>(uv.x, uv.y, 0.5);
return vec4<f32>(color, 1.0);
```

### 7.3 Distance Calculations

```wgsl
let d: f32 = length(uv - vec2<f32>(0.5, 0.5));
let col: vec3<f32> = vec3<f32>(d, d, d);
```

### 7.4 Loops (Full Dynamic Support in WGSL)

```wgsl
var sum: f32 = 0.0;
for (var i: u32 = 0u; i < 10u; i = i + 1u) {
    sum = sum + f32(i);
}
```

### 7.5 Conditionals

```wgsl
if (d < 0.1) {
    color = vec3<f32>(1.0, 0.0, 0.0);
} else {
    color = vec3<f32>(0.0, 1.0, 0.0);
}
```

---

## 8. File Format and Output

### 8.1 File Extension

Always output `.wgsl` (not `.glsl`, `.vert`, `.frag`)

### 8.2 Expected XML Output Format

```xml
<shader file="shader.wgsl">
@vertex
fn vs_main(@builtin(vertex_index) vertex_index: u32) -> @builtin(position) vec4<f32> {
    let vertex_id = vertex_index % 3u;
    let x = f32(i32(vertex_id & 1u) << 2u) - 1.0;
    let y = f32(i32((vertex_id >> 1u) & 1u) << 2u) - 1.0;
    return vec4<f32>(x, y, 0.0, 1.0);
}

@group(0) @binding(0) var<uniform> Params: Params;

struct Params {
    resolution: vec2<f32>,
    // Your fields here
};

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let uv = pos.xy / Params.resolution;

    // Your visualization logic here

    return vec4<f32>(color, 1.0);
}
</shader>
```

---

## 9. Validation Checklist

Before submitting a generated shader, verify:

- [ ] File extension is `.wgsl`
- [ ] `@vertex fn vs_main(...)` exists with exact signature
- [ ] `@fragment fn fs_main(...)` exists with exact signature
- [ ] `vs_main` returns the full-screen triangle (or doesn't modify it)
- [ ] `@group(0) @binding(0) var<uniform> Params: Params;` exists
- [ ] `struct Params { resolution: vec2<f32>, ... };` defined
- [ ] All types use explicit generics: `vec3<f32>`, not `vec3`
- [ ] All variables include address spaces: `var<function>`, not just `var`
- [ ] No GLSL syntax: no `uniform`, `in`, `out`, `gl_*`, `#ifdef`
- [ ] No implicit type conversions
- [ ] Fragment shader returns `vec4<f32>` at `@location(0)`

---

## 10. Implementation Notes for Maintainers

### Why This Works for LLMs

1. **Explicit Contract:** LLMs can reliably generate code within strict constraints
2. **Zero Impedance:** No GLSL→SPIR-V translation layer (shaderc removed)
3. **Native Execution:** Direct WGSL loading via `wgpu::ShaderSource::Wgsl`
4. **Structured Feedback:** Compilation errors from wgpu are actionable
5. **Dynamic Indexing:** WGSL supports full loops, no compile-time unrolling needed

### Files Involved

- **Harness:** `shader_harness/src/main.rs` - Direct WGSL loading, no compilation pipeline
- **Prompt:** `llm_harness/prompt_template.txt` - Specifies `.wgsl` format and constraints
- **Client:** `llm_harness/llm_client.py` - Loads main.rs as ABI reference
- **Dependency:** `shader_harness/Cargo.toml` - WGSL-only, no shaderc

### Comments in Code

Key code sections include comments explaining:
- Line 1-5 of `src/main.rs`: "WGSL only: locked format for deterministic LLM generation"
- Line 1-10 of `prompt_template.txt`: "🔒 WGSL FORMAT LOCK - STRICT ABI CONTRACT"
- Line 54-56 of `llm_client.py`: "CRITICAL: This loads ABI documentation for strict WGSL generation"

---

## 11. Future Extensibility

If the system needs to support additional features:

1. **Time Uniform:** Add `time: f32` to Params struct
2. **Multiple Textures:** Add `@group(0) @binding(1) var texture: texture_2d<f32>;`
3. **Compute Shaders:** WGSL supports native compute (`@compute`)
4. **Storage Buffers:** Add `@storage` bindings for read-write access

All extensions **MUST maintain the existing ABI contract** for backward compatibility.

---

## 12. References

- **WGSL Specification:** https://www.w3.org/TR/WGSL/
- **wgpu Documentation:** https://docs.rs/wgpu/latest/wgpu/
- **WebGPU Standard:** https://gpuweb.github.io/

---

**Document Status:** Locked
**Last Updated:** October 24, 2025
**Maintainer Note:** This is the authoritative ABI contract. Changes require explicit approval and version increment.
