#!/bin/bash
# Pre-commit hook: Run flutter analyze on changed Dart files
# Blocks commit if analysis errors found. Warnings reported but don't block.

set -e

# Find changed Dart files
CHANGED_FILES=$(git diff --cached --name-only --diff-filter=ACM | grep '\.dart$' || true)

if [ -z "$CHANGED_FILES" ]; then
  echo "No Dart files changed. Skipping analysis."
  exit 0
fi

echo "Running flutter analyze on changed files..."

# Run flutter analyze
ANALYSIS_OUTPUT=$(flutter analyze 2>&1) || true

# Check for errors (not warnings)
if echo "$ANALYSIS_OUTPUT" | grep -q "error •"; then
  echo "❌ Flutter analysis found errors:"
  echo "$ANALYSIS_OUTPUT" | grep "error •"
  echo ""
  echo "Fix errors before committing. Run: flutter analyze"
  exit 1
fi

# Report warnings but don't block
if echo "$ANALYSIS_OUTPUT" | grep -q "warning •"; then
  echo "⚠️  Flutter analysis warnings (non-blocking):"
  echo "$ANALYSIS_OUTPUT" | grep "warning •"
  echo ""
fi

echo "✅ Flutter analysis passed."
exit 0
