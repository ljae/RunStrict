#!/usr/bin/env bash
# Skill activation prompt hook (UserPromptSubmit)
# Auto-suggests relevant skills based on user prompts

USER_PROMPT="${USER_PROMPT:-}"

# Check for skill-rules.json
RULES_FILE="${CLAUDE_PROJECT_DIR:-.}/.claude/skills/skill-rules.json"
if [[ ! -f "$RULES_FILE" ]]; then
  exit 0
fi

# Simple keyword matching for skill suggestions
SUGGESTIONS=""

# Flutter/Dart development
if echo "$USER_PROMPT" | grep -qiE "widget|screen|riverpod|provider|notifier|dart|flutter"; then
  SUGGESTIONS="${SUGGESTIONS}flutter-dev-guidelines "
fi

# Supabase/database
if echo "$USER_PROMPT" | grep -qiE "supabase|migration|rpc|rls|database|schema|sql|edge function"; then
  SUGGESTIONS="${SUGGESTIONS}supabase-patterns "
fi

# Mapbox/map/hex
if echo "$USER_PROMPT" | grep -qiE "mapbox|map|hex|geojson|layer|camera|boundary"; then
  SUGGESTIONS="${SUGGESTIONS}mapbox-hex-patterns "
fi

# Output suggestions (non-blocking)
if [[ -n "$SUGGESTIONS" ]]; then
  echo "Relevant skills: $SUGGESTIONS"
fi

exit 0
