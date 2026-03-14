#!/usr/bin/env bash
# =============================================================================
# RunStrict — Post-Revision Code Review Hook
# =============================================================================
# Rules condensed from error-fix-history.md (19 invariants + recurring bugs).
# Every FAIL maps to a documented production bug. WARNs require human judgment.
#
# Usage:
#   ./scripts/post-revision-check.sh           # Full audit of lib/
#   ./scripts/post-revision-check.sh --staged  # Git hook mode: staged files only
#   SKIP_REVISION_CHECK=1 git commit            # Emergency bypass (leaves audit trail)
#
# Install as git pre-commit hook:
#   ln -sf ../../scripts/post-revision-check.sh .git/hooks/pre-commit
# =============================================================================
set -uo pipefail
IFS=$'\n\t'

# ─── Bypass ───────────────────────────────────────────────────────────────────
if [[ "${SKIP_REVISION_CHECK:-}" == "1" ]]; then
  echo "[post-revision-check] Bypassed via SKIP_REVISION_CHECK=1" >&2
  exit 0
fi

# ─── Paths ────────────────────────────────────────────────────────────────────
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIB="$ROOT/lib"

# ─── Colors ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'; YEL='\033[1;33m'; GRN='\033[0;32m'; CYN='\033[0;36m'
BLD='\033[1m'; DIM='\033[2m'; RST='\033[0m'

FAILS=0
WARNS=0
CHECKED=0

# ─── File collection ──────────────────────────────────────────────────────────
declare -a FILES=()

if [[ "${1:-}" == "--staged" ]]; then
  while IFS= read -r f; do
    [[ "$f" == *.dart && -f "$ROOT/$f" ]] && FILES+=("$ROOT/$f")
  done < <(git -C "$ROOT" diff --cached --name-only --diff-filter=ACM 2>/dev/null || true)
else
  while IFS= read -r f; do
    FILES+=("$f")
  done < <(find "$LIB" -name "*.dart" -not -path "*/test/*" 2>/dev/null)
fi

# ─── Emit helpers ─────────────────────────────────────────────────────────────
emit_fail() {
  local id="$1" name="$2" file="$3" ln="$4" content="$5" hint="$6"
  printf "${RED}✗ FAIL${RST} ${BLD}[%s]${RST} %s\n" "$id" "$name"
  printf "  ${CYN}%s:%s${RST}  ${DIM}%s${RST}\n" "${file#"$ROOT/"}" "$ln" "${content//	/ }"
  printf "  ${GRN}▸${RST} %s\n\n" "$hint"
  (( FAILS++ )) || true
}

emit_warn() {
  local id="$1" name="$2" file="$3" ln="$4" content="$5" hint="$6"
  printf "${YEL}⚠ WARN${RST} ${BLD}[%s]${RST} %s\n" "$id" "$name"
  printf "  ${CYN}%s:%s${RST}  ${DIM}%s${RST}\n" "${file#"$ROOT/"}" "$ln" "${content//	/ }"
  printf "  ${GRN}▸${RST} %s\n\n" "$hint"
  (( WARNS++ )) || true
}

# ─── Rule helpers ─────────────────────────────────────────────────────────────

# grep_all SEV ID NAME PATTERN HINT [SKIP_RE]
grep_all() {
  local sev="$1" id="$2" name="$3" pat="$4" hint="$5" skip="${6:-}"
  (( CHECKED++ )) || true
  for f in "${FILES[@]}"; do
    [[ -f "$f" ]] || continue
    while IFS= read -r raw; do
      local ln="${raw%%:*}"
      local content="${raw#*:}"
      # Skip pure comment lines
      [[ "$content" =~ ^[[:space:]]*/\/ ]] && continue
      # Skip if exclusion pattern matches content
      if [[ -n "$skip" ]] && echo "$content" | grep -qE "$skip" 2>/dev/null; then
        continue
      fi
      if [[ "$sev" == "FAIL" ]]; then
        emit_fail "$id" "$name" "$f" "$ln" "${content:0:110}" "$hint"
      else
        emit_warn "$id" "$name" "$f" "$ln" "${content:0:110}" "$hint"
      fi
    done < <(grep -nE "$pat" "$f" 2>/dev/null || true)
  done
}

