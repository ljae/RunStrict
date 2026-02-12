# RunStrict Data Flow Analysis & Optimization Guide

> Analysis of current data structures, field redundancy, and optimization opportunities.

---

## 1. Current Model Inventory

### 1.1 All Models (10 files, ~95 stored fields total)

| Model | File | Stored Fields | Computed | Purpose |
|-------|------|:---:|:---:|---------|
| `Team` | `team.dart` | 0 (enum) | 4 getters | Team identity |
| `UserModel` | `user_model.dart` | 12 | 2 | User profile + aggregates |
| `Run` | `run.dart` | 11 stored + 5 transient | 5 | Active + completed runs (unified) |
| `HexModel` | `hex_model.dart` | 4 | 7 | Hex tile state |
| `AppConfig` | `app_config.dart` | 7 sub-configs (~50 fields) | 0 | Remote config |
| `DailyRunningStat` | `daily_running_stat.dart` | 6 | 3 | Daily aggregates |
| `LocationPoint` | `location_point.dart` | 8 | 0 | GPS point (active run) |
| `RoutePoint` | `route_point.dart` | 3 | 1 | Compact GPS (cold storage) |
| `LapModel` | `lap_model.dart` | 5 | 1 | Per-km lap data |
| `Sponsor` | `sponsor.dart` | 7 | 0 | Sponsor display |

### 1.2 Provider/Service "Shadow Models" (defined inline, not in models/)

| Class | Defined In | Fields | Problem |
|-------|-----------|:---:|---------|
| `LeaderboardEntry` | `leaderboard_provider.dart` | 10 | Overlaps `UserModel` (7 shared fields) |
| `CachedHex` | `prefetch_service.dart` | 3 | Overlaps `HexModel` (2 shared fields) |
| `CachedLeaderboardEntry` | `prefetch_service.dart` | 8 | Overlaps `LeaderboardEntry` (6 shared fields) |
| `YesterdayStats` | `team_stats_provider.dart` | 8 | One-off data bag |
| `RankingEntry` | `team_stats_provider.dart` | 4 | Mini leaderboard |
| `TeamRankings` | `team_stats_provider.dart` | 9 | Aggregates rankings |
| `HexDominanceScope` | `team_stats_provider.dart` | 5 | Hex counts |
| `HexDominance` | `team_stats_provider.dart` | 4 | Wraps HexDominanceScope |
| `RedTeamBuff` | `team_stats_provider.dart` | 6 | Red buff state |
| `BlueTeamBuff` | `team_stats_provider.dart` | 1 | Blue buff state |
| `PurpleParticipation` | `team_stats_provider.dart` | 3 | Purple participation |
| `TeamBuffComparison` | `team_stats_provider.dart` | 6 | Wraps team buffs |
| `BuffBreakdown` | `buff_service.dart` | 8 | Buff details |
| `HexAggregatedStats` | `hex_data_provider.dart` | 4 | View-only stats |

**Total inline classes: 14** (with ~79 additional fields)

---

## 2. Data Flow Diagram

