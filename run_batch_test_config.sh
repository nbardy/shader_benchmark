#!/bin/bash

# Configurable Batch Test Script - Tier 3
# Runs benchmark harness for multiple LLM models using JSON configuration
# Usage: ./run_batch_test_config.sh [config_file.json]

# Default config file
CONFIG_FILE="${1:-test_config.json}"

# Check if config file exists
if [ ! -f "$CONFIG_FILE" ]; then
    echo "❌ Config file not found: $CONFIG_FILE"
    echo ""
    echo "Usage: $0 [config_file.json]"
    echo "Example: $0 test_config.json"
    exit 1
fi

echo "🚀 Shader Benchmark - Configurable Batch Testing (Tier 3)"
echo "📋 Using config: $CONFIG_FILE"

# Parse JSON config using Python
PARSE_SCRIPT=$(cat << 'EOF'
import json
import sys
from datetime import datetime

with open(sys.argv[1], 'r') as f:
    config = json.load(f)

print(f"NAME={config['name']}")
print(f"DESCRIPTION={config['description']}")
print(f"MODELS={' '.join(config['models'])}")
print(f"PROBLEMS={' '.join(config['problems'])}")
print(f"TIMEOUT={config['settings']['timeout_minutes']}")
print(f"PAUSE_TESTS={config['settings']['pause_between_tests']}")
print(f"PAUSE_MODELS={config['settings']['pause_between_models']}")
print(f"OUTPUT_DIR={config['settings']['output_directory']}")

# Update start time and save back
config['progress']['start_time'] = datetime.now().isoformat()
with open(sys.argv[1], 'w') as f:
    json.dump(config, f, indent=2)
EOF
)

# Parse configuration
eval $(python3 -c "$PARSE_SCRIPT" "$CONFIG_FILE")

echo ""
echo "📊 Test Configuration:"
echo "   Name: $NAME"
echo "   Description: $DESCRIPTION"
echo "   Models: $(echo $MODELS | wc -w)"
echo "   Problems: $(echo $PROBLEMS | wc -w)"
echo "   Total tests: $(($(echo $MODELS | wc -w) * $(echo $PROBLEMS | wc -w)))"
echo "   Output directory: $OUTPUT_DIR"
echo "============================================================"

# Create output directory
mkdir -p "$OUTPUT_DIR"

cd llm_harness
source venv/bin/activate

# Track progress
COMPLETED_MODELS=()
FAILED_MODELS=()
TOTAL_COMPLETED=0

for model in $MODELS; do
    echo ""
    echo "🎯 Running benchmark for: $model"
    echo "------------------------------------------------------------"
    
    # Run benchmark harness for this model
    timeout ${TIMEOUT}m python3 benchmark_harness.py --model "$model" --problems $PROBLEMS
    
    if [ $? -eq 0 ]; then
        echo "✅ BENCHMARK COMPLETE: $model"
        COMPLETED_MODELS+=("$model")
        TOTAL_COMPLETED=$((TOTAL_COMPLETED + $(echo $PROBLEMS | wc -w)))
        
        # Move generated report to output directory
        LATEST_REPORT=$(ls benchmark_${model//\//_}_*.md 2>/dev/null | tail -1)
        if [ -n "$LATEST_REPORT" ]; then
            mv "$LATEST_REPORT" "../$OUTPUT_DIR/"
            echo "📊 Report moved to: $OUTPUT_DIR/$LATEST_REPORT"
        fi
    else
        echo "❌ BENCHMARK FAILED: $model"
        FAILED_MODELS+=("$model")
    fi
    
    echo ""
    sleep $PAUSE_MODELS  # Pause between models
done

cd ..

# Update progress in config file
UPDATE_PROGRESS_SCRIPT=$(cat << 'EOF'
import json
import sys
from datetime import datetime

config_file = sys.argv[1]
completed_models = sys.argv[2].split() if sys.argv[2] else []
failed_models = sys.argv[3].split() if sys.argv[3] else []
completed_tests = int(sys.argv[4])

with open(config_file, 'r') as f:
    config = json.load(f)

config['progress']['completed_models'] = completed_models
config['progress']['failed_models'] = failed_models
config['progress']['completed_tests'] = completed_tests
config['progress']['end_time'] = datetime.now().isoformat()

with open(config_file, 'w') as f:
    json.dump(config, f, indent=2)

print(f"✅ Progress saved to {config_file}")
EOF
)

python3 -c "$UPDATE_PROGRESS_SCRIPT" "$CONFIG_FILE" "${COMPLETED_MODELS[*]}" "${FAILED_MODELS[*]}" "$TOTAL_COMPLETED"

echo "============================================================"
echo "🏁 BATCH TESTING COMPLETE!"
echo ""
echo "📊 Results Summary:"
echo "   ✅ Successful models: ${#COMPLETED_MODELS[@]} (${COMPLETED_MODELS[*]})"
echo "   ❌ Failed models: ${#FAILED_MODELS[@]} (${FAILED_MODELS[*]})"
echo "   📈 Total tests completed: $TOTAL_COMPLETED"
echo ""
echo "📁 Generated files:"
echo "   - Reports: $OUTPUT_DIR/benchmark_*.md"
echo "   - Test results: llm_harness/test_*_results/"
echo "   - Progress: $CONFIG_FILE (updated)"
echo ""
echo "📋 Each benchmark report contains:"
echo "   - Success rates and execution times"
echo "   - 1-100 scale scores with /500 totals"  
echo "   - Embedded images for all successful tests"