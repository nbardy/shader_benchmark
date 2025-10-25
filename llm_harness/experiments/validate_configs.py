#!/usr/bin/env python3
"""
Configuration Validation Script
Validates all experiment configurations for correctness
"""

import sys
from pathlib import Path
from experiment_config import ExperimentConfig

def validate_all_configs():
    """Validate all experiment configurations"""
    experiments_dir = Path(__file__).parent
    config_files = sorted(experiments_dir.glob("exp_*/config.yaml"))

    print("="*80)
    print("EXPERIMENT CONFIGURATION VALIDATION")
    print("="*80)
    print(f"Found {len(config_files)} experiment configurations\n")

    errors = []
    warnings = []
    success_count = 0

    for config_file in config_files:
        exp_name = config_file.parent.name
        print(f"Validating {exp_name}...")

        try:
            # Load configuration
            config = ExperimentConfig.load_from_yaml(str(config_file))

            # Validate required fields
            assert config.experiment_id, "Missing experiment_id"
            assert config.name, "Missing name"
            assert config.description, "Missing description"
            assert config.hypothesis, "Missing hypothesis"
            assert config.problems_to_test, "Missing problems_to_test"
            assert config.expected_runtime_hours > 0, "Invalid runtime"
            assert config.success_criteria, "Missing success_criteria"

            # Check for missing referenced files
            missing_files = config.validate_files_exist()
            if missing_files:
                for f in missing_files:
                    warnings.append(f"{exp_name}: Referenced file not found: {f}")

            # Print summary
            print(f"  ✅ Configuration valid")
            print(f"     - ID: {config.experiment_id}")
            print(f"     - Name: {config.name}")
            print(f"     - Problems: {len(config.problems_to_test)}")
            print(f"     - Runtime: {config.expected_runtime_hours:.1f}h")
            print(f"     - Variant: {config.get_variant_description()}")

            success_count += 1

        except FileNotFoundError as e:
            errors.append(f"{exp_name}: Config file not found: {e}")
            print(f"  ❌ ERROR: {e}")

        except Exception as e:
            errors.append(f"{exp_name}: Validation failed: {e}")
            print(f"  ❌ ERROR: {e}")

        print()

    # Print summary
    print("="*80)
    print("VALIDATION SUMMARY")
    print("="*80)
    print(f"Total configs: {len(config_files)}")
    print(f"Valid configs: {success_count}")
    print(f"Errors: {len(errors)}")
    print(f"Warnings: {len(warnings)}")
    print()

    if errors:
        print("ERRORS:")
        for error in errors:
            print(f"  ❌ {error}")
        print()

    if warnings:
        print("WARNINGS:")
        for warning in warnings:
            print(f"  ⚠️  {warning}")
        print()

    if errors:
        print("❌ Validation FAILED")
        return False
    elif warnings:
        print("⚠️  Validation passed with warnings")
        return True
    else:
        print("✅ All configurations valid!")
        return True


def test_baseline_config():
    """Test baseline configuration generation"""
    from experiment_config import create_baseline_config

    print("\nTesting baseline configuration...")
    baseline = create_baseline_config()

    assert baseline.experiment_id == "baseline"
    assert baseline.language_spec.value == "wgsl"
    assert baseline.constraint_level.value == "standard"
    assert baseline.problems_to_test

    print("  ✅ Baseline configuration valid")


def test_config_serialization():
    """Test configuration save/load cycle"""
    from experiment_config import create_baseline_config
    import tempfile
    import os

    print("\nTesting configuration serialization...")

    baseline = create_baseline_config()

    # Save to temporary file
    with tempfile.NamedTemporaryFile(mode='w', suffix='.yaml', delete=False) as f:
        temp_path = f.name

    try:
        baseline.save_to_yaml(temp_path)
        loaded = ExperimentConfig.load_from_yaml(temp_path)

        assert loaded.experiment_id == baseline.experiment_id
        assert loaded.name == baseline.name
        assert loaded.language_spec == baseline.language_spec

        print("  ✅ Serialization test passed")

    finally:
        os.unlink(temp_path)


if __name__ == "__main__":
    try:
        # Test baseline
        test_baseline_config()

        # Test serialization
        test_config_serialization()

        # Validate all configs
        success = validate_all_configs()

        sys.exit(0 if success else 1)

    except Exception as e:
        print(f"\n❌ FATAL ERROR: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
