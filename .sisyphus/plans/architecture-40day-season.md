# RunStrict Architecture Change: 40-Day Season & Two Home-Hex System

## TL;DR

> **Quick Summary**: Major architecture overhaul introducing two distinct home-hex concepts (location-based for map display, season-based for leaderboard/multiplier), changing season duration from 280 to 40 days, and adding 4 years of dummy run history.
> 
> **Deliverables**:
> - Season duration updated to 40 days (app + database)
> - Two home-hex fields: `homeHex` (dynamic, for map) and `seasonHomeHex` (fixed, for leaderboard/multiplier)
> - MapScreen shows strict H3 parent cell boundaries for CITY/ALL scopes
> - Leaderboard MY LEAGUE filters by season-home-hex's Res 4 parent
> - Multiplier bonus only applies within home region
> - ~1,460 dummy runs (4 years of history)
> 
> **Estimated Effort**: Large (3-4 days)
> **Parallel Execution**: YES - 3 waves
> **Critical Path**: Task 2 (UserModel) → Task 5 (PrefetchService) → Task 7 (MapScreen) → Task 10 (Integration Test)

---

## Context

### Original Request
Major architecture change for RunStrict Flutter app covering:
1. Season duration: 280 days → 40 days
2. Two home-hex concepts (location vs season)
3. MapScreen H3 parent cell fixed regions
4. Leaderboard using season-home-hex
5. Multiplier home-region bonus
6. 4 years of dummy run data

### Interview Summary
**Key Discussions**:
- Season home-hex set on FIRST APP LAUNCH of season (from GPS), not first run
- Multiplier uses Res 4 (ALL scope) - consistent with MY LEAGUE
- MapScreen uses STRICT boundary - only hexes within parent cell
- Dummy data: 50/50 Red/Blue, run summaries only (~1,460 records)

**Research Findings**:
- Current `homeHex` in UserModel serves both map and leaderboard (needs separation)
- PrefetchService.initialize() handles GPS → homeHex setting
- HexagonMap uses k-ring for CITY/ALL, needs to switch to parent cell children
- CrewMultiplierService has no region awareness (needs addition)
- LocalStorage runs table ready for dummy data insertion

### Self-Review Gap Analysis
**Identified Gaps** (addressed):
1. Season detection logic needed for "first launch of season" → Added SeasonService check
2. What happens when seasonHomeHex is null but homeHex exists → Use homeHex as fallback
3. Migration path for existing users → Set seasonHomeHex = homeHex on upgrade
4. Server-side multiplier validation needs update → Added RPC update task
5. HexService.getChildHexIds goes to childResolution, need all descendants to Res 9 → Add recursive children method

---

## Work Objectives

### Core Objective
Separate the single "home hex" concept into two distinct purposes: dynamic location-based hex for map display, and fixed season-based hex for competitive features (leaderboard, multiplier).

### Concrete Deliverables
- `lib/models/app_config.dart` - SeasonConfig with durationDays: 40
- `lib/models/user_model.dart` - New `seasonHomeHex` field
- `lib/services/prefetch_service.dart` - Dual home-hex logic
- `lib/widgets/hexagon_map.dart` - Parent cell boundary display
- `lib/services/hex_service.dart` - New `getAllChildrenAtResolution()` method
- `lib/providers/leaderboard_provider.dart` - Use seasonHomeHex
- `lib/services/crew_multiplier_service.dart` - Region-aware multiplier
- `supabase/migrations/XXX_season_home_hex.sql` - Database schema update
- `lib/utils/dummy_data_generator.dart` - 4-year run history generator
- Updated tests for new 40-day season

### Definition of Done
- [ ] `flutter test` passes with no failures
- [ ] `flutter analyze` returns no errors
- [ ] App launches and sets seasonHomeHex on first season launch
- [ ] MapScreen CITY/ALL shows strict parent cell boundaries
- [ ] Leaderboard MY LEAGUE filters by seasonHomeHex's Res 4 parent
- [ ] Multiplier applies only within home region
- [ ] Run history shows 4 years of dummy data

### Must Have
- Season duration changeable via remote config (40 default)
- seasonHomeHex persists across app restarts within same season
- seasonHomeHex resets when new season starts
- Backward compatibility for existing users (migration)
- homeHex (location-based) continues to work for map centering

