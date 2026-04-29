#!/usr/bin/env bash
# =============================================================================
# pre-edit-check.sh — RunStrict Pre-Edit Safety Checklist
#
# Run BEFORE touching any file in this codebase.
# Encodes lessons from error-fix-history.md to prevent recurring regressions.
#
# Usage:
#   ./scripts/pre-edit-check.sh                   # Interactive checklist
#   ./scripts/pre-edit-check.sh --search <term>   # Search error-fix-history.md
#   ./scripts/pre-edit-check.sh --analyze         # Run flutter analyze only
# =============================================================================

set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HISTORY_FILE="$REPO_ROOT/error-fix-history.md"
ARCHIVE_FILE="$REPO_ROOT/docs/invariants/fix-archive.md"
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
header() { echo -e "\n${BOLD}${CYAN}$1${RESET}"; }
ok()     { echo -e "  ${GREEN}✓${RESET} $1"; }
warn()   { echo -e "  ${YELLOW}⚠${RESET}  $1"; }
fail()   { echo -e "  ${RED}✗${RESET} $1"; }
ask()    {
  local prompt="$1"
  echo -en "  ${BOLD}→${RESET} $prompt [y/n] "
  read -r ans
  [[ "$ans" =~ ^[Yy]$ ]]
}

# ---------------------------------------------------------------------------
# --search mode: grep error-fix-history.md for a term
# ---------------------------------------------------------------------------
if [[ "${1:-}" == "--search" ]]; then
  term="${2:?Usage: $0 --search <term>}"
  header "Searching error-fix-history.md (index) + docs/invariants/fix-archive.md for: \"$term\""
  found=0
  if grep -n -i --color=always "$term" "$HISTORY_FILE" 2>/dev/null; then
    found=1
  fi
  if [[ -f "$ARCHIVE_FILE" ]] && grep -n -i --color=always "$term" "$ARCHIVE_FILE" 2>/dev/null; then
    found=1
  fi
  if [[ "$found" -eq 0 ]]; then
    warn "No matches found for \"$term\""
  fi
  exit 0
fi

# ---------------------------------------------------------------------------
# --analyze mode: just run flutter analyze
# ---------------------------------------------------------------------------
if [[ "${1:-}" == "--analyze" ]]; then
  header "Running flutter analyze..."
  cd "$REPO_ROOT"
  flutter analyze
  exit $?
fi

# ---------------------------------------------------------------------------
# Interactive checklist
# ---------------------------------------------------------------------------
echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════════════════╗${RESET}"
echo -e "${BOLD}║       RunStrict Pre-Edit Safety Checklist                ║${RESET}"
echo -e "${BOLD}╚══════════════════════════════════════════════════════════╝${RESET}"
echo -e "  Lessons from ${CYAN}error-fix-history.md${RESET} — every item below blocked a bug."
echo ""

BLOCKED=0

# ---------------------------------------------------------------------------
# Step 1 — Identify what you're editing
# ---------------------------------------------------------------------------
header "Step 1: What are you about to edit?"
echo -en "  Enter component name (RPC, provider, service, screen): "
read -r COMPONENT

if [[ -z "$COMPONENT" ]]; then
  warn "No component specified — skipping error history search."
