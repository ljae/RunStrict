#!/usr/bin/env bash
# Post-tool-use file change tracker
# Tracks edited .dart files for context management

CHANGED_FILE="${TOOL_INPUT_FILE_PATH:-${TOOL_INPUT_PATH:-}}"

# Only track .dart files
if [[ -n "$CHANGED_FILE" && "$CHANGED_FILE" == *.dart ]]; then
  TRACKER_FILE="${CLAUDE_PROJECT_DIR:-.}/.claude/.changed-files"
  mkdir -p "$(dirname "$TRACKER_FILE")"
  # Append unique entries only
  if ! grep -qxF "$CHANGED_FILE" "$TRACKER_FILE" 2>/dev/null; then
    echo "$CHANGED_FILE" >> "$TRACKER_FILE"
  fi
fi

exit 0