### Must NOT Have (Guardrails)
- NO UI for manually setting season-home-hex
- NO changes to ZONE scope behavior (camera-following stays as-is)
- NO route points in dummy data (summaries only)
- NO purple team in dummy data
- NO changes to core run tracking/GPS logic
- NO changes to hex capture mechanics
- NO scope creep into auth or crew management

---

## Verification Strategy (MANDATORY)

### Test Decision
- **Infrastructure exists**: YES (Flutter test framework)
- **User wants tests**: Manual verification + existing test updates
- **Framework**: `flutter test`

### Automated Verification

Each task includes executable verification that agents can run:

**For Flutter code changes**:
```bash
# Agent runs:
flutter analyze lib/
flutter test
```

**For database migrations**:
```bash
# Agent runs via Supabase CLI:
supabase db diff
supabase db push --dry-run
```

**For app behavior**:
```
# Agent uses playwright skill for iOS Simulator:
1. Launch app
2. Verify season countdown shows D-40 (not D-280)
3. Check leaderboard MY LEAGUE filtering
4. Navigate map to verify parent cell boundaries
```

---

## Execution Strategy

### Parallel Execution Waves

```
Wave 1 (Start Immediately - Foundation):
├── Task 1: Season duration 280→40 (app_config + SQL)
├── Task 2: UserModel seasonHomeHex field
├── Task 3: HexService.getAllChildrenAtResolution()
└── Task 11: Dummy data generator script

Wave 2 (After Wave 1 - Core Logic):
├── Task 4: Database migration (season_home_hex column)
├── Task 5: PrefetchService dual home-hex logic
├── Task 6: LeaderboardProvider use seasonHomeHex
└── Task 8: Multiplier region-aware logic

Wave 3 (After Wave 2 - Integration):
├── Task 7: HexagonMap parent cell boundaries
├── Task 9: Server-side multiplier validation
└── Task 10: Integration testing & verification

Critical Path: Task 2 → Task 5 → Task 7 → Task 10
Parallel Speedup: ~50% faster than sequential
```

### Dependency Matrix

| Task | Depends On | Blocks | Can Parallelize With |
|------|------------|--------|---------------------|
| 1 | None | 10 | 2, 3, 11 |
| 2 | None | 4, 5, 6 | 1, 3, 11 |
| 3 | None | 7 | 1, 2, 11 |
| 4 | 2 | 5, 9 | 6, 8 |
| 5 | 2, 4 | 6, 7, 8 | None |
| 6 | 2, 5 | 10 | 8 |
| 7 | 3, 5 | 10 | 8, 9 |
| 8 | 5 | 9, 10 | 6, 7 |
| 9 | 4, 8 | 10 | 7 |
| 10 | 6, 7, 8, 9 | None | None (final) |
| 11 | None | 10 | 1, 2, 3 |

### Agent Dispatch Summary

| Wave | Tasks | Recommended Dispatch |
|------|-------|---------------------|
| 1 | 1, 2, 3, 11 | 4 parallel agents (all independent) |
| 2 | 4, 5, 6, 8 | 4 agents, but 5 must wait for 2+4 |
| 3 | 7, 9, 10 | Sequential after Wave 2, Task 10 is final |

---

## TODOs

### Wave 1: Foundation (Parallel)

---

