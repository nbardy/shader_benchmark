# Reporting System Rollout Plan

**Version:** 1.0
**Date:** 2025-10-26
**Status:** Phased Implementation Plan

---

## Table of Contents

1. [Overview](#overview)
2. [Phase 1: Install and Test](#phase-1-install-and-test)
3. [Phase 2: Migrate benchmark_harness.py](#phase-2-migrate-benchmark_harnesspl)
4. [Phase 3: Deprecate Old System](#phase-3-deprecate-old-system)
5. [Testing Checklist](#testing-checklist)
6. [Rollback Procedures](#rollback-procedures)
7. [Timeline and Resources](#timeline-and-resources)

---

## Overview

### Current State

**Existing Components:**
- ✅ Data structures defined (`results_collector.py`)
- 🟡 Stub renderers exist (`report_renderer.py`)
- ❌ Hiccup system not implemented
- ❌ Full renderers not implemented
- ❌ Integration not complete

**Legacy System:**
- `generate_report.py` - Functional markdown generator
- Works with existing harness runs
- Scattered file organization
- No HTML output

### Rollout Objectives

1. **Complete Implementation**: Finish all stub components
2. **Validate Quality**: Ensure reports match or exceed legacy quality
3. **Migrate Safely**: Transition without breaking existing workflows
4. **Deprecate Gradually**: Phase out old system with user support

### Success Criteria

- [ ] All components fully implemented and tested
- [ ] Reports generate in <2 seconds for 100 tests
- [ ] HTML and Markdown output validated
- [ ] No data loss during migration
- [ ] User documentation complete
- [ ] Rollback plan tested and ready

---

## Phase 1: Install and Test

**Duration:** 3-4 weeks
**Goal:** Complete implementation of all stub components

### Step 1.1: Implement Hiccup System (Week 1)

**Tasks:**

```bash
cd /Users/nicholasbardy/git/shader_benchmark/llm_harness

# Create hiccup_builder.py
touch hiccup_builder.py
```

**Implementation Checklist:**

- [ ] Create `hiccup_builder.py` module
- [ ] Implement core hiccup functions:
  - [ ] `h(tag, attrs, *children)` - Basic node builder
  - [ ] `text(content)` - Plain text nodes
  - [ ] `fragment(*children)` - Fragment container
- [ ] Implement convenience builders:
  - [ ] `div()`, `section()`, `p()`, `h1()`, `h2()`, `h3()`
  - [ ] `img()`, `table()`, `code_block()`, `link()`
- [ ] Add report-specific builders:
  - [ ] `build_report_hiccup(benchmark)` - Main report structure
  - [ ] `build_test_result_section(test)` - Individual test section
  - [ ] `build_error_summary(error)` - Error analysis section
  - [ ] `build_summary_section(summary)` - Statistics section
- [ ] Unit tests for hiccup builders

**Validation:**

```python
# Test hiccup structure generation
from hiccup_builder import h, div, h1, p

hiccup = div(
    h1("Test Report"),
    p("This is a test paragraph")
)

# Expected output:
# ["div", {}, ["h1", {}, "Test Report"], ["p", {}, "This is a test paragraph"]]

assert hiccup[0] == "div"
assert len(hiccup) == 4  # tag, attrs, h1, p
print("✓ Hiccup builder working")
```

### Step 1.2: Implement Full Renderers (Week 2)

**Tasks:**

**A. Markdown Renderer:**

- [ ] Expand `report_renderer.py` with full Markdown implementation
- [ ] Create `MarkdownWriter` class:
  - [ ] `write_text()` - Plain text with escaping
  - [ ] `write_tag()` - Tag dispatcher
  - [ ] `_write_header()` - # H1, ## H2, ### H3
  - [ ] `_write_paragraph()` - Paragraphs with blank lines
  - [ ] `_write_image()` - ![alt](src)
  - [ ] `_write_table()` - Markdown table syntax
  - [ ] `_write_code_block()` - Triple backticks
  - [ ] `_write_link()` - [text](url)
- [ ] Implement `hiccup_to_markdown()` function
- [ ] Handle nested structures recursively

**B. HTML Renderer:**

- [ ] Create `HTMLWriter` class:
  - [ ] `write_document_start()` - HTML5 doctype, head, CSS
  - [ ] `write_document_end()` - Close tags
  - [ ] `write_navigation()` - Sidebar with test links
  - [ ] `write_text()` - HTML-escaped text
  - [ ] `write_tag()` - HTML tag generation
  - [ ] `_write_open_tag()` - Opening tags with attributes
  - [ ] `_write_close_tag()` - Closing tags
- [ ] Implement `hiccup_to_html()` function
- [ ] Add inline CSS for styling:
  - [ ] Typography and layout
  - [ ] Navigation sidebar (fixed position)
  - [ ] Code syntax highlighting classes
  - [ ] Responsive design
- [ ] Test in multiple browsers

**Validation:**

```python
from results_collector import BenchmarkRun, BenchmarkSummary, JudgeScores
from report_renderer import generate_report
from datetime import datetime

# Create test data
summary = BenchmarkSummary(
    model_name="test-model",
    judge_model="test-judge",
    language_spec="wgsl",
    run_id="test_run",
    start_time=datetime.now(),
    end_time=datetime.now(),
    total_duration_seconds=100.0,
    total_tests=10,
    successful_tests=8,
    failed_tests=2,
    compile_failures=1,
    render_failures=1,
    judge_failures=0,
    average_scores=None,
    median_scores=None,
    best_test=None,
    worst_test=None,
    error_summaries=[]
)

benchmark = BenchmarkRun(summary=summary, test_results=[])
md, html = generate_report(benchmark)

assert "test-model" in md
assert "<html>" in html
print("✓ Renderers producing output")
```

### Step 1.3: Complete Results Collector (Week 2-3)

**Tasks:**

- [ ] Implement full `ResultsCollector.finalize()` method
- [ ] Add result dict → TestResult conversion:
  - [ ] Parse execution status from errors
  - [ ] Build TimingInfo from execution_time
  - [ ] Build JudgeScores from scores array
  - [ ] Build ErrorInfo from error messages
  - [ ] Load shader artifacts from test directories
- [ ] Calculate summary statistics:
  - [ ] Average scores across successful tests
  - [ ] Median scores (add implementation)
  - [ ] Find best/worst tests
  - [ ] Count failure types
- [ ] Build error summaries:
  - [ ] Group errors by category
  - [ ] Collect affected problems
  - [ ] Extract example messages/tracebacks

**Validation:**

```python
from results_collector import ResultsCollector
from datetime import datetime

collector = ResultsCollector("test_run")

# Add mock results
collector.add_result({
    'problem': 'geometric_cube',
    'success': True,
    'scores': [85, 72, 91, 67, 88],
    'execution_time': 7.23,
    'image_path': '/path/to/result.png',
    'test_dir': '/path/to/test_dir'
})

# Finalize
benchmark = collector.finalize(
    model="test-model",
    judge_model="test-judge",
    language="wgsl",
    start_time=datetime.now(),
    end_time=datetime.now()
)

assert benchmark.summary.total_tests == 1
assert benchmark.summary.successful_tests == 1
assert benchmark.summary.average_scores.s1_mathematical_accuracy == 85
print("✓ Results collector building BenchmarkRun")
```

### Step 1.4: Create Integration Tests (Week 3)

**Tasks:**

- [ ] Create `test_reporting_system.py`
- [ ] Unit tests for all components:
  - [ ] Hiccup builder tests
  - [ ] Markdown renderer tests
  - [ ] HTML renderer tests
  - [ ] Results collector tests
- [ ] Integration tests:
  - [ ] End-to-end report generation
  - [ ] File organization tests
  - [ ] Metadata JSON generation tests
- [ ] Performance tests:
  - [ ] Benchmark with 100 test results
  - [ ] Memory usage profiling
  - [ ] Report generation speed

**Validation:**

```bash
# Run test suite
python -m pytest test_reporting_system.py -v

# Expected output:
# test_hiccup_builder ..................... PASSED
# test_markdown_renderer .................. PASSED
# test_html_renderer ...................... PASSED
# test_results_collector .................. PASSED
# test_end_to_end ......................... PASSED
# test_performance ........................ PASSED
```

### Step 1.5: Performance Validation (Week 3-4)

**Tasks:**

- [ ] Test with real benchmark data:
  - [ ] 10 test results
  - [ ] 50 test results
  - [ ] 100 test results
  - [ ] 500 test results (stretch)
- [ ] Measure performance:
  - [ ] Report generation time
  - [ ] Memory usage
  - [ ] File sizes
- [ ] Optimize bottlenecks:
  - [ ] Profile slow code paths
  - [ ] Optimize hiccup→HTML rendering
  - [ ] Optimize file I/O operations

**Success Criteria:**

- [ ] <2 seconds for 100 tests
- [ ] <5 seconds for 500 tests
- [ ] <500 MB memory usage for 100 tests
- [ ] No memory leaks

---

## Phase 2: Migrate benchmark_harness.py

**Duration:** 1-2 weeks
**Goal:** Integrate new reporting system into harness

### Step 2.1: Add Feature Flag (Day 1)

**Implementation:**

```python
# In benchmark_harness.py

class BenchmarkHarness:
    def __init__(self, ..., use_new_reporting: bool = False):
        # ...
        self.use_new_reporting = use_new_reporting

# Update CLI args
parser.add_argument('--new-report', action='store_true',
                    help='Use new reporting system (experimental)')
```

**Test:**

```bash
# Run with new reporting (should work but may be basic)
python benchmark_harness.py \
    --model "anthropic/claude-3.5-sonnet" \
    --problems ../problems/base_set/geometric_cube \
    --new-report
```

### Step 2.2: Implement Report Builder (Days 2-3)

**Tasks:**

- [ ] Create `_build_benchmark_run()` method in `BenchmarkHarness`
- [ ] Convert `self.results` list to BenchmarkRun:
  - [ ] Use ResultsCollector
  - [ ] Add each result during harness execution
  - [ ] Finalize at end of run
- [ ] Handle checkpoint/resume compatibility:
  - [ ] Load partial results from checkpoints
  - [ ] Support incremental report updates

**Implementation:**

```python
# In benchmark_harness.py

from results_collector import ResultsCollector

class BenchmarkHarness:
    def __init__(self, ...):
        # ...
        self.results_collector = ResultsCollector(self.run_id)

    async def run_single_problem(self, problem_dir):
        # ... existing code ...
        result = {
            'problem': problem_name,
            'success': success,
            'scores': scores,
            # ...
        }
        self.results.append(result)

        # NEW: Also add to results collector
        self.results_collector.add_result(result)

    def _build_benchmark_run(self):
        """Build BenchmarkRun from collected results"""
        return self.results_collector.finalize(
            model=self.model,
            judge_model=self.judge_model,
            language=self.language,
            start_time=self.start_time,
            end_time=self.end_time
        )
```

### Step 2.3: Implement File Organization (Days 4-5)

**Tasks:**

- [ ] Create `_organize_test_artifacts()` method
- [ ] Copy test artifacts to `runs/` directory:
  - [ ] Create `run-NNN-problem_name/` directories
  - [ ] Copy result.png
  - [ ] Copy shader files
  - [ ] Write metadata.json
  - [ ] Write error.log if failed
- [ ] Create `images/` directory:
  - [ ] Symlinks to result images (try/except for Windows)
  - [ ] Fallback to copies if symlinks fail
- [ ] Write `summary.json`

**Implementation:**

```python
def _organize_test_artifacts(self, benchmark_run, output_dir):
    """Copy test artifacts into organized runs/ structure"""
    runs_dir = output_dir / "runs"
    runs_dir.mkdir(exist_ok=True)

    images_dir = output_dir / "images"
    images_dir.mkdir(exist_ok=True)

    for test in benchmark_run.test_results:
        run_name = f"run-{test.run_number:03d}-{test.problem_name}"
        run_dir = runs_dir / run_name
        run_dir.mkdir(exist_ok=True)

        # Copy result image
        if test.result_image_path and test.result_image_path.exists():
            shutil.copy2(test.result_image_path, run_dir / "result.png")

            # Create symlink (or copy on Windows)
            symlink_path = images_dir / f"run-{test.run_number:03d}.png"
            try:
                symlink_path.symlink_to(f"../runs/{run_name}/result.png")
            except OSError:
                # Windows or permission issue - copy instead
                shutil.copy2(test.result_image_path, symlink_path)

        # Write metadata.json
        metadata = {
            "test_id": test.test_id,
            "run_number": test.run_number,
            # ... (see design doc for full format)
        }
        with open(run_dir / "metadata.json", 'w') as f:
            json.dump(metadata, f, indent=2)
```

### Step 2.4: Update generate_report() (Days 6-7)

**Tasks:**

- [ ] Modify `generate_report()` method to use new system when enabled
- [ ] Keep old system as fallback
- [ ] Generate both MD and HTML reports
- [ ] Print paths to generated reports

**Implementation:**

```python
def generate_report(self):
    """Generate unified report"""

    if self.use_new_reporting:
        # NEW SYSTEM
        from report_renderer import render_to_files

        # Build BenchmarkRun
        benchmark_run = self._build_benchmark_run()

        # Organize artifacts
        output_dir = Path(self.run_id)
        self._organize_test_artifacts(benchmark_run, output_dir)

        # Generate reports
        md_path, html_path = render_to_files(benchmark_run, output_dir)

        # Write summary.json
        self._write_summary_json(benchmark_run, output_dir)

        print(f"\n✓ Report generated: {output_dir}/")
        print(f"  - Markdown: {md_path}")
        print(f"  - HTML: {html_path}")
        print(f"  - Summary: {output_dir / 'summary.json'}")

        return output_dir
    else:
        # OLD SYSTEM (existing code)
        # ... existing generate_report.py logic ...
        pass
```

### Step 2.5: Test Integration (Days 8-10)

**Tasks:**

- [ ] Run benchmark with `--new-report` flag
- [ ] Verify all files created correctly
- [ ] Compare with legacy report output
- [ ] Test with different models
- [ ] Test with different problem counts
- [ ] Test checkpoint/resume compatibility

**Test Script:**

```bash
#!/bin/bash
# Test new reporting system

cd /Users/nicholasbardy/git/shader_benchmark/llm_harness

# Test 1: Small run (3 problems)
echo "Test 1: Small run"
python benchmark_harness.py \
    --model "anthropic/claude-3.5-sonnet" \
    --problems ../problems/base_set/geometric_cube \
              ../problems/base_set/parametric_surface \
              ../problems/base_set/julia_set \
    --new-report

# Test 2: Medium run (10 problems)
echo "Test 2: Medium run"
python benchmark_harness.py \
    --model "anthropic/claude-haiku-4.5" \
    --problems ../problems/base_set/ \
    --limit 10 \
    --new-report

# Test 3: Checkpoint/resume
echo "Test 3: Checkpoint resume"
# (interrupt first run, then resume)

# Verify outputs
echo "Verifying structure..."
ls -R harness_*/
```

---

## Phase 3: Deprecate Old System

**Duration:** 2-3 weeks
**Goal:** Make new system default, deprecate legacy

### Step 3.1: Make New System Default (Week 1)

**Tasks:**

- [ ] Change default: `use_new_reporting=True`
- [ ] Add `--legacy-report` flag for old system
- [ ] Update all documentation
- [ ] Announce change to users

**Implementation:**

```python
# In benchmark_harness.py

parser.add_argument('--legacy-report', action='store_true',
                    help='Use legacy reporting system (deprecated)')

class BenchmarkHarness:
    def __init__(self, ..., use_legacy_reporting: bool = False):
        self.use_new_reporting = not use_legacy_reporting
```

**Communication:**

```markdown
# ANNOUNCEMENT: New Reporting System Default

Starting [DATE], the shader benchmark harness uses a new reporting system by default.

## What's New
- HTML reports with navigation
- Better file organization
- Type-safe data structures
- Faster generation

## Migration
- New system is automatic (no changes needed)
- Old reports available with `--legacy-report` flag
- Report any issues on GitHub

## Timeline
- Now: New system default
- [DATE +30 days]: Gather feedback
- [DATE +60 days]: Remove legacy system
```

### Step 3.2: Validation Period (Weeks 1-2)

**Tasks:**

- [ ] Monitor for issues
- [ ] Collect user feedback
- [ ] Fix bugs promptly
- [ ] Document workarounds
- [ ] Compare report quality

**Metrics to Track:**

- Number of `--legacy-report` usages
- Reported issues/bugs
- Performance metrics
- User satisfaction

### Step 3.3: Remove Legacy System (Week 3)

**Tasks:**

- [ ] Remove `--legacy-report` flag
- [ ] Archive `generate_report.py`:
  - Move to `legacy/` directory
  - Add README explaining deprecation
- [ ] Update all documentation
- [ ] Remove old code paths

**Implementation:**

```bash
# Archive legacy system
mkdir -p legacy
git mv generate_report.py legacy/
echo "# Legacy Reporting System (Deprecated)" > legacy/README.md
```

**Final Cleanup:**

```python
# In benchmark_harness.py

# REMOVE:
# - use_new_reporting flag (now always true)
# - --legacy-report argument
# - Old report generation code

def generate_report(self):
    """Generate unified report (new system)"""
    # Only new system code remains
    from report_renderer import render_to_files
    # ...
```

---

## Testing Checklist

### Unit Tests

- [ ] Hiccup builder functions
  - [ ] Basic node creation
  - [ ] Nested structures
  - [ ] Attribute handling
  - [ ] Text escaping
- [ ] Markdown renderer
  - [ ] Headers (h1, h2, h3)
  - [ ] Paragraphs
  - [ ] Images
  - [ ] Tables
  - [ ] Code blocks
  - [ ] Links
- [ ] HTML renderer
  - [ ] Complete document structure
  - [ ] Tag generation
  - [ ] Attribute escaping
  - [ ] Navigation sidebar
  - [ ] CSS styling
- [ ] Results collector
  - [ ] Result dict conversion
  - [ ] Summary statistics
  - [ ] Error categorization
  - [ ] Best/worst test finding

### Integration Tests

- [ ] End-to-end report generation
  - [ ] Mock BenchmarkRun → Reports
  - [ ] File creation and organization
  - [ ] Metadata JSON generation
  - [ ] Summary JSON generation
- [ ] File organization
  - [ ] runs/ directory structure
  - [ ] images/ symlinks (or copies)
  - [ ] Metadata files
  - [ ] Error logs
- [ ] Harness integration
  - [ ] ResultsCollector during execution
  - [ ] Report generation at end
  - [ ] Checkpoint compatibility

### Performance Tests

- [ ] Small runs (10 tests)
  - [ ] Generation time <0.5s
  - [ ] Memory usage <100 MB
- [ ] Medium runs (100 tests)
  - [ ] Generation time <2s
  - [ ] Memory usage <500 MB
- [ ] Large runs (500 tests)
  - [ ] Generation time <5s
  - [ ] Memory usage <2 GB

### Regression Tests

- [ ] Compare with legacy reports
  - [ ] Same test data
  - [ ] Verify no data loss
  - [ ] Check score accuracy
  - [ ] Validate image paths
- [ ] Checkpoint/resume
  - [ ] Partial run → complete
  - [ ] Report regeneration
  - [ ] State consistency

### User Acceptance Tests

- [ ] Generate report for real benchmark run
- [ ] Open HTML in multiple browsers
  - [ ] Chrome/Edge
  - [ ] Firefox
  - [ ] Safari
- [ ] View Markdown in editors
  - [ ] VSCode
  - [ ] GitHub web interface
  - [ ] Standard markdown viewers
- [ ] Share report directory
  - [ ] Zip and unzip
  - [ ] Verify images load
  - [ ] Check links work

---

## Rollback Procedures

### If New System Has Critical Issues

**Immediate Rollback:**

```bash
# Revert to legacy system
cd /Users/nicholasbardy/git/shader_benchmark/llm_harness

# Use --legacy-report flag
python benchmark_harness.py \
    --model "..." \
    --problems ... \
    --legacy-report
```

**Code Rollback (if flag removed):**

```bash
# Restore legacy system from archive
git restore legacy/generate_report.py
git mv legacy/generate_report.py .

# Revert harness changes
git revert <commit-hash>
```

**Communication:**

```markdown
# ROLLBACK NOTICE

We've identified issues with the new reporting system and are temporarily
reverting to the legacy system while we address them.

## What to Do
- Use `--legacy-report` flag (or update to reverted version)
- Existing reports remain valid
- We'll announce when new system is re-enabled

## Timeline
- Now: Legacy system default again
- [DATE]: Fix deployed and tested
- [DATE]: Re-enable new system
```

### Partial Rollback (Keep Some Features)

**Scenario:** New system mostly works, but one component broken

**Options:**

1. **Disable HTML, keep Markdown**
   ```python
   # Only generate Markdown temporarily
   md_path = output_dir / "all.md"
   md_content, _ = generate_report(benchmark)
   md_path.write_text(md_content)
   # Skip HTML generation
   ```

2. **Use old file organization, new renderers**
   ```python
   # Skip _organize_test_artifacts()
   # Generate reports from existing scattered structure
   ```

3. **Use new data structures, old templates**
   ```python
   # Convert BenchmarkRun back to old dict format
   # Use legacy generate_report.py with converted data
   ```

---

## Timeline and Resources

### Overall Timeline

| Phase | Duration | Start | End |
|-------|----------|-------|-----|
| Phase 1: Implementation | 3-4 weeks | Week 1 | Week 4 |
| Phase 2: Integration | 1-2 weeks | Week 5 | Week 6 |
| Phase 3: Deprecation | 2-3 weeks | Week 7 | Week 9 |
| **Total** | **6-9 weeks** | Week 1 | Week 9 |

### Resource Allocation

**Primary Engineer (Full Implementation):**
- Phase 1: 30-40 hours/week (hiccup, renderers, collector)
- Phase 2: 20-30 hours/week (integration, testing)
- Phase 3: 10-20 hours/week (monitoring, fixes)

**Supporting Engineer (Testing & Documentation):**
- Phase 1: 10-15 hours/week (unit tests, documentation)
- Phase 2: 15-20 hours/week (integration tests, validation)
- Phase 3: 5-10 hours/week (user support, bug fixes)

**CTO/Tech Lead:**
- All Phases: 5-10 hours/week (reviews, decisions, support)

### Milestones

**Week 2:** Hiccup system complete
**Week 4:** Full renderers working
**Week 5:** Integration tests passing
**Week 6:** Harness integration complete
**Week 7:** New system becomes default
**Week 9:** Legacy system removed

---

## Risk Mitigation

### Risk: Implementation Takes Longer Than Expected

**Mitigation:**
- Break work into smaller chunks
- Prioritize MVP features (MD + basic HTML)
- Defer nice-to-have features (navigation sidebar, CSS polish)

### Risk: Performance Issues With Large Runs

**Mitigation:**
- Profile early and often
- Optimize critical paths
- Add streaming/pagination if needed

### Risk: User Resistance to Change

**Mitigation:**
- Keep legacy system available longer
- Provide clear migration path
- Document differences and benefits
- Responsive bug fixing

### Risk: Data Loss or Corruption

**Mitigation:**
- Extensive testing with real data
- Validation against legacy reports
- Checkpoint/resume compatibility testing
- Rollback plan ready

---

## Success Metrics

### Technical Metrics

- [ ] Report generation <2s for 100 tests
- [ ] Memory usage <500 MB for 100 tests
- [ ] HTML loads in <1s in modern browsers
- [ ] Markdown renders correctly in all viewers
- [ ] Zero data loss vs legacy system

### User Metrics

- [ ] <5 bug reports in first month
- [ ] >80% user satisfaction
- [ ] <10% users requesting legacy system
- [ ] Documentation rated helpful

### Project Metrics

- [ ] Delivered on time (±1 week)
- [ ] Within resource budget
- [ ] All tests passing
- [ ] Code review approved

---

## Document History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2025-10-26 | Initial rollout plan |

---

**End of Rollout Plan**
