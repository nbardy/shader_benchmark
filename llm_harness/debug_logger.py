"""
Thread-safe debug logger for benchmark harness.

WHY THIS EXISTS:
Before this logging system, test failures were impossible to debug because:
1. Progress bar (tqdm) shows "100% complete" even when all tests FAIL
2. Multiple problems running in parallel created interleaved console output
3. Fast-failing problems left no trace of what went wrong
4. Python's default file buffering didn't flush logs for problems that failed quickly

Example symptom:
  Running benchmarks: 100%|██████████| 5/5 [01:03<00:00, 12.74s/test]
  ✅ Success rate: 0/5 (0.0%)  # All tests "completed" but all failed!

This system solves those issues by providing:
- Immediate file-based logging with microsecond timestamps
- Thread-safe concurrent writes for parallel execution
- Explicit flush() after every write to ensure persistence
- Separate logs per problem for clean separation
- Master timeline (execution_summary.log) showing all START/END events

CRITICAL DESIGN DECISIONS:
1. flush() after EVERY log write - ensures fast-failing problems persist logs
2. threading.Lock() for concurrent access - prevents corrupted log files
3. Try/except around ALL log operations - logging failures shouldn't crash tests
4. Separate problem loggers - easier to debug individual problems
5. Master timeline log - quick overview of which problems ran/failed

See LOGGING_GUIDE.md for usage instructions and debugging patterns.
"""

import logging
import sys
from pathlib import Path
from datetime import datetime
from threading import Lock
from typing import Optional
import traceback


