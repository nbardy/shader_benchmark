# Directory Structure Maintenance Guide

## Purpose

This document captures the lessons learned from directory structure refactoring bugs and provides maintenance guidelines to prevent future regressions.

## What We Learned

### Bug 1: `has_image` Flag Always False (test_runner.py)

**Problem**: The `has_image` flag in `results.json` was always False even when PNG files existed.

**Root Cause**: The code only checked for PNGs in the root directory using `glob("*.png")`, but new multi-problem benchmark runs save PNGs to an `artifacts/` subdirectory.

**Impact**: Report renderer couldn't embed images because it relied on the `has_image` flag.

**Fix Location**: `/Users/nicholasbardy/git/shader_benchmark/llm_harness/test_runner.py` line 436

```python
# CRITICAL: Check for PNG files in BOTH root and artifacts/ subdirectory
# Why both locations?
# - Legacy single-problem runs: result.png in root directory
# - New multi-problem runs: result.png in artifacts/ subdirectory
# If directory structure changes, update BOTH glob patterns here
png_files = list(test_folder.glob("*.png")) + list(test_folder.glob("artifacts/*.png"))
has_image = len(png_files) > 0
```

**Lesson**: When file locations change, grep for ALL code that depends on those locations, not just the code that creates the files.

### Bug 2: analyze_results.py Missing New Directories

**Problem**: `analyze_results.py` only scanned `harness_*` directories, missing new `benchmark_run_output/*/` directories.

**Root Cause**: Directory pattern hard-coded to single glob pattern. When new directory structure was added, scanning logic wasn't updated.

**Impact**: New benchmark runs were invisible to analysis tools.

**Fix Location**: `/Users/nicholasbardy/git/shader_benchmark/llm_harness/analyze_results.py` lines 47-52

```python
# CRITICAL: Support BOTH legacy and new directory structures
# Legacy pattern: harness_anthropic_claude-3.5-sonnet-20241022_20251024_123456/
# New pattern:    benchmark_run_output/97fe1f08_anthropic_claude-haiku-4.5_20251026_154624/
#
# If you add a third directory pattern, add another glob here AND update
# the model name extraction logic in _analyze_harness() below

old_pattern_dirs = sorted([d for d in self.harness_dir.glob('harness_*') if d.is_dir()])
new_pattern_dirs = sorted([d for d in (self.harness_dir / 'benchmark_run_output').glob('*')
                           if d.is_dir()]) if (self.harness_dir / 'benchmark_run_output').exists() else []

harness_dirs = old_pattern_dirs + new_pattern_dirs
```

**Lesson**: Directory scanning and directory creation are coupled - when one changes, update the other.

### Bug 3: Model Name Extraction from Directory Names

**Problem**: Model names couldn't be extracted from new UUID-prefixed directory names.

**Root Cause**: Parsing logic assumed `harness_MODEL_DATE_TIME` format, but new format is `UUID_MODEL_DATE_TIME`.

**Impact**: Analysis reports showed "unknown" for all new benchmark runs.

**Fix Location**: `/Users/nicholasbardy/git/shader_benchmark/llm_harness/analyze_results.py` lines 70-98

```python
# CRITICAL: Model name extraction depends on directory naming convention
# This code must stay synchronized with directory patterns in analyze() above
#
# Naming conventions:
# - Legacy: harness_MODEL_DATE_TIME  (e.g., harness_anthropic_claude-3.5-sonnet_20251024_011837)
# - New:    UUID_MODEL_DATE_TIME     (e.g., 97fe1f08_anthropic_claude-haiku-4.5_20251026_154624)
#
# If benchmark_harness.py changes how it names directories, update this logic!

if dirname.startswith('harness_'):
    # Legacy pattern: harness_MODEL_DATE_TIME
    timestamp_pattern = r'(\d{8}_\d{6})$'
    match = re.search(timestamp_pattern, dirname)
    if match:
        model = dirname[:match.start()].replace('harness_', '')
    else:
        model = "unknown"
else:
    # New pattern: UUID_MODEL_DATE_TIME
    if re.match(r'^[a-f0-9]{8}_', dirname):
        remaining = dirname[9:]  # Skip "UUID_"
        timestamp_pattern = r'_(\d{8}_\d{6})$'
        match = re.search(timestamp_pattern, remaining)
        if match:
            model = remaining[:match.start()]
        else:
            model = remaining
    else:
        model = "unknown"
```

**Lesson**: String parsing and string formatting are coupled - when one changes, update the other.

## Integration Test

We created `/Users/nicholasbardy/git/shader_benchmark/llm_harness/test_directory_structure_integration.py` to prevent these regressions.

**When to run**: After ANY changes to:
- Directory structure (where files are saved)
- Directory naming (how directories are named)
- File location assumptions (code that looks for files)
- Path handling logic

**How to run**:
```bash
cd /Users/nicholasbardy/git/shader_benchmark/llm_harness
python3 test_directory_structure_integration.py
```

**What it tests**:
1. `has_image` flag correctly detects PNGs in both root and `artifacts/` subdirectory
2. Directory scanning finds both legacy `harness_*` and new `benchmark_run_output/*/` patterns
3. Model name extraction works for both `harness_MODEL_DATE_TIME` and `UUID_MODEL_DATE_TIME` patterns
4. `results.json` structure includes all required fields

