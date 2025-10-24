# Shader Benchmark Logging System Guide

## Overview

This document explains the comprehensive logging system implemented for the shader benchmark harness to enable debugging of failures, especially when running multiple problems in parallel.

## Why Logging Was Essential

### The Problem We Solved

**Symptom**: Tests showed "100% complete" in progress bar but had 0% success rate with no visibility into failures.

**Root Cause**: Before logging was implemented:
- No execution traces for failed problems
- Progress bar (tqdm) updates for BOTH successes AND failures, masking issues
- Parallel execution made console output interleaved and unusable
- Fast-failing problems left no evidence of what went wrong

**Example**: Running 5 problems showed:
```
Running benchmarks: 100%|██████████| 5/5 [01:03<00:00, 12.74s/test]
✅ Success rate: 0/5 (0.0%)
```

All 5 tests "completed" according to the progress bar, but ALL failed. Without logs, debugging was impossible.

## Logging Architecture

### Components

1. **`debug_logger.py`** - Thread-safe logging module
   - Uses Python's `threading.Lock()` for concurrent write safety
   - Explicit `flush()` after all file writes to ensure persistence
   - Microsecond-precision timestamps for accurate timing analysis

2. **`execution_summary.log`** - Master timeline
   - Records when each problem starts and ends
   - Shows SUCCESS/FAILURE status with duration
   - Includes exception information for failed problems

3. **`problem_NNN_name.log`** - Per-problem detailed logs
   - Stage-by-stage execution trace (generate, compile, render, judge)
   - API call details with response sizes
   - Exception stack traces with full context
   - Info/warning/error events

### Directory Structure

```
harness_MODEL_TIMESTAMP/
├── logs/
│   ├── execution_summary.log          # Master timeline
│   ├── problem_000_problem_name.log   # Problem 0 details
│   ├── problem_001_problem_name.log   # Problem 1 details
│   └── ...
└── checkpoints/
    ├── manifest.json                   # Run metadata
    ├── problem_000.json               # Problem 0 checkpoint
    └── ...
```

## How to Use the Logs

### 1. Quick Status Check

First, check the execution summary for high-level view:

```bash
cat harness_*/logs/execution_summary.log
```

Look for:
- Which problems started
- Which problems completed
- SUCCESS vs FAILURE status
- Execution duration for each problem

Example output:
```
[2025-10-24 00:00:37.766536] START problem_000: ackermann_function_growth
[2025-10-24 00:02:20.545653] END problem_000: ackermann_function_growth - SUCCESS (102.78s)
[2025-10-24 00:00:38.123456] START problem_001: al_khwarizmi_geometric_algebra
[2025-10-24 00:01:15.789012] END problem_001: al_khwarizmi_geometric_algebra - FAILURE (37.67s)
```

### 2. Deep Dive into Failures

For failed problems, read the detailed log:

```bash
cat harness_*/logs/problem_001_al_khwarizmi_geometric_algebra.log
```

Look for:
- **STAGE START/END** markers to see how far execution progressed
- **API CALL** markers to verify LLM requests succeeded
- **EXCEPTION** markers for error details
- **ERROR** log entries for failure reasons

### 3. Common Patterns

#### Pattern 1: Problem Never Started
```
# execution_summary.log shows problem in initialization but no START entry
[2025-10-24 00:00:37.759433] HARNESS INITIALIZED
  Problem list:
    000: ackermann_function_growth
    001: al_khwarizmi_geometric_algebra  # Listed but no START event
```

**Cause**: Problem failed during initialization (e.g., directory not found, invalid config)

**Solution**: Check console output for error messages before asyncio.gather()

#### Pattern 2: Fast Failure (< 1 second)
```
[2025-10-24 00:00:38.123456] START problem_001: problem_name
[2025-10-24 00:00:38.234567] EXCEPTION in generate stage
  RuntimeError: Request prompt file not found
[2025-10-24 00:00:38.345678] END problem_001: problem_name - FAILURE (0.22s)
```

**Cause**: Problem failed very early (missing files, invalid configuration)

**Solution**: Read the detailed problem log for the exception details

#### Pattern 3: WGSL Compilation Failure
```
[2025-10-24 00:01:15.123456] STAGE START: compile
[2025-10-24 00:01:15.789012] EXCEPTION in compile stage
  RuntimeError: Shader execution failed:
  thread 'main' panicked at wgpu-0.20.1/src/backend/wgpu_core.rs:2996
  Shader validation error: naga::Expression [39]
```

**Cause**: LLM generated invalid WGSL code (syntax error, unsupported features)

**Solution**: Check test_*/render_error.log for full shader validation error

#### Pattern 4: Render Timeout
```
[2025-10-24 00:01:30.000000] STAGE START: render
[2025-10-24 00:03:30.000000] EXCEPTION in render stage
  TimeoutExpired: Command '['cargo', 'run', ...]' timed out after 120 seconds
```

**Cause**: Shader entered infinite loop or took too long to render

**Solution**: Review shader code for loops without proper termination conditions

## Critical Implementation Details

### Why We Use Explicit flush()

**Problem**: Python file writes are buffered by default. If a problem fails very quickly (< 1 second), the buffer might not flush to disk before the process exits.

**Solution**: Every log write includes explicit `flush()`:

