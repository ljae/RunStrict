# Remote Configuration System for RunStrict

## TL;DR

> **Quick Summary**: Create a server-configurable system where all 50+ game constants (GPS thresholds, scoring tiers, season rules, hex config) are stored in Supabase, fetched on app launch, cached locally, and used throughout the app with graceful fallback to defaults.
> 
> **Deliverables**:
> - Supabase `app_config` table with JSONB storage
> - Extended `app_launch_sync` RPC returning config
> - `AppConfig` typed Dart model with all defaults
> - `RemoteConfigService` singleton (fetch, cache, provide)
> - Updated 11 service files to read from RemoteConfigService
> - Unit tests for RemoteConfigService
> 
> **Estimated Effort**: Large (15-20 tasks, ~8-12 hours)
> **Parallel Execution**: YES - 3 waves
> **Critical Path**: Task 1 (SQL) -> Task 2 (RPC) -> Task 4 (Model) -> Task 5 (Service) -> Tasks 7-17 (Updates)

---

## Context

### Original Request
Create a server-configurable system where ALL configuration constants are stored in Supabase, fetchable on app launch, cached locally, with graceful fallback to hardcoded defaults.

### Interview Summary
**Key Discussions**:
- **Data Model**: Single-row table with JSONB column (simpler than key-value pairs)
- **Fetch Strategy**: Extend existing `app_launch_sync` RPC (one network call)
- **Run Consistency**: Config frozen at run start to prevent mid-run changes
- **Testing**: TDD approach with unit tests for RemoteConfigService
- **Cache Location**: JSON file matching existing `LocalStorageService` pattern

**Research Findings**:
- 50+ constants across 11 files need migration
- Existing `app_launch_sync` RPC returns `{user, yesterday_crew_count, hexes_in_viewport}`
- `LocalStorageService` pattern provides JSON file caching template
- `flutter_test` already in dev_dependencies
- Services use singleton pattern with static instances

### Metis Review
**Identified Gaps** (addressed):
- Config version tracking for cache invalidation: Added `config_version` field
- Run-time consistency: Config snapshot frozen at run start
- Fallback chain clarity: server -> cache -> hardcoded defaults
- Test infrastructure: TDD approach with `flutter_test`

---

## Work Objectives

### Core Objective
Enable server-side configuration of all game parameters without requiring app updates, while maintaining offline functionality through local caching and hardcoded fallbacks.

### Concrete Deliverables
- `app_config` table in Supabase (1 row, JSONB column)
- Updated `app_launch_sync` PostgreSQL function
- `lib/models/app_config.dart` - Typed config model
- `lib/services/remote_config_service.dart` - Fetch/cache/provide service
- `lib/services/config_cache_service.dart` - Local JSON cache
- Updated services: `season_service.dart`, `gps_validator.dart`, `location_service.dart`, `running_score_service.dart`, `run_tracker.dart`, `hex_data_provider.dart`, `hexagon_map.dart`, `accelerometer_service.dart`, `app_lifecycle_manager.dart`, `h3_config.dart`, `crew_model.dart`
- `test/services/remote_config_service_test.dart` - Unit tests

### Definition of Done
- [ ] `flutter test` passes with new RemoteConfigService tests
- [ ] `flutter analyze` shows no new errors
- [ ] App launches with server config (verified via debug logs)
- [ ] App launches offline with cached config
- [ ] App launches with no cache using defaults
- [ ] Config values can be changed in Supabase and take effect on next launch

### Must Have
- All 50+ config constants migrated to server
- Graceful fallback: server -> cache -> defaults
- Config frozen at run start
- Type-safe Dart model with defaults
- Unit tests for RemoteConfigService

### Must NOT Have (Guardrails)
- No admin UI (use Supabase dashboard)
- No real-time config updates (no WebSocket)
- No A/B testing or user-specific configs
- No config change audit log
- No mid-run config changes
- No breaking changes to existing service APIs

---

## Verification Strategy (MANDATORY)

### Test Decision
- **Infrastructure exists**: YES (flutter_test in pubspec.yaml)
- **User wants tests**: TDD
- **Framework**: flutter_test (built-in)

### TDD Workflow

Each core task follows RED-GREEN-REFACTOR:

**Task Structure:**
1. **RED**: Write failing test first
   - Test file: `test/services/remote_config_service_test.dart`
   - Test command: `flutter test test/services/`
   - Expected: FAIL (test exists, implementation doesn't)
2. **GREEN**: Implement minimum code to pass
   - Command: `flutter test test/services/`
   - Expected: PASS
3. **REFACTOR**: Clean up while keeping green
   - Command: `flutter test`
   - Expected: PASS (all tests)

### Manual Verification (supplement to tests)

**For config fetch verification:**
```bash
flutter run -d macos  # or ios/android
# Check debug console for:
# "RemoteConfigService: Loaded config version X from server"
# "RemoteConfigService: Cached config to config_cache.json"
```

**For offline fallback verification:**
```bash
# 1. Run app online (populates cache)
# 2. Disable network
# 3. Force quit and relaunch
# Check debug console for:
# "RemoteConfigService: Server unreachable, using cached config"
```

**For defaults fallback verification:**
```bash
# 1. Delete app data (clear cache)
# 2. Disable network
# 3. Launch app
# Check debug console for:
# "RemoteConfigService: No cache available, using defaults"
```

---

## Execution Strategy

### Parallel Execution Waves

```
Wave 1 (Start Immediately - Foundation):
├── Task 1: Create Supabase app_config table [no dependencies]
├── Task 3: Create AppConfig Dart model with defaults [no dependencies]
└── Task 6: Set up test infrastructure [no dependencies]

Wave 2 (After Wave 1 - Core Services):
├── Task 2: Update app_launch_sync RPC [depends: 1]
├── Task 4: Create ConfigCacheService [depends: 3]
└── Task 5: Create RemoteConfigService [depends: 2, 3, 4]

Wave 3 (After Wave 2 - Service Updates):
├── Task 7: Update SeasonService [depends: 5]
├── Task 8: Update GpsValidator [depends: 5]
├── Task 9: Update LocationService [depends: 5]
├── Task 10: Update RunningScoreService [depends: 5]
├── Task 11: Update RunTracker [depends: 5]
├── Task 12: Update HexDataProvider [depends: 5]
├── Task 13: Update HexagonMap [depends: 5]
├── Task 14: Update AccelerometerService [depends: 5]
├── Task 15: Update AppLifecycleManager [depends: 5]
├── Task 16: Update H3Config [depends: 5]
└── Task 17: Update CrewModel [depends: 5]

Wave 4 (After Wave 3 - Integration):
├── Task 18: Update main.dart initialization [depends: 5, 7-17]
└── Task 19: Integration testing & verification [depends: 18]

Critical Path: Task 1 -> Task 2 -> Task 5 -> Task 18 -> Task 19
Parallel Speedup: ~50% faster than sequential
```

### Dependency Matrix

| Task | Depends On | Blocks | Can Parallelize With |
|------|------------|--------|---------------------|
| 1 | None | 2 | 3, 6 |
| 2 | 1 | 5 | 4 |
| 3 | None | 4, 5 | 1, 6 |
| 4 | 3 | 5 | 2 |
| 5 | 2, 3, 4 | 7-17 | None |
| 6 | None | 7-17 | 1, 3 |
| 7-17 | 5, 6 | 18 | Each other |
| 18 | 5, 7-17 | 19 | None |
| 19 | 18 | None | None |

### Agent Dispatch Summary

| Wave | Tasks | Recommended Dispatch |
|------|-------|---------------------|
| 1 | 1, 3, 6 | 3 parallel agents (quick category) |
| 2 | 2, 4, 5 | Sequential (dependencies) or 2 parallel then 1 |
| 3 | 7-17 | Up to 11 parallel agents (quick category) |
| 4 | 18, 19 | Sequential (integration) |

---

## TODOs

### Wave 1: Foundation (Parallel)

- [ ] 1. Create Supabase `app_config` table

  **What to do**:
  - Create migration SQL for `app_config` table with:
    - `id INTEGER PRIMARY KEY DEFAULT 1` (single-row constraint)
    - `config_version INTEGER NOT NULL DEFAULT 1`
    - `config_data JSONB NOT NULL`
    - `updated_at TIMESTAMPTZ DEFAULT now()`
  - Insert initial row with all default config values
  - Add CHECK constraint to ensure only one row exists
  - Document the JSON schema in SQL comments

  **Must NOT do**:
  - Create multiple rows
  - Add user-specific config columns
  - Create separate tables for each config category

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Single SQL migration file, well-defined schema
  - **Skills**: [`supabase-schema-from-requirements`]
    - `supabase-schema-from-requirements`: Directly relevant for creating table from spec

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Tasks 3, 6)
  - **Blocks**: Task 2 (RPC update)
  - **Blocked By**: None

  **References**:
  - `lib/services/supabase_service.dart:1-20` - Existing Supabase patterns and client usage
  - `lib/config/supabase_config.dart` - Supabase URL/key configuration
  - Draft file `.sisyphus/drafts/remote-config-system.md` - Full list of config values to include

  **JSON Schema for config_data**:
  ```json
  {
    "season": {
      "duration_days": 280,
      "server_timezone_offset_hours": 2
    },
    "crew": {
      "max_members_regular": 12,
      "max_members_purple": 24
    },
    "gps": {
      "max_speed_mps": 6.94,
      "min_speed_mps": 0.3,
      "max_accuracy_meters": 50.0,
      "max_altitude_change_mps": 5.0,
      "max_jump_distance_meters": 100,
      "moving_avg_window_seconds": 20,
      "max_capture_pace_min_per_km": 8.0,
      "polling_rate_hz": 0.5,
      "min_time_between_points_ms": 1500
    },
    "scoring": {
      "tier_thresholds_km": [0, 3, 6, 9, 12, 15],
      "tier_points": [10, 25, 50, 100, 150, 200],
      "pace_multipliers": {
        "walking": 0.8,
        "easy_jog": 1.0,
        "comfortable": 1.2,
        "strong": 1.5,
        "fast": 1.8,
        "sprint": 2.0
      },
      "crew_multipliers": {
        "solo": 1.0,
        "duo": 1.3,
        "squad": 1.6,
        "crew": 2.0,
        "full_force": 2.5,
        "unity_wave": 3.0
      }
    },
    "hex": {
      "base_resolution": 9,
      "zone_resolution": 8,
      "city_resolution": 6,
      "all_resolution": 4,
      "capture_check_distance_meters": 20.0,
      "max_cache_size": 4000
    },
    "timing": {
      "accelerometer_sampling_period_ms": 200,
      "refresh_throttle_seconds": 30
    }
  }
  ```

  **Acceptance Criteria**:
  - [ ] SQL migration file created
  - [ ] Applied to Supabase via dashboard or CLI
  - [ ] `SELECT * FROM app_config` returns 1 row with valid JSONB
  - [ ] `config_version` is 1
  - [ ] All config categories present in `config_data`

  **Commit**: YES
  - Message: `feat(config): add app_config table for remote configuration`
  - Files: `supabase/migrations/YYYYMMDD_create_app_config.sql`