# grep_scoped SEV ID NAME PATH_SUBSTR PATTERN HINT [SKIP_RE]
# Only runs on files whose path contains PATH_SUBSTR.
grep_scoped() {
  local sev="$1" id="$2" name="$3" scope="$4" pat="$5" hint="$6" skip="${7:-}"
  (( CHECKED++ )) || true
  for f in "${FILES[@]}"; do
    [[ -f "$f" && "$f" == *"$scope"* ]] || continue
    while IFS= read -r raw; do
      local ln="${raw%%:*}"
      local content="${raw#*:}"
      [[ "$content" =~ ^[[:space:]]*/\/ ]] && continue
      if [[ -n "$skip" ]] && echo "$content" | grep -qE "$skip" 2>/dev/null; then
        continue
      fi
      if [[ "$sev" == "FAIL" ]]; then
        emit_fail "$id" "$name" "$f" "$ln" "${content:0:110}" "$hint"
      else
        emit_warn "$id" "$name" "$f" "$ln" "${content:0:110}" "$hint"
      fi
    done < <(grep -nE "$pat" "$f" 2>/dev/null || true)
  done
}

# grep_except SEV ID NAME EXCLUDED_PATH_SUBSTR PATTERN HINT
# Runs on all files EXCEPT those matching EXCLUDED_PATH_SUBSTR.
grep_except() {
  local sev="$1" id="$2" name="$3" excl="$4" pat="$5" hint="$6"
  (( CHECKED++ )) || true
  for f in "${FILES[@]}"; do
    [[ -f "$f" ]] || continue
    [[ "$f" == *"$excl"* ]] && continue
    while IFS= read -r raw; do
      local ln="${raw%%:*}"
      local content="${raw#*:}"
      [[ "$content" =~ ^[[:space:]]*/\/ ]] && continue
      if [[ "$sev" == "FAIL" ]]; then
        emit_fail "$id" "$name" "$f" "$ln" "${content:0:110}" "$hint"
      else
        emit_warn "$id" "$name" "$f" "$ln" "${content:0:110}" "$hint"
      fi
    done < <(grep -nE "$pat" "$f" 2>/dev/null || true)
  done
}

# ─── Complex checks (need context beyond single-line grep) ───────────────────

# E1: _hexCache.get() must only appear inside getHex() in hex_repository.dart
check_e1_hexcache_bypass() {
  (( CHECKED++ )) || true
  for f in "${FILES[@]}"; do
    [[ -f "$f" && "$f" == *"hex_repository"* ]] || continue
    while IFS= read -r raw; do
      local ln="${raw%%:*}"
      local content="${raw#*:}"
      [[ "$content" =~ ^[[:space:]]*/\/ ]] && continue
      # The only legitimate call is `final cached = _hexCache.get(` inside getHex()
      echo "$content" | grep -qE 'cached\s*=\s*_hexCache\.get' && continue
      # Also skip sentinel-commented intentional direct reads
      echo "$content" | grep -qE 'cache-merge:|dedup:' && continue
      emit_fail "E1" "_hexCache.get() bypasses overlay — use getHex() (Invariant #16)" \
        "$f" "$ln" "${content:0:110}" \
        "getHex() merges _hexCache + _localOverlayHexes. Direct _hexCache.get() ignores today-flips in overlay → same-color recounts → inflated flip points."
    done < <(grep -nE '_hexCache\.get\(' "$f" 2>/dev/null || true)
  done
}

# E3: computeHexDominance() in team_stats_provider must include includeLocalOverlay: false
check_e3_dominance_overlay() {
  (( CHECKED++ )) || true
  for f in "${FILES[@]}"; do
    [[ -f "$f" && "$f" == *"team_stats_provider"* ]] || continue
    while IFS= read -r raw; do
      local ln="${raw%%:*}"
      # Check call + next 5 lines for includeLocalOverlay: false
      local window
      window=$(sed -n "${ln},$((ln+5))p" "$f" 2>/dev/null || true)
      echo "$window" | grep -qE 'includeLocalOverlay\s*:\s*false' && continue
      local content
      content=$(sed -n "${ln}p" "$f" 2>/dev/null || true)
      emit_fail "E3" "computeHexDominance() missing includeLocalOverlay:false (Invariant #18)" \
        "$f" "$ln" "${content:0:110}" \
        "TeamScreen territory = snapshot-only. Must pass includeLocalOverlay: false. Default (true) merges today-run flips → spurious territory on Day 1."
    done < <(grep -n 'computeHexDominance(' "$f" 2>/dev/null || true)
  done
}

