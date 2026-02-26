# Error Fix History

> Track all fixes to prevent duplicated errors or mistakes.
> Updated: 2026-02-26

---

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
