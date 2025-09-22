#!/usr/bin/env python3
"""
Configuration Generator for Shader Benchmark
Creates JSON config files for batch testing
"""

import json
import argparse
from datetime import datetime
from pathlib import Path

def create_config(name, description, models, problems, output_dir="output", timeout=5):
    """Create a test configuration"""
    
    config = {
        "name": name,
        "description": description,
        "timestamp": datetime.now().strftime("%Y-%m-%d"),
        "models": models,
        "problems": problems,
        "settings": {
            "timeout_minutes": timeout,
            "pause_between_tests": 1,
            "pause_between_models": 3,
            "embed_images": True,
            "output_directory": output_dir
        },
        "progress": {
            "completed_models": [],
            "failed_models": [],
            "total_tests": len(models) * len(problems),
            "completed_tests": 0,
            "start_time": None,
            "end_time": None
        }
    }
    
    return config

def main():
    parser = argparse.ArgumentParser(description='Create shader benchmark configuration')
    parser.add_argument('--name', required=True, help='Test name')
    parser.add_argument('--description', required=True, help='Test description')
    parser.add_argument('--models', nargs='+', required=True, help='List of models to test')
    parser.add_argument('--problems', nargs='+', required=True, help='List of problems to test')
    parser.add_argument('--output', default='test_config.json', help='Output config file')
    parser.add_argument('--timeout', type=int, default=5, help='Timeout in minutes per test')
    
    args = parser.parse_args()
    
    # Create configuration
    config = create_config(
        name=args.name,
        description=args.description,
        models=args.models,
        problems=args.problems,
        timeout=args.timeout
    )
    
    # Save to file
    with open(args.output, 'w') as f:
        json.dump(config, f, indent=2)
    
    print(f"✅ Configuration created: {args.output}")
    print(f"📊 Test setup:")
    print(f"   Models: {len(args.models)}")
    print(f"   Problems: {len(args.problems)}")
    print(f"   Total tests: {len(args.models) * len(args.problems)}")
    print(f"   Timeout: {args.timeout} minutes per test")
    print()
    print(f"🚀 To run: ./run_batch_test_config.sh {args.output}")

if __name__ == "__main__":
    main()