#!/bin/bash

# Quick test of the benchmark harness with one model
# Usage: ./test_single_benchmark.sh

echo "🧪 Testing Benchmark Harness (Tier 2) - Single Model"

cd llm_harness
source venv/bin/activate

# Test with a small subset first
MODEL="anthropic/claude-sonnet-4"
PROBLEMS="geometric_cube regular_tetrahedron"

echo "🎯 Model: $MODEL"
echo "📝 Problems: $PROBLEMS"
echo "=========================================="

python3 benchmark_harness.py --model "$MODEL" --problems $PROBLEMS

echo ""
echo "📊 Check the generated benchmark_*.md file for results!"