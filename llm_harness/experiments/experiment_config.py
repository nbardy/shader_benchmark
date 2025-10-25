#!/usr/bin/env python3
"""
Experiment Configuration System
Defines configuration dataclass for ablation experiments
"""

from dataclasses import dataclass, field
from typing import List, Dict, Optional
from pathlib import Path
import yaml
from enum import Enum


class LanguageSpec(str, Enum):
    """Shader language specification"""
    WGSL = "wgsl"
    GLSL = "glsl"


class PromptStrategy(str, Enum):
    """Prompt engineering strategy"""
    ZERO_SHOT = "zero-shot"
    ONE_SHOT = "one-shot"
    FEW_SHOT = "few-shot"


class ValidatorStrategy(str, Enum):
    """Validation strategy"""
    LLM_JUDGE = "llm_judge"
    METRIC_BASED = "metric_based"
    HYBRID = "hybrid"


class ConstraintLevel(str, Enum):
    """Constraint tightness level"""
    MINIMAL = "minimal"
    STANDARD = "standard"
    STRICT = "strict"


@dataclass
class OutputFormatConfig:
    """Output format configuration"""
    resolution: int = 1600
    format: str = "png"
    color_space: str = "srgb"
    hdr_enabled: bool = False

    def to_dict(self) -> Dict:
        return {
            "resolution": self.resolution,
            "format": self.format,
            "color_space": self.color_space,
            "hdr_enabled": self.hdr_enabled
        }

    @classmethod
    def from_dict(cls, data: Dict) -> 'OutputFormatConfig':
        return cls(
            resolution=data.get("resolution", 1600),
            format=data.get("format", "png"),
            color_space=data.get("color_space", "srgb"),
            hdr_enabled=data.get("hdr_enabled", False)
        )


@dataclass
class ExperimentConfig:
    """Configuration for a single ablation experiment.

    This dataclass defines all parameters needed to run an ablation experiment,
    allowing systematic variation of one variable while holding others constant.
    """

    # Experiment identification
    experiment_id: str
    name: str
    description: str
    hypothesis: str

    # Core experimental parameters
    language_spec: LanguageSpec
    constraint_level: ConstraintLevel
    prompt_strategy: PromptStrategy
    output_format: OutputFormatConfig
    validator_strategy: ValidatorStrategy

    # Experiment scope
    problems_to_test: List[str]
    expected_runtime_hours: float
    success_criteria: str

    # File paths for variant specifications
    constraint_prompt_path: Optional[str] = None
    prompt_template_path: Optional[str] = None
    validator_config_path: Optional[str] = None

    # Additional metadata
    baseline_comparison: str = "standard_wgsl_baseline"
    tags: List[str] = field(default_factory=list)
    notes: str = ""

    def __post_init__(self):
        """Validate configuration after initialization"""
        # Convert enums if strings were provided
        if isinstance(self.language_spec, str):
            self.language_spec = LanguageSpec(self.language_spec)
        if isinstance(self.constraint_level, str):
            self.constraint_level = ConstraintLevel(self.constraint_level)
        if isinstance(self.prompt_strategy, str):
            self.prompt_strategy = PromptStrategy(self.prompt_strategy)
        if isinstance(self.validator_strategy, str):
            self.validator_strategy = ValidatorStrategy(self.validator_strategy)
        if isinstance(self.output_format, dict):
            self.output_format = OutputFormatConfig.from_dict(self.output_format)

        # Validate problems list is not empty
        if not self.problems_to_test:
            raise ValueError(f"Experiment {self.experiment_id} must specify at least one problem to test")

        # Validate runtime estimate
        if self.expected_runtime_hours <= 0:
            raise ValueError(f"Experiment {self.experiment_id} runtime must be positive")

    def to_dict(self) -> Dict:
        """Convert configuration to dictionary for serialization"""
        return {
            "experiment_id": self.experiment_id,
            "name": self.name,
            "description": self.description,
            "hypothesis": self.hypothesis,
            "language_spec": self.language_spec.value,
            "constraint_level": self.constraint_level.value,
            "prompt_strategy": self.prompt_strategy.value,
            "output_format": self.output_format.to_dict(),
            "validator_strategy": self.validator_strategy.value,
            "problems_to_test": self.problems_to_test,
            "expected_runtime_hours": self.expected_runtime_hours,
            "success_criteria": self.success_criteria,
            "constraint_prompt_path": self.constraint_prompt_path,
            "prompt_template_path": self.prompt_template_path,
            "validator_config_path": self.validator_config_path,
            "baseline_comparison": self.baseline_comparison,
            "tags": self.tags,
            "notes": self.notes
        }

    @classmethod
    def from_dict(cls, data: Dict) -> 'ExperimentConfig':
        """Create configuration from dictionary"""
        # Extract output format
        output_format = data.get("output_format", {})
        if isinstance(output_format, dict):
            output_format = OutputFormatConfig.from_dict(output_format)

        return cls(
            experiment_id=data["experiment_id"],
            name=data["name"],
            description=data["description"],
            hypothesis=data["hypothesis"],
            language_spec=LanguageSpec(data["language_spec"]),
            constraint_level=ConstraintLevel(data.get("constraint_level", "standard")),
            prompt_strategy=PromptStrategy(data.get("prompt_strategy", "one-shot")),
            output_format=output_format,
            validator_strategy=ValidatorStrategy(data.get("validator_strategy", "llm_judge")),
            problems_to_test=data["problems_to_test"],
            expected_runtime_hours=data["expected_runtime_hours"],
            success_criteria=data["success_criteria"],
            constraint_prompt_path=data.get("constraint_prompt_path"),
            prompt_template_path=data.get("prompt_template_path"),
            validator_config_path=data.get("validator_config_path"),
            baseline_comparison=data.get("baseline_comparison", "standard_wgsl_baseline"),
            tags=data.get("tags", []),
            notes=data.get("notes", "")
        )

    @classmethod
    def load_from_yaml(cls, config_path: str) -> 'ExperimentConfig':
        """Load experiment configuration from YAML file

        Args:
            config_path: Path to YAML config file

        Returns:
            ExperimentConfig instance

        Raises:
            FileNotFoundError: If config file doesn't exist
            yaml.YAMLError: If config file is malformed
            ValueError: If required fields are missing
        """
        config_file = Path(config_path)

        if not config_file.exists():
            raise FileNotFoundError(f"Config file not found: {config_path}")

        with open(config_file, 'r') as f:
            data = yaml.safe_load(f)

        if not data:
            raise ValueError(f"Config file is empty: {config_path}")

        # Resolve relative paths in config
        config_dir = config_file.parent
        if data.get("constraint_prompt_path"):
            rel_path = config_dir / data["constraint_prompt_path"]
            if rel_path.exists():
                data["constraint_prompt_path"] = str(rel_path.absolute())

        if data.get("prompt_template_path"):
            rel_path = config_dir / data["prompt_template_path"]
            if rel_path.exists():
                data["prompt_template_path"] = str(rel_path.absolute())

        if data.get("validator_config_path"):
            rel_path = config_dir / data["validator_config_path"]
            if rel_path.exists():
                data["validator_config_path"] = str(rel_path.absolute())

        return cls.from_dict(data)

    def save_to_yaml(self, output_path: str):
        """Save configuration to YAML file

        Args:
            output_path: Path to write YAML config
        """
        output_file = Path(output_path)
        output_file.parent.mkdir(parents=True, exist_ok=True)

        with open(output_file, 'w') as f:
            yaml.dump(self.to_dict(), f, default_flow_style=False, sort_keys=False)

    def get_variant_description(self) -> str:
        """Get human-readable description of what varies from baseline

        Returns:
            String describing the experimental variation
        """
        variants = []

        if self.language_spec != LanguageSpec.WGSL:
            variants.append(f"Language: {self.language_spec.value}")

        if self.constraint_level != ConstraintLevel.STANDARD:
            variants.append(f"Constraints: {self.constraint_level.value}")

        if self.prompt_strategy != PromptStrategy.ONE_SHOT:
            variants.append(f"Prompting: {self.prompt_strategy.value}")

        if self.output_format.resolution != 1600:
            variants.append(f"Resolution: {self.output_format.resolution}x{self.output_format.resolution}")

        if self.output_format.hdr_enabled:
            variants.append("HDR: enabled")

        if self.validator_strategy != ValidatorStrategy.LLM_JUDGE:
            variants.append(f"Validator: {self.validator_strategy.value}")

        if not variants:
            return "Baseline configuration (no variations)"

        return " | ".join(variants)

    def validate_files_exist(self) -> List[str]:
        """Check that all referenced files exist

        Returns:
            List of missing file paths (empty if all exist)
        """
        missing = []

        if self.constraint_prompt_path:
            if not Path(self.constraint_prompt_path).exists():
                missing.append(self.constraint_prompt_path)

        if self.prompt_template_path:
            if not Path(self.prompt_template_path).exists():
                missing.append(self.prompt_template_path)

        if self.validator_config_path:
            if not Path(self.validator_config_path).exists():
                missing.append(self.validator_config_path)

        return missing


