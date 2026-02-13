# RunStrict Data Flow Analysis & Optimization Guide

> Analysis of current data structures, field redundancy, and optimization opportunities.
> Last updated: 2026-02-14

---

## 1. Current Model Inventory

### 1.1 All Models (10 files, ~100 stored fields total)

| Model | File | Stored Fields | Computed | Purpose |
|-------|------|:---:|:---:|---------|
| `Team` | `team.dart` | 0 (enum) | 5 getters | Team identity (red/blue/purple) |
| `UserModel` | `user_model.dart` | 12 | 2 | User profile + season aggregates |
| `Run` | `run.dart` | 11 stored + 5 transient | 5 | Active + completed runs (unified) |
| `HexModel` | `hex_model.dart` | 4 | 7 | Hex tile state + conflict resolution |
| `AppConfig` | `app_config.dart` | 7 sub-configs (~50 fields) | 0 | Remote config (Season, GPS, Scoring, Hex, Timing, Buff) |
| `DailyRunningStat` | `daily_running_stat.dart` | 6 | 4 | Daily aggregates (warm data) |
| `LocationPoint` | `location_point.dart` | 8 | 0 | High-fidelity GPS point (active run) |
| `RoutePoint` | `route_point.dart` | 3 | 1 | Compact route point (cold storage) |
| `LapModel` | `lap_model.dart` | 5 | 1 | Per-km lap data for CV calculation |
| `Sponsor` | `sponsor.dart` | 7 | 0 | Sponsor display + `SponsorTier` enum |

### 1.2 Provider/Service "Shadow Models" (defined inline, not in models/)