---

- [ ] 3. Create `AppConfig` Dart model with typed defaults

  **What to do**:
  - Create `lib/models/app_config.dart` with:
    - Nested classes for each config category (SeasonConfig, CrewConfig, GpsConfig, ScoringConfig, HexConfig, TimingConfig)
    - All fields with hardcoded default values (current constants)
    - `factory AppConfig.defaults()` returning all defaults
    - `factory AppConfig.fromJson(Map<String, dynamic>)` for deserialization
    - `Map<String, dynamic> toJson()` for serialization
    - `copyWith()` for immutable updates
  - Include `configVersion` field

  **Must NOT do**:
  - Make fields mutable (use final)
  - Skip default values (every field needs a fallback)
  - Use dynamic types (everything typed)

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Single model file with clear structure
  - **Skills**: [`moai-lang-flutter`]
    - `moai-lang-flutter`: Flutter/Dart best practices for model classes

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Tasks 1, 6)
  - **Blocks**: Tasks 4, 5
  - **Blocked By**: None

  **References**:
  - `lib/models/user_model.dart` - Existing model pattern with fromRow/toRow
  - `lib/models/crew_model.dart:1-93` - Pattern for copyWith and fromJson
  - `lib/services/season_service.dart:8-11` - Season config defaults
  - `lib/services/gps_validator.dart:57-67` - GPS config defaults
  - `lib/services/running_score_service.dart:63-78` - Scoring tier defaults
  - `lib/config/h3_config.dart:21-33` - Hex resolution defaults

  **Acceptance Criteria**:
  - [ ] `lib/models/app_config.dart` created
  - [ ] All 50+ config values have typed fields with defaults
  - [ ] `AppConfig.defaults()` returns valid instance
  - [ ] `AppConfig.fromJson(jsonDecode(jsonEncode(config)))` round-trips correctly
  - [ ] `flutter analyze lib/models/app_config.dart` shows no errors

  **Commit**: YES
  - Message: `feat(config): add AppConfig model with typed defaults`
  - Files: `lib/models/app_config.dart`

