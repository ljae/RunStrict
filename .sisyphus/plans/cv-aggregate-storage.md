# CV & Aggregate Storage Architecture

## TL;DR

> **Quick Summary**: Implement lap tracking during runs to calculate CV (pace consistency), store detailed run data locally on device, and sync only aggregate stats to server for leaderboard display.
> 
> **Deliverables**:
> - LapService for CV calculation logic
> - Lap tracking integration in RunTracker
> - Local SQLite schema v6 (cv column + laps table)
> - Server schema update (aggregate columns on users)
> - Updated finalize_run RPC with CV/aggregates
> - Leaderboard UI showing Stability Score, avg pace, total distance
> - Unit tests + Playwright verification
> 
> **Estimated Effort**: Medium
> **Parallel Execution**: YES - 3 waves
> **Critical Path**: Task 1 → Task 2 → Task 3 → Task 5 → Task 7 → Task 9

---

## Context

### Original Request
Implement a data storage architecture change where:
1. Personal running history (km, time, avg pace, CV per run, lap splits) stored LOCALLY on device
2. Only aggregated info transferred to server for leaderboard/ranking: total distance, avg pace, flip points, avg CV

### Interview Summary
**Key Discussions**:
- CV Algorithm: Split run into 1km laps, calculate `(stdev / mean) × 100`
- Warmup/Cooldown: Include everything (no filtering)
- Partial Laps: Exclude from CV calculation (only complete 1km laps count)
- Runs < 1km: CV = null (no complete laps to calculate variance)
- Server CV Aggregation: Simple average `sum(cv) / run_count`
- Display: Stability Score = `100 - CV` (higher = better), clamped 0-100, shown as integer
- Lap Data: Store individual lap splits locally for run detail view
- Tests: Implementation first, then add tests

**Research Findings**:
- `GpsValidator` has 20-sec moving average pace (different purpose - for hex capture validation)
- `RunTracker` tracks `distanceMeters` incrementally - easy to detect 1km crossings
- `LocalStorage` at v5, needs migration to v6
- `RunSummary` is upload payload - needs `cv` field
- Leaderboard uses `LeaderboardRunner` model with mock data fallback
- `finalize_run` RPC already calculates avg_pace and updates run_history

### Metis Review
**Identified Gaps** (addressed):
- CV for short runs: Decided null (excluded from aggregation)
- Lap data storage: Decided yes, store for run detail view
- Stability Score precision: Decided integer display
- Standard deviation type: Using sample stdev (n-1 denominator)
- Single-lap runs: CV = 0 (no variance with one sample - mathematically)

---

## Work Objectives

### Core Objective
Track pace consistency (CV) during runs via 1km lap splits, store detailed data locally, and sync aggregate statistics to server for leaderboard ranking.

### Concrete Deliverables
1. `lib/services/lap_service.dart` - CV calculation logic
2. `lib/models/lap_model.dart` - Lap data model
3. Updated `lib/services/run_tracker.dart` - Lap detection integration
4. Updated `lib/storage/local_storage.dart` - v6 schema with laps table
5. Updated `lib/models/run_summary.dart` - cv field for upload
6. Updated `lib/models/user_model.dart` - aggregate fields
7. `supabase/migrations/003_cv_aggregates.sql` - Server schema
8. Updated `lib/services/supabase_service.dart` - New RPC calls
9. Updated `lib/screens/leaderboard_screen.dart` - New stats display
10. `test/services/lap_service_test.dart` - Unit tests
11. Playwright verification of leaderboard

### Definition of Done
- [ ] `flutter test` passes with new lap_service_test.dart
- [ ] Run completion calculates CV from lap data
- [ ] Local SQLite stores cv column and lap splits
- [ ] Server receives cv in finalize_run and updates user aggregates
- [ ] Leaderboard displays Stability Score, avg pace, total distance
- [ ] Playwright screenshot confirms leaderboard UI update

### Must Have
- Lap detection at exactly 1km intervals
- CV calculation using sample standard deviation
- Stability Score clamped to 0-100
- Backward-compatible schema migration (v5 → v6)
- Incremental aggregate updates on server