| Class | Defined In | Fields | Purpose |
|-------|-----------|:---:|---------|
| `LeaderboardEntry` | `leaderboard_provider.dart` | 10 | Season leaderboard row (overlaps `UserModel`: 9 shared fields) |
| `YesterdayStats` | `team_stats_provider.dart` | 8 | Yesterday's personal performance |
| `RankingEntry` | `team_stats_provider.dart` | 4 | Mini leaderboard entry (yesterday's points) |
| `TeamRankings` | `team_stats_provider.dart` | 9 | Red elite/common + Blue rankings |
| `HexDominanceScope` | `team_stats_provider.dart` | 5 | Hex counts per team in a scope |
| `HexDominance` | `team_stats_provider.dart` | 4 | Wraps allRange + cityRange scopes |
| `RedTeamBuff` | `team_stats_provider.dart` | 6 | Red buff status with elite tier |
| `BlueTeamBuff` | `team_stats_provider.dart` | 1 | Blue union multiplier |
| `PurpleParticipation` | `team_stats_provider.dart` | 3 | Purple participation rate + count |
| `TeamBuffComparison` | `team_stats_provider.dart` | 6 | Wraps team buffs + user multiplier |
| `BuffBreakdown` | `buff_service.dart` | 8 | Buff calculation details from RPC |
| `HexAggregatedStats` | `hex_data_provider.dart` | 4 | View-only hex color counts |
| `RunStopResult` | `run_tracker.dart` | 5 | Run completion data bundle |
| `RunningScoreState` | `running_score_service.dart` | 4 | Active run scoring UI state |
| `SeasonAggregate` | `data_manager.dart` | 5 | Season totals (from daily stats) |
| `ValidationResult` | `gps_validator.dart` | 5 | GPS validation outcome |
| `PermissionResult` | `location_service.dart` | 3 | GPS permission request outcome |
| `LocationPermissionException` | `location_service.dart` | 2 | Permission error with settings flag |

**Total inline classes: 18** (with ~92 additional fields)

### 1.3 Enums Defined Outside models/

| Enum | Defined In | Values | Purpose |
|------|-----------|:---:|---------|
| `ImpactTier` | `running_score_service.dart` | 6 | Distance-based tier (starter -> unstoppable) with emoji, color, baseImpact |
| `GpsSignalQuality` | `location_service.dart` | 5 | GPS accuracy classification (none/poor/fair/good/excellent) |

### 1.4 Internal/Private Classes (implementation detail, not data models)

| Class | Defined In | Purpose |
|-------|-----------|---------|
| `_PaceSample` | `gps_validator.dart` | Distance-time pair for moving average |
| `_KalmanFilter1D` | `gps_validator.dart` | 1D Kalman filter state |
| `GpsKalmanFilter` | `gps_validator.dart` | GPS noise filter |
| `AccelerometerValidator` | `gps_validator.dart` | Anti-spoofing accelerometer logic |
| `_AccelSample` | `gps_validator.dart` | Accelerometer data sample |
| `_Unspecified` | `run.dart` | Sentinel for `copyWith()` null handling |

---

## 2. Data Flow Diagram

```
                          APP LAUNCH
                              |
                     +--------v--------+
                     | RemoteConfig    |  (1) Server -> Cache -> Defaults
                     | .initialize()   |
                     +--------+--------+
                              |
                     +--------v--------+
                     | LocalStorage    |  (2) SQLite v13 open
                     | .initialize()   |
                     +--------+--------+
                              |
                     +--------v--------+
                     | AppStateProvider|  (3) Restore UserModel from local_user.json
                     | .initialize()   |
                     +--------+--------+
                              |
                     +--------v--------+
                     | PrefetchService |  (4) GPS Home Hex -> download ~2,401 hexes
                     | .initialize()   |      into HexRepository (delta sync)
                     +--------+--------+
                              |
                     +--------v--------+
                     | appLaunchSync   |  (5) Server baseline + local unsynced
                     | + PointsService |      -> hybrid FlipPoints total
                     +--------+--------+
                              |
                     +--------v--------+
                     | AppLifecycle    |  (6) OnResume handler setup
                     | Manager         |
                     +--------+--------+
                              |
              +---------------+---------------+
              |               |               |
         user_data      hex_map[]      app_config
              |               |               |
    +---------v---+    +------v------+  +-----v---------+
    |UserRepository|    |HexRepository|  |RemoteConfig   |
    |(local_user   |    |(LRU Cache   |  |Service        |
    | .json)       |    | max 4000)   |  |(config_cache  |
    +------+-------+    +------+------+  | .json)        |
           |                   |         +-------+-------+
    +------v-------+    +------v------+          |
    |AppState      |    |HexData     |    +------v------+
    |Provider      |    |Provider    |    |SeasonService|
    |(ChangeNotify) |    |(singleton) |    |BuffService  |
    +------+-------+    +------+------+    |GpsValidator |
           |                   |          +-------------+
           +--------+  +------+
                    |  |
              +-----v--v-----+
              |  HOME SCREEN  |
              | (FlipPoints,  |
              |  Season Badge)|
              +-------+------+
                      |
       +--------------+--------------+
       |              |              |
  +----v----+   +-----v-----+  +----v------+
  |MapScreen|   |RunScreen  |  |Leaderboard|
  |         |   |           |  |Screen     |
  +----+----+   +-----+-----+  +----+------+
       |              |              |
       |         RUN START           |
       |              |              |
       |    +---------v----------+   |
       |    |LocationService     |   |
       |    |  (GPS stream 0.5Hz)|   |
       |    +---------+----------+   |
       |              |              |
       |    +---------v----------+   |
       |    |RunTracker          |   |
       |    | - distance calc    |   |
       |    | - hex capture      |   |
       |    | - lap tracking     |   |
       |    | - checkpoint save  |   |
       |    +---------+----------+   |
       |              |              |
       |    +---------v----------+   |
       |    |RunProvider         |   |
       |    | - Run model        |   |
       |    | - timer            |   |
       |    | - UI state         |   |
       |    | - PointsService    |   |
       |    +---------+----------+   |
       |              |              |
       |         RUN COMPLETE        |
       |              |              |
       |    +---------v----------+   |
       |    |LocalStorage.save   |   |
       |    | runs + laps + route|   |
       |    +---------+----------+   |
       |              |              |
       |    +---------v----------+   |
       |    |"The Final Sync"    |   |
       |    | finalize_run() RPC |   |
       |    | (1 POST request)   |   |
       |    +----+---------------+   |
       |         |                   |
       |    +----v---------------+   |
       |    |SyncRetryService    |   |
       |    | (retry on failure) |   |
       |    +--------------------+   |
       |                             |
       +-----------------------------+
```

---

## 3. Field Redundancy Map

### 3.1 `stabilityScore` - Computed 3x from same formula

```
100 - cv  (clamped 0-100)
```

| Location | Type | Redundant? |
|----------|------|:---:|
| `Run.stabilityScore` | getter | Primary |
| `UserModel.stabilityScore` | getter | OK (different cv source) |
| `LeaderboardEntry.stabilityScore` | getter | Duplicate of UserModel pattern |

**Verdict**: Not stored, all computed. OK as-is.

### 3.2 `avgPaceMinPerKm` - Stored redundantly

| Location | Source | Redundant? |
|----------|--------|:---:|
| `Run.avgPaceMinPerKm` | Computed getter | NO - derived on demand |
| ~~`Run.toMap()['avgPaceSecPerKm']`~~ | ~~Stored in SQLite (sec/km)~~ | ~~YES~~ REMOVED in v13 |
| `UserModel.avgPaceMinPerKm` | Supabase `users` table | Aggregate - needed |
| `DailyRunningStat.avgPaceMinPerKm` | Supabase `daily_stats` | Can compute from distance/duration |
| `LeaderboardEntry.avgPaceMinPerKm` | Supabase leaderboard RPC | Copy of UserModel field |

**Optimization**: `DailyRunningStat.avgPaceMinPerKm` can be computed from `totalDistanceKm` and `totalDurationSeconds`. Remove the stored field.

### 3.3 `hexesColored` vs `hexPath.length` vs `flipCount`

| Location | Name | Source |
|----------|------|--------|
| `Run.hexesColored` | mutable counter | Incremented during run |
| `Run.hexPath` | list of hex IDs | Contains all passed hexes |
| `Run.flipPoints` | computed getter | `hexesColored * buffMultiplier` |
| ~~`Run.toMap()['flip_points']`~~ | ~~stored in SQLite~~ | ~~Redundant~~ REMOVED in v13 |
| `DailyRunningStat.flipCount` | daily aggregate | Server-side |

**Problem**: `hexesColored` is NOT `hexPath.length`. `hexesColored` counts actual flips (color changes), while `hexPath` lists all hexes entered. They track different things and are both needed.

**Resolved**: `flip_points` removed from SQLite schema in v13. Now computed dynamically as `SUM(hexesColored * buff_multiplier)` in SQL queries.

### 3.4 Distance: meters vs km

| Location | Unit | Conversion |
|----------|------|------------|
| `Run.distanceMeters` | meters | Primary storage |
| `Run.distanceKm` | km | Computed getter |
| `Run.toMap()['distance_meters']` | meters | Direct storage (v13+) |
| `UserModel.totalDistanceKm` | km | Aggregate |
| `DailyRunningStat.totalDistanceKm` | km | Aggregate |
| `LeaderboardEntry.totalDistanceKm` | km | Copy of UserModel |
| Supabase `runs.distance_meters` | meters | Server |

**Resolved**: SQLite now stores `distance_meters` (v13 migration). No conversion needed in `toMap()`/`fromMap()`. `fromMap()` retains backward compat fallback for `distanceKm` (pre-v13 rows).

### 3.5 `LeaderboardEntry` vs `UserModel` overlap

| Field | UserModel | LeaderboardEntry | Shared? |
|-------|:---------:|:----------------:|:-------:|
| id | x | x | YES |
| name | x | x | YES |
| team | x | x | YES |
| avatar | x | x | YES |
| seasonPoints | x | x | YES |
| totalDistanceKm | x | x | YES |
| avgPaceMinPerKm | x | x | YES |
| avgCv | x | x | YES |
| homeHex | x | x | YES |
| rank | - | x | NO |
| manifesto | x | - | NO |
| totalRuns | x | - | NO |
| seasonHomeHex | x | - | NO |

**9 of 12 UserModel fields duplicated in LeaderboardEntry.**

### 3.6 `BuffBreakdown` vs `TeamBuffComparison` overlap

| Field | BuffBreakdown | TeamBuffComparison | Shared? |
|-------|:---:|:---:|:-------:|
| multiplier / userTotalMultiplier | x | x | YES (different name) |
| allRangeBonus | x | x | YES |
| isCityLeader / cityLeaderBonus | x (bool) | x (int 0/1) | YES (different type) |
| isElite | x | (in RedTeamBuff) | PARTIAL |
| team / userTeam | x | x | YES (different name) |
| cityHex | x | - | NO |
| baseBuff | x | - | NO |
| reason | x | - | NO |
| redBuff | - | x | NO |
| blueBuff | - | x | NO |

**5 fields overlap between BuffBreakdown and TeamBuffComparison.**

---

## 4. Optimization Recommendations

### 4.1 ~~MERGE: `CachedHex` into `HexModel`~~ DONE

**Status**: Already completed. `CachedHex` no longer exists in the codebase. `PrefetchService.getCachedHex()` delegates directly to `HexRepository().getHex()` which returns `HexModel`.

---

### 4.2 ~~MERGE: `CachedLeaderboardEntry` into `LeaderboardEntry`~~ DONE

**Status**: Already completed. `CachedLeaderboardEntry` no longer exists. `LeaderboardEntry` now has `toCacheMap()` / `fromCacheMap()` serialization for SQLite leaderboard cache.

---

### 4.3 ~~REMOVE: Stored `flip_points` from `Run.toMap()`~~ DONE

**Status**: Completed in v13 migration. `flip_points` removed from `Run.toMap()` and SQLite schema. SQL queries now compute dynamically as `SUM(hexesColored * buff_multiplier)`.

---

### 4.4 REMOVE: Stored `avgPaceMinPerKm` from `DailyRunningStat`

**Current**: Stored alongside `totalDistanceKm` and `totalDurationSeconds`.

**Proposed**: Compute on demand:
```dart
double get avgPaceMinPerKm {
  if (totalDistanceKm <= 0 || totalDurationSeconds <= 0) return 0;
  return (totalDurationSeconds / 60.0) / totalDistanceKm;
}
```

**Fields eliminated**: 1

---

### 4.5 ~~REMOVE: `isPurpleRunner` legacy field from `Run.toMap()`~~ DONE

**Status**: Already removed. `Run.toMap()` no longer includes `isPurpleRunner`.

---

### 4.6 DERIVE: `LeaderboardEntry` from `UserModel`

**Current**: `LeaderboardEntry` duplicates 9 fields from `UserModel` and adds `rank`.

**Proposed**: Make `LeaderboardEntry` wrap `UserModel` + `rank`:

```dart
class LeaderboardEntry {
  final UserModel user;
  final int rank;

  // Delegate getters
  String get id => user.id;
  String get name => user.name;
  Team get team => user.team;
  int get seasonPoints => user.seasonPoints;
  int? get stabilityScore => user.stabilityScore;
  // ...
}
```

**Fields eliminated**: 9 (replaced by delegation)

---

### 4.7 ~~NORMALIZE: Distance unit in SQLite~~ DONE

**Status**: Completed in v13 migration. SQLite column renamed from `distanceKm` to `distance_meters` with data conversion (`distanceKm * 1000`). `toMap()` now writes meters directly. `fromMap()` reads `distance_meters` first, falls back to `distanceKm * 1000` for backward compat. Also removed `avgPaceSecPerKm` and `isPurpleRunner` columns from schema (table recreated).

---

### 4.8 CONSOLIDATE: TeamStats inline models

`team_stats_provider.dart` defines 9 inline classes with ~46 fields. Many are UI-specific display models.

**Current structure**:
```
YesterdayStats (8 fields)
RankingEntry (4 fields)
TeamRankings (9 fields)
HexDominanceScope (5 fields)
HexDominance (4 fields)
RedTeamBuff (6 fields)
BlueTeamBuff (1 field)
PurpleParticipation (3 fields)
TeamBuffComparison (6 fields)
```

**Proposed consolidation**:

```dart
/// Single response model for team stats RPC
class TeamStatsSnapshot {
  // Yesterday
  final double? yesterdayDistanceKm;
  final int yesterdayFlips;
  final int yesterdayPoints;
  final int yesterdayRunCount;

  // Dominance (all range)
  final int allRedHexes;
  final int allBlueHexes;
  final int allPurpleHexes;

  // Dominance (city range)
  final int? cityRedHexes;
  final int? cityBlueHexes;
  final int? cityPurpleHexes;

  // Territory
  final String? territoryName;
  final int? districtNumber;

  // Buff (user-specific)
  final int userMultiplier;
  final bool userIsElite;
  final bool isCityLeader;
  final bool hasProvinceRange;

  // Computed
  String? get allDominantTeam { ... }
  String? get cityDominantTeam { ... }
  double get purpleParticipationRate { ... }
}
```

**Fields eliminated**: ~30 (from 46 to ~16)

This removes:
- `BlueTeamBuff` (1 field, can be derived)
- `RedTeamBuff.commonMultiplier` (always 1)
- `RedTeamBuff.activeMultiplier` (derivable)
- `TeamBuffComparison` wrapper (fields flattened)
- `HexDominanceScope.total` (derivable from sum)
- `HexDominanceScope.dominantTeam` (derivable from max)
- `HexDominance` wrapper (fields flattened)
- `TeamRankings` (most fields computable)

---

### 4.9 MERGE: `BuffBreakdown` with `TeamBuffComparison`

**Current**: Two separate classes for buff information.
```
BuffBreakdown (buff_service.dart) = { multiplier, baseBuff, allRangeBonus, reason, team, cityHex, isCityLeader, isElite }
TeamBuffComparison (team_stats_provider.dart) = { redBuff, blueBuff, allRangeBonus, cityLeaderBonus, userTeam, userTotalMultiplier }
```

**Proposed**: Use a single `BuffStatus` model:
```dart
class BuffStatus {
  final int multiplier;
  final int baseBuff;
  final int allRangeBonus;
  final int cityLeaderBonus;
  final String team;
  final bool isElite;
  final String? reason;
}
```

**Fields eliminated**: ~8

---

## 5. Summary: Optimization Impact

### Already Completed

| Action | Fields Removed | Classes Removed | Status |
|--------|:-:|:-:|---|
| Merge CachedHex -> HexModel | 3 | 1 | DONE |
| Merge CachedLeaderboardEntry -> LeaderboardEntry | 8 | 1 | DONE |
| Remove isPurpleRunner legacy | 1 | 0 | DONE |
| Remove stored flip_points from Run.toMap + SQLite | 1 | 0 | DONE (v13) |
| Normalize distance: distanceKm → distance_meters | 0 | 0 | DONE (v13) |
| Remove avgPaceSecPerKm from Run.toMap + SQLite | 1 | 0 | DONE (v13) |
| **Subtotal** | **14** | **2** | |

### Remaining Opportunities

| Action | Fields Removed | Classes Removed | Complexity Reduction |
|--------|:-:|:-:|---|
| Remove stored avgPace from DailyRunningStat | 1 | 0 | Compute on demand |
| Derive LeaderboardEntry from UserModel | 9 | 0 | Single user data model |
| Consolidate TeamStats models | ~30 | ~7 | Single snapshot model |
| Merge BuffBreakdown + TeamBuffComparison | ~8 | 1 | Single buff model |
| **Subtotal** | **~48 fields** | **~8 classes** | |

### Current vs Fully Optimized

| Metric | Current | After Remaining |
|--------|:------:|:-----:|
| Model files | 10 | 10 |
| Inline model classes | 18 | ~10 |
| Total stored/cached fields | ~189 | ~141 |
| Redundant fields | ~48 | 0 |

---

## 6. Priority Order (Remaining)

| Priority | Action | Risk | Effort |
|:--------:|--------|:----:|:------:|
| ~~1~~ | ~~Remove `flip_points` from `Run.toMap`~~ | | DONE |
| ~~6~~ | ~~Normalize distance unit in SQLite~~ | | DONE (v13) |
| 1 | Remove stored `avgPaceMinPerKm` from `DailyRunningStat` | Low | Low |
| 2 | Derive `LeaderboardEntry` from `UserModel` | Medium | Medium |
| 3 | Consolidate TeamStats inline models | Medium | High |
| 4 | Merge `BuffBreakdown` + `TeamBuffComparison` | Medium | Medium |

---

## 7. Repository Layer Data Flow

The codebase uses a 3-layer **Forwarding Provider-Repository** pattern:

```
+------------------+     +------------------+     +------------------+
|   PROVIDERS      |     |   REPOSITORIES   |     |   SERVICES       |
| (UI binding)     |---->| (source of truth)|<----| (data fetch)     |
+------------------+     +------------------+     +------------------+
| AppStateProvider |     | UserRepository   |     | AuthService      |
| RunProvider      |     | HexRepository    |     | SupabaseService  |
| HexDataProvider  |     | LeaderboardRepo  |     | PrefetchService  |
| LeaderboardProv  |     |                  |     | BuffService      |
| TeamStatsProv    |     |                  |     | PointsService    |
+------------------+     +------------------+     +------------------+
```

### Data Ownership

| Data Type | Owner (State) | Persistence | Mutated By |
|-----------|--------------|-------------|------------|
| User Profile | `UserRepository` | `local_user.json` / Supabase `profiles` | `AppStateProvider`, `AuthService` |
| Hex Colors | `HexRepository` | LRU cache (max 4000) / Supabase `hexes` | `PrefetchService`, `RunProvider` (via capture) |
| Run History | `RunProvider` | SQLite `runs`, `routes`, `laps` | `RunTracker` (via `RunProvider.stopRun()`) |
| Leaderboard | `LeaderboardRepository` | SQLite `leaderboard_cache` | `LeaderboardProvider`, `PrefetchService` |
| Points | `PointsService` | `UserRepository` / SQLite `runs` | `RunProvider` (during run), `appLaunchSync` |
| Game Config | `RemoteConfigService` | `config_cache.json` / Supabase `app_config` | `RemoteConfigService.initialize()` |

### Provider -> Repository Delegation

```
AppStateProvider.currentUser  --> UserRepository.currentUser
HexDataProvider.getCachedHex  --> HexRepository.getHex
LeaderboardProvider.entries   --> LeaderboardRepository.entries
```

This delegation is clean but introduces forwarding boilerplate. Each provider has 3-5 forwarding getters.

### RunProvider: Multi-Service Coordinator

`RunProvider` coordinates the most complex data flow in the app:

```
LocationService (GPS 0.5Hz)
    -> RunTracker (distance, hex capture, lap tracking, checkpoint save)
        -> HexDataProvider (capture signals)
    -> RunProvider (Run model, timer, UI state)
        -> PointsService (adds points via BuffService multiplier)
        -> LocalStorage (saves runs + laps + route on completion)
        -> SupabaseService.finalizeRun() ("The Final Sync")
            -> SyncRetryService (retry on failure: launch, OnResume, next run)
```

### Points Hybrid Model

Points use a dual-source calculation:

```
todayFlipPoints = ServerBaseline (synced runs) + LocalUnsynced (pending SQLite runs)

On run complete:
  1. _localUnsyncedToday += points  (immediate UI update)
  2. UserRepository.updateSeasonPoints()  (triggers notifyListeners)
  3. finalizeRun() RPC -> server
  4. On sync success: transfer from _localUnsyncedToday to _serverTodayBaseline
```

### OnResume Data Refresh

When app returns to foreground, `AppLifecycleManager` triggers (throttled 30s):
- Hex map data refresh (`PrefetchService` delta sync)
- Leaderboard refresh
- Retry failed syncs (`SyncRetryService`)
- Buff multiplier refresh (`BuffService`)
- Today's points baseline refresh (`appLaunchSync` + `PointsService`)

Skipped during active runs.

---

## 8. Serialization Overhead

Each model maintains 2-4 serialization formats:

| Format | Method | Used By |
|--------|--------|---------|
| `toJson()` / `fromJson()` | camelCase | Local file persistence, inter-model |
| `toRow()` / `fromRow()` | snake_case | Supabase PostgreSQL |
| `toMap()` / `fromMap()` | mixed case | SQLite local storage |
| `toCacheMap()` / `fromCacheMap()` | snake_case | SQLite leaderboard cache |
| `toCompact()` / `fromCompact()` | array | RoutePoint binary storage |

**`Run` model has 4 serialization methods** (`toMap`, `fromMap`, `toRow`, `fromRow`) with field name mapping between them. This is the highest-maintenance model.

**`LeaderboardEntry` has 4 serialization methods** (`fromJson`, `toCacheMap`, `fromCacheMap`, plus constructor). Second highest maintenance.

**Recommendation**: Consider using a code-generation approach (`json_serializable` or `freezed`) if the project grows further, to auto-generate serialization and `copyWith`.

---

## 9. Storage Schema (SQLite v13)

| Table | Purpose | Key Columns |
|-------|---------|-------------|
| `runs` | Run history (cold) | `id`, `distance_meters`, `durationSeconds`, `hexesColored`, `teamAtRun`, `hex_path`, `buff_multiplier`, `cv`, `sync_status`, `run_date` |
| `routes` | GPS path per run (cold) | `runId`, lat/lng stream |
| `laps` | Per-km segments (cold) | `runId`, `lapNumber`, `distanceMeters`, `durationSeconds` |
| `run_checkpoint` | Crash recovery (hot) | `run_id`, `captured_hex_ids` - saved on every hex flip |
| `prefetch_meta` | Persistent anchors | `home_hex`, daily territory snapshots (JSON) |
| `leaderboard_cache` | Offline leaderboard | `user_id`, `name`, `team`, `flip_points`, `total_distance_km`, `stability_score`, `home_hex` |

### Data Temperature Classification

```
HOT DATA (Season-scoped, reset on D-Day):
+-- Hex colors (HexRepository LRU cache)
+-- Season points (UserRepository)
+-- Run checkpoints (SQLite run_checkpoint)
+-- Leaderboard cache (SQLite leaderboard_cache)

WARM DATA (Refreshed periodically):
+-- Daily stats (Supabase daily_running_stats)
+-- Buff multiplier (BuffService, frozen during runs)
+-- Remote config (RemoteConfigService)

COLD DATA (Permanent, never deleted):
+-- Run history (SQLite runs)
+-- Route archives (SQLite routes)
+-- Lap data (SQLite laps)
+-- User profile (local_user.json)
```