```python
def log_problem_start(self, problem_index: int, problem_name: str):
    """Log when a problem starts execution"""
    try:
        logger = self._get_problem_logger(problem_index, problem_name)
        logger.info(f"========== PROBLEM START ==========")
        logger.info(f"Index: {problem_index}")
        logger.info(f"Name: {problem_name}")

        # CRITICAL: Flush immediately to ensure writes persist
        for handler in logger.handlers:
            handler.flush()
    except Exception as e:
        print(f"⚠️  Logger initialization failed: {e}")
```

### Thread Safety with asyncio

**Challenge**: Multiple problems run in parallel using asyncio, all writing to logs simultaneously.

**Solution**: Use `threading.Lock()` to serialize file writes:

```python
class DebugLogger:
    def __init__(self, run_id: str):
        self.run_id = run_id
        self.log_dir = Path(f"{run_id}/logs")
        self.log_dir.mkdir(parents=True, exist_ok=True)
        self._lock = threading.Lock()  # Protects concurrent access
        self._loggers = {}

    def log_info(self, problem_index: int, problem_name: str, message: str):
        """Thread-safe logging of info messages"""
        with self._lock:  # Acquire lock before writing
            logger = self._get_problem_logger(problem_index, problem_name)
            logger.info(message)
            for handler in logger.handlers:
                handler.flush()
```

## Maintenance Guidelines

### When Adding New Stages

If you add a new pipeline stage (e.g., "preprocess"), add logging:

```python
# Stage N: Preprocess
if not self._is_stage_complete(problem_index, 'preprocess'):
    self.logger.log_stage_start(problem_index, problem, 'preprocess')  # ADD THIS

    try:
        # Your stage logic here
        result = await preprocess_step()

        self._save_stage_checkpoint(problem_index, 'preprocess', 'complete')
        self.logger.log_stage_end(problem_index, problem, 'preprocess', True)  # ADD THIS
    except Exception as e:
        error_msg = str(e)[:500]
        self.logger.log_exception(problem_index, problem, "preprocess stage", e)  # ADD THIS
        self._save_stage_checkpoint(problem_index, 'preprocess', 'failed', {'error': error_msg})
        self.logger.log_stage_end(problem_index, problem, 'preprocess', False)  # ADD THIS
        raise
```

### When Debugging Silent Failures

1. **Check if logs directory exists**: If not, problem failed before logger initialized
2. **Check execution_summary.log**: See which problems actually started
3. **Read problem_NNN logs**: Get detailed execution trace
4. **Check test_*/ directories**: Contains shader files, errors, and results
5. **Verify flush() calls**: Ensure all logging calls include flush for persistence

### Common Pitfalls

1. **Forgetting to flush**: Fast failures might not persist without flush()
2. **Not using lock**: Concurrent writes can corrupt log files
3. **Logging after exception**: Always log BEFORE raising exception
4. **Missing initialization logging**: Log problem start BEFORE any work

## Testing the Logging System

### Verify Logging Works

Run a simple test with known failures:

```bash
cd llm_harness
python benchmark_harness.py \
  --model "anthropic/claude-3.5-sonnet-20241022" \
  --problems geometric_cube \
  --max-parallel 1
```

Then check:

```bash
# 1. Verify logs directory created
ls harness_*/logs/

# 2. Check execution summary
cat harness_*/logs/execution_summary.log

# 3. Read problem details
cat harness_*/logs/problem_000_*.log
```

Expected output:
- `logs/` directory exists
- `execution_summary.log` shows HARNESS INITIALIZED, START, and END events
- Problem log shows detailed stage progression

### Test Parallel Execution Logging

Run multiple problems to verify thread safety:

```bash
python benchmark_harness.py \
  --model "anthropic/claude-3.5-sonnet-20241022" \
  --problems ackermann_function_growth al_khwarizmi_geometric_algebra \
  --max-parallel 2
```

Verify:
- Both problems have log files
- No corrupted/garbled log entries (would indicate lock failure)
- Timestamps show parallel execution (overlapping time ranges)

## Future Improvements

Potential enhancements to consider:

1. **Log Levels**: Add configurable verbosity (DEBUG, INFO, WARNING, ERROR)
2. **Log Rotation**: Prevent log files from growing too large
3. **Structured Logging**: Use JSON format for easier parsing/analysis
4. **Metrics Collection**: Aggregate statistics across all problems
5. **Real-time Monitoring**: WebSocket endpoint for live log streaming

## Quick Reference

### Log File Locations
- Master timeline: `harness_*/logs/execution_summary.log`
- Problem details: `harness_*/logs/problem_NNN_name.log`
- Shader errors: `test_*/render_error.log`
- Test results: `test_*/results.json`

### Key Log Markers
- `HARNESS INITIALIZED` - Run started
- `START problem_NNN` - Problem began execution
- `STAGE START: stage_name` - Pipeline stage started
- `API CALL: description` - LLM or judge API request
- `EXCEPTION` - Error occurred with stack trace
- `END problem_NNN - SUCCESS/FAILURE` - Problem completed

### Common Commands
```bash
# Quick status check
tail harness_*/logs/execution_summary.log

# Find failed problems
grep "FAILURE" harness_*/logs/execution_summary.log

# See all exceptions
grep -r "EXCEPTION" harness_*/logs/

# Check problem 3's execution
cat harness_*/logs/problem_003_*.log
```
