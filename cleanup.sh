#!/bin/bash

# Cleanup script for shader benchmark repository
# Moves old test results to archive and removes temporary files

echo "🧹 Cleaning up shader benchmark repository..."

# Create archive directory if it doesn't exist
mkdir -p archive

# Move old test results to archive
if ls llm_harness/test_*_results 1> /dev/null 2>&1; then
    echo "📦 Archiving old test results..."
    mv llm_harness/test_*_results archive/
    echo "✅ Moved test results to archive/"
else
    echo "ℹ️  No old test results to archive"
fi

# Remove temporary files
echo "🗑️  Removing temporary files..."
find . -name "*.pyc" -delete 2>/dev/null || true
find . -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true
find . -name ".DS_Store" -delete 2>/dev/null || true

# Clean up any temporary images
if ls llm_harness/*.png 1> /dev/null 2>&1; then
    echo "🖼️  Archiving temporary images..."
    mkdir -p archive/images
    mv llm_harness/*.png archive/images/ 2>/dev/null || true
fi

# Create output directory for future results
mkdir -p output

echo ""
echo "✅ Cleanup complete!"
echo "📁 Structure:"
echo "   - archive/          Old test results and images"
echo "   - output/           Future test results will go here"
echo "   - llm_harness/      Clean working directory"