---

- [ ] 6. Set up test infrastructure for RemoteConfigService

  **What to do**:
  - Create `test/services/` directory
  - Create `test/services/remote_config_service_test.dart` with test stubs:
    - `test('loads config from server')`
    - `test('falls back to cache when server unavailable')`
    - `test('falls back to defaults when no cache')`
    - `test('caches config after successful fetch')`
    - `test('freezes config snapshot for run')`
  - Create mock classes for Supabase client
  - Verify test runs with `flutter test test/services/`

  **Must NOT do**:
  - Implement actual tests yet (just stubs)
  - Add external test dependencies (use flutter_test)
  - Test implementation details (test behavior)

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Test scaffolding with stubs
  - **Skills**: [`moai-lang-flutter`]
    - `moai-lang-flutter`: Flutter testing patterns

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Tasks 1, 3)
  - **Blocks**: Tasks 7-17 (need test infra)
  - **Blocked By**: None

  **References**:
  - `test/widget_test.dart` - Existing test file pattern
  - `pubspec.yaml:76-78` - flutter_test dependency

  **Acceptance Criteria**:
  - [ ] `test/services/remote_config_service_test.dart` exists
  - [ ] 5 test stubs defined (can be `skip: true` or empty bodies)
  - [ ] `flutter test test/services/` runs without errors (tests may be skipped)

  **Commit**: YES
  - Message: `test(config): add RemoteConfigService test scaffolding`
  - Files: `test/services/remote_config_service_test.dart`

---

### Wave 2: Core Services (Sequential/Partial Parallel)

- [ ] 2. Update `app_launch_sync` RPC to return config

  **What to do**:
  - Modify the `app_launch_sync` PostgreSQL function to:
    - SELECT config_data, config_version FROM app_config
    - Include in return object as `app_config` key
  - Return structure: `{user, yesterday_crew_count, hexes_in_viewport, app_config: {version, data}}`
  - Handle case where app_config table is empty (return null)

  **Must NOT do**:
  - Break existing return fields
  - Add separate RPC (extend existing)
  - Return config for every RPC call (only app_launch_sync)

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Single SQL function modification
  - **Skills**: [`supabase-schema-from-requirements`]
    - `supabase-schema-from-requirements`: RPC function patterns

  **Parallelization**:
  - **Can Run In Parallel**: NO (depends on Task 1)
  - **Parallel Group**: Wave 2 (can parallel with Task 4 after Task 1)
  - **Blocks**: Task 5
  - **Blocked By**: Task 1

  **References**:
  - `lib/services/supabase_service.dart:81-87` - Current app_launch_sync call pattern
  - Task 1 output - app_config table schema

  **Acceptance Criteria**:
  - [ ] SQL function updated in Supabase
  - [ ] Calling `app_launch_sync` returns object with `app_config` key
  - [ ] `app_config` contains `version` (int) and `data` (object)
  - [ ] Existing fields (`user`, `yesterday_crew_count`) still work

  **Commit**: YES
  - Message: `feat(config): extend app_launch_sync RPC to return config`
  - Files: `supabase/migrations/YYYYMMDD_update_app_launch_sync.sql`

---

- [ ] 4. Create `ConfigCacheService` for local JSON caching

  **What to do**:
  - Create `lib/services/config_cache_service.dart` following `LocalStorageService` pattern:
    - `saveConfig(AppConfig config)` - Write to `config_cache.json`
    - `loadConfig()` -> `AppConfig?` - Read from cache, return null if missing/corrupt
    - `clearCache()` - Delete cache file
    - `getCacheAge()` -> `Duration?` - Time since last cache
  - Use `path_provider` for document directory (already a dependency)
  - Include `config_version` in cached data for validation

  **Must NOT do**:
  - Use SharedPreferences (use JSON file)
  - Cache partial configs (all or nothing)
  - Throw exceptions (return null on failure)

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Single service file following existing pattern
  - **Skills**: [`moai-lang-flutter`]
    - `moai-lang-flutter`: Dart file I/O patterns

  **Parallelization**:
  - **Can Run In Parallel**: YES (with Task 2 after Task 3)
  - **Parallel Group**: Wave 2
  - **Blocks**: Task 5
  - **Blocked By**: Task 3 (needs AppConfig model)

  **References**:
  - `lib/services/local_storage_service.dart:1-51` - **PRIMARY PATTERN** - Follow this exactly
  - `lib/models/app_config.dart` (from Task 3) - Config model to serialize

  **Acceptance Criteria**:
  - [ ] `lib/services/config_cache_service.dart` created
  - [ ] `saveConfig()` writes JSON to documents directory
  - [ ] `loadConfig()` returns `AppConfig` or null
  - [ ] Round-trip test: save -> load returns equivalent config
  - [ ] `flutter analyze lib/services/config_cache_service.dart` passes

  **Commit**: YES
  - Message: `feat(config): add ConfigCacheService for local config caching`
  - Files: `lib/services/config_cache_service.dart`

