# Draft: RunStrict Data Architecture Optimization

## Requirements (confirmed)
- User wants ONE screen map with numbered screens showing links
- Remove ALL duplicated data - single source of truth
- Use local calculation where possible to reduce download volume
- App prefetches on launch/resume -> save local -> calculate local
- After run end, upload to server (handle unsynced data display)
- Server calculates rankings and hex colors
- Optimize for minimum data download
- Share variables across the app properly
- Output: Parallel task graph showing which changes can be done simultaneously

## Current Architecture Analysis

### Screens Identified (11 total)
1. AppInitializer - Entry point, session restore
2. SeasonRegisterScreen - New user onboarding
3. TeamSelectionScreen - Legacy team selection (fallback)
4. HomeScreen - Navigation hub with 5 tabs
5. MapScreen - Territory exploration
6. RunningScreen - GPS tracking during runs
7. TeamScreen - Team stats, yesterday's performance
8. RunHistoryScreen - Calendar view of past runs
9. LeaderboardScreen - Rankings with scope filtering
10. ProfileScreen - User avatar, manifesto, stats
11. TraitorGateScreen - Purple team defection

### Providers (5)
1. AppStateProvider - User identity, team, points (from local JSON)
2. RunProvider - Active run lifecycle, GPS, "Final Sync"
3. HexDataProvider - Territory state with LRU cache
4. TeamStatsProvider - Competitive stats from server RPCs
5. LeaderboardProvider - Rankings with scope filtering

### Services (15+)
- SupabaseService, PrefetchService, RunTracker, BuffService
- LocationService, GpsValidator, HexService, LocalStorage
- PointsService, SeasonService, RemoteConfigService, etc.

## Data Duplication Identified

### 1. RUN MODELS (80% field overlap) - CRITICAL
| Field | RunSession | RunSummary | RunHistoryModel |
|-------|------------|------------|-----------------|
| id | YES | YES | YES |
| startTime | YES | derived | YES |
| endTime | YES | YES | YES |
| distanceKm | derived | YES | YES |
| durationSeconds | derived | YES | YES |
| avgPaceMinPerKm | derived | YES | YES |
| hexesColored | YES | YES | flipCount (YES) |
| teamAtRun | YES | YES | YES |
| cv | YES | YES | NO |
| buffMultiplier | NO | YES | NO |
| flipPoints | NO | derived | YES |
| userId | NO | NO | YES |

**SOLUTION**: Single `Run` model with computed getters

### 2. USER POINTS (3 locations) - CRITICAL
- `AppStateProvider._currentUser.seasonPoints`
- `PointsService._seasonPoints` (also _serverTodayBaseline, _localUnsyncedToday)
- `LeaderboardProvider._entries[i].seasonPoints`

**SOLUTION**: Single `UserRepository` as source of truth

### 3. USER TEAM (3 locations) - HIGH
- `AppStateProvider._currentUser.team`
- `TeamStatsProvider._rankings.userTeam`
- `LeaderboardProvider._entries[i].team` (current user entry)

**SOLUTION**: Single `UserRepository` accessed by all providers

### 4. USER LOCATION (2 locations) - MEDIUM
- `RunProvider._activeRun.route` (during runs)
- `HexDataProvider._userLocation` + `_currentUserHexId`

**SOLUTION**: `HexDataProvider` subscribes to `RunProvider` location stream

### 5. HEX CACHE (2 locations) - HIGH
- `PrefetchService._hexCache` (Map<String, CachedHex>)
- `HexDataProvider._hexCache` (LruCache<String, HexModel>)

**SOLUTION**: Single `HexRepository` accessed by both

### 6. LEADERBOARD CACHE (2 locations) - MEDIUM
- `PrefetchService._leaderboardCache`
- `LeaderboardProvider._entries`

**SOLUTION**: Single `LeaderboardRepository` accessed by both

