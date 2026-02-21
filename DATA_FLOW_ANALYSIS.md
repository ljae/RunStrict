# RunStrict Data Flow Analysis & Optimization Guide

> Analysis of current data structures, field redundancy, and optimization opportunities.
> Last updated: 2026-02-18

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
| `Sponsor` | `sponsor.dart` | 7 | 0 | Sponsor display + `SponsorTier` enum (replaced by AdMob) |

### 1.2 Provider/Service "Shadow Models" (defined inline, not in models/)

| Class | Defined In | Fields | Purpose |
|-------|-----------|:---:|---------|
| `LeaderboardEntry` | `leaderboard_provider.dart` | 2 (wraps `UserModel` + `rank`) | Season leaderboard row (delegates to `UserModel`) |
| `YesterdayStats` | `models/team_stats.dart` | 8 | Yesterday's personal performance |
| `RankingEntry` | `models/team_stats.dart` | 4 | Mini leaderboard entry (yesterday's points) |
| `TeamRankings` | `models/team_stats.dart` | 9 | Red elite/common + Blue rankings |
| `HexDominanceScope` | `models/team_stats.dart` | 3 + 2 computed | Hex counts per team in a scope |
| `HexDominance` | `models/team_stats.dart` | 4 | Wraps allRange + cityRange scopes |
| `RedTeamBuff` | `models/team_stats.dart` | 6 | Red buff status with elite tier |
| `PurpleParticipation` | `models/team_stats.dart` | 3 | Purple participation rate + count |
| `TeamBuffComparison` | `models/team_stats.dart` | 3 + delegates to `BuffBreakdown` | Wraps team buffs + user multiplier |
| `BuffBreakdown` | `buff_service.dart` | 8 | Buff calculation details from RPC |
| `HexAggregatedStats` | `hex_data_provider.dart` | 4 | View-only hex color counts |
| `RunStopResult` | `run_tracker.dart` | 5 | Run completion data bundle |
| `RunningScoreState` | `running_score_service.dart` | 4 | Active run scoring UI state |
| `SeasonAggregate` | `data_manager.dart` | 5 | Season totals (from daily stats) |
| `ValidationResult` | `gps_validator.dart` | 5 | GPS validation outcome |
| `PermissionResult` | `location_service.dart` | 3 | GPS permission request outcome |
| `LocationPermissionException` | `location_service.dart` | 2 | Permission error with settings flag |

**Total inline/extracted classes: 17** (`BlueTeamBuff` eliminated, 8 classes moved to `models/team_stats.dart`)

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
                     | LocalStorage    |  (2) SQLite v15 open
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
                     | AdService       |  (6) Google AdMob SDK init
                     | .initialize()   |
                     +--------+--------+
                              |
                     +--------v--------+
                     | AppLifecycle    |  (7) OnResume handler setup
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
    |(Notifier)     |    |(singleton) |    |BuffService  |
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

**Resolved**: `DailyRunningStat.avgPaceMinPerKm` is now a computed getter from `totalDistanceKm` and `totalDurationSeconds`. Stored field removed.

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

**Resolved**: `LeaderboardEntry` now wraps `UserModel` + `rank` via delegation pattern. 9 duplicated fields eliminated.

### 3.6 `BuffBreakdown` vs `TeamBuffComparison` overlap

| Field | BuffBreakdown | TeamBuffComparison | Shared? |
|-------|:---:|:---:|:-------:|
| multiplier / userTotalMultiplier | x | x | YES (different name) |
| allRangeBonus | x | x | YES |
| hasDistrictWin / districtWinBonus | x (bool) | x (int 0/1) | YES (different type) |
| hasProvinceWin / provinceWinBonus | x (bool) | x (int 0/1) | YES (different type) |
| isElite | x | (in RedTeamBuff) | PARTIAL | *(based on yesterday's flip_points, NOT flip_count)* |
| team / userTeam | x | x | YES (different name) |
| baseBuff | x | - | NO |
| reason | x | - | NO |
| redBuff | - | x | NO |
| blueBuff | - | x | NO |

**Resolved**: `TeamBuffComparison` now holds a `BuffBreakdown` reference and delegates overlapping fields. 5 duplicated fields eliminated.

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

### 4.4 ~~REMOVE: Stored `avgPaceMinPerKm` from `DailyRunningStat`~~ DONE

**Status**: Completed. `avgPaceMinPerKm` is now a computed getter derived from `totalDistanceKm` and `totalDurationSeconds`. Removed from constructor, `fromRow`, `fromJson`, `toRow`, `toJson`, `copyWith`. `addRun()` simplified — no longer takes `paceMinPerKm` parameter.

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

### 4.6 ~~DERIVE: `LeaderboardEntry` from `UserModel`~~ DONE

**Status**: Completed. `LeaderboardEntry` now wraps `UserModel user` + `int rank` instead of duplicating 9 fields. Delegate getters (`id`, `name`, `team`, `avatar`, `seasonPoints`, `totalDistanceKm`, `avgPaceMinPerKm`, `avgCv`, `homeHex`, `stabilityScore`) forward to `user`. Added `LeaderboardEntry.create()` convenience factory. `fromJson` constructs via `UserModel.fromRow(json)`. `fromCacheMap` constructs a `UserModel` directly.

**Fields eliminated**: 9 (replaced by delegation)

---

### 4.7 ~~NORMALIZE: Distance unit in SQLite~~ DONE

**Status**: Completed in v13 migration. SQLite column renamed from `distanceKm` to `distance_meters` with data conversion (`distanceKm * 1000`). `toMap()` now writes meters directly. `fromMap()` reads `distance_meters` first, falls back to `distanceKm * 1000` for backward compat. Also removed `avgPaceSecPerKm` and `isPurpleRunner` columns from schema (table recreated).

---

### 4.8 ~~CONSOLIDATE: TeamStats inline models~~ DONE

**Status**: Completed. Extracted 8 model classes from `team_stats_provider.dart` into `lib/data/models/team_stats.dart`. Key changes:
- `HexDominanceScope.dominantTeam` → computed getter (derived from max hex count)
- `HexDominanceScope.total` → computed getter (sum of red + blue + purple)
- `BlueTeamBuff` eliminated — `unionMultiplier` folded into `TeamBuffComparison.blueUnionMultiplier`
- All ~6 `HexDominanceScope` constructor sites updated to remove stored `dominantTeam:` and `total:` params
- `team_screen.dart` updated: `comparison.blueBuff.unionMultiplier` → `comparison.blueUnionMultiplier`

**Fields eliminated**: ~5 (2 derived fields from HexDominanceScope, 1 class eliminated, 2 redundant constructor params)

---

### 4.9 ~~MERGE: `BuffBreakdown` with `TeamBuffComparison`~~ DONE

**Status**: Completed. `TeamBuffComparison` now holds a `BuffBreakdown breakdown` reference and delegates `allRangeBonus`, `districtWinBonus`, `provinceWinBonus`, `userTeam`, `userTotalMultiplier` to it instead of duplicating. Removed 4 duplicated constructor parameters and 3 now-unused local variables from `_calculateBuffComparison()` in `team_stats_provider.dart`.

**Fields eliminated**: 5 (4 duplicated params + 1 class wrapper simplified)

---

## 5. Summary: Optimization Impact

### All Completed

| Action | Fields Removed | Classes Removed | Status |
|--------|:-:|:-:|---|
| Merge CachedHex -> HexModel | 3 | 1 | DONE |
| Merge CachedLeaderboardEntry -> LeaderboardEntry | 8 | 1 | DONE |
| Remove isPurpleRunner legacy | 1 | 0 | DONE |
| Remove stored flip_points from Run.toMap + SQLite | 1 | 0 | DONE (v13) |
| Normalize distance: distanceKm → distance_meters | 0 | 0 | DONE (v13) |
| Remove avgPaceSecPerKm from Run.toMap + SQLite | 1 | 0 | DONE (v13) |
| Remove stored avgPace from DailyRunningStat | 1 | 0 | DONE |
| Derive LeaderboardEntry from UserModel | 9 | 0 | DONE |
| Consolidate TeamStats inline models | ~5 | 1 | DONE |
| Merge BuffBreakdown + TeamBuffComparison | 5 | 0 | DONE |
| **Total** | **~34** | **3** | |

### Final State

| Metric | Before Optimization | After All Cleanups |
|--------|:------:|:-----:|
| Model files | 10 | 11 (added team_stats.dart) |
| Inline model classes | 18 | 10 |
| Total stored/cached fields | ~189 | ~169 |
| Redundant fields | ~34 | 0 |

---

## 6. Priority Order (All Complete)

| Priority | Action | Status |
|:--------:|--------|:------:|
| ~~1~~ | ~~Remove `flip_points` from `Run.toMap`~~ | DONE (v13) |
| ~~2~~ | ~~Normalize distance unit in SQLite~~ | DONE (v13) |
| ~~3~~ | ~~Remove stored `avgPaceMinPerKm` from `DailyRunningStat`~~ | DONE |
| ~~4~~ | ~~Derive `LeaderboardEntry` from `UserModel`~~ | DONE |
| ~~5~~ | ~~Consolidate TeamStats inline models~~ | DONE |
| ~~6~~ | ~~Merge `BuffBreakdown` + `TeamBuffComparison`~~ | DONE |

All data flow optimizations are complete. No remaining redundant fields.

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
| Ads | `AdService` | Google AdMob (BannerAd on MapScreen) | `AdService().initialize()` in main.dart |

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

### Two Data Domains

All app data belongs to exactly one of two domains:

**Snapshot Domain (Server → Local, read-only until next midnight):**
- Hex map base layer, leaderboard rankings + season record, team stats, buff multiplier, user aggregates
- Downloaded on app launch/OnResume via prefetch
- NEVER changes from running — frozen until next prefetch
- **Always anchored to home hex** — `PrefetchService` downloads using `homeHex`/`homeHexAll` (never GPS)
- Leaderboard: `get_leaderboard` RPC reads from `season_leaderboard_snapshot` table (NOT live `users`)
- LeaderboardScreen Season Record uses snapshot `LeaderboardEntry`, NOT live `currentUser`
- Used by: TeamScreen, LeaderboardScreen, ALL TIME aggregates (distance, pace, stability, run count)

**Live Domain (Local creation → Upload):**
- Header FlipPoints, run records, hex overlay (own runs only)
- Created/updated by user's running actions
- Uploaded to server via "The Final Sync"
- Used by: FlipPointsWidget, RunHistoryScreen (recent runs, period stats)

**The Only Hybrid Value:**
`PointsService.totalSeasonPoints = server season_points + local unsynced today`
This is used for both the header FlipPoints AND the ALL TIME points display, ensuring they always match.

| Screen/Widget | Domain | Data Source |
|--------------|--------|-------------|
| Header FlipPoints | Live (hybrid) | `PointsService.totalSeasonPoints` |
| Run History ALL TIME | Snapshot + hybrid points | `UserModel` aggregates + `totalSeasonPoints` |
| Run History period stats | Live | Local SQLite runs (run-level granularity) |
| TeamScreen | Snapshot | Server RPCs only (home hex anchored) |
| LeaderboardScreen | Snapshot | `season_leaderboard_snapshot` via `get_leaderboard` RPC (NOT live `users` or `currentUser`) |
| MapScreen display | Snapshot + GPS | GPS hex for camera/territory when outside province; home hex otherwise |
| Hex Map | Snapshot + Live overlay | `hex_snapshot` + own local flips |

### Location Domain Separation (Home vs GPS)

Server data and map display use different location anchors to prevent server data from changing when the user travels.

| Concern | Location Anchor | Implementation |
|---------|----------------|----------------|
| Hex snapshot download | **Home hex** | `PrefetchService._homeHexAll` in `_downloadHexData()` |
| Leaderboard filtering | **Home hex** | `LeaderboardProvider.filterByScope()` reads `homeHex` |
| TeamScreen territory | **Home hex** | `PrefetchService().homeHexCity` / `homeHex` |
| Season register | **Home hex** | `PrefetchService().homeHex` |
| MapScreen camera/overlay | **GPS hex** (outside province) | `PrefetchService().gpsHex` via `isOutsideHomeProvince` |
| HexagonMap anchor | **GPS hex** (outside province) | `_updateHexagons()` uses `gpsHex` |
| Hex capture | **Disabled** outside province | `_OutsideProvinceBanner` on MapScreen |

**PrefetchService getters** (no `activeHex*` — removed to prevent domain conflation):
- `homeHex`, `homeHexCity`, `homeHexAll` — registered home (server data anchor)
- `gpsHex`, `getGpsHexAtScope()` — current GPS (map display only)
- `isOutsideHomeProvince` — GPS province ≠ home province

**Outside-province UX flow**:
1. MapScreen shows `_OutsideProvinceBanner` (glassmorphism card) directing user to Profile
2. ProfileScreen `_LocationCard` shows both registered home and GPS locations
3. "UPDATE TO CURRENT" button triggers FROM→TO confirmation dialog with buff reset warning
4. After update: all screens realign to new home location, banner disappears

### Points Hybrid Model

Points use a dual-source calculation:

```
totalSeasonPoints = UserRepository.seasonPoints + _localUnsyncedToday
todayFlipPoints = _serverTodayBaseline + _localUnsyncedToday

During run:
  1. addRunPoints() → _localUnsyncedToday += points (immediate header update)

On run complete (The Final Sync):
  2. finalizeRun() RPC → server updates season_points, user aggregates
  3. onRunSynced() → transfer _localUnsyncedToday to server baseline
     (decrement local BEFORE updating season to avoid transient spike)

On app resume:
  4. appLaunchSync → refresh server season_points (use max to prevent regression)
  5. refreshFromLocalTotal → recalculate local unsynced from SQLite
```

### OnResume Data Refresh

When app returns to foreground, `AppLifecycleManager` triggers (throttled 30s):
- Hex map data refresh (`PrefetchService` delta sync)
- Leaderboard refresh
- Retry failed syncs (`SyncRetryService`)
- Buff multiplier refresh (`BuffService`)
- Today's points baseline refresh (`appLaunchSync` + `PointsService`)

Skipped during active runs (including during stopRun's Final Sync via `_isStopping` flag).

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

## 9. Storage Schema (SQLite v15)

| Table | Purpose | Key Columns |
|-------|---------|-------------|
| `runs` | Run history (cold) | `id`, `distance_meters`, `durationSeconds`, `hexesColored`, `teamAtRun`, `hex_path`, `buff_multiplier`, `cv`, `sync_status`, `run_date` |
| `routes` | GPS path per run (local only, never uploaded) | `runId`, lat/lng stream |
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