---

- [ ] 5. Create `RemoteConfigService` (TDD)

  **What to do**:
  - **RED**: Implement the test stubs from Task 6 with actual assertions
  - **GREEN**: Create `lib/services/remote_config_service.dart`:
    - Singleton pattern (matching `SupabaseService`)
    - `initialize()` - Fetch from server, cache, fallback chain
    - `AppConfig get config` - Current config (throws if not initialized)
    - `AppConfig get configSnapshot` - Frozen config for current run
    - `freezeForRun()` - Capture current config for run duration
    - `unfreezeAfterRun()` - Release frozen config
    - Internal fallback chain: server -> cache -> defaults
  - **REFACTOR**: Clean up, add documentation

  **Must NOT do**:
  - Fetch config on every access (cache in memory)
  - Allow config changes mid-run (use snapshot)
  - Block app launch on slow network (timeout + fallback)

  **Recommended Agent Profile**:
  - **Category**: `ultrabrain`
    - Reason: Core service with complex logic, TDD, multiple dependencies
  - **Skills**: [`moai-lang-flutter`, `systematic-debugging`]
    - `moai-lang-flutter`: Flutter service patterns
    - `systematic-debugging`: TDD workflow

  **Parallelization**:
  - **Can Run In Parallel**: NO (depends on Tasks 2, 3, 4)
  - **Parallel Group**: Wave 2 (final task)
  - **Blocks**: Tasks 7-17
  - **Blocked By**: Tasks 2, 3, 4

  **References**:
  - `lib/services/supabase_service.dart:1-30` - Singleton pattern, client access
  - `lib/services/config_cache_service.dart` (from Task 4) - Cache service
  - `lib/models/app_config.dart` (from Task 3) - Config model
  - `test/services/remote_config_service_test.dart` (from Task 6) - Test file

  **Acceptance Criteria**:
  - [ ] All 5 tests pass: `flutter test test/services/remote_config_service_test.dart`
  - [ ] `RemoteConfigService().config` returns valid `AppConfig`
  - [ ] Offline test: disable network, verify cache fallback (debug log)
  - [ ] No-cache test: clear cache, disable network, verify defaults (debug log)
  - [ ] `freezeForRun()` / `unfreezeAfterRun()` work correctly

  **Commit**: YES
  - Message: `feat(config): add RemoteConfigService with fallback chain`
  - Files: `lib/services/remote_config_service.dart`, `test/services/remote_config_service_test.dart`

---

### Wave 3: Service Updates (Parallel)

- [ ] 7. Update `SeasonService` to use RemoteConfigService

  **What to do**:
  - Replace static constants with `RemoteConfigService().config.season.*`
  - Update: `seasonDurationDays`, `serverTimezoneOffsetHours`
  - Keep derived calculations (purple unlock at D-140)
  - Add import for `remote_config_service.dart`

  **Must NOT do**:
  - Change public API of SeasonService
  - Remove the static constants entirely (keep as fallback comments)
  - Access config in constructor (access in methods)

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Simple constant replacement
  - **Skills**: None required
    - Domain-specific, no special skills needed

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 3 (with Tasks 8-17)
  - **Blocks**: Task 18
  - **Blocked By**: Task 5

  **References**:
  - `lib/services/season_service.dart:8-11` - Constants to replace
  - `lib/services/remote_config_service.dart` (from Task 5) - Config access pattern

  **Acceptance Criteria**:
  - [ ] `seasonDurationDays` reads from `config.season.durationDays`
  - [ ] `serverTimezoneOffsetHours` reads from `config.season.serverTimezoneOffsetHours`
  - [ ] `flutter analyze lib/services/season_service.dart` passes
  - [ ] SeasonService still works (manual: check D-day display)

  **Commit**: NO (groups with Task 17)

---

