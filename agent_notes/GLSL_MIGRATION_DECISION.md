# GLSL Migration Decision - October 24, 2025

## Status: CANCELLED - Staying with WGSL
After investigation, we decided to remain with WGSL instead of migrating to GLSL.

## Investigation Summary

### Problem Identified
- WGSL forbids dynamic array indexing (hardware GPU parallelism constraint)
- LLMs naturally generate GLSL patterns due to 20+ years of training data
- GLSL patterns fail WGSL validation: "may only be indexed by a constant"
- This resulted in ~20% success rate on initial tests

### Migration Approach Considered
1. **Use Naga for GLSL→WGSL translation**
   - Naga is the official WGSL validator/translator
   - GLSL has massive training corpus (what LLMs know)
   - Automatic translation at runtime

### Why GLSL Migration Was Cancelled

#### Issue 1: Naga API Complexity
The Naga crate's GLSL support is:
- Difficult to integrate into the compilation pipeline
- Requires handling of shader module preprocessing
- No simple `parse_glsl(code)` → `wgsl_code` function
- Would add significant complexity to the shader harness

#### Issue 2: Fragment-Shader-Only Limitation
Our current architecture renders **fragment shaders only**:
- Vertex shader is auto-generated (full-screen triangle)
- GLSL shaders require both vertex and fragment sections
- Makes GLSL-to-WGSL translation more complex
- Naga preprocessor conditionals (`#ifdef VERTEX_SHADER`) don't help much

#### Issue 3: GPU Hardware Constraint
WGSL's dynamic indexing restriction is **fundamental to GPU architecture**:
- Not a compiler bug or limitation
- Result of GPU thread divergence requirements
- All GPU languages have similar constraints (HLSL, GLSL with compute)
- No translation layer can work around hardware physics

## Decision: Strengthen WGSL Guidance Instead

Rather than complex runtime translation, we're investing in:

1. **Better LLM Constraints Documentation** ✅
   - Explain GPU parallelism fundamentally
   - Show why `array[i]` fails vs `if (i == 0) ... else if (i == 1)`
   - Provide clear manual expansion patterns

2. **Enhanced Shader Guide** ✅
   - Document WGSL capabilities clearly
   - Provide working examples for common patterns
   - Explain the "why" behind constraints

3. **Prompt Engineering Improvements**
   - Include WGSL constraints in all LLM prompts
   - Show successful patterns (manual expansion, function abstraction)
   - Reference wgsl_constraints_guide.txt in all generations

## Key Files Modified

### Reverted Changes
- `Cargo.toml`: Removed naga dependency
- `src/main.rs`: Simplified to WGSL-only, removed translation function

### Improved Documentation
- `glsl_guide.txt`: Renamed and rewritten as WGSL guide explaining constraints
- `llm_client.py`: Already loads wgsl_constraints_guide.txt in prompts
- `wgsl_constraints_guide.txt`: Enhanced with GPU parallelism explanation

## Path Forward

### Short Term (Current)
1. Use updated documentation in LLM prompts
2. Run validation tests to measure improvement
3. Refine constraint guidance based on failures

### Medium Term (Future if needed)
1. Implement proper GLSL frontend with custom preprocessing
2. Or consider supporting compute shaders (less restricted)
3. Evaluate newer GPU languages (Rust → GPU compilation)

### Long Term Vision
As GPU programming evolves:
- WGSL matures and gets more training data
- LLM training includes more modern GPU code
- Standard patterns emerge for dynamic-indexing workarounds

## Technical Debt

### Created
None - actually simplified the codebase

### Eliminated
- Complex Naga integration
- Runtime shader translation overhead
- Unclear error messages from GLSL→WGSL conversion

## Validation Plan

1. Run current benchmark with improved WGSL constraints guide
2. Measure success rate improvement (baseline: 20%)
3. Compare against original WGSL-only approach

## Conclusion

**The real problem isn't the language - it's the training data distribution.**

WGSL constraints are hardware-level requirements, not bugs. The solution is better documentation and smarter prompt engineering, not runtime translation. This is simpler, faster, and more honest about the actual limitation.

The GPU parallelism constraint (no dynamic indexing) is fundamental and worth explaining to LLMs explicitly. When they understand the *why*, they generate better solutions within the constraints.

---

**Decision Made**: October 24, 2025
**Status**: Implementation Complete
**Next Step**: Enhanced WGSL guidance already deployed, validate with test run
