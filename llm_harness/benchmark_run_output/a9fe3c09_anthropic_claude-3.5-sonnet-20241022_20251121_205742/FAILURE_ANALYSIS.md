# Failure Analysis Report

**Run ID:** a9fe3c09_anthropic_claude-3.5-sonnet-20241022_20251121_205742  
**Date:** 2025-11-21  
**Model:** anthropic/claude-3.5-sonnet-20241022  
**Success Rate:** 1/3 (33%)

---

## Summary of Failures

| Problem | Status | Primary Issue | Root Cause |
|---------|--------|---------------|------------|
| **geometric_cube** | ❌ Failed | Variable array indexing | WGSL constraint violation |
| **mandelbrot_set** | ❌ Not Processed | Missing from results | Likely early failure/timeout |
| **klein_bottle** | ✅ Success | Judge API error | API authentication issue |

---

## Issue #1: Geometric Cube - Shader Compilation Failure

### Error Sequence

**First Error (Initial Render):**
```
Shader 'user_shader' parsing error: redefinition of `Params`
   ┌─ wgsl:9:8
   │
 9 │ struct Params {
   │        ^^^^^^ previous definition of `Params`
   ·
15 │ @group(0) @binding(0) var<uniform> Params: Params;
   │                                    ^^^^^^ redefinition of `Params`
```

**Second Error (After Repair Attempt):**
```
Shader validation error: 
   ┌─ user_shader:74:36
   │
74 │         let rotated = rotate_point(vertices[i]);
   │                                    ^^^^^^^^^^^
   
The expression [44] may only be indexed by a constant
```

### Root Cause Analysis

#### Problem 1: Params Struct Naming Conflict
- **Issue:** The LLM generated `var<uniform> Params: Params` (uppercase variable name)
- **WGSL Constraint:** Variable names should be lowercase to avoid confusion with type names
- **Repair Attempt:** The shader parser tried to fix this by changing `Params` → `params`, but the repair didn't fully resolve the issue

#### Problem 2: Variable Array Indexing (Critical WGSL Constraint)
- **Issue:** Line 74 uses `vertices[i]` where `i` is a loop variable
- **WGSL Constraint:** Arrays can **only** be indexed with **constant** values, not variables
- **Why This Fails:** WGSL doesn't support dynamic array indexing for performance/portability reasons
- **LLM Mistake:** The model generated code that works in GLSL/HLSL but violates WGSL constraints

### Generated Code (Problematic Section)

```wgsl
// Line 58-67: Array definition (OK - constant indices)
let vertices = array<vec3<f32>, 8>(
    vec3<f32>(-1.0, -1.0, -1.0),  // 0
    vec3<f32>( 1.0, -1.0, -1.0),  // 1
    // ... more vertices
);

// Line 73-77: Loop with variable indexing (FAILS)
for (var i = 0u; i < 8u; i = i + 1u) {
    let rotated = rotate_point(vertices[i]);  // ❌ ERROR: i is not constant
    transformed[i] = rotated.xy;
    depths[i] = rotated.z;
}
```

### How to Fix This

**Option 1: Unroll the Loop (Manual Expansion)**
```wgsl
// Replace loop with explicit constant-indexed accesses
let rotated0 = rotate_point(vertices[0u]);
transformed[0u] = rotated0.xy;
depths[0u] = rotated0.z;

let rotated1 = rotate_point(vertices[1u]);
transformed[1u] = rotated1.xy;
depths[1u] = rotated1.z;
// ... repeat for all 8 vertices
```

**Option 2: Use Switch Statement**
```wgsl
// WGSL allows switch statements with constant cases
switch (i) {
    case 0u: { let rotated = rotate_point(vertices[0u]); transformed[0u] = rotated.xy; }
    case 1u: { let rotated = rotate_point(vertices[1u]); transformed[1u] = rotated.xy; }
    // ... etc
}
```

**Option 3: Restructure Algorithm**
- Use SDF (Signed Distance Function) approach instead of explicit vertex arrays
- Or use texture-based vertex storage (if supported)