### Must NOT Have (Guardrails)
- ❌ Real-time lap notifications during run (out of scope)
- ❌ Warmup/cooldown filtering (user confirmed: include everything)
- ❌ Weighted CV average (user confirmed: simple average)
- ❌ CV backfill for existing runs (forward-only)
- ❌ Lap data stored on server (local-only per privacy spec)
- ❌ Modification of existing runs table columns (only ADD new ones)
- ❌ Changes to 20-sec moving average window (that's for hex capture)

---

## Verification Strategy (MANDATORY)

### Test Decision
- **Infrastructure exists**: YES (flutter test)
- **User wants tests**: YES (Tests after implementation)
- **Framework**: flutter_test

### Approach
1. Implement features first
2. Add unit tests for CV calculation logic
3. Add integration test for full flow
4. Playwright for visual UI verification

---

## Execution Strategy

### Parallel Execution Waves

```
Wave 1 (Start Immediately):
├── Task 1: Create LapModel and LapService (pure logic, no deps)
├── Task 4: Create server migration SQL (independent)
└── (preparation only)

Wave 2 (After Wave 1):
├── Task 2: Integrate lap tracking into RunTracker (depends: 1)
├── Task 3: Update local SQLite schema v6 (depends: 1)
├── Task 5: Update RunSummary and UserModel (depends: 1)
└── Task 6: Update SupabaseService RPC calls (depends: 4)

Wave 3 (After Wave 2):
├── Task 7: Update finalize_run RPC logic (depends: 4, 5)
├── Task 8: Update Leaderboard UI (depends: 5, 6)
├── Task 9: Add unit tests (depends: 1, 2)
└── Task 10: Playwright verification (depends: 8)

Critical Path: Task 1 → Task 2 → Task 3 → Task 5 → Task 7 → Task 9
Parallel Speedup: ~35% faster than sequential
```

### Dependency Matrix

| Task | Depends On | Blocks | Can Parallelize With |
|------|------------|--------|---------------------|
| 1 | None | 2, 3, 5, 9 | 4 |
| 2 | 1 | 3, 9 | 4, 5, 6 |
| 3 | 1, 2 | None | 5, 6 |
| 4 | None | 6, 7 | 1, 2, 3, 5 |
| 5 | 1 | 7, 8 | 2, 3, 4, 6 |
| 6 | 4 | 8 | 2, 3, 5 |
| 7 | 4, 5 | None | 8, 9 |
| 8 | 5, 6 | 10 | 7, 9 |
| 9 | 1, 2 | None | 7, 8, 10 |
| 10 | 8 | None | 9 |

### Agent Dispatch Summary

| Wave | Tasks | Recommended Dispatch |
|------|-------|---------------------|
| 1 | 1, 4 | `run_in_background=true` (parallel) |
| 2 | 2, 3, 5, 6 | Sequential within wave (tight deps) |
| 3 | 7, 8, 9, 10 | 7+8 parallel, then 9+10 parallel |

---

## TODOs

### Wave 1: Foundation (Start Immediately)

- [ ] 1. Create LapModel and LapService

  **What to do**:
  - Create `lib/models/lap_model.dart`:
    - `lapNumber`: int
    - `distanceMeters`: double (should be 1000.0 for complete laps)
    - `durationSeconds`: double
    - `avgPaceSecPerKm`: double (derived: durationSeconds / (distanceMeters/1000))
    - `startTimestampMs`: int
    - `endTimestampMs`: int
    - `toMap()` and `fromMap()` for SQLite serialization
  
  - Create `lib/services/lap_service.dart`:
    - `calculateCV(List<Lap> laps)`: Returns CV as double (or null if < 2 laps)
    - `calculateStabilityScore(double? cv)`: Returns `max(0, 100 - cv).round()` or null
    - Uses sample standard deviation formula: `sqrt(sum((x-mean)^2) / (n-1))`
    - CV formula: `(stdev / mean) * 100`

  **Must NOT do**:
  - Do not add any run-state tracking to LapService (it's stateless)
  - Do not integrate with RemoteConfig yet (1km is fixed for now)
  - Do not add any UI or notification logic

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Pure logic implementation, single responsibility, ~100 lines total
  - **Skills**: [`moai-lang-flutter`]
    - `moai-lang-flutter`: Flutter/Dart patterns and best practices

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Task 4)
  - **Blocks**: Tasks 2, 3, 5, 9
  - **Blocked By**: None (can start immediately)

  **References**:
  - `lib/models/location_point.dart:1-50` - Model pattern with toMap/fromMap
  - `lib/services/gps_validator.dart:40-46` - `_PaceSample` class pattern for lap data
  - `lib/services/gps_validator.dart:216-266` - Moving average calculation pattern (adapt for CV)

  **Acceptance Criteria**:
  - [ ] `LapModel` has all required fields with proper types
  - [ ] `LapService.calculateCV([5.0, 5.5, 5.0])` returns correct CV (~4.71)
  - [ ] `LapService.calculateCV([])` returns null (no laps)
  - [ ] `LapService.calculateCV([5.0])` returns 0 or null (single lap = no variance)
  - [ ] `LapService.calculateStabilityScore(15.0)` returns 85
  - [ ] `LapService.calculateStabilityScore(120.0)` returns 0 (clamped)
  - [ ] `flutter analyze` passes with no errors

  **Commit**: YES
  - Message: `feat(cv): add LapModel and LapService for CV calculation`
  - Files: `lib/models/lap_model.dart`, `lib/services/lap_service.dart`
  - Pre-commit: `flutter analyze`

---

- [ ] 4. Create Server Migration SQL

  **What to do**:
  - Create `supabase/migrations/003_cv_aggregates.sql`:
    - Add columns to `users` table:
      - `total_distance_km DOUBLE PRECISION DEFAULT 0`
      - `avg_pace_min_per_km DOUBLE PRECISION` (nullable - no runs = no pace)
      - `avg_cv DOUBLE PRECISION` (nullable - no CV data = no avg)
      - `total_runs INTEGER DEFAULT 0`
    - Update `finalize_run` function to:
      - Accept new parameter `p_cv DOUBLE PRECISION DEFAULT NULL`
      - Update user aggregates incrementally:
        - `total_distance_km = total_distance_km + p_distance_km`
        - `total_runs = total_runs + 1`
        - `avg_pace_min_per_km` = incremental average
        - `avg_cv` = incremental average (only if p_cv IS NOT NULL)
    - Update `get_leaderboard` to return new columns
    - Update `app_launch_sync` to include new user stats

  **Must NOT do**:
  - Do not DROP or ALTER existing columns
  - Do not store lap-level data on server (local only)
  - Do not modify run_history table (CV is per-run, stored there via existing flow)

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: SQL migration script, well-defined schema changes
  - **Skills**: []
    - No special skills needed for SQL

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Task 1)
  - **Blocks**: Tasks 6, 7
  - **Blocked By**: None (can start immediately)

  **References**:
  - `supabase/migrations/002_rpc_functions.sql:1-100` - Existing finalize_run RPC pattern
  - `supabase/migrations/002_rpc_functions.sql:195-321` - app_launch_sync pattern
  - `supabase/migrations/001_initial_schema.sql:36-45` - users table current schema

  **Acceptance Criteria**:
  - [ ] SQL file is syntactically valid
  - [ ] Uses `ADD COLUMN IF NOT EXISTS` for safety
  - [ ] `finalize_run` accepts `p_cv` parameter with NULL default
  - [ ] `finalize_run` uses incremental formula for averages
  - [ ] `get_leaderboard` returns `total_distance_km`, `avg_pace_min_per_km`, `avg_cv`
  - [ ] Comments explain the incremental average formulas

  **Manual Verification**:
  - [ ] Review SQL in Supabase SQL Editor (syntax check)
  - [ ] Verify column additions don't break existing queries

  **Commit**: YES
  - Message: `feat(db): add CV aggregate columns and update RPCs`
  - Files: `supabase/migrations/003_cv_aggregates.sql`
  - Pre-commit: None (SQL file)