- [ ] 1. Update Season Duration from 280 to 40 days

  **What to do**:
  - Update `SeasonConfig.defaults()` in `lib/models/app_config.dart` to use `durationDays: 40`
  - Update `SeasonConfig.fromJson()` default fallback from 280 to 40
  - Update SQL migration `supabase/migrations/20260128_create_app_config.sql` default value
  - Search and update any tests that expect 280 days

  **Must NOT do**:
  - Do NOT change serverTimezoneOffsetHours
  - Do NOT modify other config sections

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Simple find-and-replace across few files
  - **Skills**: [`git-master`]
    - `git-master`: For atomic commit of related changes

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Tasks 2, 3, 11)
  - **Blocks**: Task 10 (integration test)
  - **Blocked By**: None

  **References**:

  **Pattern References**:
  - `lib/models/app_config.dart:99-100` - SeasonConfig.defaults() factory method (change 280→40)
  - `lib/models/app_config.dart:103` - fromJson fallback value (change 280→40)

  **API/Type References**:
  - `lib/services/season_service.dart` - Uses SeasonConfig.durationDays for D-day calculation

  **Database References**:
  - `supabase/migrations/20260128_create_app_config.sql` - Server-side default config JSONB

  **Test References**:
  - `test/services/remote_config_service_test.dart` - May reference 280

  **WHY Each Reference Matters**:
  - `app_config.dart:99-100`: Primary source of truth for default season duration
  - `app_config.dart:103`: Fallback when server config missing - must match
  - SQL migration: Ensures server and client defaults are synchronized

  **Acceptance Criteria**:

  ```bash
  # Agent runs:
  flutter analyze lib/models/app_config.dart
  # Assert: No errors
  
  grep -n "280" lib/models/app_config.dart
  # Assert: No matches (all 280s replaced with 40)
  
  grep -n "durationDays.*40" lib/models/app_config.dart
  # Assert: Returns line ~100 showing durationDays: 40
  ```

  **Commit**: YES
  - Message: `feat(season): change default duration from 280 to 40 days`
  - Files: `lib/models/app_config.dart`, `supabase/migrations/20260128_create_app_config.sql`
  - Pre-commit: `flutter analyze`

---

- [ ] 2. Add seasonHomeHex field to UserModel

  **What to do**:
  - Add `final String? seasonHomeHex;` field to UserModel
  - Add parameter to constructor with default null
  - Add to `copyWith()` method with `clearSeasonHomeHex` option
  - Add to `fromRow()` - read from `season_home_hex` column
  - Add to `toRow()` - write to `season_home_hex` column
  - Add to `fromJson()` and `toJson()` for serialization
  - Add `defectToPurple()` - preserve seasonHomeHex (don't reset)

  **Must NOT do**:
  - Do NOT rename existing `homeHex` field
  - Do NOT modify homeHex behavior
  - Do NOT add any UI-related code

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Straightforward model field addition following existing patterns
  - **Skills**: [`git-master`]
    - `git-master`: Atomic commit

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Tasks 1, 3, 11)
  - **Blocks**: Tasks 4, 5, 6 (all need this field)
  - **Blocked By**: None

  **References**:

  **Pattern References**:
  - `lib/models/user_model.dart:17` - Existing `homeHex` field pattern to follow
  - `lib/models/user_model.dart:61-93` - copyWith() method pattern
  - `lib/models/user_model.dart:118-132` - fromRow() pattern with null handling

  **WHY Each Reference Matters**:
  - Line 17 shows exact field declaration style and documentation pattern
  - copyWith() at 61-93 shows the clearXxx boolean pattern for nullable fields
  - fromRow() at 118-132 shows snake_case database column mapping

  **Acceptance Criteria**:

  ```bash
  # Agent runs:
  flutter analyze lib/models/user_model.dart
  # Assert: No errors
  
  grep -n "seasonHomeHex" lib/models/user_model.dart
  # Assert: Multiple matches (field, constructor, copyWith, fromRow, toRow, fromJson, toJson)
  
  grep -n "season_home_hex" lib/models/user_model.dart
  # Assert: Matches in fromRow and toRow (snake_case database column)
  ```

  **Commit**: YES
  - Message: `feat(model): add seasonHomeHex field to UserModel`
  - Files: `lib/models/user_model.dart`
  - Pre-commit: `flutter analyze`

---

- [ ] 3. Add getAllChildrenAtResolution method to HexService

  **What to do**:
  - Add `List<String> getAllChildrenAtResolution(String parentHexId, int targetResolution)` method
  - Method should recursively get all descendants from parent resolution down to target
  - For CITY (Res 6 → Res 9): Returns ~343 hexes
  - For ALL (Res 4 → Res 9): Returns ~16,807 hexes (but we filter to ~3,781 in practice)
  - Use existing `h3.cellToChildren()` iteratively

  **Must NOT do**:
  - Do NOT modify existing methods
  - Do NOT add any caching logic (let caller handle caching)

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Single method addition with clear H3 library usage
  - **Skills**: []
    - No special skills needed, straightforward Dart

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Tasks 1, 2, 11)
  - **Blocks**: Task 7 (HexagonMap needs this)
  - **Blocked By**: None

  **References**:

  **Pattern References**:
  - `lib/services/hex_service.dart:91-96` - Existing getChildHexIds() one-level method
  - `lib/services/hex_service.dart:83-88` - getParentHexId() for resolution math reference

  **External References**:
  - h3_flutter package: `h3.cellToChildren()` returns 7 children at next resolution

  **WHY Each Reference Matters**:
  - getChildHexIds() at 91-96 shows how to call h3.cellToChildren and convert to hex strings
  - Need to iterate: parent → children → grandchildren until targetResolution reached

  **Acceptance Criteria**:

  ```bash
  # Agent runs:
  flutter analyze lib/services/hex_service.dart
  # Assert: No errors
  
  grep -n "getAllChildrenAtResolution" lib/services/hex_service.dart
  # Assert: Method exists
  ```

  ```dart
  // Agent can write a simple test or inline verification:
  // For a Res 6 hex, getting children at Res 9 should return ~343 hexes
  // Formula: 7^(9-6) = 7^3 = 343
  ```

  **Commit**: YES
  - Message: `feat(hex): add getAllChildrenAtResolution for parent cell children`
  - Files: `lib/services/hex_service.dart`
  - Pre-commit: `flutter analyze`