```
                          APP LAUNCH
                              |
                     +--------v--------+
                     | app_launch_sync |  (1 GET request)
                     |    Supabase RPC  |
                     +--------+--------+
                              |
              +---------------+---------------+
              |               |               |
         user_data      hex_map[]      app_config
              |               |               |
    +---------v---+    +------v------+  +-----v---------+
    |UserRepository|    |HexRepository|  |RemoteConfig   |
    |(local_user   |    |(LRU Cache)  |  |Service        |
    | .json)       |    |             |  |(config_cache  |
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
       |    |  (GPS stream)      |   |
       |    +---------+----------+   |
       |              |              |
       |    +---------v----------+   |
       |    |RunTracker          |   |
       |    | - distance calc    |   |
       |    | - hex capture      |   |
       |    | - lap tracking     |   |
       |    +---------+----------+   |
       |              |              |
       |    +---------v----------+   |
       |    |RunProvider         |   |
       |    | - Run model        |   |
       |    | - timer            |   |
       |    | - UI state         |   |
       |    +---------+----------+   |
       |              |              |
       |         RUN COMPLETE        |
       |              |              |
       |    +---------v----------+   |
       |    |"The Final Sync"    |   |
       |    | finalize_run() RPC |   |
       |    | (1 POST request)   |   |
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
| `Run.toMap()['avgPaceSecPerKm']` | Stored in SQLite | YES - can compute from distance/duration |
| `UserModel.avgPaceMinPerKm` | Supabase `users` table | Aggregate - needed |
| `DailyRunningStat.avgPaceMinPerKm` | Supabase `daily_stats` | Can compute from distance/duration |
| `LeaderboardEntry.avgPaceMinPerKm` | Supabase leaderboard RPC | Copy of UserModel field |

**Optimization**: `DailyRunningStat.avgPaceMinPerKm` can be computed from `totalDistanceKm` and `totalDurationSeconds`. Remove the stored field.

### 3.3 `hexesColored` vs `hexPath.length` vs `flipCount`

| Location | Name | Source |
|----------|------|--------|
| `Run.hexesColored` | mutable counter | Incremented during run |
| `Run.hexPath` | list of hex IDs | Contains all passed hexes |
| `Run.flipPoints` | computed | `hexesColored * buffMultiplier` |
| `Run.toMap()['flip_points']` | stored in SQLite | Redundant with computed getter |
| `DailyRunningStat.flipCount` | daily aggregate | Server-side |

**Problem**: `hexesColored` is NOT `hexPath.length`. `hexesColored` counts actual flips (color changes), while `hexPath` lists all hexes entered. They track different things and are both needed.

**Problem**: `flip_points` is stored in SQLite but is already computable from `hexesColored * buffMultiplier`.

### 3.4 Distance: meters vs km

| Location | Unit | Conversion |
|----------|------|------------|
| `Run.distanceMeters` | meters | Primary storage |
| `Run.distanceKm` | km | Computed getter |
| `Run.toMap()['distanceKm']` | km | Converted for SQLite (legacy) |
| `UserModel.totalDistanceKm` | km | Aggregate |
| `DailyRunningStat.totalDistanceKm` | km | Aggregate |
| `LeaderboardEntry.totalDistanceKm` | km | Copy of UserModel |
| Supabase `runs.distance_meters` | meters | Server |

**Problem**: SQLite stores `distanceKm` but the model stores `distanceMeters`. This requires conversion in both `toMap()` and `fromMap()`, adding complexity and potential rounding errors.

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

### 3.6 `CachedHex` vs `HexModel` overlap

| Field | HexModel | CachedHex | Shared? |
|-------|:--------:|:---------:|:-------:|
| id/hexId | x | x | YES |
| lastRunnerTeam | x | x | YES |
| lastFlippedAt | x (DateTime?) | x (lastUpdated) | YES (different name) |
| center (LatLng) | x | - | NO |

**CachedHex is a strict subset of HexModel.**

### 3.7 `CachedLeaderboardEntry` vs `LeaderboardEntry`

| Field | LeaderboardEntry | CachedLeaderboardEntry | Shared? |
|-------|:----------------:|:---------------------:|:-------:|
| id/oderId | x | x (typo: "oderId") | YES |
| name | x | x | YES |
| team | x | x | YES |
| avatar | x | x | YES |
| seasonPoints/flipPoints | x | x | YES |
| totalDistanceKm | x | x | YES |
| avgCv/stabilityScore | x (avgCv) | x (stabilityScore) | PARTIAL |
| homeHex | x | x | YES |
| rank | x | - | NO |
| avgPaceMinPerKm | x | - | NO |

**6 of 8 CachedLeaderboardEntry fields duplicate LeaderboardEntry.** Plus a typo (`oderId`).

---

## 4. Optimization Recommendations

### 4.1 MERGE: `CachedHex` into `HexModel`

**Current**: Two models for the same concept.
```
HexModel    = { id, center, lastRunnerTeam, lastFlippedAt }
CachedHex   = { hexId, lastRunnerTeam, lastUpdated }
```

**Proposed**: Delete `CachedHex`. Use `HexModel` everywhere. The `center` field can be computed on-demand from the hex ID via `HexService.getHexCenter()`.

**Impact**: Remove `CachedHex` class (50 lines). Update `PrefetchService` to use `HexModel` directly.

**Fields eliminated**: 3 (`CachedHex.hexId`, `lastRunnerTeam`, `lastUpdated`)

---

### 4.2 MERGE: `CachedLeaderboardEntry` into `LeaderboardEntry`

**Current**: Two near-identical models.

**Proposed**: Delete `CachedLeaderboardEntry`. Use `LeaderboardEntry` in `PrefetchService`. Fix `oderId` typo.

**Impact**: Remove `CachedLeaderboardEntry` class (45 lines). Update `PrefetchService` to use `LeaderboardEntry`.

**Fields eliminated**: 8 (entire class)

---

### 4.3 DERIVE: `LeaderboardEntry` from `UserModel`

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

### 4.5 REMOVE: Stored `flip_points` from `Run.toMap()`

**Current**: `'flip_points': flipPoints` stored in SQLite.

**Proposed**: Remove from `toMap()`. Already computable via `hexesColored * buffMultiplier`.

**Fields eliminated**: 1

---

### 4.6 REMOVE: `isPurpleRunner` legacy field from `Run.toMap()`

**Current**: `'isPurpleRunner': teamAtRun == Team.purple ? 1 : 0`

This is a legacy field. Purple status is already derivable from `teamAtRun`.

**Fields eliminated**: 1

---

### 4.7 NORMALIZE: Distance unit in SQLite

**Current**: Model stores `distanceMeters`, SQLite stores `distanceKm`, Supabase stores `distance_meters`. The `toMap()`/`fromMap()` methods perform conversions both ways.

**Proposed**: Store meters everywhere. Update SQLite column name from `distanceKm` to `distanceMeters` (migration).

**Fields eliminated**: 0 (but removes conversion complexity and potential rounding errors)

---

### 4.8 CONSOLIDATE: TeamStats inline models

`team_stats_provider.dart` defines 10 inline classes with 46 fields. Many are UI-specific display models.

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

| Action | Fields Removed | Classes Removed | Complexity Reduction |
|--------|:-:|:-:|---|
| Merge CachedHex -> HexModel | 3 | 1 | Eliminate dual hex model |
| Merge CachedLeaderboardEntry -> LeaderboardEntry | 8 | 1 | Eliminate dual leaderboard model |
| Derive LeaderboardEntry from UserModel | 9 | 0 | Single user data model |
| Remove stored avgPace from DailyRunningStat | 1 | 0 | Compute on demand |
| Remove stored flip_points from Run.toMap | 1 | 0 | Compute on demand |
| Remove isPurpleRunner legacy | 1 | 0 | Dead code removal |
| Consolidate TeamStats models | ~30 | ~7 | Single snapshot model |
| Merge BuffBreakdown + TeamBuffComparison | ~8 | 1 | Single buff model |
| **TOTAL** | **~61 fields** | **~10 classes** | |

### Before vs After

| Metric | Before | After |
|--------|:------:|:-----:|
| Model files | 10 | 10 |
| Inline model classes | 14 | ~4 |
| Total stored/cached fields | ~174 | ~113 |
| Redundant fields | ~61 | 0 |
| Serialization methods | ~40 | ~25 |

---

## 6. Priority Order

| Priority | Action | Risk | Effort |
|:--------:|--------|:----:|:------:|
| 1 | Remove `CachedHex` (use `HexModel`) | Low | Low |
| 2 | Remove `CachedLeaderboardEntry` (use `LeaderboardEntry`) | Low | Low |
| 3 | Remove `isPurpleRunner` + `flip_points` from `Run.toMap` | Low | Low |
| 4 | Remove stored `avgPaceMinPerKm` from `DailyRunningStat` | Low | Low |
| 5 | Derive `LeaderboardEntry` from `UserModel` | Medium | Medium |
| 6 | Consolidate TeamStats inline models | Medium | High |
| 7 | Merge `BuffBreakdown` + `TeamBuffComparison` | Medium | Medium |
| 8 | Normalize distance unit in SQLite | Medium | Medium (migration) |

---

## 7. Repository Layer Data Flow

The codebase uses a 3-layer architecture for state:

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

**Data ownership**:
- `UserRepository`: Single `UserModel` instance (persisted to `local_user.json`)
- `HexRepository`: LRU cache of `HexModel` instances (max 4000)
- `LeaderboardRepository`: List of `LeaderboardEntry` instances (refreshed every 30s)

**Provider -> Repository delegation pattern**:
```
AppStateProvider.currentUser  --> UserRepository.currentUser
HexDataProvider.getCachedHex  --> HexRepository.getHex
LeaderboardProvider.entries   --> LeaderboardRepository.entries
```

This delegation is clean but introduces forwarding boilerplate. Each provider has 3-5 forwarding getters.

---

## 8. Serialization Overhead

Each model maintains 2-4 serialization formats:

| Format | Method | Used By |
|--------|--------|---------|
| `toJson()` / `fromJson()` | camelCase | Local file persistence, inter-model |
| `toRow()` / `fromRow()` | snake_case | Supabase PostgreSQL |
| `toMap()` / `fromMap()` | mixed case | SQLite local storage |
| `toCompact()` / `fromCompact()` | array | RoutePoint binary storage |

**`Run` model has 4 serialization methods** (`toMap`, `fromMap`, `toRow`, `fromRow`) with field name mapping between them. This is the highest-maintenance model.

**Recommendation**: Consider using a code-generation approach (`json_serializable` or `freezed`) if the project grows further, to auto-generate serialization and `copyWith`.