## Critical Code Locations

### 1. File Creation (where files are written)

**test_runner.py** - Creates test folders and saves results:
- Line 147-148: Creates `artifacts/` subdirectory
- Line 234, 298, 325: Writes `result.png` to `artifacts/` subdirectory
- Line 436: Checks for PNG files (MUST check both root and artifacts/)
- Line 447: Writes `results.json`

**benchmark_harness.py** - Names output directories:
- Creates `benchmark_run_output/UUID_MODEL_DATE_TIME/` directories
- If you change this naming pattern, update `analyze_results.py` line 88

### 2. File Discovery (where files are read)

**test_runner.py** - `save_results()` method (line 428):
```python
# CRITICAL: Check for PNG files in BOTH root and artifacts/ subdirectory
png_files = list(test_folder.glob("*.png")) + list(test_folder.glob("artifacts/*.png"))
has_image = len(png_files) > 0
```

**analyze_results.py** - `analyze()` method (line 36):
```python
# CRITICAL: Support BOTH legacy and new directory structures
old_pattern_dirs = sorted([d for d in self.harness_dir.glob('harness_*') if d.is_dir()])
new_pattern_dirs = sorted([d for d in (self.harness_dir / 'benchmark_run_output').glob('*')
                           if d.is_dir()]) if (self.harness_dir / 'benchmark_run_output').exists() else []
```

**analyze_results.py** - `_analyze_harness()` method (line 59):
```python
# CRITICAL: Model name extraction depends on directory naming convention
# This code must stay synchronized with directory patterns in analyze() above
```

### 3. Data Contract (results.json format)

**test_runner.py** - `save_results()` method (line 439):
```python
results = {
    "scores": scores,              # list of 5 integers
    "test_folder": str(test_folder),
    "status": "completed" if execution_success else "failed",
    "execution_success": execution_success,  # boolean
    "has_image": has_image         # boolean - CRITICAL for report rendering
}
```

**report_renderer.py** - Reads `results.json`:
- Expects `has_image` boolean flag
- Uses flag to decide whether to embed PNG

## Maintenance Checklist

When making changes to directory structure, verify:

1. **File Creation Changes**
   - [ ] Grep for all code that creates files in the old location
   - [ ] Update all file creation code to use new location
   - [ ] Update glob patterns that search for those files
   - [ ] Run integration tests to verify detection works

2. **Directory Naming Changes**
   - [ ] Grep for all code that parses directory names
   - [ ] Update regex patterns to handle new naming format
   - [ ] Support legacy format for backward compatibility
   - [ ] Run integration tests to verify parsing works

3. **Directory Scanning Changes**
   - [ ] Update all glob patterns that scan for directories
   - [ ] Add new patterns alongside old patterns (don't replace)
   - [ ] Update analysis tools to recognize new structure
   - [ ] Run integration tests to verify scanning works

4. **Data Contract Changes**
   - [ ] Update `results.json` structure carefully
   - [ ] Grep for all code that reads `results.json`
   - [ ] Update all consumers to expect new fields
   - [ ] Add integration test for new field

## Prevention Strategy

### Ultra-Think Before Changing Structure

Before changing file locations or directory names, ask:

1. **What creates these files?** (Grep for write/mkdir operations)
2. **What reads these files?** (Grep for glob/open operations)
3. **What parses these names?** (Grep for regex/split operations)
4. **What assumes these locations?** (Grep for hard-coded paths)

### Comment Strategy

Add CRITICAL comments at:
- **Creation points**: Where files/directories are created
- **Coupling points**: Where parsing depends on formatting
- **Search points**: Where code globs for files/directories

Comment format:
```python
# CRITICAL: [What this code does]
# Why: [Why it's structured this way]
# Coupling: [What other code depends on this]
# Change checklist: [What to update if this changes]
```

### Testing Strategy

1. **Run integration tests** after EVERY directory structure change
2. **Add new test cases** when adding new directory patterns
3. **Keep tests synchronized** with actual code behavior
4. **Don't skip tests** - they catch real bugs

## File Manifest

Key files for directory structure maintenance:

```
llm_harness/
├── test_runner.py                              # Creates test folders, saves results
│   └── save_results() line 428                 # CRITICAL: has_image flag
├── benchmark_harness.py                        # Names output directories
├── analyze_results.py                          # Scans for benchmark directories
│   ├── analyze() line 36                       # CRITICAL: directory scanning
│   └── _analyze_harness() line 59              # CRITICAL: model name extraction
├── report_renderer.py                          # Reads results.json
├── test_directory_structure_integration.py     # Integration tests
└── DIRECTORY_STRUCTURE_MAINTENANCE.md          # This file
```

## Summary

**The Pattern**: When you change WHERE something is created, you must update EVERYWHERE that assumes WHERE it is.

**The Tool**: Grep is your friend. Search for the old pattern across the entire codebase.

**The Safety Net**: Run `test_directory_structure_integration.py` after changes.

**The Documentation**: This file. Update it when you discover new coupling points.