# Predefined test sets for experiments
QUICK_TEST_SET = [
    "geometric_cube",
    "sphere_wireframe",
    "torus_knot",
    "mandelbrot_set",
    "julia_set"
]

MEDIUM_TEST_SET = QUICK_TEST_SET + [
    "sierpinski_triangle",
    "koch_snowflake",
    "dragon_curve",
    "hilbert_curve",
    "apollonian_gasket"
]

FULL_TEST_SET = MEDIUM_TEST_SET + [
    "archimedean_spiral_galaxy",
    "apollonius_conic_sections",
    "al_khwarizmi_geometric_algebra",
    "ackermann_function_growth",
    "hopf_fibration_4d",
    "klein_bottle",
    "fractal_loxodromic",
    "voronoi_diagram",
    "delaunay_triangulation",
    "gaussian_curvature"
]


def create_baseline_config() -> ExperimentConfig:
    """Create the baseline configuration for comparison

    This represents the standard WGSL configuration that all
    ablation experiments are compared against.
    """
    return ExperimentConfig(
        experiment_id="baseline",
        name="WGSL Baseline Configuration",
        description="Standard WGSL configuration with constraint-based prompting",
        hypothesis="Baseline for comparison - no experimental variation",
        language_spec=LanguageSpec.WGSL,
        constraint_level=ConstraintLevel.STANDARD,
        prompt_strategy=PromptStrategy.ONE_SHOT,
        output_format=OutputFormatConfig(resolution=1600, format="png"),
        validator_strategy=ValidatorStrategy.LLM_JUDGE,
        problems_to_test=QUICK_TEST_SET,
        expected_runtime_hours=0.5,
        success_criteria="Success rate ≥ 50% (S1+S2+S3+S4+S5 ≥ 250/500)",
        baseline_comparison="self",
        tags=["baseline", "wgsl"],
        notes="Standard configuration - all experiments compare against this"
    )