---

- [ ] 11. Create Dummy Data Generator Script

  **What to do**:
  - Create `lib/utils/dummy_data_generator.dart`
  - Generate ~1,460 runs (365 days × 4 years, 2022-01-01 to 2025-12-31)
  - One run per day with realistic variation:
    - Distance: 5-10km (random normal distribution, mean 7km)
    - Duration: Based on pace 5:00-7:00 min/km
    - avgPaceSecPerKm: 300-420 (5:00-7:00)
    - CV: 5-25 (realistic consistency range)
    - hexesColored: distance/0.174 (based on ~174m hex size)
    - teamAtRun: 50/50 red/blue alternating
  - Provide `Future<void> insertDummyRuns(LocalStorage storage)` method
  - Also create CLI entry point or integrate with app startup (debug mode only)

  **Must NOT do**:
  - Do NOT generate route points (GPS coordinates)
  - Do NOT include purple team
  - Do NOT generate lap data
  - Do NOT insert in production mode

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Standalone utility, no dependencies on other tasks
  - **Skills**: []
    - Standard Dart, no special skills needed

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Tasks 1, 2, 3)
  - **Blocks**: Task 10 (integration testing uses this data)
  - **Blocked By**: None

  **References**:

  **Pattern References**:
  - `lib/storage/local_storage.dart:279-305` - saveRun() transaction pattern
  - `lib/models/run_summary.dart` - RunSummary fields to generate

  **Database References**:
  - `lib/storage/local_storage.dart:48-61` - runs table schema (exact column names)

  **WHY Each Reference Matters**:
  - saveRun() shows how to insert into runs table within transaction
  - RunSummary fields define what data we need to generate
  - Table schema ensures column names match exactly

  **Acceptance Criteria**:

  ```bash
  # Agent runs:
  flutter analyze lib/utils/dummy_data_generator.dart
  # Assert: No errors
  
  # Verify file exists with expected function
  grep -n "insertDummyRuns" lib/utils/dummy_data_generator.dart
  # Assert: Function exists
  
  grep -n "1460\|365\|4.*year" lib/utils/dummy_data_generator.dart
  # Assert: Contains logic for ~1460 runs over 4 years
  ```

  **Commit**: YES
  - Message: `feat(dev): add dummy data generator for 4 years of run history`
  - Files: `lib/utils/dummy_data_generator.dart`
  - Pre-commit: `flutter analyze`

---

### Wave 2: Core Logic (After Wave 1)

---

