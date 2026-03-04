# Error Fix History

> Track all fixes to prevent duplicated errors or mistakes.
> Updated: 2026-03-03

---

## ⚡ Critical Invariants — Quick Reference

> Before editing ANY file, check this list. Each invariant was forged from a real production bug.

| # | Rule | What breaks if violated |
|---|------|------------------------|
| 1 | **Snapshot date = D+1** | `get_hex_snapshot` must query `GMT+2_date + 1`. Map shows all gray if wrong. |
| 2 | **Server response is truth** | After `finalize_run()`, use `syncResult['points_earned']` — NOT client `flipPoints`. Inflated header points. |
| 3 | **Local overlay ≠ LRU cache** | `_localOverlayHexes` is a plain Map. Putting it in `_hexCache` causes today's flips to disappear on eviction. |
| 4 | **clearAll() is nuclear** | Only for season reset / province change. Day rollover → use `clearLocalOverlay()` only. |
| 5 | **OnResume refreshes ALL providers** | `_onAppResume()` must call every server-derived provider. Missing one = stale data until cold restart. |
| 6 | **initState fires once** | Screens in the nav stack don't re-run `initState` on resume. Push data via `_onAppResume()`. |
| 7 | **Two data domains — never mix** | ALL TIME stats = local SQLite `runs.fold()`. Season data = server RPCs. Never read `UserModel` aggregates for display. |
| 8 | **Season boundary in RPCs** | RPCs querying 'yesterday' must guard: if yesterday < season start → return defaults (not last-season data). |
| 9 | **RPC shape = parser shape** | JSON key mismatch makes `fromJson` silently return 0. Always verify both sides. |
| 10 | **AppLifecycleManager singleton** | Only first `initialize()` wins. Don't call from multiple entry points. |
| 11 | **Server-domain fallback dates = GMT+2** | Any fallback `DateTime` in server-domain models (e.g., `YesterdayStats`, `TeamRankings`) must use `Gmt2DateUtils.todayGmt2`, never `DateTime.now()`. Wrong timezone causes stat gaps for users in non-GMT+2 zones. |
| 12 | **`_onAppResume` math.max must trust server zero** | Use `serverSeasonPoints == 0 ? 0 : math.max(serverSeasonPoints, points.seasonPoints)`. Using `math.max(server, totalSeasonPoints)` (1) blocks season resets and (2) double-counts `_localUnsyncedToday`. |
| 13 | **`snapshot_season_leaderboard()` must be date-bounded** | Old version read `users.season_points` + `users.team` — reset each season. Call after transition → empty snapshot. New version (migration 20260303000001) reads `run_history` with explicit date bounds. Safe retroactively and after reset. |
| 14 | **`get_season_leaderboard` must read `season_leaderboard_snapshot`** | Old version ignored `p_season_number` entirely and always returned current live `users` data. Every past-season navigation always showed current season. Fix (migration 20260303000003): read from `season_leaderboard_snapshot WHERE season_number = p_season_number`. |
| 15 | **`handle_season_transition` cron must run at 21:55 UTC (5 min before midnight)** | `build_daily_hex_snapshot()` runs at 22:00 UTC (midnight GMT+2). If `reset_season()` runs after or simultaneously, hexes are still populated when the new season's Day-1 snapshot is built — new season starts with S5 territory. `handle_season_transition` must run at 21:55 UTC to wipe hexes first. |
| 16 | **`updateHexColor` must use `getHex()` not `_hexCache.get()`** | `getHex()` merges `_hexCache` + `_localOverlayHexes`. Using raw `_hexCache.get()` ignores today's flips in the overlay — if the snapshot showed hex as BLUE but the user already flipped it RED today (in overlay), `updateHexColor` sees BLUE and re-counts the flip. Same-color running = spurious flip points. |
| 17 | **Dart `if` in widget tree must be INSIDE the `children: [...]` list** | Placing `if (cond) ...[...]` AFTER the closing `],` of a Column/Row `children` list (but still inside the parent widget call) causes a build error: "Expected an identifier, but got 'if'" + "Too many positional arguments". Always ensure `if` spreads go inside `children: [ ..., if (cond) ...[...], ]` before the closing `]`. |
| 18 | **`computeHexDominance` for TeamScreen must pass `includeLocalOverlay: false`** | Default is `true` (merges `_localOverlayHexes` = today's own flips). TeamScreen territory is "yesterday's snapshot" — it must never include today's runs. On Day 1 this causes the map to show non-zero territory despite the season just resetting. Always use `includeLocalOverlay: false` in `TeamStatsNotifier`. |
| 19 | **Buff indicator must always show during running** | `showMultiplier = multiplier > 1` hides the ⚡ BUFF stat on the running screen when buff is 1x. New users and Day-1 runners never see their buff status. Show always; use dim color (`AppTheme.textSecondary`) for 1x, amber for > 1x. |

**Pre-edit script**: `./scripts/pre-edit-check.sh` — interactive checklist for any edit.
**Pre-edit search**: `./scripts/pre-edit-check.sh --search <component>` — grep history for your component.

---
## Bug Fix: Territory Shows Today's Runs Instead of Snapshot (2026-03-03)

### Problem
TeamScreen territory section showed 9 red hexes on Season Day 1 even though the season reset wiped all hexes. The `computeHexDominance()` method in `HexRepository` merged both `_hexCache` (midnight snapshot) AND `_localOverlayHexes` (today's own run flips). Since territory is "yesterday's snapshot"-based (same baseline as buff calculation), including today's live flips was wrong.

### Root Cause
`HexRepository.computeHexDominance()` used `_localOverlayHexes[hexId] ?? hex.lastRunnerTeam` unconditionally, and also counted overlay-only hexes not in the LRU cache. On Day 1, the snapshot was empty (season reset) but `_localOverlayHexes` had the user's 9 today-run flips, causing the wrong territory display.

### Fix
Added `includeLocalOverlay` parameter (default `true`) to `computeHexDominance()` in `hex_repository.dart`. Updated `TeamStatsNotifier.loadTeamData()` to pass `includeLocalOverlay: false` — territory always reads snapshot-only.

```dart
// hex_repository.dart — added parameter
Map<String, Map<String, int>> computeHexDominance({
  required String homeHexAll,
  String? homeHexCity,
  bool includeLocalOverlay = true,  // NEW
})

// team_stats_provider.dart — snapshot-only for TeamScreen
final localDominance = HexRepository().computeHexDominance(
  homeHexAll: provinceHex ?? '',
  homeHexCity: cityHex,
  includeLocalOverlay: false, // Territory = snapshot-only (yesterday's state)
);
```

### Verification
- LSP diagnostics: 0 errors on both files
- `flutter analyze lib/`: 0 errors
- Default `includeLocalOverlay: true` preserved for existing map rendering (which correctly shows today's flips on the hex map)

### Lesson Learned
The hex map display correctly merges snapshot + local overlay (so runners see their own real-time flips). But the TeamScreen territory counter is a different concern — it's anchored to yesterday's snapshot, the same baseline used for buff calculation. These two usages of `computeHexDominance()` need different behaviors.

---
## Bug Fix: Lightning Ball (⚡ BUFF) Disappears During Running (2026-03-03)

### Problem
The ⚡ BUFF stat item on the running screen was hidden when `multiplier == 1`. New users, Day-1 runners, and anyone with base buff never saw their buff status during a run.

### Root Cause
`_buildSecondaryStats()` in `running_screen.dart` used `showMultiplier = multiplier > 1` to gate the buff display. This hid the entire indicator when buff was 1x.

### Fix
Removed the conditional. The buff indicator (`⚡ BUFF` stat item) is now always visible. At 1x it shows with `AppTheme.textSecondary` color (dimmed); above 1x it shows amber.

```dart
// Before: hidden at 1x
if (showMultiplier) ...[  // ← gated
  _buildStatItem(icon: Icons.flash_on, value: '${multiplier}x', color: Colors.amber),
]

// After: always visible, color-coded
...[  // ← always shown
  _buildStatItem(
    icon: Icons.flash_on,
    value: '${multiplier}x',
    color: multiplier > 1 ? Colors.amber : AppTheme.textSecondary,
  ),
]
```

### Verification
- LSP diagnostics: 0 errors
- `flutter analyze lib/`: 0 errors

### Lesson Learned
Buff status is always relevant during running. Even 1x is meaningful context. "Never show" ≠ "show dimmed for 1x".

---
## Sync Rule Change: All Runs Upload to Server (2026-03-02)

### Change
Previously, only runs with ≥1 hex flip were uploaded to the server via `finalize_run()`.
Runs with 0 flips (e.g., running in already-owned territory, running too fast, outside home province)
were silently skipped — saved locally only, never synced.

The rule is now: **ALL completed runs are uploaded to the server**, regardless of flip count.

### Motivation
- Server `users.total_distance_km`, `total_runs`, `avg_pace_min_per_km` were undercounting
  because distance-only runs never reached `finalize_run()`
- `run_history` was incomplete — a user who ran 10km through already-dominated territory had
  no server record of that effort
- Season leaderboard stat details (distance, pace) were inaccurate for active territory-holders

### Game Balance Impact (Accepted)
- RED Elite threshold: 0-flip RED runners now count in the district runner pool → Elite
  threshold becomes slightly easier to achieve (mild buff inflation, accepted)
- PURPLE participation rate: 0-flip Purple runners now count as "active" → participation rate
  inflates, potentially bumping buff tier (accepted)
- Leaderboard ranking: unaffected — still filtered by `SUM(flip_points) > 0`

### Implementation
**Server migration** (`add_has_flips_to_run_history`):
- Added `has_flips BOOLEAN NOT NULL DEFAULT true` to `run_history` table
- Updated `finalize_run()` to set `has_flips = (hex_path IS NOT NULL AND array_length > 0)`
- Existing rows default to `true` (correct — all pre-existing rows had flips)

**Client changes**:
- `run_provider.dart`: Removed `capturedHexIds.isNotEmpty` gate from sync condition
- `sync_retry_service.dart`: Removed `hexPath.isEmpty` early-continue (0-flip runs now retry)
- `run.dart`: Added `hasFlips` bool field (toMap/fromMap/fromRow; NOT in toRow — server computes)
- `local_storage.dart`: Bumped SQLite to v17, added `has_flips INTEGER NOT NULL DEFAULT 1`

### Why has_flips Column
`has_flips` is a future toggle. Current buff RPCs (`get_user_buff`) count ALL runners in
`run_history`. If the game design decision is later reversed (0-flip runs should NOT count
for buff pool), add `AND has_flips = true` to the buff RPC queries — no new migration needed.

### Verification
- `finalize_run(p_hex_path := '{}')` confirmed safe: `hexes` write guarded, `district_hex`
  from separate param (not hex_path[1]), `p_hex_parents` guarded against NULL iteration
- `flutter analyze`: 0 new errors
- LSP diagnostics: clean on all modified files

---


## Fix #N — Voice Announcements Silent on iOS (2026-03-01)

### Problem
Voice announcements (`announceRunStart`, `announceKilometer`) stopped playing silently on iOS.
No crash, no error log — TTS simply produced no sound.

### Root Cause
`flutter_tts` on iOS requires explicit `AVAudioSession` configuration via `setSharedInstance(true)`
and `setIosAudioCategory(...)`. Without it, any competing audio session (Google Ads SDK sets
`AVAudioSessionCategoryAmbient` when displaying banner ads on `MapScreen`) silently takes
priority, causing TTS output to be suppressed with no error.

Call flow that triggered it:
1. User views `MapScreen` → `AdService` loads a banner ad → Google Ads SDK sets `AVAudioSessionCategoryAmbient`
2. User taps 'Start Run' → `VoiceAnnouncementService.initialize()` runs with NO audio session config
3. `announceRunStart()` fires but TTS is silently blocked by the pre-claimed audio session

Additionally, `initialize()` had no try-catch — any TTS exception propagated to `startRun()`'s
catch block and could abort the run start entirely, with no diagnostic output.

### Fix Applied
**File**: `lib/features/run/services/voice_announcement_service.dart`

```dart
// Inside initialize(), after setVolume():
if (Platform.isIOS) {
  await _tts!.setSharedInstance(true);  // claim shared audio session
  await _tts!.setIosAudioCategory(
    IosTextToSpeechAudioCategory.playback,
    [
      IosTextToSpeechAudioCategoryOptions.allowBluetooth,
      IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
      IosTextToSpeechAudioCategoryOptions.mixWithOthers,  // coexist with music/GPS
    ],
    IosTextToSpeechAudioMode.defaultMode,
  );
}
```

Also wrapped the entire TTS setup block in try-catch so failures surface in logs instead
of propagating silently to the caller.

### Verification
- `flutter analyze` — 0 new issues (pre-existing test errors unchanged)
- LSP diagnostics clean on `voice_announcement_service.dart`
- Manual test required: start run on iOS physical device → confirm 'Run started. Let's go!' plays
  after viewing map screen with ad banner active

### Lesson Learned
> **iOS audio session is first-come-first-served.** Google Ads SDK claims `AVAudioSessionCategoryAmbient`
> when any ad loads. `flutter_tts` needs `setSharedInstance(true)` + `IosTextToSpeechAudioCategory.playback`
> with `mixWithOthers` to override this. This must be set during `initialize()`, before the first
> `speak()` call. Absence = silent TTS with zero error output.

## FlipPoints Header: Client-Server Points Mismatch (2026-02-26)

### Problem
After a run completes and syncs successfully, the FlipPoints header could show inflated points that don't match the server's validated total. The server anti-cheat (`finalize_run`) may cap `points_earned` below the client-calculated `flipPoints` (e.g., server returns 6 but client calculated 11), yet the client used its own unvalidated value.

### Root Cause
Two code paths called `onRunSynced(flipPoints)` with the **client-calculated** flip points (`hexesColored × buffMultiplier`) instead of the **server-validated** `points_earned` from the `finalize_run` RPC response:

1. **`run_provider.dart` line 587**: After Final Sync, passed local `flipPoints` to `onRunSynced()` — ignored `syncResult['points_earned']`
2. **`sync_retry_service.dart` line 78**: After retry sync, accumulated `run.flipPoints` — ignored `syncResult['points_earned']`

The `finalize_run` RPC validates: `points = LEAST(client_points, hex_path_length × server_validated_multiplier)`. When the server caps points (anti-cheat), the client's `PointsNotifier.onRunSynced()` would:
- Add the inflated client points to `seasonPoints`
- Show inflated `totalSeasonPoints` in the header
- Self-correct only on next app launch when `appLaunchSync` fetches the true server `season_points`

### Fix Applied

**`lib/features/run/providers/run_provider.dart`:**
- Extract `serverValidatedPoints` from `syncResult['points_earned']` after `finalizeRun()`
- Pass `serverValidatedPoints` (not `flipPoints`) to `onRunSynced()`
- Enhanced debug logging: now shows both server and client point values

**`lib/core/services/sync_retry_service.dart`:**
- Extract `serverPoints` from `syncResult['points_earned']` after `finalizeRun()`
- Accumulate `serverPoints` (not `run.flipPoints`) into `totalSyncedPoints`
- Enhanced debug logging with both server and client values

### Verification
- LSP diagnostics: 0 errors on both files
- `flutter analyze`: no new errors/warnings introduced
- Server `app_launch_sync` returns correct `season_points: 6` matching `run_history` sum ✓

### Lesson
After ANY server-validated write, the client must use the server's **response values** — not its own pre-validation calculations. The server is the source of truth for points; the client's role is display and optimistic UI, corrected by server responses.

---

## TeamScreen FLAME RANKINGS Shows Only 1 Elite Runner (2026-02-27)

### Problem
TeamScreen showed only 1 elite runner (the logged-in user, ljae.m10, 25pts) in the FLAME RANKINGS section. The leaderboard confirmed 3 RED runners in the same province (BreezeGold 13pts, PrismSummit 13pts), and the DB had 15 RED runners in district `86283472fffffff` who ran on 2026-02-26. The UI showed `Top 20% = Elite (≥25 pts)`, `1 in City`, `Top 1 = Elite` — consistent with only 1 runner being found.

### Root Cause
The `get_team_rankings` RPC had a `COALESCE` ordering bug:

```sql
-- BEFORE (wrong): client p_city_hex takes precedence over authoritative server value
v_city_hex := COALESCE(p_city_hex, v_user.district_hex);

-- AFTER (correct): server-stored district_hex preferred; p_city_hex is fallback only
v_city_hex := COALESCE(v_user.district_hex, p_city_hex);
```

The client computed `homeHexCity` via `getScopeHexId(homeHex, GeographicScope.city)` (Res 6 parent of Res 9 `homeHex`). GPS drift or hex boundary edge cases caused `homeHexCity` to resolve to a **neighboring district hex** (`862834727ffffff`) instead of the authoritative `users.district_hex = '86283472fffffff'`. With the wrong district hex, the RPC found only the logged-in user in that district → `red_runner_count_city = 1`, `elite_threshold = 25` (user's own points), `elite_top3 = [ljae.m10]`.

**Confirmed via SQL**: `get_team_rankings(userId, '862834727ffffff')` → 1 runner. `get_team_rankings(userId, '86283472fffffff')` → 3 runners. `get_team_rankings(userId, NULL)` → 3 runners (server fallback).

### Fix Applied

**Migration**: `fix_team_rankings_prefer_server_district_hex`
- Changed `COALESCE(p_city_hex, v_user.district_hex)` → `COALESCE(v_user.district_hex, p_city_hex)` in `get_team_rankings`
- `users.district_hex` is set server-side by `finalize_run()` — it is the authoritative value
- Client-provided `p_city_hex` is now a fallback for new users who have never completed a run

**`lib/features/team/providers/team_stats_provider.dart`**:
- Added debug logging after `TeamRankings.fromJson()` to surface `cityHex`, elite count, threshold, runner count for future diagnostics

**`get_user_buff`**: already had the correct ordering `COALESCE(v_user.district_hex, p_district_hex)` — no change needed.

### Verification
- `get_team_rankings(userId, '862834727ffffff')` (wrong hex) → now returns 3 runners ✓
- `flutter analyze`: 0 issues on `team_stats_provider.dart` ✓
- LSP diagnostics: 0 errors on `team_stats_provider.dart` ✓
- `get_user_buff` COALESCE order confirmed correct ✓

### Lesson
**Client-computed geographic scoping is unreliable**. GPS drift and H3 boundary edge cases cause client-computed parent hexes to resolve to neighboring districts. Any RPC that scopes queries by district MUST prefer `users.district_hex` (server-authoritative, set by `finalize_run`) over client-provided hex values. The client parameter should only serve as a fallback for new users who have never completed a run.

---

## TeamScreen Cross-Season Elite/Rankings Contamination (2026-02-26)

### Problem
On Season Day 1, TeamScreen showed user as ELITE with 14 pts and 2x buff multiplier.
There was no yesterday record (Day 1 = no previous day in this season), yet FLAME RANKINGS showed stale Season 4 data.
The 2x buff was also stale — computed from Season 4's last day `run_history`.

### Root Cause
Both `get_user_buff()` and `get_team_rankings()` RPCs query `run_history` for "yesterday" (`v_yesterday := today - 1`).
On Season Day 1, yesterday = previous season's last day. `run_history` is preserved across seasons,
so both RPCs found Season 4 data and returned stale elite status/rankings/buff.

The client had Day 1 protection for `getUserYesterdayStats` but NOT for `getTeamRankings` or `getBuffMultiplier`.

### Fix Applied

**Server-side (3 SQL migrations):**
- Added season boundary check to `get_user_buff()`: reads `app_config.season` to compute current season start.
  If yesterday < current season start, returns default 1x multiplier with `is_elite: false`.
- Added same check to `get_team_rankings()`: returns empty rankings if yesterday is cross-season.
- Date math fix: `DATE - DATE` returns integer in PostgreSQL, not interval.

**Client-side (belt + suspenders):**
- `TeamStatsNotifier.loadTeamData()`: extended `isDay1` guard to also skip `getTeamRankings()` call on Day 1.
  Previously only skipped `getUserYesterdayStats()`.

### Verification
- `get_user_buff` returns: `multiplier: 1, is_elite: false, reason: "Default (new season)"` ✓
- `get_team_rankings` returns: `user_is_elite: false, red_elite_top3: [], user_yesterday_points: 0` ✓

### Lesson
ALL server RPCs that query `run_history` for "yesterday" must have season boundary awareness.
Season boundary = `current_season_start` computed from `app_config.season.startDate + durationDays`.
Client-side Day 1 guards are belt-and-suspenders, not primary defense.

---
## ARCHITECTURE RULE: Two Data Domains (2026-02-26)

### Rule
Formalized as permanent architectural rule after ALL TIME stats were incorrectly reset during Season 5 transition.

**Rule 1 — Running History = Client-side (cross-season, never reset):**
- ALL TIME stats computed from local SQLite `runs` table (`allRuns.fold()`) in `run_history_screen.dart`
- NEVER read from server `UserModel` aggregate fields (`totalDistanceKm`, `avgPaceMinPerKm`, `avgCv`, `totalRuns`)
- Period stats (DAY/WEEK/MONTH/YEAR) also from local SQLite
- Survives The Void — personal running history is permanent
- Also available: `LocalStorage.getAllTimeStats()` for async contexts

**Rule 2 — Hexes + TeamScreen + Leaderboard = Server-side (season-based, reset each season):**
- Downloaded on app launch/OnResume. Reset each season.
- Leaderboard from `season_leaderboard_snapshot` (NOT live `users`)
- TeamScreen from server RPCs (home hex anchored)

### Changes Made
- `run_history_screen.dart`: ALL TIME panel now computes from `allRuns.fold()` (was reading `UserModel` server fields)
- `local_storage.dart`: Added `getAllTimeStats()` method for non-UI async contexts
- Removed unused `points_provider.dart` import from `run_history_screen.dart`
- `UserRepository.updateAfterRun()`: KEPT — harmless, server overwrites on next launch via `app_launch_sync()`
- Updated: AGENTS.md, DEVELOPMENT_SPEC.md, docs/03-data-architecture.md

### Why This Matters
Server `UserModel` fields can be incorrectly reset during season transitions. Local SQLite `runs` table is append-only and never reset, making it the reliable source of truth for personal running history.

---

## ALL TIME Stats Reset + TeamScreen Yesterday Season Boundary (2026-02-26)

### Problem
1. **ALL TIME running stats incorrectly reset**: Season 5 reset zeroed `users.total_distance_km`, `avg_pace_min_per_km`, `avg_cv`, `total_runs`, `cv_run_count`. These are ALL TIME aggregates (cross-season) and should NEVER be reset. The run_history_screen ALL TIME panel showed 0 for everything.
2. **TeamScreen yesterday shows previous season data**: On Day 1, `get_user_yesterday_stats` returns data from the previous season's last day (because `run_history` is preserved). TeamScreen displayed stale cross-season yesterday stats.

### Root Cause
1. **ALL TIME**: The season reset SQL followed the Season 2 seed migration pattern which reset ALL fields. But ALL TIME aggregate fields (`total_distance_km`, `avg_pace_min_per_km`, `avg_cv`, `total_runs`, `cv_run_count`) accumulate across seasons and must persist.
2. **Yesterday stats**: `TeamStatsNotifier.loadTeamData()` fetches yesterday's stats by date without checking if "yesterday" falls in the current season. On Day 1, yesterday = previous season's last day.

### Fix Applied

**Server-side (SQL):**
- Recalculated ALL TIME aggregates from `run_history` for all users:
  ```sql
  WITH user_agg AS (
    SELECT user_id, SUM(distance_km), COUNT(*), AVG(avg_pace_min_per_km),
           AVG(cv) FILTER (WHERE cv IS NOT NULL), COUNT(cv)
    FROM run_history GROUP BY user_id
  )
  UPDATE users SET total_distance_km=..., total_runs=..., avg_pace=..., avg_cv=..., cv_run_count=...
  FROM user_agg WHERE users.id = user_agg.user_id;
  ```
- Verified: 198 users now have restored ALL TIME stats

**Client-side:**
- `TeamStatsNotifier.loadTeamData()`: Added `SeasonService().isFirstDay` check — on Day 1, returns `{'has_data': false}` instead of calling `getUserYesterdayStats` RPC. This makes TeamScreen show "No runs yesterday" on season's first day.

### Files Modified
- `lib/features/team/providers/team_stats_provider.dart` — Day 1 season boundary check for yesterday stats

### Key Lesson: Two Data Domains for User Stats
| Field | Domain | Reset on New Season? |
|-------|--------|---------------------|
| `season_points` | Season | YES — reset to 0 |
| `team` | Season | YES — reset to NULL |
| `season_home_hex` | Season | YES — reset to NULL |
| `total_distance_km` | ALL TIME | **NO — never reset** |
| `avg_pace_min_per_km` | ALL TIME | **NO — never reset** |
| `avg_cv` | ALL TIME | **NO — never reset** |
| `total_runs` | ALL TIME | **NO — never reset** |
| `cv_run_count` | ALL TIME | **NO — never reset** |

---

## Season 5 Day 1 Fix (2026-02-26)

### Problem
Season 5 started (Feb 26 GMT+2) but the app showed stale Season 4 data: leaderboard rankings from Season 4, hex territory from Season 4.

### Root Cause
1. **Server-side**: No automated season reset existed. Season 4 data (hexes, hex_snapshot, daily_buff_stats, users.season_points) was never cleared.
2. **Client-side**: No Day 1 detection — PrefetchService always downloads snapshot/live hexes regardless of season day, wasting network calls and potentially loading stale data.

### Fix Applied

**Server-side (SQL):**
- Archived Season 4 leaderboard into `season_leaderboard_snapshot` (season_number=4, 198 entries)
- Deleted stale data: `hexes`, `hex_snapshot`, `daily_buff_stats`, `daily_province_range_stats`, `daily_all_range_stats`
- Reset SEASON-ONLY fields: `season_points=0`, `team=NULL`, `season_home_hex=NULL`
- Preserved: `run_history` (674 rows), `runs`, `daily_stats`, ALL TIME aggregate fields

**Client-side:**
- Added `SeasonService.isFirstDay` getter (`currentSeasonDay == 1`)
- `PrefetchService._downloadHexData()`: On Day 1, clears hex cache + applies local overlay only (skips server calls)
- `PrefetchService._downloadLeaderboardData()`: On Day 1, clears leaderboard cache (skips server calls)

### Files Modified
- `lib/core/services/season_service.dart` — Added `isFirstDay` getter
- `lib/core/services/prefetch_service.dart` — Added Day 1 early-return in `_downloadHexData()` and `_downloadLeaderboardData()`

### Already Handled (no changes needed)
- **Leaderboard empty state**: `_buildEmptyState()` already shows "No runners found" when entries are empty
- **Auth flow**: Router redirects to `/season-register` when `team = NULL` (existing behavior)
- **Local SQLite overlay**: `getTodayFlippedHexes()` filters by today's date, so S4 runs don't appear

### Prevention
- **TODO**: Create a reusable `reset_season()` SQL function for future season transitions
- **TODO**: Consider an Edge Function cron that runs season reset automatically on Day 1
---

## Post-Run Hex Data Disappearing (2026-02-25)

### Problem
After a run completes, the hex map shows 0% for all teams — all territory info disappears.

### Root Cause (suspected)
`RunProvider.stopRun()` completes the run but doesn't trigger a hex data refresh. The hex cache may be getting cleared or invalidated during run completion without being repopulated from the server.

### Fix Applied
**Defensive fix**: Added `PrefetchService().refresh()` + `notifyHexDataChanged()` calls in all 3 `stopRun()` code paths (guest, normal, no-result).

**Debug logging**: Added strategic logging in `HexRepository.bulkLoadFromSnapshot()`, `HexRepository.bulkLoadFromServer()`, `HexDataNotifier`, and `PrefetchService._downloadHexData()` to capture cache state if the issue recurs.

### Files Modified
- `lib/features/run/providers/run_provider.dart` — Post-run hex refresh in 3 stopRun paths
- `lib/data/repositories/hex_repository.dart` — Debug logging in bulk load methods
- `lib/features/map/providers/hex_data_provider.dart` — Warning log in getAggregatedStats
- `lib/core/services/prefetch_service.dart` — Cache size logs

### Status
Defensive fix implemented, awaiting verification. Debug logging will help diagnose root cause if it recurs.

---

## P0-1: Global Error Handlers + Back Button Protection (2026-02-25)

### Problem
No global error handlers for uncaught exceptions. Users could accidentally exit a run with the back button.

### Fix Applied
- Added `FlutterError.onError` and `PlatformDispatcher.onError` in `main.dart`
- Added `PopScope` with confirmation dialog to `RunningScreen` to prevent accidental back-button exits during active runs

### Files Modified
- `lib/main.dart` — Global error handlers
- `lib/features/run/screens/running_screen.dart` — PopScope + confirmation dialog

---

## P0-2: Silent GPS Failure + Periodic Checkpoints (2026-02-25)

### Problem
GPS could silently fail during a run with no user feedback. Run data could be lost on crash.

### Fix Applied
- Added GPS error stream to `LocationService` that emits error events
- `RunProvider` listens to GPS errors and auto-stops run after 60s of GPS failure
- Added periodic checkpoint saving (every hex flip) via `run_checkpoint` SQLite table

### Files Modified
- `lib/features/run/services/location_service.dart` — GPS error stream
- `lib/features/run/providers/run_provider.dart` — GPS error listener, periodic checkpoints

---

## P0-3: Run History Pagination + Redundant RPC Removal (2026-02-25)

### Problem
Run history loaded all records at once (potential performance issue). App called `getUserBuff()` RPC separately when it was already included in `appLaunchSync()`.

### Fix Applied
- Added pagination to `SupabaseService.getRunHistory()` (limit/offset params)
- Replaced separate `getUserBuff()` call in `AppInitProvider` with buff data from `appLaunchSync()` response

### Files Modified
- `lib/core/services/supabase_service.dart` — Pagination params, leaderboard limit 200→50
- `lib/features/auth/providers/app_init_provider.dart` — Removed redundant getUserBuff RPC

---

## P0-4: SyncRetry Exponential Backoff + Dead Letter (2026-02-25)

### Problem
Failed run syncs retried immediately on every opportunity with no backoff, potentially hammering the server. No way to give up on permanently failed syncs.

### Fix Applied
- Added `retry_count` and `next_retry_at` columns to SQLite `runs` table (DB v16)
- Exponential backoff: 30s, 2min, 8min, 32min, 2h (5 retries max)
- Dead-letter: After 5 retries, sync_status set to 'failed' and no longer retried
- `SyncRetryService` checks `next_retry_at` before retrying

### Files Modified
- `lib/core/storage/local_storage.dart` — DB v16, retry tracking methods
- `lib/core/services/sync_retry_service.dart` — Exponential backoff logic

---

## P1-1: Offline Connectivity Banner (2026-02-25)

### Problem
No indication to users when they're offline — server operations silently fail.

### Fix Applied
- Created `ConnectivityProvider` (StreamProvider) using `connectivity_plus`
- Added persistent offline banner to `HomeScreen` — appears below AppBar when offline

### Files Modified
- `lib/core/providers/connectivity_provider.dart` — NEW: StreamProvider for connectivity
- `lib/app/home_screen.dart` — Offline banner widget

---

## Common Patterns & Lessons

### Things that already handle null/empty gracefully (don't fix these):
- `LeaderboardScreen._buildEmptyState()` — "No runners found"
- `TeamScreen._buildYesterdaySection()` — "No runs yesterday" when `hasData == false`
- `YesterdayStats.fromJson()` — `has_data: false` fallback
- `_buildSeasonStatsSection()` — `?? 0` fallbacks for null leaderboard entry
- `getTodayFlippedHexes()` — filters by today's GMT+2 date, old seasons don't leak

### Season transition checklist (for future resets):
1. Archive leaderboard: `INSERT INTO season_leaderboard_snapshot SELECT ... FROM users WHERE season_points > 0`
2. Clear: `hexes`, `hex_snapshot`, `daily_buff_stats`, `daily_province_range_stats`, `daily_all_range_stats`
3. Reset SEASON-ONLY user fields: `season_points=0`, `team=NULL`, `season_home_hex=NULL`
4. **DO NOT reset ALL TIME fields**: `total_distance_km`, `avg_pace_min_per_km`, `avg_cv`, `total_runs`, `cv_run_count`
5. DO NOT delete: `run_history`, `runs`, `daily_stats`, `season_leaderboard_snapshot` (archives)
6. Client auto-handles: Day 1 detection skips snapshot/leaderboard/yesterday-stats, router redirects to team selection
7. If ALL TIME fields were accidentally reset, recalculate from `run_history` using `AVG()`/`SUM()`/`COUNT()`

---

## Hex Local Overlay Eviction + Day 1 Map Blank + Points Mismatch (2026-02-27)

### Problems
Three related bugs on Season Day 1:
1. **Hex overlay eviction**: User's own run flips (colored hexes) were being wiped from the in-memory cache whenever `PrefetchService.refresh()` ran, because `bulkLoadFromSnapshot()` called `_hexCache.clear()` — removing the local overlay that lived in the same LRU cache.
2. **Post-run map blank (Day 1)**: After run completes on Day 1, `_downloadHexData()` called `repo.clearAll()` before `_applyLocalOverlay()`. Since our Fix 1 moved the overlay to `_localOverlayHexes`, `clearAll()` wiped both stores — map showed 0/0/0 neutral.
3. **Points mismatch header vs history**: `_filterRunsForStats()` in `run_history_screen.dart` used `run.startTime` converted to display timezone for the DAY filter, while `PointsService`/SQLite used `run_date` (GMT+2 string from `endTime`). A run near midnight could land in different date buckets.

### Root Causes
1. **LRU eviction**: `applyLocalOverlay()` wrote into `_hexCache` (LRU), so snapshot reloads (`_hexCache.clear()`) silently discarded user's flips.
2. **Day 1 clearAll**: Previous fix correctly changed `clearAll()` → `clearLocalOverlay()` in Day 1 branch, but the edit accidentally dropped the closing `}` of `_RunHistoryScreenState`, nesting top-level classes inside it.
3. **Timezone mismatch**: History screen's `today` was computed from local device timezone, but SQLite queries used `Gmt2DateUtils.todayGmt2String` (server timezone). Could diverge for users in UTC−/UTC+ relative to GMT+2.

### Fixes Applied

**Fix 1 — `lib/data/repositories/hex_repository.dart`:**
- Added `final Map<String, Team> _localOverlayHexes = {}` — eviction-immune map separate from LRU cache.
- `applyLocalOverlay()` writes into `_localOverlayHexes` (not LRU) — survives all snapshot reloads.
- `updateHexColor()` (live run flips) also writes into `_localOverlayHexes` for the same reason.
- `getHex()` merges overlay on top of LRU: if LRU evicted a flip, `_localOverlayHexes` reconstructs it.
- `clearAll()` clears both (explicit full reset only — province change / season reset).
- New `clearLocalOverlay()` resets overlay only (midnight rollover).
- `computeHexDominance()` walks both LRU and overlay-only hexes, overlay wins for shared entries.
- `cacheStats` includes `'overlay': _localOverlayHexes.length`.

**Fix 2 — `lib/core/services/prefetch_service.dart`:**
- Day 1 branch of `_downloadHexData()`: changed from `repo.clearAll()` to `repo.clearLocalOverlay()` so overlay (today's run flips) is reset from SQLite rather than fully wiped.

**Fix 3 — `lib/features/history/screens/run_history_screen.dart`:**
- `_filterRunsForStats()` DAY case: when `run.runDate` is non-null, compare it directly against `Gmt2DateUtils.todayGmt2String` (same boundary as `sumAllTodayPoints()`). Falls back to display-timezone `startTime` for legacy runs without `runDate`.
- Structural fix: closing `}` of `_RunHistoryScreenState` was missing — `_BarEntry` and `_PaceLinePainter` were nested inside the class, causing 30+ compile errors. Added the missing `}` to close the class before those top-level classes.

**Fix 4 — `lib/app/home_screen.dart`:**
- `_refreshAppData()` was calling `clearAllHexData()` → `HexRepository.clearAll()` on every app resume, wiping both `_hexCache` AND `_localOverlayHexes` (today's run flips).
- Replaced with `PrefetchService().refresh()` + `notifyHexDataChanged()` — the correct pattern that preserves the overlay through snapshot reloads.
- Root of the post-run blank map: after run ended, navigating back to map screen triggered a resume event, `_refreshAppData()` fired, and wiped all hex data including the overlay just populated by the post-run refresh.

### Why Fix 4 Was the Real Root Cause
`AppLifecycleManager` is a singleton with `if (_isInitialized) return` guard — only the first `initialize()` call sets the callback. `home_screen.dart` registered `_refreshAppData()` (destructive: `clearAllHexData()`). `app_init_provider.dart` registered `_onAppResume()` (safe: `PrefetchService().refresh()`). Whichever initialized first set the destructive callback, wiping hex data on every resume — overriding all post-run refresh work.

### Files Modified
- `lib/data/repositories/hex_repository.dart` — `_localOverlayHexes`, `clearLocalOverlay()`, updated `getHex()`, `applyLocalOverlay()`, `updateHexColor()`, `clearAll()`, `computeHexDominance()`, `cacheStats`
- `lib/core/services/prefetch_service.dart` — Day 1 branch: `clearLocalOverlay()` instead of `clearAll()`
- `lib/features/history/screens/run_history_screen.dart` — DAY filter uses `run.runDate` (GMT+2); structural fix for missing `}`
- `lib/app/home_screen.dart` — `_refreshAppData()` uses `PrefetchService().refresh()` instead of `clearAllHexData()`

### Verification
- `flutter analyze lib/`: 0 errors after each fix
- LSP diagnostics: clean on all modified files

### Lessons
1. **Never put local overlay in the LRU cache** — any `clear()` call silently evicts it. Use a separate eviction-immune map.
2. **`clearAll()` is a nuclear option** — reserve for season reset / province change only. Use `clearLocalOverlay()` for day rollover.
3. **Resume callbacks must not clear data** — they should refresh (fetch + merge), not wipe. `PrefetchService().refresh()` is the correct pattern; raw `clearAllHexData()` is wrong.
4. **Date boundary must match** — client 'today' filter and SQLite 'today' filter must use the same timezone/field (`run_date` GMT+2 string), or points appear in different buckets.
5. **AppLifecycleManager singleton guard** — only the first `initialize()` wins. If two callers register callbacks, only one takes effect. Audit all `initialize()` call sites when debugging lifecycle issues.


---

## TeamScreen Territory Shows 0/0/0 Despite Downloaded Snapshot (2026-02-27)

### Problem
TeamScreen showed 0 hexes for all teams (Red/Blue/Purple) even though `hex_snapshot` had 259 rows downloaded on app launch.

### Root Cause
Double mismatch between the `get_hex_dominance` Supabase RPC and the client parser:

**Mismatch 1 — JSON key names:**
- RPC returned flat keys: `"red_hexes"`, `"blue_hexes"`, `"purple_hexes"`, `"total_hexes"`
- `HexDominanceScope.fromJson()` expected: `"red_hex_count"`, `"blue_hex_count"`, `"purple_hex_count"`
- All three parsed as `null` → defaulted to `0`

**Mismatch 2 — Response nesting:**
- `HexDominance.fromJson()` expected a nested structure: `{ "all_range": {...}, "city_range": {...} }`
- RPC returned flat counts at the top level — no nesting, no `all_range` key
- `allRange` parsed from `null` → all zeros; `cityRange` absent

**Structural blocker — No H3 in Postgres:**
- `hexes` table has no `district_hex` column (only `parent_hex` at Res 5 province)
- No H3 PostgreSQL extension installed → city-range (Res 6) filtering is impossible server-side
- The client needs city-range, but the RPC has no way to compute it

### Fix Applied

**`lib/features/team/providers/team_stats_provider.dart`:**
- Removed `supabase.getHexDominance(parentHex: provinceHex)` from the `Future.wait()` array
- After `Future.wait()`, compute dominance via `HexRepository().computeHexDominance(homeHexAll: provinceHex, homeHexCity: cityHex)` — which uses the already-downloaded hex data in the local cache
- Construct `HexDominance` + `HexDominanceScope` directly from the local counts map (`'red'`, `'blue'`, `'purple'` keys)
- Added import for `HexRepository`

This is cleaner than fixing the RPC because:
1. The snapshot is already downloaded and stored in `HexRepository` on app launch
2. `computeHexDominance()` correctly handles both province-level (`allRange`) and district-level (`cityRange`) via H3 parent resolution client-side
3. Local data reflects the user's own today flips (via `_localOverlayHexes`) which the server doesn't have yet

### Files Modified
- `lib/features/team/providers/team_stats_provider.dart` — Replaced RPC call with `HexRepository().computeHexDominance()`

### Verification
- `flutter analyze lib/`: 0 errors introduced

### Lesson
When the backend lacks a capability (H3 resolution math, no Postgres extension), and the client already has the data, compute locally. The hex snapshot is downloaded specifically so the client has territory data — use it. Don't force a round-trip RPC for data the client already holds.


---

## TeamScreen FLAME RANKINGS Shows Only Current User (2026-02-27)

### Observed Symptom
On Season 5 Day 2 (Feb 27, D-3 remaining), TeamScreen FLAME RANKINGS showed:
- ELITE section: only `#1 ljae.m10  25 pts`
- `Top 20% = Elite  (≥25 pts)` — threshold incorrectly set to the user's own points
- `1 in City` / `Top 1 = Elite` in the buff section
- Other runners (BreezeGold, PrismSummit, etc.) absent despite having Feb 26 runs in the district

The leaderboard screen correctly showed 15+ runners. Only TeamScreen rankings was wrong.

### Root Cause
Two compounding issues:

**Issue 1 — Client `isDay1` guard too broad (primary):**
```dart
// BEFORE — skipped rankings on Day 1; getHexDominance was 3rd future
final results = await Future.wait([
  if (!isDay1) supabase.getUserYesterdayStats(...) else Future.value({'has_data': false}),
  if (!isDay1) supabase.getTeamRankings(...) else Future.value(<String, dynamic>{}),
  supabase.getHexDominance(parentHex: provinceHex),  // 3rd future, wrong JSON shape
]);
```
On Day 1, `getTeamRankings()` returned `{}` → `redEliteTop3 = []`. On Day 2+, it was called
but depended on the server RPC returning correct season-scoped data.

**Issue 2 — Server RPC `get_team_rankings` lacked season boundary check:**
When called on Day 2 (`v_today = Feb 27`, `v_yesterday = Feb 26`), the old RPC correctly
returned Feb 26 data. However if called while only 1 runner had run in the district,
`elite_cutoff_rank = GREATEST(1, floor(1×0.2)) = 1` → `elite_threshold = user's own points = 25`
→ HAVING clause excluded everyone except the user → `red_elite_top3 = [{user only}]`.

This is not a logic bug in the RPC — it correctly reflects the state at query time.
The real issue was the client guard blocking the call unnecessarily on Day 1, and the
hex dominance RPC returning a wrong JSON shape (flat keys vs nested, no city-range support).

### Fixes Applied

**Fix A — `lib/features/team/providers/team_stats_provider.dart`:**
- Removed the `if (!isDay1) ... else Future.value({})` conditional around `getTeamRankings()`.
- Rankings are now **always fetched** regardless of season day.
- Removed `supabase.getHexDominance()` call (3rd future) — replaced with local computation.
- `Future.wait` now has 2 elements only (yesterday stats + rankings).
- The `getUserYesterdayStats` Day 1 guard is **preserved** — correctly prevents Season 4 stats leaking.

**Fix B — Hex dominance replaced with local `HexRepository().computeHexDominance()`:**
- The `getHexDominance` RPC returns flat keys (`red_hexes`) that don't match the client parser
  (`red_hex_count`), and can't compute city-range (Res 6) without H3 extension in Postgres.
- Local `HexRepository` already holds the full downloaded snapshot — compute directly.
- City-range (district-level) dominance is resolved client-side via H3 parent resolution.

```dart
// AFTER — always fetch rankings; 2-element Future.wait; local dominance
final results = await Future.wait([
  if (!isDay1)
    supabase.getUserYesterdayStats(userId, date: yesterdayStr)
  else
    Future.value(<String, dynamic>{'has_data': false}),
  // Rankings always fetched — server RPC handles season boundary internally.
  supabase.getTeamRankings(userId, cityHex: cityHex),
]);
// ... then compute dominance locally:
final localDominance = HexRepository().computeHexDominance(
  homeHexAll: provinceHex ?? '',
  homeHexCity: cityHex,
);
```

### Verification
- Direct RPC `get_team_rankings('08f88e4b...', '86283472fffffff')` returns 3 runners:
  ljae.m10 (25pts, rank#1), BreezeGold (13pts), PrismSummit (13pts), threshold=13, 15 runners in city ✓
- `flutter analyze lib/`: 125 issues, 0 new errors (all pre-existing info/warnings) ✓

### Files Modified
- `lib/features/team/providers/team_stats_provider.dart` — Removed `isDay1` guard for `getTeamRankings()`; removed `getHexDominance` call; added local dominance computation

### Lesson
1. **Client Day 1 guards must be narrow** — guard only the specific cross-season concern
   (`getUserYesterdayStats`). Don't block other RPCs that have their own guards.
2. **RPC results reflect real-time state** — if only 1 runner has run at query time,
   rankings correctly shows 1. This is correct behavior, not a bug.
3. **Replace broken RPCs with local computation** when the client already has the data.
   The hex snapshot is downloaded on launch specifically so client has territory data.
4. **JSON shape mismatches are silent** — `fromJson` with wrong keys returns 0, not an error.
   Always verify RPC response shape matches the client parser's expected keys.

---

## TeamScreen Rankings Stale After Season Day Rolls (OnResume Not Refreshing) (2026-02-27)

### Problem
After the previous fix (removing `isDay1` guard from `getTeamRankings()`), TeamScreen FLAME RANKINGS still showed only user `#1 ljae.m10` without other runners, even though:
- The server RPC `get_team_rankings()` returns 3 runners correctly (verified via direct SQL call)
- `run_history` has 15 red runners in the same district with Feb 26 runs
- `TeamRankings.fromJson()` correctly parses `red_elite_top3`

### Why the Previous Fix Was Incomplete
The previous fix correctly fixed the **code path** (removed the `isDay1` guard). But it was verified by a **direct RPC test** — not by actually launching the app and navigating to TeamScreen.

The real remaining bug: **`_onAppResume()` in `app_init_provider.dart` never called `teamStatsProvider.loadTeamData()`**.

`TeamScreen` only loads data in `initState` via `addPostFrameCallback`. This means:
- On **first open**: works correctly (initState fires, `_loadData()` is called)
- On **app resume** (foreground from background): `_onAppResume()` refreshes hex data, leaderboard, points, and buff — but NOT team rankings
- On **subsequent navigation** to TeamScreen (screen stays in stack): initState is NOT re-called

Result: After the season day rolled from Day 1 → Day 2, the `TeamStatsState` retained the stale state from the PREVIOUS session (when the `isDay1` guard may have returned `{}` for rankings, showing 0 other runners). Only a cold app restart would re-trigger initState and load fresh rankings.

### Root Cause Chain
1. Season Day 1 (Feb 26): `isDay1 = TRUE` → old code returned `{}` for rankings → `TeamRankings.empty()` stored in provider
2. Code fix applied: `isDay1` guard removed from `getTeamRankings()`
3. Season Day 2 (Feb 27): App foregrounded → `_onAppResume()` fires
4. `_onAppResume()` refreshes everything EXCEPT `teamStatsProvider`
5. `TeamStatsState` still holds the Day 1 empty rankings from step 1
6. User sees only 1 runner (their own data from `user_yesterday_points`, no `red_elite_top3`)

### Fix Applied

**`lib/features/auth/providers/app_init_provider.dart`:**
- Added `import '../../team/providers/team_stats_provider.dart'`
- Added `teamStatsProvider.loadTeamData()` call inside `_onAppResume()` after `appLaunchSync` succeeds
- Uses same params as `TeamScreen._loadData()`: `cityHex` (homeHexCity), `provinceHex` (homeHexAll), `userTeam`, `userName`
- Call is fire-and-forget (not awaited) to avoid blocking other OnResume work
- Placed inside the `try` block after points refresh, guarded by `if (user != null)`

```dart
// In _onAppResume(), after points.refreshFromLocalTotal():
final user = ref.read(userRepositoryProvider);
if (user != null) {
  final provinceHex = PrefetchService().homeHexAll;
  ref.read(teamStatsProvider.notifier).loadTeamData(
    user.id,
    cityHex: cityHex,
    provinceHex: provinceHex,
    userTeam: user.team.name,
    userName: user.name,
  );
}
```

### Files Modified
- `lib/features/auth/providers/app_init_provider.dart` — Added `teamStatsProvider.loadTeamData()` to `_onAppResume()` + import

### Verification
- `flutter analyze lib/features/auth/providers/app_init_provider.dart`: No issues ✓
- LSP diagnostics: 0 errors ✓
- Server RPC: `get_team_rankings('08f88e4b...', '86283472fffffff')` returns 3 runners in `red_elite_top3` ✓

### Lesson
1. **OnResume must refresh ALL stateful providers** — not just hex/leaderboard/points. Any provider that holds server-derived state and is NOT auto-invalidated (e.g., `teamStatsProvider`) must be explicitly refreshed in `_onAppResume()`.
2. **Verifying a fix via direct RPC test is insufficient** — the bug may be in the call site (when/whether the RPC is called), not the RPC itself.
3. **Riverpod `Notifier` state survives hot-reload and app-resume** — it persists until the widget tree is disposed. Stale state from a previous session's guard returning `{}` will remain visible until explicitly refreshed.
4. **`initState` is only called once** per widget lifecycle — it does NOT re-fire on app resume if the screen is already in the navigation stack.


---

## Map Shows No Colored Hexes (Snapshot Date Mismatch) (2026-02-27)

### Problem
Map screen displayed all hexes in neutral gray despite `hex_snapshot` having 259 colored rows and the dominance panel showing correct counts (12 red, 92 blue, 155 purple).

### Root Cause
Date mismatch between `build_daily_hex_snapshot()` and `get_hex_snapshot()`:

- `build_daily_hex_snapshot()` runs at midnight GMT+2 and writes `snapshot_date = TODAY + 1` (tomorrow). Correct — this builds tomorrow's baseline from today's runs.
- `get_hex_snapshot()` queried `snapshot_date = (NOW() AT TIME ZONE 'Etc/GMT-2')::DATE` (today). Wrong — this looks for today's entry but data is stored as tomorrow.

So when the app ran on Feb 27, the RPC queried for `2026-02-27`, found nothing, returned `[]`, fell back to the live `hexes` table (empty), and the map showed all gray.

The snapshot data was correctly stored for `2026-02-28` — it was the read side that had the wrong date offset.

### Fix Applied

**Supabase RPC (`get_hex_snapshot`) — migration `fix_get_hex_snapshot_date_offset`:**
```sql
-- Changed from:
v_date := COALESCE(p_snapshot_date, (NOW() AT TIME ZONE 'Etc/GMT-2')::DATE);
-- Changed to:
v_date := COALESCE(p_snapshot_date, (NOW() AT TIME ZONE 'Etc/GMT-2')::DATE + 1);
```

The `+ 1` aligns with the build function's write date. When the app runs on day D, it queries `snapshot_date = D + 1`, which is exactly what the midnight cron wrote.

### Verification
- `SELECT COUNT(*) FROM get_hex_snapshot('85283473fffffff')` returns 259 ✓
- Map will now receive colored hex data on app launch

### Lesson
The snapshot is built FOR tomorrow (it's a copy of today's state, used as tomorrow's baseline). The query must match the write date — `D + 1`. When debugging 'snapshot returns empty', always cross-check the `snapshot_date` written vs the date being queried.


---

## Buff/Ranking Alignment with Leaderboard — Confirmed Non-Issue (2026-02-27)

### User Report
TeamScreen buff ranking (2X) appeared misaligned with the leaderboard rankings.

### Investigation Result
After tracing the full data pipeline:

1. **Leaderboard** (`season_leaderboard_snapshot`): Shows accumulated season points. JewelTrack #1 (118 pts), InkBear #2 (112 pts).
2. **TeamScreen rankings** (`get_team_rankings` → `run_history.flip_points`): Shows yesterday's daily runners for buff qualification. ljae.m10 #1 (25 pts), BreezeGold #2 (13 pts), PrismSummit #3 (13 pts).

These are **intentionally different** — different domains for different purposes.

The reported symptom (TeamScreen showing only 1 runner) was caused by the previously fixed bug: `_onAppResume()` not calling `teamStatsProvider.loadTeamData()`. That fix (see entry above) was the correct and complete resolution.

The buff multiplier shown (2X) correctly reflects the RED Elite baseline (no district/province wins), which matches the server's `app_launch_sync` response.

### No Code Changes Needed
This investigation confirmed the prior fix was complete and correct.

### Lesson
**Leaderboard ≠ TeamScreen rankings** — these show fundamentally different data:
- Leaderboard = season-long accumulated points (who has the most points overall)
- TeamScreen = yesterday's daily flip points (who qualifies for Elite buff today)
When users report 'rankings look wrong', confirm which screen and which metric they're comparing.

---

## Timezone System-Wide Audit & Hardening (2026-03-01)

### Problem
User reported the midnight timer appeared local-time-based in logs. Full system timezone audit performed to clarify and enforce the two-domain rule: running history = local time, everything else = GMT+2.

### Root Causes Found & Fixed

**1. `season_service.dart` — `daysRemaining` and `currentSeasonDay`**
Both used `DateTime.now()` (device local) instead of `serverTime` (GMT+2). For a Korean user (KST = GMT+9), D-day counter and `isFirstDay` could be up to 7 hours ahead of the server.
Fixed: both now use `serverTime`.

**2. `team_stats.dart` — `YesterdayStats` fallback dates**
`YesterdayStats.fromJson()` fallback and `YesterdayStats.empty()` used `DateTime.now().subtract(Duration(days: 1))`. During midnight gap (00:00-02:00 GMT+2 = 07:00-09:00 KST) this refers to the wrong game day.
Fixed: both now use `Gmt2DateUtils.todayGmt2.subtract(const Duration(days: 1))`.

### Verified Correct (No Changes Needed)
- `app_lifecycle_manager.dart` midnight timer: already used `season.serverTime`
- `Gmt2DateUtils`: correct implementation
- `buff_service.dart`, `points_service.dart`: no `DateTime.now()` at all
- `team_stats_provider.dart`: already used `Gmt2DateUtils.todayGmt2`
- `_resolveCurrentSeason()`: correctly uses `DateTime.now().toUtc()` for pure elapsed-days math (UTC-to-UTC duration, not a date display)
- Server RPCs: all use `AT TIME ZONE 'Etc/GMT-2'`

### Documentation Added
- `AGENTS.md`: New `## Timezone Architecture` section — definitive two-domain rule, GMT+2 sources, when `DateTime.now()` is correct vs wrong, midnight-crossing run behavior, season boundary math exception
- `error-fix-history.md`: Added Critical Invariant #11

### Verification
- `flutter analyze` on all changed files: 0 issues
- LSP diagnostics on all changed files: 0 errors

### Lesson
Two categories of `DateTime.now()` exist: **wall-clock** (throttling, GPS, cache TTL — local is correct) and **game-logic** (dates for buffs, seasons, snapshots, stats — must be GMT+2). Any server-domain model that needs a fallback date must use `Gmt2DateUtils.todayGmt2`, never `DateTime.now()`. See `AGENTS.md ## Timezone Architecture` for the complete reference.

---

## Fix #N+2 — AdMob SDK Crash on Launch (SIGABRT, Thread 1)

**Date**: 2026-03-03
**Severity**: Critical (crash on launch, app unusable)

### Problem
App crashed on launch with `SIGABRT` on Thread 1 (background dispatch queue).
Crash stack: `GADApplicationVerifyPublisherInitializedCorrectly + 160`

### Root Cause
The `GADApplicationIdentifier` in `ios/Runner/Info.plist` was set to the **real production App ID** (`ca-app-pub-5211646950805880/2016747370`), but `ad_service.dart` was using **Google's generic test ad unit IDs** (`ca-app-pub-3940256099942544/...`).

The AdMob SDK runs `GADApplicationVerifyPublisherInitializedCorrectly` asynchronously on a background thread. When it detects the publisher account mismatch between the App ID and the ad unit IDs, it throws an `NSException` on a background thread, causing `SIGABRT`.

### Fix
**`ios/Runner/Info.plist`** — replaced real publisher App ID with Google's official test App ID:
```xml
<!-- Before -->
<string>ca-app-pub-5211646950805880/2016747370</string>

<!-- After -->
<string>ca-app-pub-3940256099942544~1458002511</string>
```

### When to Revert
Before App Store release, replace the test App ID in `Info.plist` with the real production App ID **AND** update `ad_service.dart` to use real ad unit IDs from the same publisher account (`ca-app-pub-5211646950805880`).

### Verification
- `flutter analyze` (lib/ only): 0 errors
- LSP diagnostics on `Info.plist`: N/A (XML)

### Lesson
The `GADApplicationIdentifier` in `Info.plist` must match the publisher account of the ad unit IDs used in code. During development, either use Google's test App ID (`ca-app-pub-3940256099942544~1458002511`) with test ad unit IDs, OR use real App ID + real ad unit IDs. Never mix real App ID with generic test unit IDs from a different publisher.

---

## Fix #N+3 — Missing Comma in SQLite `_onCreate` Schema (Silent Crash on Fresh Install)

**Date**: 2026-03-03
**Severity**: High (crashes fresh installs / new users)

### Problem
Fresh installs (no prior SQLite DB) would crash during `_onCreate` due to a SQL syntax error in the `runs` table DDL.

### Root Cause
Missing trailing comma after `next_retry_at INTEGER` in `local_storage.dart` `_onCreate()`:
```dart
// Before (broken SQL):
retry_count INTEGER DEFAULT 0,
next_retry_at INTEGER       // ← missing comma
has_flips INTEGER NOT NULL DEFAULT 1
```

### Fix
**`lib/core/storage/local_storage.dart`** line 84 — added missing comma:
```dart
// After (fixed SQL):
retry_count INTEGER DEFAULT 0,
next_retry_at INTEGER,      // ← comma added
has_flips INTEGER NOT NULL DEFAULT 1
```

### Note
Existing installs are unaffected — the schema is only executed in `_onCreate` (fresh DB). Existing users go through `_onUpgrade` which handles `has_flips` correctly.

### Verification
- `flutter analyze` (lib/ only): 0 errors
- LSP diagnostics on `local_storage.dart`: 0 errors

### Lesson
SQL DDL strings in Dart are opaque to the analyzer — syntax errors only surface at runtime on fresh installs. When adding columns to `_onCreate`, always diff against `_onUpgrade` to confirm all new columns are present with correct commas.

---
## Bug: Header Points Not Resetting After Season Transition (2026-03-03)

### Problem
Header still showed 25 pts (Season 5 carry-over) on S6 Day 1. `_onAppResume()` was called repeatedly but the displayed points never dropped to 0.

### Root Cause
`app_init_provider.dart` `_onAppResume()` lines 250-254 (original):
```dart
final safeSeasonPoints = math.max(
  serverSeasonPoints,      // 0 (server correctly reset for S6)
  points.totalSeasonPoints, // 25 (S5 stale value in UserRepository memory)
);
points.setSeasonPoints(safeSeasonPoints); // → 25 (WRONG)
```
Two compounding errors:
1. `math.max(0, 25) = 25` — the guard that was meant to handle read-replica lag prevented the season reset from taking effect
2. Used `totalSeasonPoints` (= `seasonPoints + _localUnsyncedToday`) instead of `seasonPoints` — causes double-counting of `_localUnsyncedToday` since `refreshFromLocalTotal()` is called immediately after and adds it again

### Fix
**`lib/features/auth/providers/app_init_provider.dart`**:
```dart
// Use server value directly on season reset (server 0 is authoritative).
// For read-replica lag protection, fall back to local seasonPoints only
// (NOT totalSeasonPoints — that includes _localUnsyncedToday which gets
// added again by refreshFromLocalTotal() below, causing double-counting).
final safeSeasonPoints = serverSeasonPoints == 0
    ? 0 // Season reset: always trust server zero
    : math.max(serverSeasonPoints, points.seasonPoints);
points.setSeasonPoints(safeSeasonPoints);
```

### Verification
- `flutter analyze`: 0 new errors (all pre-existing issues are in test files, unchanged)
- LSP diagnostics on `app_init_provider.dart`: 0 errors
- Cold start (`_loadTodayFlipPoints`) was already correct — no `math.max` used there

### Lesson
See **Invariant #12**. When writing a read-replica lag guard, always use `points.seasonPoints` (pure server value) not `points.totalSeasonPoints` (server + local buffer). And always special-case server zero as authoritative for season resets.

---
## Bug: Season 5 Leaderboard Snapshot Missing (2026-03-03)

### Problem
Navigating to Season 5 on LeaderboardScreen showed 'No runners found'. The `season_leaderboard_snapshot` table had no rows for `season_number = 5`.

### Root Cause
The `snapshot_season_leaderboard(p_season_number)` function (latest version in `20260222100000_fix_leaderboard_snapshot_season_points.sql`) reads from `users.season_points` and `users.team` — **live fields that are reset to 0/NULL at each season transition**. By the time anyone noticed S5 was missing, S6 had already started and these fields were wiped.

Additionally, calling the function retroactively would have been wrong even with the older `run_history`-based version (`20260222000000`), because that version had no date filter — it summed ALL `run_history` across all seasons.

### Fix
Created `supabase/scripts/retroactive_s5_snapshot.sql` — a standalone idempotent SQL script that:
- Reads `SUM(run_history.flip_points)` filtered to S5 date range (`run_date` 2026-02-26 to 2026-03-02)
- Resolves team from `run_history.team_at_run` (preserved across seasons, unlike `users.team`)
- Filters to only users with > 0 flip_points in S5
- Must be run manually in the Supabase SQL Editor (one-time operation)

### Verification (to run after applying SQL)
```sql
SELECT COUNT(*), SUM(season_points)
FROM season_leaderboard_snapshot
WHERE season_number = 5;

SELECT rank, name, team, season_points, total_runs
FROM season_leaderboard_snapshot
WHERE season_number = 5
ORDER BY rank LIMIT 10;
```

### Lesson
See **Invariant #13** (updated). `snapshot_season_leaderboard()` is now date-bounded (migration 20260303000001) — safe to call at any time, retroactively or after reset. The fix reads `run_history` with explicit date bounds derived from `app_config.season`. Old versions that read `users.season_points` are superseded.
See **Invariant #13**. `snapshot_season_leaderboard()` is NOT safe to call retroactively after a season transition because it reads live `users` fields that are reset. The midnight cron MUST run this function BEFORE season fields are cleared. If a season closes without a snapshot (bug, cron failure, etc.), use `run_history` with explicit date bounds instead.

---

## Bug: Season 6 Leaderboard Showing Season 5 Data (2026-03-03)

**Date**: 2026-03-03
**Severity**: High (leaderboard shows wrong season’s data)

### Problem
After the S5→S6 transition on 2026-03-03, `LeaderboardScreen` displayed Season 5
rankings labeled as “Season 6”. The < > season navigation arrows also always showed
the same (current) data regardless of which season was selected.

### Root Cause
Two independent failures:

**Failure 1 — `reset_season()` was never defined or called:**
`reset_season()` existed only as a comment/TODO in old migrations.
At the S5→S6 boundary, no automated transition ran, so:
- `users.season_points` still held S5 values (never zeroed)
- `get_leaderboard()` (reads live `users.season_points`) returned S5 data
- `SeasonService` advanced the season number client-side via elapsed-time math,
  so the client displayed “Season 6” while the server had S5 data

**Failure 2 — `get_season_leaderboard(p_season_number)` ignored its parameter:**
The function always JOINed live `users` regardless of `p_season_number`.
Every past-season navigation showed the current season’s live data.

### Fix
- Migration `20260303000001`: `snapshot_season_leaderboard()` rewritten to be date-bounded
  (reads `run_history` with explicit date range, uses `team_at_run`)
- Migration `20260303000002`: `reset_season(p_season_number)` properly created:
  calls snapshot first, resets only season fields, wipes season tables
- Migration `20260303000003`: `get_season_leaderboard()` fixed to read from
  `season_leaderboard_snapshot WHERE season_number = p_season_number`
- Migration `20260303000004`: `handle_season_transition()` cron function created
  (runs at 21:55 UTC, detects season boundary, calls `reset_season(ending_season)`)
- Script `supabase/scripts/immediate_s6_fix.sql`: one-time repair for S5→S6
  (retroactively snapshots S5, resets users, restores genuine S6 Day-1 activity)

### Verification
After running `immediate_s6_fix.sql`:
```sql
-- Should show S5 snapshot rows
SELECT COUNT(*), SUM(season_points) FROM season_leaderboard_snapshot WHERE season_number = 5;

-- Should show only genuine S6 activity
SELECT COUNT(*) FILTER (WHERE season_points > 0) FROM users;

-- Season tables should be empty
SELECT COUNT(*) FROM hexes;
```

### Lesson
See **Invariants #14 and #15**.
1. `reset_season()` must be a proper SQL function called automatically by cron — manual one-off SQL migrations are not reliable for repeating events.
2. `get_season_leaderboard` must read from the snapshot table, not live `users`.
3. Cron ordering is critical: season transition (21:55 UTC) MUST precede hex snapshot build (22:00 UTC).

---

## Bug: `get_season_leaderboard` Always Returned Current Season (2026-03-03)

**Date**: 2026-03-03
**Severity**: Medium (past-season navigation non-functional)

### Problem
Navigating to past seasons via the < > arrows on `LeaderboardScreen` always showed
the same data as the current season. Every value of `p_season_number` produced identical results.

### Root Cause
The original `get_season_leaderboard(p_season_number, p_limit)` (in `20260216063757_rpc_functions.sql`)
read from a `SELECT ... FROM users` query. The `WHERE` clause filtered on `province_hex`
using the passed hex, but **`p_season_number` was never referenced** in the query at all.
The function was effectively `get_leaderboard()` with a different name.

### Fix
Migration `20260303000003_fix_get_season_leaderboard.sql`:
- Drops and recreates `get_season_leaderboard(INTEGER, INTEGER)`
- Reads from `season_leaderboard_snapshot WHERE season_number = p_season_number`
- Returns identical JSON shape to `get_leaderboard()` so no client changes needed
- `district_hex` returned as `NULL::TEXT` (not in snapshot table; client handles null safely)

### Verification
```sql
SELECT COUNT(*) FROM get_season_leaderboard(5); -- should return S5 runners (after snapshot)
SELECT COUNT(*) FROM get_season_leaderboard(6); -- should return S6 runners (currently 0 until runs sync)
```

### Lesson
See **Invariant #14**. When a function accepts a season number parameter, always grep for that
parameter name inside the function body to confirm it’s actually used. Silent parameter-ignoring
produces no error, only wrong data.

---

## Bug: `_seasonRecordLabel()` Shows Non-Existent Day on Season Day 1 (2026-03-03)

**Date**: 2026-03-03
**Severity**: Medium (misleading UI label)

### Problem
On Day 1 of any season, the `SEASON RECORD` panel in `LeaderboardScreen` displayed
"SEASON RECORD until D-5" (for a 5-day test season). But D-5 doesn't exist — the
season's first day is D-4. For a 40-day season the same bug produces "SEASON RECORD
until D-40", which is also before the season started.

### Root Cause
`_seasonRecordLabel()` in `leaderboard_screen.dart`:
```dart
final yesterdayDDay = remaining + 1;
if (remaining >= 0 && yesterdayDDay <= SeasonService.seasonDurationDays) {  // ← wrong: <=
  return 'SEASON RECORD  until D-$yesterdayDDay';
}
```
On Day 1: `remaining = seasonDurationDays - 1`. So `yesterdayDDay = seasonDurationDays`.
The condition `yesterdayDDay <= seasonDurationDays` is TRUE (equal), so the label shows
`D-{seasonDurationDays}` which is the day BEFORE the season started.

### Fix
**`lib/features/leaderboard/screens/leaderboard_screen.dart`**:
```dart
// Changed <= to < so Day 1 falls back to plain 'SEASON RECORD'
if (remaining >= 0 && yesterdayDDay < SeasonService.seasonDurationDays) {
```
On Day 1: `yesterdayDDay == seasonDurationDays` → `<` is false → shows "SEASON RECORD" (correct).
On Day 2+: `yesterdayDDay < seasonDurationDays` → true → shows "SEASON RECORD until D-X" (correct).

### Verification
- `flutter analyze lib/`: 0 new errors
- LSP diagnostics on `leaderboard_screen.dart`: clean

### Lesson
When using `remaining + 1` to compute "yesterday's D-day", the first day of any season
produces `yesterdayDDay == seasonDurationDays` (a day that doesn't exist in this season).
Always use strict `<` not `<=` when comparing against duration-based boundaries.

---

## Bug: Day 1 Leaderboard Shows Generic Empty State (2026-03-03)

**Date**: 2026-03-03
**Severity**: Low (poor UX, not a data bug)

### Problem
On Season Day 1 (when no one has run yet), the `LeaderboardScreen` list showed a
generic empty icon with "No runners found". This is accurate but uninspiring and gives
no context about the season just starting.

### Fix
Added `_buildDay1EmptyState()` method that shows:
- Rocket icon
- "SEASON N HAS STARTED!" header
- "Be the first to run and claim the #1 spot."

Wired into both portrait and landscape layout branches:
```dart
runners.isEmpty
  ? (_isViewingCurrentSeason && SeasonService().isFirstDay
     ? _buildDay1EmptyState()
     : _buildEmptyState())
  : CustomScrollView(...)  // normal list
```
The regular `_buildEmptyState()` is preserved for:
- Viewing a past season with no data
- Viewing MY LEAGUE scope with no runners in the user's province

### Verification
- `flutter analyze lib/`: 0 new errors
- LSP diagnostics: clean

---

## Bug: `get_leaderboard` today_points Uses `created_at` Instead of `run_date` (2026-03-03)

**Date**: 2026-03-03
**Severity**: Medium (points land in wrong day's bucket for delayed syncs)

### Problem
The `today_points` CTE in `get_leaderboard` (which subtracts today's runs to show
"as of yesterday midnight") used `r.created_at >= midnight_gmt2_today` instead of
`r.run_date = today_gmt2`. This caused two cases of misattribution:
1. A run from today that syncs next day: `created_at` = tomorrow → subtracted from
   tomorrow's leaderboard instead of today's
2. Run at 23:59 GMT+2 syncing at 00:01 GMT+2: row appears in the next day's
   "today_points" CTE when it should be in today's

### Fix
**Migration `20260303000005_fix_get_leaderboard_run_date.sql`**:
```sql
-- Before:
WHERE r.created_at >= (date_trunc('day', now() AT TIME ZONE 'UTC' + interval '2 hours') - interval '2 hours')

-- After:
WHERE r.run_date = (NOW() AT TIME ZONE 'Etc/GMT-2')::DATE
```
`run_date` is set server-side by `finalize_run()` as `(p_end_time AT TIME ZONE 'Etc/GMT-2')::DATE`.
It is deterministic, timezone-correct, and matches the boundary used by all other RPCs.

### Verification
- Migration deployed successfully via Supabase API (HTTP 201)
- `get_leaderboard()` confirmed functional after deployment

### Lesson
See **Invariant #8** pattern. Any server function that partitions data by game day must use
`run_date` (or the equivalent `AT TIME ZONE 'Etc/GMT-2'` date cast). Using `created_at`
ties the partition to SYNC time, not RUN time — these diverge for delayed syncs.

---

## Bug: Same-Color Hex Counted as Flip (Overlay Ignored in `updateHexColor`) (2026-03-03)

**Date**: 2026-03-03
**Severity**: High (inflated flip points, wrong game mechanics)

### Problem
User running as RED team on RED hexes (already flipped earlier today) was seeing those
hexes counted as flips. Screenshot showed `○ 1 1` in header after running through
hexes visually showing as RED.

### Root Cause
`HexRepository.updateHexColor()` (line 102) read the existing hex state via:
```dart
final existing = _hexCache.get(hexId);  // BUG: only the LRU snapshot cache
```
This ignores `_localOverlayHexes`, which holds the user's own flips from earlier TODAY.

Scenario:
1. Midnight snapshot: Hex A = BLUE (stored in `_hexCache`)
2. Run 1 (morning): User (RED) flips Hex A. `_localOverlayHexes[hexA] = RED`.
3. Run 2 (afternoon): User runs over Hex A again.
4. `updateHexColor` calls `_hexCache.get(hexA)` → still sees BLUE (snapshot value).
5. Condition `BLUE != RED` is TRUE → returns `HexUpdateResult.flipped`.
6. Points incremented. ❌ Wrong.

`getHex()` already exists and correctly merges both layers:
```dart
HexModel? getHex(String hexId) {
  final cached = _hexCache.get(hexId);
  final overlayTeam = _localOverlayHexes[hexId];
  if (overlayTeam == null) return cached;
  // Overlay wins — apply team on top of cached model (or create one).
  if (cached != null) return cached.copyWith(lastRunnerTeam: overlayTeam);
  ...
}
```
But `updateHexColor` bypassed it.

### Fix
`lib/data/repositories/hex_repository.dart` — changed one line:
```dart
// Before (line 102):
final existing = _hexCache.get(hexId);

// After:
final existing = getHex(hexId);  // merges _hexCache + _localOverlayHexes
```
Also updated the comment in the `sameTeam` branch to note it covers both snapshot and
overlay cases.

### Verification
- LSP diagnostics on `hex_repository.dart`: 0 errors
- `flutter analyze lib/`: 0 new errors
- Hex rendering unaffected (it already used `getHex()`)
- `_capturedHexesThisSession` still prevents within-session double-count (unchanged)

### Lesson
See **Invariant #16**. Anytime `updateHexColor` or any flip-counting logic needs the
current effective state of a hex, it MUST call `getHex()` (the merged view) not the raw
`_hexCache`. The LRU cache only holds the midnight snapshot; today's user flips live
exclusively in `_localOverlayHexes` until the next bulkLoadFromSnapshot call.

---

## Build Error: Dart `if` Spread Outside `children` List (Recurring — 2026-03-03)

**Date**: 2026-03-03  
**Severity**: Build failure (app cannot compile)
**Recurrence**: This error has appeared MULTIPLE TIMES. Invariant #17 added to prevent it.

### Error Messages
```
Error: Expected an identifier, but got 'if'.
Try inserting an identifier before 'if'.
    if (SeasonService().isFirstDay) ...[
    ^^
Error: Expected ')' before this.
Error: Too many positional arguments: 0 allowed, but 1 found.
    return _buildCard(
                     ^
```

### Root Cause
When adding Day-1 conditional content to a widget, the `if` spread was placed **after** the `children` list closed but **before** the parent widget call closed:

```dart
// ❌ WRONG — 'if' is outside Column.children but still inside _buildCard()
return _buildCard(
  child: Column(
    children: [
      Row(...),       // last item
    ],                // ← Column.children closes here
  ),                  // ← Column closes here
  // Day 1 block lands HERE — outside children, inside _buildCard args
  if (condition) ...[
    SizedBox(),
    Text('...'),
  ],
);
```

Dart widget calls only accept named parameters (like `child:`, `children:`). An `if` expression is not a named parameter — it's a list item. Placing it outside `children: [...]` but inside the parent widget's argument list is a syntax error.

### Fix
```dart
// ✅ CORRECT — 'if' is INSIDE Column.children
return _buildCard(
  child: Column(
    children: [
      Row(...),
      // Day 1 block goes HERE, before the closing ],
      if (condition) ...[
        const SizedBox(height: 8),
        Text('...'),
      ],
    ],  // ← Column.children closes AFTER the if block
  ),    // ← Column closes
);
```

### Trigger Pattern
This error reliably appears when:
1. A widget already has a complete `Column(children: [...])` structure
2. A conditional block is appended AFTER the `],` that closes `children` (e.g., by an edit tool that appends after `],` instead of before it)
3. The append target was `],` (children end) + `),` (Column end) — but the new content needs to go between `],` and `),`... which isn't valid. It must go BEFORE `],`.

### Prevention Checklist
- [ ] Before adding any `if (cond) ...[...]` inside a widget build method, identify the exact `],` that closes the `children` list you want to insert into
- [ ] Insert the `if` block BEFORE that `],`, not after it
- [ ] After editing, count braces: every `Column(children: [` must have its `if` blocks before its closing `])`
- [ ] Run `flutter analyze` immediately after any widget tree edit — this error is always caught at compile time

### Affected File History
- `lib/features/team/screens/team_screen.dart` — `_buildSimplifiedUserBuff()` (2026-03-03)

---

## Build Error: Double `),` After Widget Replacement (Corollary to Invariant #17) (2026-03-03)

**Date**: 2026-03-03  
**Severity**: Build failure

### What Happened
When replacing a single widget (e.g. `Text(...)`) with a multi-line widget (e.g. `Row(children:[...])`),
the edit tool replaced the CONTENT of the original widget but left its trailing `)` in place.
This produced two closing parens:

```dart
// ❌ RESULT AFTER BAD REPLACEMENT:
          Row(
            children: [
              Text(...),
              Spacer(),
            ],
            ),   // ← 12-space: stale close from original widget edit
          ),     // ← 10-space: correct Row closer
```

### Fix
Remove the spurious middle `),`. Only ONE closer belongs to the Row:

```dart
// ✅ CORRECT:
          Row(
            children: [
              Text(...),
              Spacer(),
            ],
          ),     // ← correct Row closer at 10-space indent
```

### Rule
After replacing any widget with a multi-line wrapper widget, count that the
replacement produces exactly ONE closing `)` at the correct indentation level.
The original widget’s trailing `)` must not survive into the replacement.