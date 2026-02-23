# WGSL Params Naming Issue - Root Cause and Fix

## Problem Discovery (October 2025)

### Initial Symptom
- 40% baseline success rate for WGSL shader compilation
- Consistent error: "redefinition of `Params`"

### Initial Misdiagnosis
We thought the LLM was defining `struct Params` multiple times. We tried:
1. Regex-based linting to remove duplicates
2. Compiler-error-driven repair to remove duplicate structs
3. Prompt engineering to tell LLM not to duplicate

All failed - still 40% success rate or worse.

## The Real Issue

**It's a naming conflict, not a duplicate struct!**

The LLM was generating:
```wgsl
struct Params {           // Line 9 - Type definition
    resolution: vec2<f32>,
};

@group(0) @binding(0) var<uniform> Params: Params;  // Line 15 - Variable declaration
                                    ^^^^^^  ^^^^^^
                                    name    type
```

The problem: The uniform **variable** is named `Params` (same as the type).
In WGSL, you can't have a variable with the same name as its type in the same scope.

The error message "redefinition of `Params`" was misleading - it meant the **name** `Params`
was being used twice (once as type, once as variable), not that the struct was defined twice.

## The Fix

Changed the constraint prompt and examples to use lowercase variable name:
```wgsl
@group(0) @binding(0) var<uniform> params: Params;  // lowercase 'params'
                                    ^^^^^^
                                    variable name

// Then reference as:
let uv = pos.xy / params.resolution;  // lowercase
```

## Key Files Changed

1. **language_specs.py**:
   - Line 168: Changed `var<uniform> Params: Params` to `var<uniform> params: Params`
   - Line 207, 215: Updated examples to use `params.resolution`

2. **shader_parser.py**:
   - Added `_fix_params_naming()` method to repair if LLM still uses uppercase
   - Converts `Params.field` references to `params.field`

## Lessons Learned

1. **Error messages can be misleading** - "redefinition" doesn't always mean duplicate definitions
2. **Look at actual generated code** - We spent too long theorizing without checking what was generated
3. **Understand the language rules** - WGSL doesn't allow variables and types with same name
4. **Simple fixes are often best** - Changing case convention was simpler than complex repairs

## Testing

After the fix, run Phase 1 validation:
```bash
cd llm_harness
source venv/bin/activate
python benchmark_harness.py --model "anthropic/claude-3.5-sonnet-20241022" \
    --problems ackermann_function_growth al_khwarizmi_geometric_algebra \
               apollonian_gasket apollonius_conic_sections archimedean_spiral_galaxy \
    --max-parallel 1
```

Expected: Success rate should improve from 40% baseline.

## Note for Future Development

If similar "redefinition" errors occur, check for:
1. Variable/type naming conflicts (same name for both)
2. Case sensitivity issues
3. Scope conflicts (global vs local)

Don't assume "redefinition" means duplicate struct definitions!