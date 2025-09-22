#!/bin/bash

# Progress Checker Script
# Shows current progress from a test configuration
# Usage: ./check_progress.sh [config_file.json]

CONFIG_FILE="${1:-test_config.json}"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "❌ Config file not found: $CONFIG_FILE"
    exit 1
fi

echo "📊 Shader Benchmark Progress Report"
echo "📋 Config: $CONFIG_FILE"
echo "============================================="

# Parse and display progress using Python
python3 -c "
import json
import sys
from datetime import datetime

with open('$CONFIG_FILE', 'r') as f:
    config = json.load(f)

print(f\"📝 Test Name: {config['name']}\")
print(f\"📋 Description: {config['description']}\")
print()

progress = config['progress']
total_models = len(config['models'])
total_problems = len(config['problems'])
total_tests = progress['total_tests']

print('📈 Progress Summary:')
print(f\"   Models: {len(progress['completed_models'])}/{total_models} completed\")
print(f\"   Tests: {progress['completed_tests']}/{total_tests} completed\")

if progress['completed_models']:
    print(f\"   ✅ Completed: {', '.join(progress['completed_models'])}\")
if progress['failed_models']:
    print(f\"   ❌ Failed: {', '.join(progress['failed_models'])}\")

if progress['start_time']:
    start = datetime.fromisoformat(progress['start_time'])
    print(f\"   ⏰ Started: {start.strftime('%Y-%m-%d %H:%M:%S')}\")
    
    if progress['end_time']:
        end = datetime.fromisoformat(progress['end_time'])
        duration = end - start
        print(f\"   🏁 Completed: {end.strftime('%Y-%m-%d %H:%M:%S')}\")
        print(f\"   ⏱️  Total time: {duration}\")
    else:
        print('   🔄 Status: In progress...')
else:
    print('   📅 Status: Not started')

print()
print('🎯 Remaining Models:')
remaining = [model for model in config['models'] if model not in progress['completed_models'] and model not in progress['failed_models']]
if remaining:
    for model in remaining:
        print(f\"   - {model}\")
else:
    print('   None - all models completed!')
"