- [ ] 8. Update `GpsValidator` to use RemoteConfigService

  **What to do**:
  - Replace static constants with `RemoteConfigService().config.gps.*`
  - Update: `maxSpeedMps`, `minSpeedMps`, `maxAccuracyMeters`, `maxAltitudeChangeMps`, `minTimeBetweenPointsMs`, `maxJumpDistanceMeters`, `movingAvgWindowSeconds`, `maxCapturePaceMinPerKm`
  - Consider using frozen config during active runs

  **Must NOT do**:
  - Change validation logic
  - Access config in hot path without caching locally

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Constant replacement
  - **Skills**: None required

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 3
  - **Blocks**: Task 18
  - **Blocked By**: Task 5

  **References**:
  - `lib/services/gps_validator.dart:57-67` - Constants to replace
  - `lib/services/gps_validator.dart:94` - maxCapturePaceMinPerKm

  **Acceptance Criteria**:
  - [ ] All 8 GPS constants read from config
  - [ ] `flutter analyze lib/services/gps_validator.dart` passes
  - [ ] GPS validation still works (manual: run tracking test)

  **Commit**: NO (groups with Task 17)

---

- [ ] 9. Update `LocationService` to use RemoteConfigService

  **What to do**:
  - Replace `_fixedPollingRateHz = 0.5` with config value
  - Access via `RemoteConfigService().config.gps.pollingRateHz`

  **Must NOT do**:
  - Change polling behavior
  - Make polling rate dynamic mid-run

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Single constant replacement
  - **Skills**: None required

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 3
  - **Blocks**: Task 18
  - **Blocked By**: Task 5

  **References**:
  - `lib/services/location_service.dart:47-48` - Constant to replace

  **Acceptance Criteria**:
  - [ ] `pollingRateHz` reads from config
  - [ ] `flutter analyze lib/services/location_service.dart` passes

  **Commit**: NO (groups with Task 17)

---

- [ ] 10. Update `RunningScoreService` to use RemoteConfigService

  **What to do**:
  - Replace tier thresholds and points with config values
  - Replace pace multipliers with config values
  - Replace crew multipliers with config values
  - Update `ImpactTier` enum to read from config (or keep enum, read values dynamically)

  **Must NOT do**:
  - Remove ImpactTier enum (keep for type safety)
  - Change scoring calculation logic

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Multiple constant replacements
  - **Skills**: None required

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 3
  - **Blocks**: Task 18
  - **Blocked By**: Task 5

  **References**:
  - `lib/services/running_score_service.dart:63-78` - Tier enum with hardcoded values
  - `lib/services/running_score_service.dart:174-201` - Multiplier methods

  **Acceptance Criteria**:
  - [ ] `getTier()` uses config thresholds
  - [ ] `getPaceMultiplier()` uses config values
  - [ ] `getCrewMultiplier()` uses config values
  - [ ] `flutter analyze` passes

  **Commit**: NO (groups with Task 17)

---

- [ ] 11. Update `RunTracker` to use RemoteConfigService

  **What to do**:
  - Replace `_hexResolution = 9` with config value
  - Replace `_captureCheckDistanceMeters = 20.0` with config value
  - Use frozen config snapshot during active run

  **Must NOT do**:
  - Change hex capture logic
  - Allow resolution to change mid-run

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Two constant replacements
  - **Skills**: None required

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 3
  - **Blocks**: Task 18
  - **Blocked By**: Task 5

  **References**:
  - `lib/services/run_tracker.dart:33-36` - Constants to replace

  **Acceptance Criteria**:
  - [ ] `_hexResolution` reads from frozen config
  - [ ] `_captureCheckDistanceMeters` reads from frozen config
  - [ ] `flutter analyze` passes

  **Commit**: NO (groups with Task 17)

---

- [ ] 12. Update `HexDataProvider` to use RemoteConfigService

  **What to do**:
  - Replace `maxCacheSize = 4000` with config value
  - Initialize LRU cache with config size

  **Must NOT do**:
  - Change cache eviction logic
  - Re-initialize cache after config changes

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Single constant replacement
  - **Skills**: None required

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 3
  - **Blocks**: Task 18
  - **Blocked By**: Task 5

  **References**:
  - `lib/providers/hex_data_provider.dart:23-24` - Constant to replace

  **Acceptance Criteria**:
  - [ ] `maxCacheSize` reads from config
  - [ ] LRU cache initialized with config value
  - [ ] `flutter analyze` passes

  **Commit**: NO (groups with Task 17)