else
  echo ""
  echo -e "  Searching ${CYAN}error-fix-history.md${RESET} + ${CYAN}docs/invariants/fix-archive.md${RESET} for \"$COMPONENT\"..."
  MATCHES_INDEX=$(grep -c -i "$COMPONENT" "$HISTORY_FILE" 2>/dev/null || echo 0)
  MATCHES_ARCHIVE=0
  if [[ -f "$ARCHIVE_FILE" ]]; then
    MATCHES_ARCHIVE=$(grep -c -i "$COMPONENT" "$ARCHIVE_FILE" 2>/dev/null || echo 0)
  fi
  MATCHES=$((MATCHES_INDEX + MATCHES_ARCHIVE))
  if [[ "$MATCHES" -gt 0 ]]; then
    warn "Found $MATCHES line(s) mentioning \"$COMPONENT\" (index: $MATCHES_INDEX, archive: $MATCHES_ARCHIVE):"
    { grep -n -i "$COMPONENT" "$HISTORY_FILE" 2>/dev/null; \
      [[ -f "$ARCHIVE_FILE" ]] && grep -n -i "$COMPONENT" "$ARCHIVE_FILE" 2>/dev/null; } | head -10 | while IFS= read -r line; do
      echo "    $line"
    done
    echo ""
    if ! ask "Have you READ those entries and understood the prior bugs?"; then
      fail "READ error-fix-history.md before proceeding."
      BLOCKED=1
    else
      ok "Prior bugs reviewed."
    fi
  else
    ok "No prior bugs recorded for \"$COMPONENT\"."
  fi
fi

# ---------------------------------------------------------------------------
# Step 2 — Data domain check
# ---------------------------------------------------------------------------
header "Step 2: Data Domain (Two Domains — Never Mix)"
echo "  Running History = local SQLite ONLY  |  Hex/Team/Leaderboard = server-side ONLY"
echo "  Points header = hybrid (PointsService: server baseline + local unsynced)"
echo ""
if ! ask "Is your change confined to ONE data domain (not mixing SQLite + server)?"; then
  fail "Do NOT mix client-side running history with server-side season data."
  fail "See AGENTS.md: 'Two Data Domains' rule."
  BLOCKED=1
else
  ok "Single data domain confirmed."
fi

# ---------------------------------------------------------------------------
# Step 3 — Consumer trace
# ---------------------------------------------------------------------------
header "Step 3: Consumer Trace"
echo "  List every consumer of the function/provider you're changing."
echo "  Example chain: get_hex_snapshot → PrefetchService → HexRepository → HexDataProvider → hexagon_map"
echo ""
echo -en "  Name the chain of consumers (or press Enter to skip): "
read -r CHAIN
if [[ -z "$CHAIN" ]]; then
  warn "No chain listed — risk of missing a downstream consumer."
  if ! ask "Are you sure you've traced all callers?"; then
    fail "Trace the full call chain before editing. Use: grep -r 'YourFunctionName' lib/"
    BLOCKED=1
  fi
else
  ok "Consumer chain: $CHAIN"
fi

# ---------------------------------------------------------------------------
# Step 4 — Critical Invariants check
# ---------------------------------------------------------------------------
header "Step 4: Critical Invariants"
echo ""

INVARIANT_FAIL=0

# 4a — Snapshot date
if echo "${COMPONENT}${CHAIN:-}" | grep -qi "snapshot\|get_hex_snapshot\|build_daily_hex_snapshot"; then
  echo -e "  ${YELLOW}⚠  Snapshot-related edit detected.${RESET}"
  if ! ask "Does your query use snapshot_date = GMT+2_date + 1 (NOT today, NOT D, but D+1)?"; then
    fail "INVARIANT VIOLATED: Snapshot date must be D+1 (tomorrow)."
    fail "build_daily_hex_snapshot writes snapshot_date = TODAY+1."
    fail "get_hex_snapshot must read snapshot_date = (NOW() AT TIME ZONE 'Etc/GMT-2')::DATE + 1"
    INVARIANT_FAIL=1
  else
    ok "Snapshot date offset confirmed (D+1)."
  fi
fi

# 4b — OnResume completeness
if echo "${COMPONENT}${CHAIN:-}" | grep -qi "provider\|notifier"; then
  echo -e "  ${YELLOW}⚠  Provider/Notifier edit detected.${RESET}"
  if ! ask "If this is a NEW server-derived provider, have you added its refresh to _onAppResume()?"; then
    warn "Remember: _onAppResume() in app_init_provider.dart must refresh ALL stateful providers."
    warn "Failing to add new providers here = stale data on app resume."
    INVARIANT_FAIL=1
  else
    ok "OnResume completeness confirmed."
  fi