# G1: getHexSnapshot call must have +1 date offset nearby (Invariant #1)
check_g1_snapshot_date() {
  (( CHECKED++ )) || true
  for f in "${FILES[@]}"; do
    [[ -f "$f" ]] || continue
    while IFS= read -r raw; do
      local ln="${raw%%:*}"
      local content="${raw#*:}"
      [[ "$content" =~ ^[[:space:]]*/\/ ]] && continue
      # Check this line + next 3 for the +1 offset
      local window
      window=$(sed -n "${ln},$((ln+3))p" "$f" 2>/dev/null || true)
      echo "$window" | grep -qE '\+\s*1\b' && continue
      emit_warn "G1" "getHexSnapshot call — confirm snapshot_date uses +1 offset (Invariant #1)" \
        "$f" "$ln" "${content:0:110}" \
        "Snapshot is WRITTEN as D+1 by build_daily_hex_snapshot(). READ must match: snapshot_date = GMT+2_date + 1. Wrong date → empty snapshot → gray map."
    done < <(grep -n 'getHexSnapshot\|get_hex_snapshot' "$f" 2>/dev/null || true)
  done
}

# J1: AdMob App ID in Info.plist must match publisher of ad unit IDs in ad_service.dart
check_j1_admob_mismatch() {
  (( CHECKED++ )) || true
  local plist="$ROOT/ios/Runner/Info.plist"
  local adsvc
  adsvc=$(find "$LIB" -name "ad_service.dart" 2>/dev/null | head -1 || true)
  [[ -f "$plist" && -n "$adsvc" ]] || return

  local app_id
  # Strip XML comment lines before extracting -- a comment between <key> and <string>
  # (as written in our Info.plist) would cause grep -A1 to capture the comment instead.
  app_id=$(grep -v '^[[:space:]]*<!--' "$plist" 2>/dev/null \
    | grep -A1 'GADApplicationIdentifier' \
    | grep '<string>' \
    | sed 's/.*<string>\([^<]*\)<\/string>.*/\1/' || true)

  # If Info.plist uses a REAL App ID (not Google's test publisher 3940256099942544)
  # but ad_service.dart still references test ad unit IDs → SIGABRT crash
  if [[ "$app_id" != *"3940256099942544"* ]]; then
    if grep -q "3940256099942544" "$adsvc" 2>/dev/null; then
      (( FAILS++ )) || true
      printf "${RED}✗ FAIL${RST} ${BLD}[J1]${RST} AdMob App ID / ad unit publisher mismatch\n"
      printf "  ${CYN}ios/Runner/Info.plist + %s${RST}\n" "${adsvc#"$ROOT/"}"
      printf "  ${DIM}Info.plist: %s (real publisher)${RST}\n" "$app_id"
      printf "  ${DIM}ad_service.dart references Google test units (ca-app-pub-3940256099942544/...)${RST}\n"
      printf "  ${GRN}▸${RST} Use test App ID (ca-app-pub-3940256099942544~1458002511) + test units, OR real App ID + real units. Never mix → SIGABRT crash on launch.\n\n"
    fi
  fi
}