---

- [ ] 13. Update `HexagonMap` to use RemoteConfigService

  **What to do**:
  - Replace `_fixedResolution = 9` with config value
  - Ensure consistency with RunTracker resolution

  **Must NOT do**:
  - Change hex rendering logic
  - Use different resolution than RunTracker

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Single constant replacement
  - **Skills**: None required

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 3
  - **Blocks**: Task 18
  - **Blocked By**: Task 5

  **References**:
  - `lib/widgets/hexagon_map.dart:419` - Constant to replace

  **Acceptance Criteria**:
  - [ ] `_fixedResolution` reads from config
  - [ ] Matches RunTracker resolution
  - [ ] `flutter analyze` passes

  **Commit**: NO (groups with Task 17)

---

- [ ] 14. Update `AccelerometerService` to use RemoteConfigService

  **What to do**:
  - Replace `_samplingPeriod = Duration(milliseconds: 200)` with config value
  - Access via `config.timing.accelerometerSamplingPeriodMs`

  **Must NOT do**:
  - Change accelerometer processing logic

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Single constant replacement
  - **Skills**: None required

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 3
  - **Blocks**: Task 18
  - **Blocked By**: Task 5

  **References**:
  - `lib/services/accelerometer_service.dart:34` - Constant to replace

  **Acceptance Criteria**:
  - [ ] `_samplingPeriod` reads from config
  - [ ] `flutter analyze` passes

  **Commit**: NO (groups with Task 17)

---

- [ ] 15. Update `AppLifecycleManager` to use RemoteConfigService

  **What to do**:
  - Replace `_throttleInterval = Duration(seconds: 30)` with config value
  - Access via `config.timing.refreshThrottleSeconds`

  **Must NOT do**:
  - Change lifecycle handling logic

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Single constant replacement
  - **Skills**: None required

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 3
  - **Blocks**: Task 18
  - **Blocked By**: Task 5

  **References**:
  - `lib/services/app_lifecycle_manager.dart:20` - Constant to replace

  **Acceptance Criteria**:
  - [ ] `_throttleInterval` reads from config
  - [ ] `flutter analyze` passes

  **Commit**: NO (groups with Task 17)

---

- [ ] 16. Update `H3Config` to use RemoteConfigService

  **What to do**:
  - Replace resolution constants with config values:
    - `baseResolution = 9`
    - `zoneResolution = 8`
    - `cityResolution = 6`
    - `allResolution = 4`
  - Update `GeographicScope` enum to read from config

  **Must NOT do**:
  - Change H3 calculation logic
  - Remove the static class (keep as namespace)

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Four constant replacements
  - **Skills**: None required

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 3
  - **Blocks**: Task 18
  - **Blocked By**: Task 5

  **References**:
  - `lib/config/h3_config.dart:21-33` - Constants to replace
  - `lib/config/h3_config.dart:51-80` - GeographicScope enum

  **Acceptance Criteria**:
  - [ ] All 4 resolution constants read from config
  - [ ] GeographicScope uses config values
  - [ ] `flutter analyze` passes

  **Commit**: NO (groups with Task 17)

---

- [ ] 17. Update `CrewModel` to use RemoteConfigService

  **What to do**:
  - Replace hardcoded `24` and `12` in `maxMembers` getter
  - Access via `config.crew.maxMembersRegular` and `config.crew.maxMembersPurple`

  **Must NOT do**:
  - Change crew membership logic
  - Store max members in model (keep as derived getter)

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Single getter modification
  - **Skills**: None required

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 3 (FINAL in wave)
  - **Blocks**: Task 18
  - **Blocked By**: Task 5

  **References**:
  - `lib/models/crew_model.dart:23` - `maxMembers` getter to update

  **Acceptance Criteria**:
  - [ ] `maxMembers` reads from config
  - [ ] Regular crews get 12, purple get 24 (from config)
  - [ ] `flutter analyze` passes

  **Commit**: YES (batch commit for Tasks 7-17)
  - Message: `refactor(config): migrate all services to use RemoteConfigService`
  - Files: All 11 updated files

---

### Wave 4: Integration (Sequential)