fi

# 4c — clearAll guard
if echo "${COMPONENT}${CHAIN:-}" | grep -qi "clearAll\|hexRepository\|hex_repository"; then
  echo -e "  ${YELLOW}⚠  HexRepository edit detected.${RESET}"
  if ! ask "Are you certain clearAll() is ONLY called for season reset or province change?"; then
    fail "INVARIANT VIOLATED: clearAll() is nuclear — wipes local overlay too."
    fail "For day rollover use clearLocalOverlay() instead."
    INVARIANT_FAIL=1
  else
    ok "clearAll() usage confirmed appropriate."
  fi
fi

# 4d — RPC response vs client calculation
if echo "${COMPONENT}${CHAIN:-}" | grep -qi "finalize_run\|syncResult\|points_earned\|flip_points"; then
  echo -e "  ${YELLOW}⚠  Points sync edit detected.${RESET}"
  if ! ask "After finalize_run(), does your code use syncResult['points_earned'] (NOT client flipPoints)?"; then
    fail "INVARIANT VIOLATED: Server response is truth."
    fail "Client-calculated flipPoints may be rejected by anti-cheat. Use syncResult['points_earned']."
    INVARIANT_FAIL=1
  else
    ok "Server-validated points usage confirmed."
  fi
fi

# 4e — local overlay isolation
if echo "${COMPONENT}${CHAIN:-}" | grep -qi "localOverlay\|_localOverlay\|overlay"; then
  echo -e "  ${YELLOW}⚠  Local overlay edit detected.${RESET}"
  if ! ask "Is _localOverlayHexes stored in a plain Map (NOT the LRU cache)?"; then
    fail "INVARIANT VIOLATED: Local overlay must be eviction-immune."
    fail "_localOverlayHexes must be a plain Map, never stored in _hexCache (LRU)."
    INVARIANT_FAIL=1
  else
    ok "Local overlay isolation confirmed."
  fi
fi

if [[ "$INVARIANT_FAIL" -eq 1 ]]; then
  BLOCKED=1
fi

# ---------------------------------------------------------------------------
# Step 5 — flutter analyze (baseline)
# ---------------------------------------------------------------------------
header "Step 5: flutter analyze (baseline before edit)"
cd "$REPO_ROOT"
echo "  Running..."
if flutter analyze --no-fatal-infos 2>&1 | tail -3; then
  ok "Analyzer clean — proceed with editing."
else
  warn "Analyzer has issues BEFORE your edit. Fix these first."
fi

# ---------------------------------------------------------------------------
# Result
# ---------------------------------------------------------------------------
echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════════════════╗${RESET}"
if [[ "$BLOCKED" -eq 1 ]]; then
  echo -e "${BOLD}║  ${RED}CHECKLIST INCOMPLETE — Fix issues above before editing.${RESET}  ${BOLD}║${RESET}"
  echo -e "${BOLD}╚══════════════════════════════════════════════════════════╝${RESET}"
  echo ""
  echo -e "  ${CYAN}After your edit, remember to:${RESET}"
  echo "  1. Run: flutter analyze"
  echo "  2. Check LSP diagnostics on modified files"
  echo "  3. Trace the app call path end-to-end (not just the RPC)"
  echo "  4. Update: error-fix-history.md"
  exit 1
else
  echo -e "${BOLD}║  ${GREEN}✓ ALL CHECKS PASSED — safe to edit.${RESET}              ${BOLD}       ║${RESET}"
  echo -e "${BOLD}╚══════════════════════════════════════════════════════════╝${RESET}"
  echo ""
  echo -e "  ${CYAN}After your edit, run:${RESET}"
  echo "  ./scripts/pre-edit-check.sh --analyze"
  echo "  Then update error-fix-history.md with what you changed and why."
  exit 0
fi