- [ ] 4. Create Database Migration for season_home_hex Column

  **What to do**:
  - Create new migration file `supabase/migrations/XXX_add_season_home_hex.sql`
  - Add `season_home_hex TEXT` column to users table
  - Add migration logic: `UPDATE users SET season_home_hex = home_hex WHERE home_hex IS NOT NULL`
  - Update `app_launch_sync` RPC to return `season_home_hex`
  - Update any leaderboard RPCs that need the field

  **Must NOT do**:
  - Do NOT modify existing columns
  - Do NOT add constraints that would break existing data
  - Do NOT remove any existing functionality

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: SQL migration following existing patterns
  - **Skills**: [`git-master`]
    - `git-master`: For proper commit of migration file

  **Parallelization**:
  - **Can Run In Parallel**: YES (after Task 2)
  - **Parallel Group**: Wave 2 (with Tasks 5, 6, 8)
  - **Blocks**: Tasks 5, 9 (need column to exist)
  - **Blocked By**: Task 2 (UserModel field must match)

  **References**:

  **Pattern References**:
  - `supabase/migrations/001_initial_schema.sql` - users table schema
  - `supabase/migrations/004_scoped_data_functions.sql` - home_hex RPC patterns
  - `supabase/migrations/20260128_update_app_launch_sync.sql` - app_launch_sync RPC

  **WHY Each Reference Matters**:
  - 001_initial_schema shows users table structure to add column to
  - 004_scoped_data shows how home_hex is used in RPCs
  - app_launch_sync RPC returns user data on login, must include new field

  **Acceptance Criteria**:

  ```bash
  # Agent runs:
  ls supabase/migrations/*season_home_hex*.sql
  # Assert: Migration file exists
  
  grep -n "season_home_hex" supabase/migrations/*season_home_hex*.sql
  # Assert: Contains ALTER TABLE and UPDATE statement
  ```

  **Commit**: YES
  - Message: `feat(db): add season_home_hex column with migration from home_hex`
  - Files: `supabase/migrations/XXX_add_season_home_hex.sql`
  - Pre-commit: N/A (SQL file)

---

