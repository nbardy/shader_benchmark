# CRITICAL: WGSL Spec Naming Conflict Bug

**Date:** October 24, 2025
**Priority:** HIGH - MUST FIX IN SPEC
**Status:** IDENTIFIED - REQUIRES SPEC UPDATE

---

## Bug Description

The WGSL_CONSTRAINT_SPEC.md section 2.3 contains a **syntactically invalid** example that will cause compilation failures in all WGSL implementations.

### Invalid Example (Current Spec)

```wgsl
@group(0) @binding(0) var<uniform> Params: Params;

struct Params {
    resolution: vec2<f32>,
}
```

**Error:**
```
Shader parsing error: redefinition of `Params`
   ┌─ wgsl:1:36
   │
1  │ @group(0) @binding(0) var<uniform> Params: Params;
   │                                    ^^^^^^ previous definition of `Params`
2  │
3  │ struct Params {
   │        ^^^^^^ redefinition of `Params`
```

### Why This Fails

WGSL **does not allow** the same identifier to be used for both:
1. A variable name (`var<uniform> Params`)
2. A type name (`struct Params`)

This is a fundamental naming collision - WGSL treats both as declarations in the same namespace.

---

## Correct Pattern

### Option 1: Lowercase Variable Name (Recommended)

```wgsl
struct Params {
    resolution: vec2<f32>,
}

@group(0) @binding(0) var<uniform> params: Params;

// Usage in fragment shader:
let uv = pos.xy / params.resolution;  // lowercase 'params'
```

**Why This is Better:**
- Follows Rust/C++ convention: types use PascalCase, variables use snake_case
- Clear distinction between type (`Params`) and instance (`params`)
- Matches wgpu Rust examples and best practices

### Option 2: Different Type Name

```wgsl
struct ParamsStruct {
    resolution: vec2<f32>,
}

@group(0) @binding(0) var<uniform> Params: ParamsStruct;

// Usage:
let uv = pos.xy / Params.resolution;  // uppercase 'Params'
```

**Why This is Less Preferred:**
- Redundant naming (`ParamsStruct` vs `Params`)
- Less idiomatic in WGSL/Rust ecosystems
- Increases verbosity without adding clarity

---

## Impact on Existing Code

### Files That Need Updates

1. **`/Users/nicholasbardy/git/shader_benchmark/WGSL_CONSTRAINT_SPEC.md`**
   - Section 2.3: Uniform Binding Contract (lines 85-93)
   - Section 7.1: Normalize Coordinates (line 248)
   - Section 8.2: Expected XML Output Format (lines 304-318)

2. **Test Shaders**
   - `/Users/nicholasbardy/git/shader_benchmark/shader_harness/shaders/test_uniform.wgsl` ✅ Already uses `params: ParamsStruct` (compliant)
   - `/Users/nicholasbardy/git/shader_benchmark/shader_harness/shaders/spec_compliant_test.wgsl` ✅ Fixed to use `params: Params`

3. **LLM Prompts** (Future)
   - Any prompt templates that reference the spec will need updating
   - Generated shaders following old spec will fail compilation

---

## Recommended Spec Fix

### Update Section 2.3 to:

```wgsl
struct Params {
    resolution: vec2<f32>,
    // Add additional fields as needed
    // All fields MUST be f32, vec2<f32>, vec3<f32>, or vec4<f32>
}

@group(0) @binding(0) var<uniform> params: Params;
```

**Invariants:**
- Group: **MUST be** `@group(0)`
- Binding: **MUST be** `@binding(0)`
- Variable name: **MUST be** `params` (lowercase)
- Type name: **MUST be** `Params` (uppercase)
- Field types: **MUST be** explicit (`f32`, `vec2<f32>`, `vec3<f32>`, `vec4<f32>`)

**Guaranteed Fields:**
- `resolution: vec2<f32>` - Viewport dimensions in pixels (always provided by harness)

**How to Use:**
```wgsl
let uv = pos.xy / params.resolution;  // lowercase 'params'
let color = vec3<f32>(uv, 0.5);
fragColor = vec4<f32>(color, 1.0);
```