# K1: _onAppResume() must refresh all server-derived providers (Invariant #5)
check_k1_onresume_completeness() {
  (( CHECKED++ )) || true
  local app_init
  app_init=$(find "$LIB" -name "app_init_provider.dart" 2>/dev/null | head -1 || true)
  [[ -f "$app_init" ]] || return

  # Grep the whole file -- each string is unique to the resume refresh calls.
  # awk block extraction was fragile (missed captures); whole-file grep is reliable.
  declare -a missing=()
  grep -qE 'teamStatsProvider|loadTeamData'        "$app_init" || missing+=("teamStatsProvider.loadTeamData")
  grep -qE 'leaderboard|fetchLeaderboard'          "$app_init" || missing+=("leaderboardProvider")
  grep -qE 'PrefetchService.*refresh|refreshHexes' "$app_init" || missing+=("PrefetchService().refresh()")
  grep -qE 'BuffService|buffProvider|Multiplier'   "$app_init" || missing+=("BuffService refresh")
  grep -qE 'PointsService|pointsProvider|refreshFrom' "$app_init" || missing+=("PointsService refresh")

  if (( ${#missing[@]} > 0 )); then
    (( WARNS++ )) || true
    printf "${YEL}WARN${RST} ${BLD}[K1]${RST} _onAppResume() may be missing provider refresh(es)\n"
    printf "  ${CYN}%s${RST}\n" "${app_init#"$ROOT/"}"
    printf "  ${DIM}Possibly absent: %s${RST}\n" "${missing[*]}"
    printf "  ${GRN}Notice${RST} Invariant #5: every server-derived provider must be refreshed in _onAppResume(). Missing = stale data until cold restart.\n\n"
  fi
}

# ─── Header ───────────────────────────────────────────────────────────────────
printf "${BLD}RunStrict Post-Revision Check${RST}  ${DIM}← error-fix-history.md${RST}\n"
printf "${DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RST}\n"
printf "${DIM}Scanning %d Dart file(s)...${RST}\n\n" "${#FILES[@]}"

# =============================================================================
# GROUP A — Dart / code quality
# =============================================================================

grep_all FAIL A1 ".withOpacity() deprecated — use .withValues(alpha:)" \
  '\.withOpacity\(' \
  'Replace with .withValues(alpha: x). Requires Flutter ≥3.27 (enforced in pubspec.yaml). 108 callsites were fixed — do not regress.'

grep_all FAIL A2 "print() — use debugPrint()" \
  '([^a-zA-Z_])print\(' \
  'Replace with debugPrint(). AGENTS.md rule: never use print() in lib/.' \
  'debugPrint'

grep_all WARN A3 "Lint suppression (// ignore:)" \
  '//\s*ignore:' \
  'AGENTS.md: do not suppress lint without a justifying comment explaining why.'

grep_all FAIL A4 "StateNotifier — banned; use Notifier<T>" \
  '(extends|with)\s+StateNotifier\b' \
  'Riverpod 3.0 rule (AGENTS.md): use Notifier<T> or AsyncNotifier<T>. StateNotifier is removed.'

# ChangeNotifier is OK only in routes.dart (_RouterRefreshNotifier — GoRouter adapter)
grep_except WARN A5 "ChangeNotifier outside routes.dart — use Riverpod" \
  "routes.dart" \
  '(extends|with|implements)\s+ChangeNotifier\b' \
  'Only _RouterRefreshNotifier in routes.dart may use ChangeNotifier. See AGENTS.md sanctioned exception. All other state: Notifier<T>.'

# =============================================================================
# GROUP B — Riverpod 3.0 patterns
# =============================================================================

grep_all FAIL B1 "ref.watch(.notifier) — use ref.read(.notifier) for mutations" \
  'ref\.watch\([a-zA-Z0-9_]+\.notifier\)' \
  'ref.watch(.notifier) subscribes to the notifier object, not its state. Mutations: ref.read(.notifier). State reads: ref.watch(provider) (no .notifier).'

# =============================================================================
# GROUP C — Data domain violations (Invariant #7)
# =============================================================================

# ALL TIME stats must come from local SQLite runs.fold(), NOT UserModel server fields
(( CHECKED++ )) || true
for f in "${FILES[@]}"; do
  [[ -f "$f" ]] || continue
  # Only check display layer (screens, providers, widgets) — not model definitions
  [[ "$f" == */screens/* || "$f" == */providers/* || "$f" == */widgets/* ]] || continue
  # Exclude leaderboard_provider -- its UserModel delegates are for OTHER users' leaderboard
  # entries (server snapshot domain), not the current user's ALL TIME stats display panel
  [[ "$f" == *"leaderboard_provider"* ]] && continue
  while IFS= read -r raw; do
    ln="${raw%%:*}"
    content="${raw#*:}"
    [[ "$content" =~ ^[[:space:]]*/\/ ]] && continue
    emit_fail "C1" "ALL TIME stats from UserModel (Invariant #7 — data domain)" \
      "$f" "$ln" "${content:0:110}" \
      "Use allRuns.fold() from local SQLite. UserModel aggregates (totalDistanceKm, totalRuns, avgPaceMinPerKm, avgCv) are server season-fields reset by The Void."
  done < <(grep -nE '\buser\.(totalDistanceKm|totalRuns|avgPaceMinPerKm|avgCv)\b' "$f" 2>/dev/null || true)
done

# =============================================================================
# GROUP D — Points & sync integrity (Invariants #2, #12)
# =============================================================================

grep_scoped FAIL D1 "Client flipPoints passed to onRunSynced() — use server response (Invariant #2)" \
  "run_provider" \
  'onRunSynced\(.*flipPoints|onRunSynced\(.*hexesColored' \
  "Use syncResult['points_earned'] from finalize_run() response. Server anti-cheat caps points; client value inflates the header permanently until next cold start."

grep_scoped FAIL D1 "Client flipPoints passed to onRunSynced() — use server response (Invariant #2)" \
  "sync_retry_service" \
  'onRunSynced\(.*flipPoints|onRunSynced\(.*hexesColored' \
  "Use syncResult['points_earned'] from finalize_run() response. run.flipPoints bypasses the server anti-cheat cap."

grep_all FAIL D2 "math.max(…, totalSeasonPoints) blocks season reset (Invariant #12)" \
  'math\.max\(.*totalSeasonPoints|math\.max\(\s*totalSeasonPoints' \
  "Use math.max(server, points.seasonPoints). totalSeasonPoints = seasonPoints + _localUnsyncedToday: (1) double-counts the unsynced buffer, (2) blocks server zero from taking effect on season reset."

# =============================================================================
# GROUP E — HexRepository misuse (Invariants #3, #4, #16, #18)
# =============================================================================

check_e1_hexcache_bypass

grep_scoped FAIL E2 "clearAll() in home_screen — nukes today-flips overlay (Invariant #4)" \
  "home_screen" \
  '(\.clearAll\(\)|[^a-zA-Z]clearAll\(\))' \
  "Use PrefetchService().refresh() in resume handlers. clearAll() wipes _localOverlayHexes (today-run flips) → blank map after returning from a run."

grep_scoped FAIL E2 "repo.clearAll() in prefetch_service — use clearLocalOverlay() (Invariant #4)" \
  "prefetch_service" \
  '\brepo\.clearAll\(\)|HexRepository\(\)\.clearAll\(\)' \
  "Day rollover / Day-1: use repo.clearLocalOverlay(). repo.clearAll() is nuclear -- only for province change or season reset (wipes everything including today-flips)." \
  'province-change:'

check_e3_dominance_overlay

# =============================================================================
# GROUP F — Timezone violations (Invariant #11)
# =============================================================================

grep_scoped FAIL F1 "DateTime.now() in server-domain model (Invariant #11)" \
  "team_stats" \
  'DateTime\.now\(\)' \
  "Server-domain fallback dates must use Gmt2DateUtils.todayGmt2 (not DateTime.now()). Device local time is wrong for non-GMT+2 users (e.g. KST = GMT+9 is 7 hours ahead)."

grep_scoped WARN F2 "DateTime.now() in buff_service — verify wall-clock vs game-logic (Invariant #11)" \
  "buff_service" \
  'DateTime\.now\(\)' \
  "Buff dates must use Gmt2DateUtils.todayGmt2. DateTime.now() is only correct for wall-clock concerns (TTL, throttle intervals). Confirm which context this is."

grep_scoped WARN F3 "DateTime.now() in season_service -- confirm not used for game-day calc (Invariant #11)" \
  "season_service" \
  'DateTime\.now\(\)' \
  "currentSeasonDay/daysRemaining must use serverTime (GMT+2). Exception: _resolveCurrentSeason() uses DateTime.now().toUtc() for pure UTC elapsed-days math (correct). Confirm which context." \
  'toUtc\(\)'

# =============================================================================
# GROUP G — Snapshot date offset (Invariant #1)
# =============================================================================

# G1 removed: the +1 offset is enforced server-side in build_daily_hex_snapshot() RPC.
# Client call sites have no fixed date param to grep -- the offset is computed dynamically
# inside PrefetchService. Grepping getHexSnapshot/get_hex_snapshot produces only false
# positives (function definition + callers with no literal +1). The invariant is documented
# in AGENTS.md and error-fix-history.md as the authoritative guard.
# check_g1_snapshot_date  <- intentionally disabled

# =============================================================================
# GROUP H — SQL date partition (Invariant #8)
# =============================================================================

grep_all WARN H1 "SQL created_at in date filter — use run_date (Invariant #8)" \
  'created_at\s*(>=|>|=)\s' \
  "run_date is set by finalize_run() from p_end_time at GMT+2. created_at = sync time. Delayed syncs misattribute runs to the wrong game day. Use run_date."

# =============================================================================
# GROUP I — SQLite DDL safety (lesson from fix #N+3: missing comma crash)
# =============================================================================

# I1 fires once per file -- only when local_storage.dart is in scope.
# Per-line hits on every CREATE TABLE produced 15 noisy WARNs per run.
(( CHECKED++ )) || true
for f in "${FILES[@]}"; do
  [[ -f "$f" && "$f" == *"local_storage.dart"* ]] || continue
  (( WARNS++ )) || true
  printf "${YEL}WARN${RST} ${BLD}[I1]${RST} local_storage.dart in scope -- verify _onCreate commas\n"
  printf "  ${CYN}%s${RST}\n" "${f#"$ROOT/"}"
  printf "  ${DIM}DDL strings are opaque to flutter analyze. After any _onCreate edit, diff the\n"
  printf "  column list against _onUpgrade to confirm all columns and commas are present.${RST}\n"
  printf "  ${GRN}Notice${RST} Missing comma only surfaces as a crash on fresh install, not on upgrade.\n\n"
  break
done

# =============================================================================
# GROUP J — AdMob consistency (lesson from SIGABRT crash)
# =============================================================================

check_j1_admob_mismatch

# =============================================================================
# GROUP K — Structural: _onAppResume completeness (Invariant #5)
# =============================================================================

check_k1_onresume_completeness

# =============================================================================
# Flutter analyze (catches everything the rules above miss)
# =============================================================================

printf "${DIM}Running flutter analyze lib/ ...${RST}\n"
if command -v flutter &>/dev/null; then
  analyze_out=$(flutter analyze lib/ 2>&1 || true)
  lib_errors=$(printf '%s\n' "$analyze_out" | grep -E "^\s+error " | grep -v "/test/" || true)
  if [[ -n "$lib_errors" ]]; then
    (( FAILS++ )) || true
    printf "${RED}✗ FAIL${RST} ${BLD}[FL]${RST} flutter analyze: errors in lib/\n"
    printf '%s\n' "$lib_errors" | head -20
    printf '\n'
  else
    printf "${GRN}✓${RST} flutter analyze: clean\n\n"
  fi
else
  printf "${DIM}flutter not in PATH — skipping analyze${RST}\n\n"
fi

# =============================================================================
# Summary
# =============================================================================
printf "${DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RST}\n"
printf "Ran %d rules on %d file(s).\n" "$CHECKED" "${#FILES[@]}"

if (( FAILS == 0 && WARNS == 0 )); then
  printf "${GRN}${BLD}✓ All clear — no violations found.${RST}\n"
  exit 0
elif (( FAILS > 0 )); then
  printf "${RED}${BLD}✗ %d FAIL(s)${RST}  ${YEL}%d WARN(s)${RST}\n" "$FAILS" "$WARNS"
  printf "${DIM}Fix all FAILs before proceeding. WARNs are advisory.\n"
  printf "Emergency bypass: SKIP_REVISION_CHECK=1 git commit${RST}\n"
  exit 1
else
  printf "${GRN}✓ 0 FAILs${RST}  ${YEL}%d WARN(s)${RST} — advisory only\n" "$WARNS"
  exit 0
fi
