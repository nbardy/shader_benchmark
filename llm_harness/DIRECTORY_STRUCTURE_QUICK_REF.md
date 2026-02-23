# Directory Structure - Quick Reference Card

> **TL;DR**: When changing WHERE files are created, grep for EVERYWHERE that assumes WHERE they are.

## Before Changing Directory Structure

### Run These 4 Commands
```bash
# 1. What creates these files?
grep -r "mkdir\|write\|\.png" llm_harness/

# 2. What reads these files?
grep -r "glob\|open\|\.png" llm_harness/

# 3. What parses directory names?
grep -r "harness_\|benchmark_run_output\|UUID" llm_harness/

# 4. What are the current patterns?
grep -r "CRITICAL:" llm_harness/
```

## After Changing Directory Structure

### Run This Test
```bash
cd llm_harness
python3 test_directory_structure_integration.py
```

**Expected**: ✅ ALL TESTS PASSED (4/4)

**If tests fail**: You broke an assumption. Check the test output to see which coupling broke.

## Critical Coupling Points

### File Location Coupling
- **Creator**: `test_runner.py` line 234, 298, 325 → writes PNGs to `artifacts/`
- **Consumer**: `test_runner.py` line 436 → searches for PNGs
- **Fix if broken**: Update BOTH glob patterns in line 436

### Directory Scanning Coupling
- **Creator**: `benchmark_harness.py` line 67 → creates `benchmark_run_output/UUID_MODEL_DATE/`
- **Consumer**: `analyze_results.py` line 48-49 → scans for directories
- **Fix if broken**: Add new glob pattern to line 48-49

### Directory Naming Coupling
- **Formatter**: `benchmark_harness.py` line 49 → formats as `UUID_MODEL_DATE_TIME`
- **Parser**: `analyze_results.py` line 77-98 → parses directory names
- **Fix if broken**: Update regex pattern in line 77-98

### Data Contract Coupling
- **Producer**: `test_runner.py` line 439-445 → writes `results.json`
- **Consumer**: `report_renderer.py` → reads `results.json`
- **Fix if broken**: Update both producer and consumer for new fields

## Common Mistakes

### ❌ Mistake 1: Only updating file creation
```python
# test_runner.py
output_path = artifacts_dir / "result.png"  # NEW location

# BUT FORGOT TO UPDATE:
# test_runner.py line 436 - still only checks root directory
png_files = list(test_folder.glob("*.png"))  # Missing artifacts/!
```

**Fix**: Update search to check both locations:
```python
png_files = list(test_folder.glob("*.png")) + list(test_folder.glob("artifacts/*.png"))
```

### ❌ Mistake 2: Breaking legacy format support
```python
# analyze_results.py
new_pattern_dirs = sorted([d for d in (self.harness_dir / 'benchmark_run_output').glob('*') if d.is_dir()])

# BUT FORGOT:
old_pattern_dirs = sorted([d for d in self.harness_dir.glob('harness_*') if d.is_dir()])

all_dirs = old_pattern_dirs + new_pattern_dirs  # Support BOTH!
```

**Fix**: Always support both old and new patterns.

### ❌ Mistake 3: Changing format without updating parser
```python
# benchmark_harness.py
self.run_id = f"{run_uuid}_{model_safe}_{timestamp}"  # NEW format with UUID

# BUT FORGOT TO UPDATE:
# analyze_results.py - still only handles harness_MODEL_DATE format
```

**Fix**: Update parser to handle both formats (see line 77-98 in analyze_results.py).

## Quick Checklist

Before committing directory structure changes:

- [ ] Grep for all code that creates files/directories
- [ ] Grep for all code that reads files/directories
- [ ] Grep for all code that parses directory names
- [ ] Update all coupling points found
- [ ] Add/update CRITICAL comments at coupling points
- [ ] Run `python3 test_directory_structure_integration.py`
- [ ] Verify all 4 tests pass

## Need More Detail?

See `/Users/nicholasbardy/git/shader_benchmark/llm_harness/DIRECTORY_STRUCTURE_MAINTENANCE.md` for:
- Complete bug analysis
- Detailed coupling explanation
- Full maintenance guide
- File manifest

## Test Locations

```
test_directory_structure_integration.py  - Run this after changes
DIRECTORY_STRUCTURE_MAINTENANCE.md      - Read this before changes
DIRECTORY_STRUCTURE_QUICK_REF.md        - This file
```
