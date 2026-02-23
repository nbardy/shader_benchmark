#!/bin/bash
# Validate directory structure assumptions across the codebase
#
# This script catches common mistakes when changing directory structure:
# - PNG glob patterns missing artifacts/ subdirectory
# - benchmark_run_output/ not in .gitignore
# - analyze_results.py not scanning new structure
#
# Run this before committing directory structure changes.

set -e

echo "🔍 Validating directory structure assumptions..."
echo ""

ERRORS=0

# Check 1: Verify PNG glob patterns include artifacts/ subdirectory
echo "📸 Checking PNG glob patterns..."
cd "$(dirname "$0")"  # Change to llm_harness directory

# Look for glob patterns that search for .png but don't include artifacts/
# Exclude this validation script itself
MISSING_ARTIFACTS=$(grep -n "glob.*\.png" *.py 2>/dev/null | grep -v "artifacts" | grep -v "validate_directory_structure" || true)

if [ -n "$MISSING_ARTIFACTS" ]; then
    echo "❌ FAIL: Found PNG glob patterns that don't check artifacts/ subdirectory:"
    echo "$MISSING_ARTIFACTS"
    echo ""
    echo "   Fix: Update these to check both locations:"
    echo "   list(folder.glob('*.png')) + list(folder.glob('artifacts/*.png'))"
    echo ""
    ERRORS=$((ERRORS + 1))
else
    echo "✅ PASS: All PNG globs check artifacts/ subdirectory"
fi

# Check 2: Verify benchmark_run_output/ is in .gitignore
echo ""
echo "📂 Checking .gitignore..."
if [ -f "../.gitignore" ]; then
    if grep -q "benchmark_run_output/" ../.gitignore; then
        echo "✅ PASS: benchmark_run_output/ found in .gitignore"
    else
        echo "❌ FAIL: benchmark_run_output/ not found in .gitignore"
        echo ""
        echo "   Fix: Add this line to .gitignore:"
        echo "   llm_harness/benchmark_run_output/"
        echo ""
        ERRORS=$((ERRORS + 1))
    fi
else
    echo "⚠️  WARN: .gitignore not found at ../.gitignore"
fi

# Check 3: Verify analyze_results.py scans for both patterns
echo ""
echo "🔍 Checking analyze_results.py..."
if [ -f "analyze_results.py" ]; then
    if grep -q "benchmark_run_output" analyze_results.py; then
        echo "✅ PASS: analyze_results.py scans benchmark_run_output/"
    else
        echo "❌ FAIL: analyze_results.py doesn't scan benchmark_run_output/"
        echo ""
        echo "   Fix: Update analyze() method to include new directory pattern:"
        echo "   new_pattern_dirs = sorted([d for d in (self.harness_dir / 'benchmark_run_output').glob('*') if d.is_dir()])"
        echo ""
        ERRORS=$((ERRORS + 1))
    fi

    # Check if it also still supports legacy pattern
    if grep -q "harness_\*" analyze_results.py || grep -q "harness_" analyze_results.py; then
        echo "✅ PASS: analyze_results.py still supports legacy harness_* pattern"
    else
        echo "⚠️  WARN: analyze_results.py may have dropped legacy harness_* support"
    fi
else
    echo "❌ FAIL: analyze_results.py not found"
    ERRORS=$((ERRORS + 1))
fi

# Check 4: Verify README documents new structure
echo ""
echo "📖 Checking README.md..."
if [ -f "README.md" ]; then
    if grep -q "benchmark_run_output" README.md; then
        echo "✅ PASS: README.md documents benchmark_run_output/ structure"
    else
        echo "⚠️  WARN: README.md doesn't mention benchmark_run_output/"
        echo "   Consider updating documentation to show new structure"
    fi
else
    echo "⚠️  WARN: README.md not found"
fi

# Summary
echo ""
echo "============================================"
if [ $ERRORS -eq 0 ]; then
    echo "✅ All directory structure validations passed!"
    exit 0
else
    echo "❌ Found $ERRORS error(s)"
    echo ""
    echo "Fix these issues before committing directory structure changes."
    echo "See DIRECTORY_STRUCTURE_CHANGE_CHECKLIST.md for guidance."
    exit 1
fi
