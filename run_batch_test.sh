#!/bin/bash

# Batch Test Script - Tier 3
# Runs benchmark harness for multiple LLM models
# Usage: ./run_batch_test.sh

echo "🚀 Shader Benchmark - Batch Testing (Tier 3)"

# Models to test
MODELS=(
    "openai/o3"
    "anthropic/claude-sonnet-4" 
    "qwen/qwen3-coder"
    "moonshotai/kimi-vl-a3b-thinking"
)

# Problems to test (geometric subset - good for initial testing)
PROBLEMS="geometric_cube regular_tetrahedron regular_octahedron rounded_box torus_donut_parametric"

cd llm_harness
source venv/bin/activate

echo "🎯 Models to test: ${#MODELS[@]}"
echo "📝 Problems per model: $(echo $PROBLEMS | wc -w)"
echo "📊 Total tests: $((${#MODELS[@]} * $(echo $PROBLEMS | wc -w)))"
echo "🔧 Using: Tier 2 Benchmark Harness"
echo "============================================================"

for model in "${MODELS[@]}"; do
    echo ""
    echo "🎯 Running benchmark for: $model"
    echo "------------------------------------------------------------"
    
    # Run benchmark harness for this model
    python3 benchmark_harness.py --model "$model" --problems $PROBLEMS
    
    if [ $? -eq 0 ]; then
        echo "✅ BENCHMARK COMPLETE: $model"
    else
        echo "❌ BENCHMARK FAILED: $model"
    fi
    
    echo ""
    sleep 3  # Brief pause between models
done

echo "============================================================"
echo "🏁 BATCH TESTING COMPLETE!"
echo ""
echo "📁 Generated files:"
echo "   - Individual test results: test_*_results/ directories"
echo "   - Benchmark reports: benchmark_*.md files (one per model)"
echo ""
echo "📊 Each benchmark report contains:"
echo "   - Success rates and execution times"
echo "   - 1-100 scale scores with /500 totals"
echo "   - Embedded images for all successful tests"