- [ ] 5. Update PrefetchService for Dual Home-Hex Logic

  **What to do**:
  - Keep existing `_homeHex` for location-based map display (dynamic, from GPS)
  - Add `_seasonHomeHex` for season-based features (fixed for season)
  - Add season detection: check if current date is in a new season vs. stored season
  - On first app launch of season:
    - Set `_seasonHomeHex` from GPS
    - Store season start date to detect new seasons
  - On subsequent launches in same season:
    - Load `_seasonHomeHex` from storage (don't update)
  - Add getter `String? get seasonHomeHex`
  - Add method `bool isInHomeRegion(String hexId)` - checks Res 4 parent match

  **Must NOT do**:
  - Do NOT change homeHex behavior for map centering
  - Do NOT require a run to set seasonHomeHex

  **Recommended Agent Profile**:
  - **Category**: `visual-engineering`
    - Reason: Core service logic with state management complexity
  - **Skills**: [`systematic-debugging`]
    - `systematic-debugging`: For handling edge cases in season detection

  **Parallelization**:
  - **Can Run In Parallel**: NO (depends on Task 2, 4)
  - **Parallel Group**: Wave 2 (starts after 2 and 4 complete)
  - **Blocks**: Tasks 6, 7, 8 (all need seasonHomeHex)
  - **Blocked By**: Tasks 2, 4

  **References**:

  **Pattern References**:
  - `lib/services/prefetch_service.dart:202-206` - _setHomeHexFromGPS() to reuse
  - `lib/services/prefetch_service.dart:447-461` - saveHomeHex/loadHomeHex for persistence
  - `lib/services/season_service.dart` - Season date calculations to reuse

  **API/Type References**:
  - `lib/models/app_config.dart:90-119` - SeasonConfig for duration

  **WHY Each Reference Matters**:
  - _setHomeHexFromGPS() has proven GPS→H3 logic to reuse
  - saveHomeHex/loadHomeHex shows persistence pattern, need similar for seasonHomeHex
  - SeasonService has season start/end calculations we can leverage

  **Acceptance Criteria**:

  ```bash
  # Agent runs:
  flutter analyze lib/services/prefetch_service.dart
  # Assert: No errors
  
  grep -n "seasonHomeHex" lib/services/prefetch_service.dart
  # Assert: Field, getter, and isInHomeRegion method exist
  
  grep -n "isInHomeRegion" lib/services/prefetch_service.dart
  # Assert: Method exists with Res 4 comparison
  ```

  **Commit**: YES
  - Message: `feat(prefetch): add seasonHomeHex with season detection logic`
  - Files: `lib/services/prefetch_service.dart`
  - Pre-commit: `flutter analyze`

---

- [ ] 6. Update LeaderboardProvider to Use seasonHomeHex

  **What to do**:
  - Update `filterByScope()` to use `_prefetchService.seasonHomeHex` instead of `homeHex`
  - Update `LeaderboardEntry.isInScope()` to accept seasonHomeHex
  - Ensure MY LEAGUE (Res 4 scope) uses seasonHomeHex for filtering
  - Add fallback: if seasonHomeHex is null, use homeHex

  **Must NOT do**:
  - Do NOT change GLOBAL filtering (still shows all)
  - Do NOT change the LeaderboardEntry model structure

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Simple field reference update
  - **Skills**: []
    - Straightforward Dart changes

  **Parallelization**:
  - **Can Run In Parallel**: YES (after Task 5)
  - **Parallel Group**: Wave 2 (with Tasks 5, 8)
  - **Blocks**: Task 10 (integration test)
  - **Blocked By**: Task 2, 5

  **References**:

  **Pattern References**:
  - `lib/providers/leaderboard_provider.dart:142-153` - filterByScope() method
  - `lib/providers/leaderboard_provider.dart:67-73` - LeaderboardEntry.isInScope()

  **WHY Each Reference Matters**:
  - filterByScope() at 142-153 currently uses _prefetchService.homeHex → change to seasonHomeHex
  - isInScope() at 67-73 is called per entry, uses referenceHomeHex param → pass seasonHomeHex

  **Acceptance Criteria**:

  ```bash
  # Agent runs:
  flutter analyze lib/providers/leaderboard_provider.dart
  # Assert: No errors
  
  grep -n "seasonHomeHex" lib/providers/leaderboard_provider.dart
  # Assert: Used in filterByScope
  ```

  **Commit**: YES
  - Message: `feat(leaderboard): use seasonHomeHex for MY LEAGUE filtering`
  - Files: `lib/providers/leaderboard_provider.dart`
  - Pre-commit: `flutter analyze`

---

- [ ] 8. Add Region-Aware Multiplier Logic

  **What to do**:
  - Update `CrewMultiplierService` or create new `RegionMultiplierService`
  - Add method `int getEffectiveMultiplier(String hexId)`:
    - If hexId is within seasonHomeHex's Res 4 parent → return crew multiplier
    - If hexId is outside home region → return 1 (no bonus)
  - Update `RunProvider` to use this when calculating points per hex
  - Add `PrefetchService.isInHomeRegion(hexId)` check

  **Must NOT do**:
  - Do NOT change crew multiplier calculation itself (yesterday's check-in)
  - Do NOT block captures outside home region (just no multiplier)

  **Recommended Agent Profile**:
  - **Category**: `visual-engineering`
    - Reason: Cross-service logic affecting core game mechanic
  - **Skills**: [`systematic-debugging`]
    - For ensuring multiplier edge cases are handled

  **Parallelization**:
  - **Can Run In Parallel**: YES (after Task 5)
  - **Parallel Group**: Wave 2 (with Tasks 6, 7)
  - **Blocks**: Tasks 9, 10
  - **Blocked By**: Task 5

  **References**:

  **Pattern References**:
  - `lib/services/crew_multiplier_service.dart` - Current multiplier fetching
  - `lib/providers/run_provider.dart` - Where points are calculated during run

  **API/Type References**:
  - `lib/services/prefetch_service.dart:370-378` - isHexInScope() pattern to follow

  **WHY Each Reference Matters**:
  - crew_multiplier_service has getYesterdayCrewCount() we wrap
  - run_provider calculates flip points, needs to call new method
  - isHexInScope() shows H3 parent comparison pattern

  **Acceptance Criteria**:

  ```bash
  # Agent runs:
  flutter analyze lib/services/crew_multiplier_service.dart
  flutter analyze lib/providers/run_provider.dart
  # Assert: No errors
  
  grep -n "getEffectiveMultiplier\|isInHomeRegion" lib/services/crew_multiplier_service.dart
  # Assert: Region check exists
  ```

  **Commit**: YES
  - Message: `feat(multiplier): apply crew bonus only within home region`
  - Files: `lib/services/crew_multiplier_service.dart`, `lib/providers/run_provider.dart`
  - Pre-commit: `flutter analyze`

---

### Wave 3: Integration (After Wave 2)

---

- [ ] 7. Update HexagonMap for Parent Cell Boundaries

  **What to do**:
  - Modify `_updateHexagons()` for CITY and ALL scopes
  - Instead of k-ring(10) or k-ring(35), use:
    - Get user's current location
    - Find Res 6 (CITY) or Res 4 (ALL) parent cell of current location
    - Use `HexService.getAllChildrenAtResolution(parentHex, 9)` to get all hexes
  - STRICT boundary: Only show hexes within parent cell
  - ZONE scope unchanged (camera-following k-ring)

  **Must NOT do**:
  - Do NOT change ZONE behavior
  - Do NOT add buffering or overlap with adjacent cells
  - Do NOT change GeoJSON rendering pattern

  **Recommended Agent Profile**:
  - **Category**: `visual-engineering`
    - Reason: Map rendering with visual implications
  - **Skills**: [`frontend-ui-ux`]
    - For ensuring smooth visual experience

  **Parallelization**:
  - **Can Run In Parallel**: NO (depends on Tasks 3, 5)
  - **Parallel Group**: Wave 3
  - **Blocks**: Task 10
  - **Blocked By**: Tasks 3, 5

  **References**:

  **Pattern References**:
  - `lib/widgets/hexagon_map.dart:526-660` - _updateHexagons() method to modify
  - `lib/widgets/hexagon_map.dart:550-579` - Current k-ring logic to replace
  - `lib/widgets/hexagon_map.dart:430-438` - _currentScope getter

  **API/Type References**:
  - `lib/services/hex_service.dart` - getAllChildrenAtResolution() from Task 3

  **WHY Each Reference Matters**:
  - _updateHexagons() is the main method controlling hex generation
  - Lines 550-579 have the k-ring logic to replace with parent cell logic
  - _currentScope determines which approach to use

  **Acceptance Criteria**:

  ```bash
  # Agent runs:
  flutter analyze lib/widgets/hexagon_map.dart
  # Assert: No errors
  
  grep -n "getAllChildrenAtResolution\|getParentHexId" lib/widgets/hexagon_map.dart
  # Assert: Parent cell methods used for CITY/ALL
  
  grep -n "kRing.*10\|kRing.*35" lib/widgets/hexagon_map.dart
  # Assert: k-ring values removed for CITY/ALL (only ZONE uses k-ring)
  ```

  **Commit**: YES
  - Message: `feat(map): use strict parent cell boundaries for CITY/ALL scopes`
  - Files: `lib/widgets/hexagon_map.dart`
  - Pre-commit: `flutter analyze`

---

- [ ] 9. Update Server-Side Multiplier Validation

  **What to do**:
  - Update `finalize_run` RPC to validate multiplier based on region
  - Add parameter or derive from hex_path: which hexes are in home region
  - Server calculates: `home_region_flips × multiplier + outside_flips × 1`
  - Ensure client and server calculations match

  **Must NOT do**:
  - Do NOT block runs that include hexes outside home region
  - Do NOT change the finalize_run signature if avoidable

  **Recommended Agent Profile**:
  - **Category**: `visual-engineering`
    - Reason: Server-side SQL logic matching client logic
  - **Skills**: []
    - SQL knowledge, no special skills

  **Parallelization**:
  - **Can Run In Parallel**: YES (after Tasks 4, 8)
  - **Parallel Group**: Wave 3 (with Task 7)
  - **Blocks**: Task 10
  - **Blocked By**: Tasks 4, 8

  **References**:

  **Pattern References**:
  - `supabase/migrations/002_rpc_functions.sql` - finalize_run RPC
  - `supabase/migrations/004_scoped_data_functions.sql` - H3 parent comparison in SQL

  **WHY Each Reference Matters**:
  - finalize_run is where server validates points, needs region logic
  - 004 shows how to do H3 parent comparison in PostgreSQL

  **Acceptance Criteria**:

  ```bash
  # Agent runs:
  grep -n "season_home_hex\|home_region" supabase/migrations/*_finalize_run*.sql
  # Assert: Region-aware calculation in finalize_run
  ```

  **Commit**: YES
  - Message: `feat(db): update finalize_run to apply multiplier only in home region`
  - Files: `supabase/migrations/XXX_update_finalize_run.sql`
  - Pre-commit: N/A (SQL file)

---

- [ ] 10. Integration Testing & Verification

  **What to do**:
  - Run full test suite: `flutter test`
  - Run analyzer: `flutter analyze`
  - Manual verification in iOS Simulator:
    - App launch shows D-40 countdown (not D-280)
    - First launch sets seasonHomeHex (visible in debug logs)
    - MapScreen CITY view shows strict parent cell boundary
    - Leaderboard MY LEAGUE filters correctly
    - Running outside home region gives 1x multiplier
  - Verify dummy data appears in run history (4 years)
  - Update any failing tests

  **Must NOT do**:
  - Do NOT skip manual verification
  - Do NOT ignore test failures

  **Recommended Agent Profile**:
  - **Category**: `visual-engineering`
    - Reason: Full system verification with UI
  - **Skills**: [`playwright`, `systematic-debugging`]
    - `playwright`: For browser/simulator automation
    - `systematic-debugging`: For fixing any issues found

  **Parallelization**:
  - **Can Run In Parallel**: NO (final task)
  - **Parallel Group**: Wave 3 (after all others)
  - **Blocks**: None (final)
  - **Blocked By**: Tasks 1, 6, 7, 8, 9, 11

  **References**:

  **Pattern References**:
  - All files modified in Tasks 1-9, 11

  **Test References**:
  - `test/widget_test.dart` - Existing test structure
  - `test/services/*_test.dart` - Service test patterns

  **Acceptance Criteria**:

  ```bash
  # Agent runs:
  flutter analyze
  # Assert: No errors
  
  flutter test
  # Assert: All tests pass
  ```

  ```
  # Agent uses playwright skill for iOS Simulator:
  1. Launch app: flutter run -d ios
  2. Verify: Season countdown shows "D-40" or similar
  3. Navigate to Map: Verify CITY scope shows bounded region
  4. Navigate to Leaderboard: Verify MY LEAGUE filtering works
  5. Navigate to Run History: Verify 4 years of dummy data visible
  6. Screenshot: .sisyphus/evidence/task-10-verification.png
  ```

  **Evidence to Capture**:
  - [ ] flutter analyze output
  - [ ] flutter test output (all tests pass)
  - [ ] Screenshot of season countdown
  - [ ] Screenshot of map with parent cell boundary
  - [ ] Screenshot of run history with dummy data

  **Commit**: YES
  - Message: `test: verify 40-day season and dual home-hex integration`
  - Files: Any test file updates needed
  - Pre-commit: `flutter test`

---

## Commit Strategy

| After Task | Message | Files | Verification |
|------------|---------|-------|--------------|
| 1 | `feat(season): change default duration from 280 to 40 days` | app_config.dart, SQL | flutter analyze |
| 2 | `feat(model): add seasonHomeHex field to UserModel` | user_model.dart | flutter analyze |
| 3 | `feat(hex): add getAllChildrenAtResolution for parent cell children` | hex_service.dart | flutter analyze |
| 4 | `feat(db): add season_home_hex column with migration from home_hex` | SQL migration | N/A |
| 5 | `feat(prefetch): add seasonHomeHex with season detection logic` | prefetch_service.dart | flutter analyze |
| 6 | `feat(leaderboard): use seasonHomeHex for MY LEAGUE filtering` | leaderboard_provider.dart | flutter analyze |
| 7 | `feat(map): use strict parent cell boundaries for CITY/ALL scopes` | hexagon_map.dart | flutter analyze |
| 8 | `feat(multiplier): apply crew bonus only within home region` | crew_multiplier_service.dart, run_provider.dart | flutter analyze |
| 9 | `feat(db): update finalize_run to apply multiplier only in home region` | SQL migration | N/A |
| 10 | `test: verify 40-day season and dual home-hex integration` | test files | flutter test |
| 11 | `feat(dev): add dummy data generator for 4 years of run history` | dummy_data_generator.dart | flutter analyze |

---

## Success Criteria

### Verification Commands
```bash
# Full test suite
flutter test  # Expected: All tests pass

# Static analysis
flutter analyze  # Expected: No issues found

# Season duration check
grep "durationDays.*40" lib/models/app_config.dart  # Expected: Match found

# seasonHomeHex field exists
grep "seasonHomeHex" lib/models/user_model.dart  # Expected: Multiple matches
```

### Final Checklist
- [ ] Season duration is 40 days (not 280)
- [ ] UserModel has both homeHex and seasonHomeHex
- [ ] PrefetchService sets seasonHomeHex on first season launch
- [ ] MapScreen CITY/ALL uses strict parent cell boundaries
- [ ] Leaderboard MY LEAGUE uses seasonHomeHex
- [ ] Multiplier only applies within home region
- [ ] 4 years of dummy run data available
- [ ] All tests pass
- [ ] No analyzer warnings