### Update Section 7.1 to:

```wgsl
let uv = pos.xy / params.resolution;  // Changed from Params to params
```

### Update Section 8.2 to:

```xml
<shader file="shader.wgsl">
@vertex
fn vs_main(@builtin(vertex_index) vertex_index: u32) -> @builtin(position) vec4<f32> {
    let vertex_id = vertex_index % 3u;
    let x = f32(i32(vertex_id & 1u) << 2u) - 1.0;
    let y = f32(i32((vertex_id >> 1u) & 1u) << 2u) - 1.0;
    return vec4<f32>(x, y, 0.0, 1.0);
}

struct Params {
    resolution: vec2<f32>,
    // Your fields here
}

@group(0) @binding(0) var<uniform> params: Params;

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let uv = pos.xy / params.resolution;

    // Your visualization logic here

    return vec4<f32>(color, 1.0);
}
</shader>
```

---

## Testing Results

### Before Fix (Spec Example)

```bash
$ cargo run -- --shader shaders/spec_compliant_test.wgsl --output spec_test.png --size 1600

thread 'main' panicked at wgpu_core.rs:2996:5:
wgpu error: Validation Error
Shader 'user_shader' parsing error: redefinition of `Params`
```

### After Fix (Lowercase Variable Name)

```bash
$ cargo run -- --shader shaders/spec_compliant_test.wgsl --output spec_test.png --size 1600
GPU 5.803 ms   | CPU 997.579 ms   | wrote "spec_test.png"
✅ SUCCESS
```

---

## Implications for LLM Generation

### Current State

If LLMs follow the current spec exactly, **100% of generated shaders will fail compilation** due to this naming conflict.

### After Spec Fix

LLMs will generate syntactically valid shaders that compile and run correctly.

### Migration Strategy

1. **Update WGSL_CONSTRAINT_SPEC.md** (all sections mentioned above)
2. **Test with existing problems** - verify none use the invalid pattern
3. **Update LLM prompts** - ensure they reference corrected spec
4. **Re-run benchmark** - confirm no regressions

---

## Why This Wasn't Caught Earlier

1. **No existing shaders used uniforms** - Previous harness didn't provide uniform buffers
2. **Spec was written before implementation** - Not validated against actual WGSL compiler
3. **Copy-paste from similar syntax** - May have been adapted from GLSL (where `uniform Params Params;` is also invalid but less obvious)

---

## Action Items

- [ ] Update WGSL_CONSTRAINT_SPEC.md section 2.3
- [ ] Update WGSL_CONSTRAINT_SPEC.md section 7.1
- [ ] Update WGSL_CONSTRAINT_SPEC.md section 8.2
- [ ] Search for any other references to `Params.resolution` (should be `params.resolution`)
- [ ] Add validation test to ensure spec examples compile
- [ ] Document naming convention in spec (PascalCase for types, snake_case for variables)

---

## Lessons Learned

### What We Learned

**Spec examples MUST be runnable code.** The spec contained syntactically invalid code that would have broken all shader generation if followed literally.

### How to Prevent This

1. **Test all spec examples** - Every code block in the spec should be a valid, compilable shader
2. **Automated validation** - Add CI test that compiles all spec examples
3. **Reference implementations** - Maintain test shaders that exactly match spec format

### Where to Add Comments

1. **WGSL_CONSTRAINT_SPEC.md** - Add note about naming conventions (types vs variables)
2. **Test shaders** - Comment why `params: Params` not `Params: Params`
3. **Implementation docs** - Document case sensitivity and namespace rules

---

## Summary

**Critical bug identified:** WGSL_CONSTRAINT_SPEC.md section 2.3 uses invalid syntax that causes compilation failures.

**Root cause:** Variable and type cannot share the same name in WGSL.

**Solution:** Change variable name from `Params` to `params` (lowercase).

**Impact:** All sections of spec that reference uniform usage need updating.

**Status:** Implementation already supports correct pattern; spec documentation needs fixes.

**Next steps:** Update spec, test all examples, validate against WGSL compiler.