### 7. DERIVED FIELDS STORED - LOW
- `avgPaceMinPerKm` stored (can calculate: durationSeconds / (distanceKm * 60))
- `run_date` in SQLite (can derive: endTime.toGmt2DateString())
- `stabilityScore` returned from server (can calculate: 100 - cv)

**SOLUTION**: Remove stored fields, use getters

### 8. SYNC QUEUE PAYLOAD - LOW
- `sync_queue.payload` duplicates runs/routes/laps data as JSON

**SOLUTION**: Store only run_id, reconstruct payload on retry

## Technical Decisions

### Unified Run Model Design
```dart
class Run {
  final String id;
  final DateTime startTime;
  final int durationSeconds;  // Store only duration
  final double distanceMeters; // Store in meters
  final int hexesColored;
  final Team teamAtRun;
  final double? cv;
  final int buffMultiplier;
  final String? userId;       // For history
  final bool isActive;        // Active run flag
  
  // Computed getters (NOT stored)
  DateTime get endTime => startTime.add(Duration(seconds: durationSeconds));
  double get distanceKm => distanceMeters / 1000;
  double get avgPaceMinPerKm => distanceMeters > 0 ? (durationSeconds / 60) / distanceKm : 0;
  int? get stabilityScore => cv != null ? (100 - cv!).round().clamp(0, 100) : null;
  int get flipPoints => hexesColored * buffMultiplier;
  
  // Transient data (not persisted, for active runs only)
  @JsonIgnore
  List<LocationPoint> route = [];
  @JsonIgnore
  List<String> hexesPassed = [];
  @JsonIgnore
  String? currentHexId;
}
```

### Repository Pattern
```
┌─────────────────────────────────────────────────────────────────┐
│                        Repositories                              │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────────┐ │
│  │UserRepository│  │HexRepository│  │LeaderboardRepository    │ │
│  │(single user)│  │(all hexes)  │  │(all rankings)           │ │
│  └──────┬──────┘  └──────┬──────┘  └───────────┬─────────────┘ │
│         │                │                      │               │
│  Notifies all providers when data changes                       │
└─────────────────────────────────────────────────────────────────┘
           │                │                      │
           ▼                ▼                      ▼
    AppStateProvider  HexDataProvider    LeaderboardProvider
    PointsService     PrefetchService    TeamStatsProvider
```

### Delta Sync for Hexes
```sql
-- RPC: get_hexes_delta
CREATE FUNCTION get_hexes_delta(
  p_parent_hex TEXT,
  p_since_time TIMESTAMPTZ
)
RETURNS TABLE(hex_id TEXT, last_runner_team TEXT, last_flipped_at TIMESTAMPTZ)
AS $$
  SELECT hex_id, last_runner_team, last_flipped_at
  FROM hexes
  WHERE parent_hex = p_parent_hex
    AND last_flipped_at > p_since_time
$$;
```

## Research Findings

### Current Data Flow
1. **App Launch**: PrefetchService.initialize() → downloads ALL 3,800 hexes
2. **During Run**: RunTracker → HexDataProvider.updateHexColor() → PointsService.addRunPoints()
3. **Run End**: RunProvider.stopRun() → SupabaseService.finalizeRun() → mark synced
4. **Resume**: AppLifecycleManager → PrefetchService.refresh() → downloads ALL hexes again

### Optimization Opportunities
1. **Delta sync**: Only download hexes changed since `last_prefetch_time`
2. **Lazy leaderboard**: Don't prefetch entire leaderboard, fetch on tab open
3. **Incremental rankings**: Server calculates user's position, sends only top N + user
4. **Remove sync_queue payload**: Reconstruct from runs table

## Open Questions
- (All requirements clear from user's detailed spec)

## Scope Boundaries
- INCLUDE: All data model refactoring, cache consolidation, delta sync, provider simplification
- EXCLUDE: UI changes, new features, Supabase schema changes beyond delta sync RPC
