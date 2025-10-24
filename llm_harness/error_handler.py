"""
Error handling utilities for benchmark harness
Provides clean decorator-based error logging with automatic file saving
"""

import functools
import asyncio
from pathlib import Path
from typing import Optional, Callable
import traceback
import subprocess


def save_subprocess_output(test_folder: Path, stage_name: str, result: subprocess.CompletedProcess, cmd: str = None):
    """
    Save subprocess output to log files

    Args:
        test_folder: Directory to save logs
        stage_name: Name of the stage (e.g., "compile", "render")
        result: subprocess.CompletedProcess result
        cmd: Optional command that was run
    """
    # Always save full log
    log_file = test_folder / f"{stage_name}.log"
    with open(log_file, 'w') as f:
        f.write(f"=== {stage_name.upper()} LOG ===\n")
        if cmd:
            f.write(f"Command: {cmd}\n")
        f.write(f"Return code: {result.returncode}\n\n")
        f.write("=== STDOUT ===\n")
        f.write(result.stdout if result.stdout else "(empty)\n")
        f.write("\n=== STDERR ===\n")
        f.write(result.stderr if result.stderr else "(empty)\n")

    # If error, also save error log
    if result.returncode != 0:
        error_log = test_folder / f"{stage_name}_error.log"
        with open(error_log, 'w') as f:
            f.write(f"=== {stage_name.upper()} FAILED ===\n")
            f.write(f"Return code: {result.returncode}\n")
            if cmd:
                f.write(f"Command: {cmd}\n\n")
            f.write("=== STDERR ===\n")
            f.write(result.stderr)
            f.write("\n\n=== STDOUT ===\n")
            f.write(result.stdout)
        print(f"❌ {stage_name.capitalize()} failed - error log saved to {error_log}")


def use_safe(stage_name: str, log_file_name: str = None):
    """
    Decorator for safe error handling with automatic logging

    Args:
        stage_name: Name of the stage (e.g., "compile", "render", "generation")
        log_file_name: Optional custom log file name (defaults to "{stage_name}_error.log")

    Usage:
        @use_safe("render")
        async def render_shader(self, test_folder: Path) -> Path:
            # Your code here
            # Errors will be automatically logged to test_folder/render_error.log
    """
    def decorator(func: Callable):
        @functools.wraps(func)
        async def async_wrapper(*args, **kwargs):
            test_folder = None

            # Try to find test_folder in args (usually second arg for instance methods)
            for arg in args:
                if isinstance(arg, Path) and arg.exists():
                    test_folder = arg
                    break

            try:
                return await func(*args, **kwargs)
            except Exception as e:
                error_msg = str(e)

                # Print error to console
                print(f"❌ {stage_name.capitalize()} stage failed: {error_msg[:200]}")

                # Save error log if we have a test folder
                if test_folder:
                    log_name = log_file_name or f"{stage_name}_error.log"
                    error_log = test_folder / log_name

                    with open(error_log, 'w') as f:
                        f.write(f"=== {stage_name.upper()} FAILED ===\n")
                        f.write(f"Error: {error_msg}\n\n")
                        f.write("=== FULL TRACEBACK ===\n")
                        f.write(traceback.format_exc())

                    print(f"   Error log saved to {error_log}")

                # Re-raise to maintain exception flow
                raise

        @functools.wraps(func)
        def sync_wrapper(*args, **kwargs):
            test_folder = None

            # Try to find test_folder in args
            for arg in args:
                if isinstance(arg, Path) and arg.exists():
                    test_folder = arg
                    break

            try:
                return func(*args, **kwargs)
            except Exception as e:
                error_msg = str(e)

                # Print error to console
                print(f"❌ {stage_name.capitalize()} stage failed: {error_msg[:200]}")

                # Save error log if we have a test folder
                if test_folder:
                    log_name = log_file_name or f"{stage_name}_error.log"
                    error_log = test_folder / log_name

                    with open(error_log, 'w') as f:
                        f.write(f"=== {stage_name.upper()} FAILED ===\n")
                        f.write(f"Error: {error_msg}\n\n")
                        f.write("=== FULL TRACEBACK ===\n")
                        f.write(traceback.format_exc())

                    print(f"   Error log saved to {error_log}")

                # Re-raise to maintain exception flow
                raise

        # Return appropriate wrapper based on whether function is async
        if asyncio.iscoroutinefunction(func):
            return async_wrapper
        else:
            return sync_wrapper

    return decorator