---

### Wave 2: Integration (After Wave 1)

- [ ] 2. Integrate Lap Tracking into RunTracker

  **What to do**:
  - Modify `lib/services/run_tracker.dart`:
    - Add `List<Lap> _completedLaps` instance variable
    - Add `double _currentLapStartDistance` to track when current lap began
    - Add `DateTime? _currentLapStartTime` for lap timing
    - In `_onLocationUpdate()`, after updating distance:
      - Check if `distanceMeters >= _currentLapStartDistance + 1000`
      - If yes, create new `Lap` with pace calculated from lap segment
      - Reset lap tracking for next lap
    - Add `calculateRunCV()` method that uses `LapService`
    - In `stopRun()`, calculate CV and include in returned `RunStopResult`
    - Add `List<Lap> get completedLaps` getter for access

  **Must NOT do**:
  - Do not modify the 20-sec moving average logic (it's for hex capture)
  - Do not emit notifications when lap completes (out of scope)
  - Do not filter warmup/cooldown (user decision: include everything)

  **Recommended Agent Profile**:
  - **Category**: `unspecified-low`
    - Reason: Modification of existing service, requires careful integration
  - **Skills**: [`moai-lang-flutter`]
    - `moai-lang-flutter`: Dart async patterns, state management

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Sequential (depends on Task 1)
  - **Blocks**: Tasks 3, 9
  - **Blocked By**: Task 1

  **References**:
  - `lib/services/run_tracker.dart:140-288` - `_onLocationUpdate()` method to modify
  - `lib/services/run_tracker.dart:319-348` - `stopRun()` method to update
  - `lib/services/gps_validator.dart:216-266` - Pattern for tracking samples over distance

  **Acceptance Criteria**:
  - [ ] `_completedLaps` populated as 1km intervals are crossed
  - [ ] Each lap has correct `avgPaceSecPerKm` calculated from its segment
  - [ ] `stopRun()` returns CV value (or null for short runs)
  - [ ] `completedLaps` getter returns immutable list
  - [ ] No changes to hex capture logic or moving average
  - [ ] `flutter analyze` passes

  **Commit**: YES
  - Message: `feat(tracking): integrate lap detection into RunTracker`
  - Files: `lib/services/run_tracker.dart`
  - Pre-commit: `flutter analyze`

---

- [ ] 3. Update Local SQLite Schema to v6

  **What to do**:
  - Modify `lib/storage/local_storage.dart`:
    - Bump `_databaseVersion` from 5 to 6
    - Add `cv REAL` column to `runs` table in `_onCreate`
    - Create new `laps` table in `_onCreate`:
      ```sql
      CREATE TABLE laps (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        runId TEXT NOT NULL,
        lapNumber INTEGER NOT NULL,
        distanceMeters REAL NOT NULL,
        durationSeconds REAL NOT NULL,
        avgPaceSecPerKm REAL NOT NULL,
        startTimestampMs INTEGER NOT NULL,
        endTimestampMs INTEGER NOT NULL,
        FOREIGN KEY (runId) REFERENCES runs (id) ON DELETE CASCADE
      )
      ```
    - Add index: `CREATE INDEX idx_laps_runId ON laps(runId)`
    - Add migration in `_onUpgrade` for v5 → v6:
      - `ALTER TABLE runs ADD COLUMN cv REAL`
      - Create laps table
    - Update `saveRun()` to:
      - Insert CV value into runs table
      - Insert lap data into laps table
    - Add `getLapsForRun(String runId)` method
    - Update `getRunById()` to include CV

  **Must NOT do**:
  - Do not modify existing columns (only ADD)
  - Do not remove pauseCount column (unrelated)
  - Do not change routes table structure

  **Recommended Agent Profile**:
  - **Category**: `unspecified-low`
    - Reason: Database migration requires careful handling
  - **Skills**: [`moai-lang-flutter`]
    - `moai-lang-flutter`: SQLite patterns in Flutter

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Sequential (after Task 2)
  - **Blocks**: None
  - **Blocked By**: Tasks 1, 2

  **References**:
  - `lib/storage/local_storage.dart:37-70` - `_onCreate` pattern
  - `lib/storage/local_storage.dart:72-116` - `_onUpgrade` migration pattern
  - `lib/storage/local_storage.dart:118-144` - `saveRun` transaction pattern

  **Acceptance Criteria**:
  - [ ] `_databaseVersion = 6`
  - [ ] Fresh install creates `laps` table with correct schema
  - [ ] Migration from v5 adds `cv` column and creates `laps` table
  - [ ] `saveRun` stores CV and lap data in transaction
  - [ ] `getLapsForRun` returns laps ordered by `lapNumber`
  - [ ] `getRunById` includes CV value
  - [ ] `flutter analyze` passes

  **Manual Verification**:
  - [ ] Delete app data, reinstall - verify fresh schema
  - [ ] Test migration by running on device with v5 database

  **Commit**: YES
  - Message: `feat(storage): add CV and laps to local SQLite schema v6`
  - Files: `lib/storage/local_storage.dart`
  - Pre-commit: `flutter analyze`

---

- [ ] 5. Update RunSummary and UserModel

  **What to do**:
  - Modify `lib/models/run_summary.dart`:
    - Add `final double? cv` field
    - Add `final double? stabilityScore` getter (calculated: `cv != null ? max(0, 100 - cv).toDouble() : null`)
    - Update constructor to accept `cv`
    - Update `toMap()` to include `cv`
    - Update `fromMap()` to read `cv`
    - Update `toRow()` to include `cv` for server upload
    - Update `fromRow()` to read `cv`

  - Modify `lib/models/user_model.dart`:
    - Add `final double totalDistanceKm`
    - Add `final double? avgPaceMinPerKm`
    - Add `final double? avgCv`
    - Add `final int totalRuns`
    - Add `int? get stabilityScore` getter (calculated from avgCv)
    - Update `fromRow()` to read new fields
    - Update `toRow()` to include new fields (for completeness)
    - Update `copyWith()` with new fields

  **Must NOT do**:
  - Do not remove any existing fields
  - Do not change field names (backward compatibility)

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Model updates, straightforward field additions
  - **Skills**: [`moai-lang-flutter`]
    - `moai-lang-flutter`: Dart immutable model patterns

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 2 (with Tasks 2, 3, 6)
  - **Blocks**: Tasks 7, 8
  - **Blocked By**: Task 1

  **References**:
  - `lib/models/run_summary.dart:1-105` - Current RunSummary implementation
  - `lib/models/user_model.dart:1-139` - Current UserModel implementation
  - `lib/models/run_session.dart:52-68` - `toSummary()` pattern

  **Acceptance Criteria**:
  - [ ] `RunSummary` has `cv` field (nullable double)
  - [ ] `RunSummary.stabilityScore` getter returns clamped 0-100 value
  - [ ] `UserModel` has `totalDistanceKm`, `avgPaceMinPerKm`, `avgCv`, `totalRuns`
  - [ ] `UserModel.stabilityScore` getter works correctly
  - [ ] All serialization methods updated
  - [ ] `flutter analyze` passes

  **Commit**: YES
  - Message: `feat(models): add CV fields to RunSummary and aggregate fields to UserModel`
  - Files: `lib/models/run_summary.dart`, `lib/models/user_model.dart`
  - Pre-commit: `flutter analyze`

---

- [ ] 6. Update SupabaseService RPC Calls

  **What to do**:
  - Modify `lib/services/supabase_service.dart`:
    - Update `finalizeRun()` to pass `cv` parameter:
      ```dart
      'p_cv': runSummary.cv,
      ```
    - Update `appLaunchSync()` response parsing to include new user fields
    - Update `getLeaderboard()` to return new columns if available

  **Must NOT do**:
  - Do not change function signatures (add optional params if needed)
  - Do not remove existing parameters

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Simple parameter additions to existing methods
  - **Skills**: []
    - No special skills needed

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 2 (with Tasks 2, 3, 5)
  - **Blocks**: Task 8
  - **Blocked By**: Task 4

  **References**:
  - `lib/services/supabase_service.dart:51-75` - `finalizeRun` method
  - `lib/services/supabase_service.dart:81-87` - `appLaunchSync` method
  - `lib/services/supabase_service.dart:27-33` - `getLeaderboard` method

  **Acceptance Criteria**:
  - [ ] `finalizeRun` passes `p_cv` to RPC
  - [ ] No breaking changes to existing calls
  - [ ] `flutter analyze` passes

  **Commit**: YES
  - Message: `feat(supabase): add CV parameter to finalizeRun RPC call`
  - Files: `lib/services/supabase_service.dart`
  - Pre-commit: `flutter analyze`

---

### Wave 3: Completion (After Wave 2)

- [ ] 7. Update finalize_run RPC Logic (Server-Side Verification)

  **What to do**:
  - This task verifies Task 4's SQL migration is correctly applied
  - Apply migration `003_cv_aggregates.sql` to Supabase:
    - Go to Supabase Dashboard → SQL Editor
    - Run the migration SQL
  - Verify function signature updated
  - Test with sample data

  **Must NOT do**:
  - Do not modify production data
  - Do not run on production without testing on staging first

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Deployment verification, not implementation
  - **Skills**: [`playwright`]
    - `playwright`: For Supabase dashboard interaction if needed

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 3 (with Task 8)
  - **Blocks**: None
  - **Blocked By**: Tasks 4, 5

  **References**:
  - `supabase/migrations/003_cv_aggregates.sql` - Migration to apply (from Task 4)
  - `supabase/README.md` - Deployment instructions

  **Acceptance Criteria**:
  - [ ] Migration applied successfully (no SQL errors)
  - [ ] `SELECT * FROM information_schema.columns WHERE table_name = 'users'` shows new columns
  - [ ] Test RPC call: `SELECT finalize_run(...)` with p_cv parameter works
  - [ ] `get_leaderboard` returns new columns

  **Manual Verification**:
  - [ ] Supabase SQL Editor: Run migration
  - [ ] Supabase SQL Editor: Query to verify columns exist
  - [ ] Supabase SQL Editor: Test RPC function

  **Commit**: NO (server-side deployment, not code change)

---

- [ ] 8. Update Leaderboard UI

  **What to do**:
  - Modify `lib/screens/leaderboard_screen.dart`:
    - Update `LeaderboardRunner` class:
      - Add `final double? avgPaceMinPerKm`
      - Add `final int? stabilityScore`
    - Update `_getFilteredRunners()` to map new fields from provider
    - Update mock data to include new fields
    - Update `_buildPodiumCard()` to show:
      - Flip points (primary)
      - Total distance (secondary)
      - Stability score with label (tertiary)
    - Update `_buildRankTile()` to show stability score badge
    - Format pace as "X:XX min/km" string
    - Format stability score as integer with "%" suffix

  **Must NOT do**:
  - Do not change the ranking order (still by flip points)
  - Do not remove existing fields
  - Do not add complex animations (keep minimal)

  **Recommended Agent Profile**:
  - **Category**: `visual-engineering`
    - Reason: UI modifications with visual design considerations
  - **Skills**: [`moai-lang-flutter`, `frontend-ui-ux`]
    - `moai-lang-flutter`: Flutter widget patterns
    - `frontend-ui-ux`: Visual design and layout

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 3 (with Task 7)
  - **Blocks**: Task 10
  - **Blocked By**: Tasks 5, 6

  **References**:
  - `lib/screens/leaderboard_screen.dart:987-1011` - `LeaderboardRunner` class to update
  - `lib/screens/leaderboard_screen.dart:619-735` - `_buildPodiumCard` layout pattern
  - `lib/screens/leaderboard_screen.dart:741-893` - `_buildRankTile` layout pattern
  - `lib/theme/app_theme.dart` - Color and typography constants

  **Acceptance Criteria**:
  - [ ] Podium cards show distance and stability score
  - [ ] Rank tiles show stability score badge
  - [ ] Pace formatted as "X:XX min/km"
  - [ ] Stability score shown as integer with "%" or descriptive label
  - [ ] Handles null values gracefully (shows "--" or similar)
  - [ ] `flutter analyze` passes
  - [ ] Visual appearance matches existing design language

  **Manual Verification**:
  - [ ] `flutter run` - navigate to leaderboard
  - [ ] Verify new stats display correctly with mock data
  - [ ] Verify layout doesn't overflow on small screens

  **Commit**: YES
  - Message: `feat(ui): add CV stability score and pace to leaderboard`
  - Files: `lib/screens/leaderboard_screen.dart`
  - Pre-commit: `flutter analyze`

---

- [ ] 9. Add Unit Tests for CV Calculation

  **What to do**:
  - Create `test/services/lap_service_test.dart`:
    - Test `calculateCV` with multiple laps (verify math)
    - Test `calculateCV` with empty list (returns null)
    - Test `calculateCV` with single lap (returns 0 or null)
    - Test `calculateCV` with identical paces (CV = 0)
    - Test `calculateStabilityScore` with various inputs
    - Test edge cases: negative CV (impossible but handle), CV > 100

  - Create `test/models/lap_model_test.dart`:
    - Test `toMap()` and `fromMap()` roundtrip
    - Test `avgPaceSecPerKm` calculation

  **Must NOT do**:
  - Do not mock too much (test real calculation logic)
  - Do not add integration tests here (separate task)

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Unit tests, straightforward test cases
  - **Skills**: [`moai-lang-flutter`]
    - `moai-lang-flutter`: Flutter testing patterns

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 3 (with Tasks 7, 8, 10)
  - **Blocks**: None
  - **Blocked By**: Tasks 1, 2

  **References**:
  - `test/widget_test.dart` - Existing test pattern
  - `lib/services/lap_service.dart` - Implementation to test (from Task 1)
  - `lib/models/lap_model.dart` - Model to test (from Task 1)

  **Acceptance Criteria**:
  - [ ] `flutter test test/services/lap_service_test.dart` passes
  - [ ] `flutter test test/models/lap_model_test.dart` passes
  - [ ] Tests cover: empty, single, multiple laps
  - [ ] Tests verify CV math is correct
  - [ ] Tests verify stability score clamping

  **Manual Verification**:
  - [ ] `flutter test` - all tests pass
  - [ ] `flutter test --coverage` - check coverage %

  **Commit**: YES
  - Message: `test(cv): add unit tests for LapService and LapModel`
  - Files: `test/services/lap_service_test.dart`, `test/models/lap_model_test.dart`
  - Pre-commit: `flutter test`

---

- [ ] 10. Playwright Verification of Leaderboard UI

  **What to do**:
  - Use Playwright to:
    - Launch app in web mode or connect to running simulator
    - Navigate to leaderboard screen
    - Verify new stats are visible:
      - Total distance displayed
      - Stability score displayed
      - Pace displayed (if applicable)
    - Take screenshot as evidence
    - Save to `.sisyphus/evidence/task-10-leaderboard.png`

  **Must NOT do**:
  - Do not test business logic (that's unit tests)
  - Do not modify app code

  **Recommended Agent Profile**:
  - **Category**: `visual-engineering`
    - Reason: Visual verification task
  - **Skills**: [`playwright`, `moai-lang-flutter`]
    - `playwright`: Browser automation
    - `moai-lang-flutter`: Flutter web testing context

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Final (after Task 8)
  - **Blocks**: None
  - **Blocked By**: Task 8

  **References**:
  - `lib/screens/leaderboard_screen.dart` - Screen to verify
  - Playwright skill documentation

  **Acceptance Criteria**:
  - [ ] Screenshot captured showing leaderboard with new stats
  - [ ] New columns visible: distance, stability score
  - [ ] No visual regressions (layout intact)
  - [ ] Evidence saved to `.sisyphus/evidence/`

  **Manual Verification**:
  - [ ] View screenshot
  - [ ] Compare against expected layout

  **Commit**: NO (verification only, no code changes)

---

## Commit Strategy

| After Task | Message | Files | Verification |
|------------|---------|-------|--------------|
| 1 | `feat(cv): add LapModel and LapService for CV calculation` | lap_model.dart, lap_service.dart | flutter analyze |
| 2 | `feat(tracking): integrate lap detection into RunTracker` | run_tracker.dart | flutter analyze |
| 3 | `feat(storage): add CV and laps to local SQLite schema v6` | local_storage.dart | flutter analyze |
| 4 | `feat(db): add CV aggregate columns and update RPCs` | 003_cv_aggregates.sql | SQL syntax |
| 5 | `feat(models): add CV fields to RunSummary and UserModel` | run_summary.dart, user_model.dart | flutter analyze |
| 6 | `feat(supabase): add CV parameter to finalizeRun RPC call` | supabase_service.dart | flutter analyze |
| 8 | `feat(ui): add CV stability score and pace to leaderboard` | leaderboard_screen.dart | flutter analyze |
| 9 | `test(cv): add unit tests for LapService and LapModel` | lap_service_test.dart, lap_model_test.dart | flutter test |

---

## Success Criteria

### Verification Commands
```bash
flutter analyze                    # No errors
flutter test                       # All tests pass
flutter test --coverage            # Check coverage
flutter run -d chrome              # Visual verification
```

### Final Checklist
- [ ] All "Must Have" present:
  - [ ] Lap detection at 1km intervals
  - [ ] CV calculation with sample stdev
  - [ ] Stability Score clamped 0-100
  - [ ] Schema migration v5 → v6
  - [ ] Server aggregates updated
- [ ] All "Must NOT Have" absent:
  - [ ] No real-time lap notifications
  - [ ] No warmup/cooldown filtering
  - [ ] No weighted CV average
  - [ ] No CV backfill
  - [ ] No lap data on server
- [ ] All tests pass
- [ ] Leaderboard shows new stats
- [ ] Playwright screenshot confirms UI