class DebugLogger:
    """Thread-safe logger that writes immediately to disk"""

    def __init__(self, run_id: str, base_dir: Path = None):
        """
        Initialize debug logger for a benchmark run.

        Args:
            run_id: Unique identifier for this benchmark run
            base_dir: Base directory for log files (defaults to run_id directory)
        """
        self.run_id = run_id
        self.base_dir = base_dir or Path(run_id)
        self.log_dir = self.base_dir / "logs"
        self.log_dir.mkdir(parents=True, exist_ok=True)

        # Thread safety
        self._lock = Lock()

        # Create summary logger
        self.summary_log = self.log_dir / "execution_summary.log"
        self._init_summary_log()

        # Per-problem loggers (created on demand)
        self._problem_loggers = {}

    def _init_summary_log(self):
        """Initialize the summary log file"""
        with open(self.summary_log, 'w') as f:
            f.write(f"=== BENCHMARK EXECUTION SUMMARY ===\n")
            f.write(f"Run ID: {self.run_id}\n")
            f.write(f"Started: {datetime.now().isoformat()}\n")
            f.write(f"=" * 60 + "\n\n")

    def _get_timestamp(self) -> str:
        """Get timestamp with microsecond precision"""
        return datetime.now().strftime("%Y-%m-%d %H:%M:%S.%f")

    def _get_problem_logger(self, problem_index: int, problem_name: str) -> logging.Logger:
        """Get or create logger for a specific problem"""
        if problem_index not in self._problem_loggers:
            logger = logging.getLogger(f"problem_{problem_index:03d}")
            logger.setLevel(logging.DEBUG)
            logger.propagate = False

            # Remove any existing handlers
            logger.handlers.clear()

            # Ensure log directory exists (in case of parallel execution)
            self.log_dir.mkdir(parents=True, exist_ok=True)

            # Create file handler with immediate flush
            log_file = self.log_dir / f"problem_{problem_index:03d}_{problem_name}.log"
            handler = logging.FileHandler(log_file, mode='w')
            handler.setLevel(logging.DEBUG)

            # Format with microsecond timestamps
            formatter = logging.Formatter(
                '%(asctime)s.%(msecs)03d [%(levelname)s] %(message)s',
                datefmt='%Y-%m-%d %H:%M:%S'
            )
            handler.setFormatter(formatter)

            # Ensure immediate writes
            handler.flush = lambda: handler.stream.flush() if handler.stream else None

            logger.addHandler(handler)
            self._problem_loggers[problem_index] = logger

            # Log initialization
            logger.info(f"Logger initialized for problem {problem_index}: {problem_name}")
            handler.flush()

        return self._problem_loggers[problem_index]

    def log_harness_init(self, model: str, problems: list, max_parallel: int):
        """Log harness initialization"""
        with self._lock:
            with open(self.summary_log, 'a') as f:
                f.write(f"[{self._get_timestamp()}] HARNESS INITIALIZED\n")
                f.write(f"  Model: {model}\n")
                f.write(f"  Problems: {len(problems)}\n")
                f.write(f"  Max parallel: {max_parallel}\n")
                f.write(f"  Problem list:\n")
                for i, p in enumerate(problems):
                    f.write(f"    {i:03d}: {p}\n")
                f.write("\n")

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
            print(f"⚠️  Logger initialization failed for problem {problem_index}: {type(e).__name__}: {e}")
            import traceback
            traceback.print_exc()

        # Also log to summary (with fallback)
        try:
            with self._lock:
                with open(self.summary_log, 'a') as f:
                    f.write(f"[{self._get_timestamp()}] START problem_{problem_index:03d}: {problem_name}\n")
                    # CRITICAL: Flush summary log immediately
                    f.flush()
        except Exception as e:
            print(f"⚠️  Summary log write failed for problem {problem_index}: {type(e).__name__}: {e}")

    def log_problem_end(self, problem_index: int, problem_name: str, success: bool, execution_time: float):
        """Log when a problem completes"""
        logger = self._get_problem_logger(problem_index, problem_name)
        status = "SUCCESS" if success else "FAILED"
        logger.info(f"========== PROBLEM END: {status} ==========")
        logger.info(f"Execution time: {execution_time:.2f}s")

        # Flush to disk
        for handler in logger.handlers:
            handler.flush()

        # Also log to summary
        with self._lock:
            with open(self.summary_log, 'a') as f:
                f.write(f"[{self._get_timestamp()}] END problem_{problem_index:03d}: {problem_name} - {status} ({execution_time:.2f}s)\n")
                f.flush()

    def log_checkpoint_save_attempt(self, problem_index: int, problem_name: str,
                                    stage_name: str, status: str):
        """Log before attempting to save checkpoint"""
        logger = self._get_problem_logger(problem_index, problem_name)
        logger.info(f"Attempting to save checkpoint: stage={stage_name}, status={status}")

    def log_checkpoint_save_success(self, problem_index: int, problem_name: str,
                                    stage_name: str, file_path: Path):
        """Log successful checkpoint save"""
        logger = self._get_problem_logger(problem_index, problem_name)
        logger.info(f"Checkpoint saved successfully: stage={stage_name}, file={file_path}")

        # Flush to disk immediately
        for handler in logger.handlers:
            handler.flush()

    def log_checkpoint_save_failure(self, problem_index: int, problem_name: str,
                                    stage_name: str, exception: Exception):
        """Log checkpoint save failure with full traceback"""
        logger = self._get_problem_logger(problem_index, problem_name)
        logger.error(f"Checkpoint save FAILED: stage={stage_name}")
        logger.error(f"Exception: {type(exception).__name__}: {str(exception)}")
        logger.error(f"Traceback:\n{''.join(traceback.format_tb(exception.__traceback__))}")

        # Flush to disk immediately
        for handler in logger.handlers:
            handler.flush()

    def log_stage_start(self, problem_index: int, problem_name: str, stage_name: str):
        """Log when a pipeline stage starts"""
        logger = self._get_problem_logger(problem_index, problem_name)
        logger.info(f"---------- STAGE START: {stage_name.upper()} ----------")

    def log_stage_end(self, problem_index: int, problem_name: str, stage_name: str, success: bool):
        """Log when a pipeline stage ends"""
        logger = self._get_problem_logger(problem_index, problem_name)
        status = "SUCCESS" if success else "FAILED"
        logger.info(f"---------- STAGE END: {stage_name.upper()} - {status} ----------")

        # Flush to disk
        for handler in logger.handlers:
            handler.flush()

    def log_api_call(self, problem_index: int, problem_name: str,
                    api_type: str, details: str = ""):
        """Log API call (LLM, judge, etc.)"""
        logger = self._get_problem_logger(problem_index, problem_name)
        logger.info(f"API call: {api_type} {details}")

    def log_api_response(self, problem_index: int, problem_name: str,
                        api_type: str, response_size: int, success: bool):
        """Log API response"""
        logger = self._get_problem_logger(problem_index, problem_name)
        status = "success" if success else "failed"
        logger.info(f"API response: {api_type} - {status}, size={response_size} bytes")

    def log_exception(self, problem_index: int, problem_name: str,
                     context: str, exception: Exception):
        """Log exception with full traceback"""
        # CRITICAL: This must NEVER throw an exception itself, or we lose all error info!
        try:
            logger = self._get_problem_logger(problem_index, problem_name)
            logger.error(f"EXCEPTION in {context}:")
            logger.error(f"  Type: {type(exception).__name__}")
            logger.error(f"  Message: {str(exception)}")
            logger.error(f"  Traceback:")
            for line in traceback.format_tb(exception.__traceback__):
                logger.error(f"    {line.rstrip()}")

            # Flush to disk immediately
            for handler in logger.handlers:
                handler.flush()
        except Exception as logger_error:
            # Logger failed - print directly to stdout as last resort
            print(f"⚠️  Logger FAILED during exception logging for problem {problem_index}!")
            print(f"   Logger error: {type(logger_error).__name__}: {logger_error}")
            print(f"   Original exception in {context}:")
            print(f"   {type(exception).__name__}: {str(exception)}")
            traceback.print_exception(type(exception), exception, exception.__traceback__)

        # Also log to summary (with fallback)
        try:
            with self._lock:
                with open(self.summary_log, 'a') as f:
                    f.write(f"[{self._get_timestamp()}] EXCEPTION in problem_{problem_index:03d} ({context}): {type(exception).__name__}: {str(exception)}\n")
                    f.flush()
        except Exception as e:
            print(f"⚠️  Summary log write failed during exception logging: {type(e).__name__}: {e}")
            print(f"   Original exception: {type(exception).__name__}: {str(exception)}")

    def log_info(self, problem_index: int, problem_name: str, message: str):
        """Log general information"""
        logger = self._get_problem_logger(problem_index, problem_name)
        logger.info(message)

    def log_warning(self, problem_index: int, problem_name: str, message: str):
        """Log warning"""
        logger = self._get_problem_logger(problem_index, problem_name)
        logger.warning(message)

    def finalize(self):
        """Finalize all logs and flush to disk"""
        with self._lock:
            with open(self.summary_log, 'a') as f:
                f.write(f"\n{'=' * 60}\n")
                f.write(f"Run completed: {datetime.now().isoformat()}\n")

        # Flush all problem loggers
        for logger in self._problem_loggers.values():
            for handler in logger.handlers:
                handler.flush()
                handler.close()
