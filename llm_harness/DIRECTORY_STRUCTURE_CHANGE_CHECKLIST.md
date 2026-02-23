# Directory Structure Change Checklist

When changing where files are stored or how directories are organized, use this checklist to ensure all integration points are updated.

## Background
The benchmark system has multiple components that depend on directory structure:
- File creation (benchmark_harness.py, test_runner.py)
- File search (glob patterns throughout codebase)
- Directory scanning (analyze_results.py)
- Documentation (README.md)
- Version control (.gitignore)

**A change in one location requires updates in all dependent locations.**

## Required Updates

### Code Changes
- [ ] Update file creation code (benchmark_harness.py, test_runner.py)
- [ ] Update all glob patterns that search for files
  - [ ] test_runner.py `save_results()` - PNG file search (line ~431)
  - [ ] analyze_results.py `analyze()` - directory pattern globs (line ~40)
  - [ ] Any reporting code that looks for artifacts
- [ ] Update directory scanning code
  - [ ] analyze_results.py `analyze()` - directory pattern globs
  - [ ] analyze_results.py `_analyze_harness()` - name extraction logic (line ~52)

### Configuration Changes
- [ ] Update .gitignore if new output directories created
- [ ] Update any CI/CD scripts that reference paths

### Documentation Changes
- [ ] Update README.md "Output Structure" section
- [ ] Update README.md usage examples with paths
- [ ] Update any architecture diagrams
- [ ] Update this checklist if new dependencies discovered

### Testing
- [ ] Update or add integration tests
- [ ] Run validation script (see below)
- [ ] Test with actual benchmark run

## Validation Steps

Run these commands to verify changes:

```bash
# Find all glob patterns in codebase
grep -r "glob(" llm_harness/*.py

# Find PNG-related code
grep -r "\.png" llm_harness/*.py

# Verify analyze_results.py finds both patterns
cd llm_harness && source venv/bin/activate && python analyze_results.py

# Create test run and verify
python benchmark_harness.py --model "test-model" --problems geometric_cube --max-parallel 1
```

## Validation Checklist
- [ ] Run `bash validate_directory_structure.sh` (if it exists)
- [ ] Verify analyze_results.py finds both old and new runs
- [ ] Create test benchmark run and verify report generation works
- [ ] Check that `has_image` flag is correctly set in results.json
- [ ] Verify .gitignore excludes new directories (git status should be clean)

## Communication
- [ ] Document breaking changes if removing old structure support
- [ ] Update migration guide if users need to move existing results
- [ ] Add deprecation warnings if supporting both patterns temporarily
- [ ] Notify team members of structural changes

## Common Pitfalls

### Glob Patterns
**Problem:** `glob("*.png")` only searches current directory, not subdirectories.
**Solution:** Use `glob("*.png") + glob("artifacts/*.png")` to check both locations.

### Model Name Extraction
**Problem:** Changing directory naming breaks analyze_results.py parsing.
**Solution:** Update BOTH the glob pattern AND the name extraction logic in `_analyze_harness()`.

### .gitignore Timing
**Problem:** Forgetting .gitignore means large files get committed.
**Solution:** Update .gitignore BEFORE creating test directories.

### Documentation Drift
**Problem:** Code changes but README examples become outdated.
**Solution:** Update README in the SAME commit as code changes.

## Example: Adding a New Subdirectory

If you add a new subdirectory like `metadata/`:

1. **Code**: Update file creation in benchmark_harness.py
2. **Search**: Update any globs that should find files in metadata/
3. **Documentation**: Add metadata/ to README directory tree
4. **Testing**: Verify metadata/ directory is created correctly
5. **.gitignore**: Add to .gitignore if needed

## History

- **2025-10-27**: Created checklist after directory structure refactoring found 4 integration bugs
  - has_image flag bug (glob pattern didn't check artifacts/)
  - analyze_results.py couldn't find new structure
  - Missing .gitignore entry
  - Outdated documentation