### Why LLM Generated This

1. **Training Data Bias:** Most shader examples in LLM training data are GLSL/HLSL, which allow variable indexing
2. **Prompt Insufficient:** The prompt template may not emphasize this critical WGSL constraint strongly enough
3. **Pattern Matching:** The model recognized the pattern (loop over vertices) but didn't know WGSL's limitation

---

## Issue #2: Mandelbrot Set - Missing Results

### Observation
- No directory exists for `001_mandelbrot_set` in results
- Only `000_geometric_cube` and `002_klein_bottle` were processed
- Likely failed very early (before shader generation or during LLM API call)

### Possible Causes
1. **LLM API Timeout:** Request took too long (>60s default timeout)
2. **Early Exception:** Failed before test directory creation
3. **Problem Name Mismatch:** Problem name might not match directory structure
4. **Silent Failure:** Error occurred but wasn't logged

### Recommendation
- Check benchmark harness logs for any early errors
- Verify problem name matches `problems/base_set/mandelbrot_set/`
- Increase timeout if LLM generation is slow

---

## Issue #3: Klein Bottle - Judge API Authentication Failure

### Error Message
```
OpenRouter API error: 401 - {"error":{"message":"User not found.","code":401}}
```

### Root Cause
- **API Key Issue:** The judge model (GPT-4o via OpenRouter) authentication failed
- **Impact:** All scores defaulted to `[1, 1, 1, 1, 1]` (minimum fallback values)
- **Actual Performance:** Unknown - shader rendered successfully but couldn't be evaluated

### Why Scores Are All 1/100
The judge system has a fallback mechanism:
- When judge API fails, it returns default scores `[1, 1, 1, 1, 1]`
- This prevents the benchmark from crashing but indicates evaluation failure

### How to Fix
1. **Check `.env` file:** Verify `OPENROUTER_API_KEY` is set correctly
2. **Verify API Key:** Ensure the key has access to GPT-4o model
3. **Test API Connection:** Run a simple judge API test
4. **Check Billing:** Ensure OpenRouter account has credits

### Klein Bottle Shader Status
- ✅ **Shader Generated:** Successfully created `klein_bottle.wgsl`
- ✅ **Shader Compiled:** No compilation errors
- ✅ **Image Rendered:** Generated 299KB PNG at 1600×1600 resolution
- ❌ **Evaluation Failed:** Could not score the result

---

## Recommendations

### Immediate Fixes

1. **Update Prompt Template** (`llm_harness/prompt_template.txt`):
   - Add prominent section: "CRITICAL WGSL CONSTRAINT: NO VARIABLE ARRAY INDEXING"
   - Provide examples of unrolled loops
   - Show switch statement alternatives

2. **Fix Judge API**:
   - Verify OpenRouter API key in `.env`
   - Test judge connection separately
   - Add better error messages for API failures

3. **Improve Error Handling**:
   - Log early failures (like mandelbrot_set)
   - Add timeout handling for LLM generation
   - Better error messages for WGSL constraint violations

### Long-Term Improvements

1. **Pre-Validation:** Add shader syntax validator before compilation
2. **Better Repair Logic:** Improve shader parser repair for array indexing
3. **Constraint Documentation:** Create comprehensive WGSL constraint guide
4. **Example Library:** Add working examples for common patterns (loops, arrays)

---

## Files to Review

- **Generated Shader:** `results/000_geometric_cube/shaders/cube.wgsl`
- **Error Logs:** `results/000_geometric_cube/render_error.log`
- **LLM Response:** `results/000_geometric_cube/llm_response.txt`
- **Judge Error:** `results/002_klein_bottle/judge_error.txt`

---

## Success: Klein Bottle

Despite the judge failure, the Klein Bottle shader demonstrates that:
- ✅ LLM can generate complex mathematical shaders
- ✅ WGSL compilation can succeed for advanced problems
- ✅ The rendering pipeline works correctly

**Image Location:** `images/002_klein_bottle_result.png`


