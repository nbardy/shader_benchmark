#!/bin/bash

# Simple Batch Test Script - Working Version
# Runs the full benchmark test directly

echo "🚀 Shader Benchmark - Full Benchmark Test"
echo "📊 Testing 4 models × 5 problems = 20 total tests"
echo "============================================================"

# Models to test
MODELS=(
    "openai/o3"
    "anthropic/claude-sonnet-4"
    "qwen/qwen3-coder"
    "moonshotai/kimi-vl-a3b-thinking"
)

# Problems to test
PROBLEMS="geometric_cube regular_tetrahedron regular_octahedron rounded_box torus_donut_parametric"

# Create output directory
mkdir -p output/full_benchmark

cd llm_harness
source ~/.cargo/env
source venv/bin/activate

# Track progress
COMPLETED_MODELS=()
FAILED_MODELS=()
TOTAL_COMPLETED=0

for model in "${MODELS[@]}"; do
    echo ""
    echo "🎯 Running benchmark for: $model"
    echo "------------------------------------------------------------"
    
    # Run benchmark harness for this model
    timeout 30m python3 benchmark_harness.py --model "$model" --problems $PROBLEMS
    
    if [ $? -eq 0 ]; then
        echo "✅ BENCHMARK COMPLETE: $model"
        COMPLETED_MODELS+=("$model")
        TOTAL_COMPLETED=$((TOTAL_COMPLETED + 5))  # 5 problems per model
        
        # Move generated report to output directory
        LATEST_REPORT=$(ls benchmark_${model//\//_}_*.md 2>/dev/null | tail -1)
        if [ -n "$LATEST_REPORT" ]; then
            mv "$LATEST_REPORT" "../output/full_benchmark/"
            echo "📊 Report moved to: output/full_benchmark/$LATEST_REPORT"
        fi
    else
        echo "❌ BENCHMARK FAILED: $model"
        FAILED_MODELS+=("$model")
    fi
    
    echo ""
    sleep 3  # Brief pause between models
done

cd ..

echo "============================================================"
echo "🏁 BATCH TESTING COMPLETE!"
echo ""
echo "📊 Results Summary:"
echo "   ✅ Successful models: ${#COMPLETED_MODELS[@]} (${COMPLETED_MODELS[*]})"
echo "   ❌ Failed models: ${#FAILED_MODELS[@]} (${FAILED_MODELS[*]})"
echo "   📈 Total tests completed: $TOTAL_COMPLETED/20"
echo ""
echo "📁 Generated files:"
echo "   - Reports: output/full_benchmark/benchmark_*.md"
echo "   - Test results: llm_harness/test_*_results/"
echo ""
echo "📋 Each benchmark report contains:"
echo "   - Success rates and execution times"
echo "   - 1-100 scale scores with /500 totals"
echo "   - Embedded images for all successful tests"