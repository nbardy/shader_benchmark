"""
Ablation Experiment Infrastructure

This package provides configuration and orchestration for systematic ablation experiments
to measure which factors contribute to shader benchmark success.
"""

from .experiment_config import (
    ExperimentConfig,
    OutputFormatConfig,
    LanguageSpec,
    PromptStrategy,
    ValidatorStrategy,
    ConstraintLevel,
    create_baseline_config,
    QUICK_TEST_SET,
    MEDIUM_TEST_SET,
    FULL_TEST_SET
)

from .experiment_runner import (
    ExperimentRunner,
    ExperimentResults,
    ComparativeReport
)

__all__ = [
    'ExperimentConfig',
    'OutputFormatConfig',
    'LanguageSpec',
    'PromptStrategy',
    'ValidatorStrategy',
    'ConstraintLevel',
    'create_baseline_config',
    'ExperimentRunner',
    'ExperimentResults',
    'ComparativeReport',
    'QUICK_TEST_SET',
    'MEDIUM_TEST_SET',
    'FULL_TEST_SET'
]