- [ ] 18. Update `main.dart` to initialize RemoteConfigService

  **What to do**:
  - Add `await RemoteConfigService().initialize()` after SupabaseService
  - Handle initialization failure gracefully (app should still launch with defaults)
  - Add debug logging for config source (server/cache/defaults)
  - Initialization order:
    1. SupabaseService.initialize()
    2. RemoteConfigService().initialize()  // NEW
    3. HexService().initialize()
    4. LocalStorage().initialize()

  **Must NOT do**:
  - Block app launch on config failure
  - Change Provider setup
  - Add config to Provider tree (access via singleton)

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Single file modification, clear insertion point
  - **Skills**: None required

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Wave 4
  - **Blocks**: Task 19
  - **Blocked By**: Tasks 5, 7-17

  **References**:
  - `lib/main.dart:25-36` - Current initialization sequence
  - `lib/services/remote_config_service.dart` (from Task 5) - Service to initialize

  **Acceptance Criteria**:
  - [ ] RemoteConfigService initialized before HexService
  - [ ] App launches successfully with server config
  - [ ] App launches successfully when server unreachable (uses cache)
  - [ ] App launches successfully with no cache (uses defaults)
  - [ ] Debug console shows config source

  **Commit**: YES
  - Message: `feat(config): integrate RemoteConfigService in app initialization`
  - Files: `lib/main.dart`

---

- [ ] 19. Integration testing and verification

  **What to do**:
  - Run full test suite: `flutter test`
  - Run analyzer: `flutter analyze`
  - Manual verification:
    1. Launch app online -> verify server config loaded
    2. Change value in Supabase -> relaunch -> verify new value
    3. Go offline -> relaunch -> verify cache used
    4. Clear cache + offline -> verify defaults used
    5. Start run -> verify config frozen during run
  - Document any issues found

  **Must NOT do**:
  - Skip offline testing
  - Skip frozen config verification
  - Consider done without all 5 scenarios passing

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Verification, not coding
  - **Skills**: [`systematic-debugging`]
    - `systematic-debugging`: For any issues found

  **Parallelization**:
  - **Can Run In Parallel**: NO (final task)
  - **Parallel Group**: Wave 4 (final)
  - **Blocks**: None (completion)
  - **Blocked By**: Task 18

  **References**:
  - All previous task outputs
  - `flutter test` command
  - `flutter analyze` command

  **Acceptance Criteria**:
  - [ ] `flutter test` passes (all tests green)
  - [ ] `flutter analyze` shows no errors
  - [ ] Online launch: config from server (debug log)
  - [ ] Config change: new value visible after relaunch
  - [ ] Offline launch: config from cache (debug log)
  - [ ] No cache + offline: defaults used (debug log)
  - [ ] Run freeze: config unchanged during run

  **Commit**: NO (verification only)

---

## Commit Strategy

| After Task(s) | Message | Files | Verification |
|--------------|---------|-------|--------------|
| 1 | `feat(config): add app_config table for remote configuration` | SQL migration | Supabase query |
| 2 | `feat(config): extend app_launch_sync RPC to return config` | SQL migration | RPC test |
| 3 | `feat(config): add AppConfig model with typed defaults` | app_config.dart | flutter analyze |
| 4 | `feat(config): add ConfigCacheService for local config caching` | config_cache_service.dart | flutter analyze |
| 5 | `feat(config): add RemoteConfigService with fallback chain` | remote_config_service.dart, tests | flutter test |
| 6 | `test(config): add RemoteConfigService test scaffolding` | test file | flutter test |
| 7-17 | `refactor(config): migrate all services to use RemoteConfigService` | 11 service files | flutter analyze |
| 18 | `feat(config): integrate RemoteConfigService in app initialization` | main.dart | flutter run |

---

## Success Criteria

### Verification Commands
```bash
# All tests pass
flutter test
# Expected: All tests passed!

# No analyzer errors
flutter analyze
# Expected: No issues found!

# App runs successfully
flutter run -d macos
# Expected: App launches, debug console shows "RemoteConfigService: Loaded config version X"
```

### Final Checklist
- [ ] All "Must Have" present:
  - [ ] 50+ config constants migrated
  - [ ] Fallback chain: server -> cache -> defaults
  - [ ] Config frozen at run start
  - [ ] Type-safe Dart model
  - [ ] Unit tests for RemoteConfigService
- [ ] All "Must NOT Have" absent:
  - [ ] No admin UI
  - [ ] No real-time updates
  - [ ] No A/B testing
  - [ ] No mid-run config changes
- [ ] All tests pass (`flutter test`)
- [ ] Analyzer clean (`flutter analyze`)
- [ ] Manual verification complete (5 scenarios)
