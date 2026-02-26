# RunStrict Data Architecture & Models

> Data models, database schema, data flow, and repository patterns. Read DEVELOPMENT_SPEC.md (index) first.

---

## A. Client Models

### Team Enum

```dart
enum Team {
  red,    // Display: "FLAME" 🔥
  blue,   // Display: "WAVE" 🌊
  purple; // Display: "CHAOS" 💜

  String get displayName => switch (this) {
    red => 'FLAME',
    blue => 'WAVE',
    purple => 'CHAOS',
  };
}
```

---

### UserModel

```dart
class UserModel {
  final String id;
  final String name;           // Display name
  final Team team;             // Current team (purple = defected)
  final String avatar;         // Emoji avatar (legacy, not displayed)
  final String sex;            // 'male', 'female', or 'other'
  final DateTime birthday;     // User birthday
  final int seasonPoints;      // Flip points this season (preserved on Purple defection)
  final String? manifesto;     // 30-char declaration, editable anytime
  final String? nationality;   // ISO country code (e.g., 'KR', 'US')
  final String? homeHex;       // First hex of last run (SELF leaderboard scope)
  final String? homeHexEnd;    // Last hex of last run (OTHERS leaderboard scope)
  final String? seasonHomeHex; // Home hex at season start
  final double totalDistanceKm; // Running season aggregate
  final double? avgPaceMinPerKm; // Weighted average pace (min/km)
  final double? avgCv;         // Average Coefficient of Variation (null if no CV data)
  final int totalRuns;         // Number of completed runs

  /// Stability score from average CV (higher = better, 0-100)
  int? get stabilityScore => avgCv == null ? null : (100 - avgCv!).round().clamp(0, 100);
}
```

**Aggregate Fields (incremental update via `finalize_run`):**
- `totalDistanceKm` → cumulative distance from all runs
- `avgPaceMinPerKm` → incremental average pace (updated on each run)
- `avgCv` → incremental average CV from runs with CV data (≥1km)
- `totalRuns` → count of completed runs

**Profile Fields (server-persisted, editable anytime):**
- `sex` → Male/Female/Other (displayed as ♂/♀/⚥ icon)
- `birthday` → user's date of birth
- `manifesto` → 30-character declaration (shown on leaderboard with electric effect)
- `nationality` → ISO country code (flag emoji display)

---

### HexModel

```dart
class HexModel {
  final String id;             // H3 hex index (resolution 9)
  final LatLng center;         // Geographic center
  Team? lastRunnerTeam;        // null = neutral, else team color
  DateTime? lastFlippedAt;     // Run's endTime when hex was flipped (for conflict resolution)

  // NO runner IDs (privacy)

  /// Returns true if color actually changed (= a flip occurred)
  bool setRunnerColor(Team runnerTeam, DateTime runEndTime) {
    if (lastRunnerTeam == runnerTeam) return false;
    // Only update if this run ended later (conflict resolution)
    if (lastFlippedAt != null && runEndTime.isBefore(lastFlippedAt!)) return false;
    lastRunnerTeam = runnerTeam;
    lastFlippedAt = runEndTime;
    return true;
  }
}
```

---

### Run (Unified Run Model — `lib/data/models/run.dart`)

> **Note**: The unified `Run` model replaces three legacy models: `RunSession` (active runs), `RunSummary` (completed runs), and `RunHistoryModel` (history display). A single model handles the full run lifecycle.

```dart
class Run {
  // Core fields
  final String id;
  final DateTime startTime;
  DateTime? endTime;
  double distanceMeters;
  int hexesPassed;
  int hexesColored;              // Flip count during this run
  Team teamAtRun;
  List<String> hexPath;          // H3 hex IDs passed (deduplicated)
  double buffMultiplier;         // Applied multiplier from buff system (frozen at run start)
  double? cv;                    // Coefficient of Variation (null for runs < 1km)
  String syncStatus;             // 'pending', 'synced', 'failed'

  // Computed getters
  double get distanceKm => distanceMeters / 1000;
  Duration get duration => (endTime ?? DateTime.now()).difference(startTime);
  double get avgPaceMinPerKm => /* calculation */;
  int? get stabilityScore => cv != null ? (100 - cv!).round().clamp(0, 100) : null;
  int get flipPoints => (hexesColored * buffMultiplier).round();

  // Mutable methods for active runs
  void addPoint(LocationPoint point) { ... }
  void updateDistance(double meters) { ... }
  void recordFlip() { ... }
  void complete() { ... }

  // Serialization
  Map<String, dynamic> toMap();    // SQLite (includes hex_path as comma-separated, buff_multiplier)
  Map<String, dynamic> toRow();    // Supabase
  factory Run.fromMap(Map<String, dynamic> map);  // SQLite
  factory Run.fromRow(Map<String, dynamic> row);  // Supabase
}
```

> **Storage Optimization**:
> - `hexPath` stores deduplicated H3 hex IDs only (no individual timestamps).
> - Raw GPS trace is NOT uploaded to server (stored locally in SQLite `routes` table for route display only).
> - Route shape can be reconstructed by connecting hex centers.
> - `endTime` is the sole timestamp used for conflict resolution.

> **Design Note**: `run_history` is separate from `runs` table.
> - `runs`: Heavy data with `hex_path` → **DELETED on season reset**
> - `run_history`: Lightweight stats → **PRESERVED across seasons** (5-year retention)

**Data Flow:**

| Stage | What Happens | Storage |
|-------|-------------|---------|
| Active run | `Run` tracks GPS, hexes, distance in memory | In-memory |
| Run completion | `Run.complete()` → saved to SQLite + server sync | SQLite `runs` table |
| Server sync | `finalize_run()` RPC with hex_path, flip_points, buff_multiplier | Supabase `runs` + `run_history` |
| History display | `Run.fromMap()` from SQLite or `Run.fromRow()` from Supabase | Read-only |

---

### DailyRunningStat (Aggregated — Preserved Across Seasons)

```dart
class DailyRunningStat {
  final String userId;
  final String dateKey;             // "2026-01-24" format
  final double totalDistanceKm;
  final int totalDurationSeconds;
  final int flipCount;              // Total flips that day

  // Computed getter (not stored — derived from totalDistanceKm / totalDurationSeconds)
  double get avgPaceMinPerKm {
    if (totalDistanceKm <= 0 || totalDurationSeconds <= 0) return 0;
    return (totalDurationSeconds / 60.0) / totalDistanceKm;
  }
}
```

---

### LapModel (Per-km Lap Data)

```dart
/// Represents a single 1km lap during a run
class LapModel {
  final int lapNumber;         // which lap (1, 2, 3...)
  final double distanceMeters; // should be 1000.0 for complete laps
  final double durationSeconds; // time to complete this lap
  final int startTimestampMs;  // when lap started
  final int endTimestampMs;    // when lap ended

  /// Derived: average pace in seconds per kilometer
  double get avgPaceSecPerKm => durationSeconds / (distanceMeters / 1000);
}
```

**Purpose**: Used to calculate Coefficient of Variation (CV) for pace consistency analysis.

**CV Calculation (LapService):**
```dart
static double? calculateCV(List<LapModel> laps) {
  if (laps.isEmpty) return null;
  if (laps.length == 1) return 0.0; // No variance with single lap
  // Sample stdev (n-1 denominator)
  // CV = (stdev / mean) * 100
  // ...
}

// Stability Score = 100 - CV (clamped 0-100, higher = better)
static int? calculateStabilityScore(double? cv) {
  if (cv == null) return null;
  return (100 - cv).round().clamp(0, 100);
}
```

---

### LocationPoint (Active GPS — Ephemeral)

```dart
class LocationPoint {
  final double latitude;
  final double longitude;
  final double altitude;
  final double speed;               // m/s
  final double accuracy;            // meters (must be ≤ 50m)
  final double heading;             // degrees (0-360, 0=North, -1=invalid)
  final DateTime timestamp;
}
```

---

### RoutePoint (Cold Storage — Compact)

```dart
class RoutePoint {
  final double lat;
  final double lng;
  // Minimal data for route replay (Douglas-Peucker compressed)
}
```

---

## B. Model Inventory

### B.1 All Models (10 files, ~100 stored fields total)

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

### B.2 Provider/Service "Shadow Models" (defined inline, not in models/)

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

### B.3 Enums Defined Outside models/

| Enum | Defined In | Values | Purpose |
|------|-----------|:---:|---------|
| `ImpactTier` | `running_score_service.dart` | 6 | Distance-based tier (starter -> unstoppable) with emoji, color, baseImpact |
| `GpsSignalQuality` | `location_service.dart` | 5 | GPS accuracy classification (none/poor/fair/good/excellent) |

### B.4 Internal/Private Classes (implementation detail, not data models)

| Class | Defined In | Purpose |
|-------|-----------|---------|
| `_PaceSample` | `gps_validator.dart` | Distance-time pair for moving average |
| `_KalmanFilter1D` | `gps_validator.dart` | 1D Kalman filter state |
| `GpsKalmanFilter` | `gps_validator.dart` | GPS noise filter |
| `AccelerometerValidator` | `gps_validator.dart` | Anti-spoofing accelerometer logic |
| `_AccelSample` | `gps_validator.dart` | Accelerometer data sample |
| `_Unspecified` | `run.dart` | Sentinel for `copyWith()` null handling |

---

## C. Database Schema (PostgreSQL via Supabase)

### C.1 Core Tables

```sql
-- Users table (permanent, survives season reset)
CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  auth_id UUID REFERENCES auth.users(id) NOT NULL,
  name TEXT NOT NULL,
  team TEXT CHECK (team IN ('red', 'blue', 'purple')),
  avatar TEXT NOT NULL DEFAULT '🏃',
  sex TEXT CHECK (sex IN ('male', 'female', 'other')),
  birthday DATE,
  nationality TEXT,                           -- ISO country code (e.g., 'KR', 'US')
  season_points INTEGER NOT NULL DEFAULT 0,
  manifesto TEXT CHECK (char_length(manifesto) <= 30),
  home_hex_start TEXT,                        -- First hex of last run (used for SELF leaderboard scope)
  home_hex_end TEXT,                          -- Last hex of last run (used for OTHERS leaderboard scope)
  district_hex TEXT,                          -- Res 6 H3 parent hex, set by finalize_run() (used for buff district scoping)
  season_home_hex TEXT,                       -- Home hex at season start
  total_distance_km DOUBLE PRECISION NOT NULL DEFAULT 0,
  avg_pace_min_per_km DOUBLE PRECISION,
  avg_cv DOUBLE PRECISION,
  total_runs INTEGER NOT NULL DEFAULT 0,
  cv_run_count INTEGER NOT NULL DEFAULT 0,   -- For incremental CV average
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Hex map (deleted on season reset)
CREATE TABLE hexes (
  id TEXT PRIMARY KEY,                       -- H3 index string (resolution 9)
  last_runner_team TEXT CHECK (last_runner_team IN ('red', 'blue', 'purple')),
  last_flipped_at TIMESTAMPTZ,              -- Run's endTime when hex was flipped (for conflict resolution)
  parent_hex TEXT                            -- Res 5 province hex (for snapshot/delta/dominance filtering)
  -- NO runner IDs (privacy)
);

-- Daily buff stats: per-city stats (calculated at midnight GMT+2 via Edge Function)
-- NOT per-user. get_user_buff() reads this + run_history to determine individual buff.
CREATE TABLE daily_buff_stats (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  stat_date DATE NOT NULL,
  city_hex TEXT,                                  -- District (Res 6) hex prefix
  dominant_team TEXT,                             -- Team with most hexes in this district
  red_hex_count INTEGER DEFAULT 0,
  blue_hex_count INTEGER DEFAULT 0,
  purple_hex_count INTEGER DEFAULT 0,
  red_elite_threshold_points INTEGER DEFAULT 0,   -- Top 20% flip_points threshold (from run_history.flip_points, NOT flip_count)
  purple_total_users INTEGER DEFAULT 0,
  purple_active_users INTEGER DEFAULT 0,
  purple_participation_rate DOUBLE PRECISION DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Daily province range stats (tracks server-wide hex dominance)
CREATE TABLE daily_province_range_stats (
  date DATE PRIMARY KEY,
  leading_team TEXT CHECK (leading_team IN ('red', 'blue')),  -- PURPLE excluded
  red_hex_count INTEGER NOT NULL DEFAULT 0,
  blue_hex_count INTEGER NOT NULL DEFAULT 0,
  calculated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Hex snapshot (frozen daily at midnight GMT+2 — basis for flip point calculation)
-- Only stores hexes that have been flipped (neutral hexes = absent from table)
CREATE TABLE hex_snapshot (
  hex_id TEXT NOT NULL,
  last_runner_team TEXT NOT NULL CHECK (last_runner_team IN ('red', 'blue', 'purple')),
  snapshot_date DATE NOT NULL,           -- Which day this snapshot is for (users download today's)
  last_run_end_time TIMESTAMPTZ,         -- For conflict resolution during snapshot build
  parent_hex TEXT,                        -- Resolution 5 parent (for prefetch filtering)
  PRIMARY KEY (hex_id, snapshot_date)
);
CREATE INDEX idx_hex_snapshot_date_parent ON hex_snapshot(snapshot_date, parent_hex);
```

### C.2 Season-Partitioned Tables (pg_partman)

```sql
-- Runs table: partitioned by season (40-day periods)
CREATE TABLE runs (
  id UUID NOT NULL DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id),
  team_at_run TEXT NOT NULL CHECK (team_at_run IN ('red', 'blue', 'purple')),
  start_time TIMESTAMPTZ NOT NULL,
  end_time TIMESTAMPTZ,
  distance_meters DOUBLE PRECISION NOT NULL DEFAULT 0,
  avg_pace_min_per_km DOUBLE PRECISION,      -- min/km (e.g., 6.0)
  hexes_colored INTEGER NOT NULL DEFAULT 0,
  hex_path TEXT[] NOT NULL DEFAULT '{}',      -- H3 hex IDs passed
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (id, created_at)
) PARTITION BY RANGE (created_at);

-- Daily stats: partitioned by month
CREATE TABLE daily_stats (
  id UUID NOT NULL DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id),
  date_key DATE NOT NULL,
  total_distance_km DOUBLE PRECISION NOT NULL DEFAULT 0,
  total_duration_seconds INTEGER NOT NULL DEFAULT 0,
  avg_pace_min_per_km DOUBLE PRECISION,
  flip_count INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (id, created_at),
  UNIQUE (user_id, date_key, created_at)
) PARTITION BY RANGE (created_at);

-- Run history: lightweight stats preserved across seasons
-- Separate from runs table which contains heavy hex_path data
CREATE TABLE run_history (
  id UUID NOT NULL DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id),
  run_date DATE NOT NULL,                       -- Date of the run
  start_time TIMESTAMPTZ NOT NULL,
  end_time TIMESTAMPTZ NOT NULL,
  distance_km DOUBLE PRECISION NOT NULL,
  duration_seconds INTEGER NOT NULL,
  avg_pace_min_per_km DOUBLE PRECISION,
  flip_count INTEGER NOT NULL DEFAULT 0,        -- Raw flips (hex color changes)
  flip_points INTEGER NOT NULL DEFAULT 0,      -- Points with multiplier (flip_count × buff). Used for RED Elite threshold.
  team_at_run TEXT NOT NULL CHECK (team_at_run IN ('red', 'blue', 'purple')),
  cv DOUBLE PRECISION,                         -- Pace consistency (Coefficient of Variation)
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (id, created_at)
) PARTITION BY RANGE (created_at);

-- NOTE: run_history is PRESERVED across season resets (personal history)
-- NOTE: daily_flips table REMOVED — no daily flip limit

-- Season leaderboard snapshot: frozen at midnight, used by get_leaderboard RPC
-- IMPORTANT: This is the Snapshot Domain source for leaderboard. Never use live `users` table.
CREATE TABLE season_leaderboard_snapshot (
  user_id UUID NOT NULL REFERENCES users(id),
  season_number INTEGER NOT NULL,
  rank INTEGER NOT NULL,
  name TEXT,
  team TEXT,
  avatar TEXT,
  season_points INTEGER NOT NULL DEFAULT 0,
  total_distance_km DOUBLE PRECISION NOT NULL DEFAULT 0,
  avg_pace_min_per_km DOUBLE PRECISION,
  avg_cv DOUBLE PRECISION,
  total_runs INTEGER DEFAULT 0,
  home_hex TEXT,
  home_hex_end TEXT,
  manifesto TEXT,
  nationality TEXT,
  PRIMARY KEY (user_id, season_number)
);
```

### C.3 Partition Management (pg_partman)

```sql
-- Auto-create partitions for runs (monthly)
SELECT partman.create_parent(
  p_parent_table := 'public.runs',
  p_control := 'created_at',
  p_type := 'native',
  p_interval := '1 month',
  p_premake := 3
);

-- Auto-create partitions for daily_stats (monthly)
SELECT partman.create_parent(
  p_parent_table := 'public.daily_stats',
  p_control := 'created_at',
  p_type := 'native',
  p_interval := '1 month',
  p_premake := 3
);

-- Auto-create partitions for run_history (monthly, PERMANENT - never deleted)
SELECT partman.create_parent(
  p_parent_table := 'public.run_history',
  p_control := 'created_at',
  p_type := 'native',
  p_interval := '1 month',
  p_premake := 3
  -- NO p_retention: run_history is preserved across seasons
);
```

**Partition Strategy by Table:**

| Table | Partition Interval | Retention | D-Day Reset Method |
|-------|-------------------|-----------|-------------------|
| `runs` | Monthly | Season data only | `DROP PARTITION` (instant) |
| `run_history` | Monthly | **5 years** (then auto-deleted) | Never deleted on D-Day |
| `daily_stats` | Monthly | **5 years** (then auto-deleted) | Never deleted on D-Day |
| `hexes` | Not partitioned | Season only | `TRUNCATE TABLE` (instant) |
| `daily_buff_stats` | Not partitioned | Season only | `TRUNCATE TABLE` (instant) |

**Data Retention Policy:**
- `run_history` and `daily_stats` are retained for **5 years** from creation date.
- pg_partman `p_retention` is set to `'5 years'` for these tables.
- Data older than 5 years is automatically dropped during partition maintenance.
- Account deletion triggers immediate deletion of all user data (GDPR compliance).

### C.4 D-Day Reset Execution (The Void)

```sql
-- Season reset: executes in < 1 second regardless of data volume
BEGIN;
  -- 1. Instant wipes (TRUNCATE = instant, no row-by-row cost)
  TRUNCATE TABLE hexes;
  TRUNCATE TABLE daily_buff_stats;
  TRUNCATE TABLE daily_province_range_stats;
  
  -- 2. Reset user season data (UPDATE, not DELETE)
  UPDATE users SET
    season_points = 0,
    team = NULL,  -- Forces re-selection
    total_distance_km = 0,
    avg_pace_min_per_km = NULL,
    avg_cv = NULL,
    total_runs = 0,
    cv_run_count = 0;
  
  -- 3. Drop season's runs partitions (heavy data, instant disk reclaim)
  -- pg_partman handles this via retention policy, or manual:
  -- DROP TABLE runs_p2026_01, runs_p2026_02, ... ;
  
  -- 4. PRESERVED tables (personal history across seasons):
  --    - run_history (per-run lightweight stats)
  --    - daily_stats (aggregated daily stats)
COMMIT;
```

**Key Advantage over Firebase/Firestore:**
- Firebase charges per-document for deletion (100万 docs = 100万 write ops = ~$0.18+)
- Supabase/PostgreSQL: `TRUNCATE`/`DROP PARTITION` = **$0, instant, no performance impact**

### C.5 Row Level Security (RLS)

```sql
-- Users can only read/update their own profile
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
CREATE POLICY users_self ON users
  USING (auth_id = auth.uid())
  WITH CHECK (auth_id = auth.uid());

-- Hexes are readable by all, writable by authenticated runners
ALTER TABLE hexes ENABLE ROW LEVEL SECURITY;
CREATE POLICY hexes_read ON hexes FOR SELECT USING (true);
CREATE POLICY hexes_write ON hexes FOR UPDATE USING (auth.role() = 'authenticated');

-- Active runs: DEPRECATED - RLS policies removed
-- Table kept for potential future use but no RLS policies defined
-- ALTER TABLE active_runs ENABLE ROW LEVEL SECURITY;  -- Disabled
```

### C.6 Key Indexes

```sql
CREATE INDEX idx_users_team ON users(team);
CREATE INDEX idx_users_season_points ON users(season_points DESC);
CREATE INDEX idx_daily_stats_user_date ON daily_stats(user_id, date_key);
CREATE INDEX idx_hexes_team ON hexes(last_runner_team);
CREATE INDEX idx_daily_buff_stats_user_date ON daily_buff_stats(user_id, date);
```

### C.7 Key RPC Functions

#### get_leaderboard

```sql
-- Leaderboard query (reads from season_leaderboard_snapshot — Snapshot Domain)
-- IMPORTANT: Do NOT read from live `users` table — leaderboard is frozen at midnight.
CREATE OR REPLACE FUNCTION get_leaderboard(p_limit INTEGER DEFAULT 20)
RETURNS TABLE(
  id UUID, name TEXT, team TEXT, avatar TEXT,
  season_points INT, total_distance_km FLOAT8,
  avg_pace_min_per_km FLOAT8, avg_cv FLOAT8,
  home_hex TEXT, home_hex_end TEXT, manifesto TEXT,
  nationality TEXT, total_runs INT, rank BIGINT
) AS $fn$
  SELECT
    s.user_id, s.name, s.team, s.avatar,
    s.season_points, s.total_distance_km,
    s.avg_pace_min_per_km, s.avg_cv,
    s.home_hex,
    COALESCE(s.home_hex_end, u.home_hex_end),
    s.manifesto,
    COALESCE(s.nationality, u.nationality),
    COALESCE(s.total_runs, u.total_runs),
    s.rank::BIGINT
  FROM public.season_leaderboard_snapshot s
  LEFT JOIN public.users u ON u.id = s.user_id
  WHERE s.season_number = (
    SELECT MAX(season_number) FROM public.season_leaderboard_snapshot
  )
  ORDER BY s.rank ASC
  LIMIT p_limit;
$fn$ LANGUAGE sql STABLE SECURITY DEFINER;
```

#### finalize_run() — "The Final Sync"

```sql
-- Finalize run: accept client flip points with cap validation ("The Final Sync")
-- Snapshot-based: client counts flips against daily snapshot, server cap-validates only.
-- Server still updates live `hexes` table for buff/dominance calculations.
CREATE OR REPLACE FUNCTION finalize_run(
  p_user_id UUID,
  p_start_time TIMESTAMPTZ,
  p_end_time TIMESTAMPTZ,
  p_distance_km DOUBLE PRECISION,
  p_duration_seconds INTEGER,
  p_hex_path TEXT[],
  p_buff_multiplier INTEGER DEFAULT 1,
  p_cv DOUBLE PRECISION DEFAULT NULL,
  p_client_points INTEGER DEFAULT 0,
  p_home_region_flips INTEGER DEFAULT 0,
  p_hex_parents TEXT[] DEFAULT NULL,
  p_district_hex TEXT DEFAULT NULL
)
RETURNS jsonb AS $$
DECLARE
  v_hex_id TEXT;
  v_team TEXT;
  v_points INTEGER;
  v_max_allowed_points INTEGER;
  v_flip_count INTEGER;
  v_current_flipped_at TIMESTAMPTZ;
  v_parent_hex TEXT;
  v_idx INTEGER;
BEGIN
  -- Get user's team
  SELECT team INTO v_team FROM users WHERE id = p_user_id;
  
  -- [SECURITY] Cap validation: client points cannot exceed hex_path_length × buff_multiplier
  v_max_allowed_points := COALESCE(array_length(p_hex_path, 1), 0) * p_buff_multiplier;
  v_points := LEAST(p_client_points, v_max_allowed_points);
  v_flip_count := CASE WHEN p_buff_multiplier > 0 THEN v_points / p_buff_multiplier ELSE 0 END;
  
  IF p_client_points > v_max_allowed_points THEN
    RAISE WARNING 'Client claimed % points but max allowed is %. Capped.', p_client_points, v_max_allowed_points;
  END IF;
  
  -- Update live `hexes` table for buff/dominance calculations (NOT for flip points)
  -- hex_snapshot is immutable until midnight build
  IF p_hex_path IS NOT NULL AND array_length(p_hex_path, 1) > 0 THEN
    v_idx := 1;
    FOREACH v_hex_id IN ARRAY p_hex_path LOOP
      -- Get parent hex from provided array or calculate
      v_parent_hex := NULL;
      IF p_hex_parents IS NOT NULL AND v_idx <= array_length(p_hex_parents, 1) THEN
        v_parent_hex := p_hex_parents[v_idx];
      END IF;

      SELECT last_flipped_at INTO v_current_flipped_at FROM public.hexes WHERE id = v_hex_id;
      
      IF v_current_flipped_at IS NULL OR p_end_time > v_current_flipped_at THEN
        INSERT INTO public.hexes (id, last_runner_team, last_flipped_at, parent_hex)
        VALUES (v_hex_id, v_team, p_end_time, v_parent_hex)
        ON CONFLICT (id) DO UPDATE
        SET last_runner_team = v_team,
            last_flipped_at = p_end_time,
            parent_hex = COALESCE(v_parent_hex, hexes.parent_hex)
        WHERE hexes.last_flipped_at IS NULL OR hexes.last_flipped_at < p_end_time;
      END IF;
      v_idx := v_idx + 1;
    END LOOP;
  END IF;
  
  -- Award client-calculated points (cap-validated)
  UPDATE users SET 
    season_points = season_points + v_points,
    home_hex_start = CASE WHEN array_length(p_hex_path, 1) > 0 THEN p_hex_path[1] ELSE home_hex_start END,
    home_hex_end = CASE WHEN array_length(p_hex_path, 1) > 0 THEN p_hex_path[array_length(p_hex_path, 1)] ELSE home_hex_end END,
    district_hex = COALESCE(p_district_hex, district_hex),
    total_distance_km = total_distance_km + p_distance_km,
    total_runs = total_runs + 1,
    avg_pace_min_per_km = CASE 
      WHEN p_distance_km > 0 THEN 
        (COALESCE(avg_pace_min_per_km, 0) * total_runs + (p_duration_seconds / 60.0) / p_distance_km) / (total_runs + 1)
      ELSE avg_pace_min_per_km 
    END,
    avg_cv = CASE 
      WHEN p_cv IS NOT NULL THEN 
        (COALESCE(avg_cv, 0) * cv_run_count + p_cv) / (cv_run_count + 1)
      ELSE avg_cv 
    END,
    cv_run_count = CASE WHEN p_cv IS NOT NULL THEN cv_run_count + 1 ELSE cv_run_count END
  WHERE id = p_user_id;
  
  -- Insert lightweight run history (PRESERVED across seasons)
  INSERT INTO run_history (
    user_id, run_date, start_time, end_time,
    distance_km, duration_seconds, avg_pace_min_per_km,
    flip_count, flip_points, team_at_run, cv
  ) VALUES (
    p_user_id, (p_end_time AT TIME ZONE 'Etc/GMT-2')::DATE, p_start_time, p_end_time,
    p_distance_km, p_duration_seconds,
    CASE WHEN p_distance_km > 0 THEN (p_duration_seconds / 60.0) / p_distance_km ELSE NULL END,
    v_flip_count, v_points, v_team, p_cv
  );
  
  -- Return summary
  RETURN jsonb_build_object(
    'flips', v_flip_count,
    'multiplier', p_buff_multiplier,
    'points_earned', v_points,
    'server_validated', true
  );
END;
$$ LANGUAGE plpgsql;
```

**Design Principles:**
- `hex_snapshot`: Daily frozen hex state — basis for all flip point calculations. Immutable during the day.
- `hexes`: Live hex state for buff/dominance calculations. Updated by `finalize_run()`. NOT used for flip counting.
- `users`: Aggregate stats updated incrementally via `finalize_run()`.
- `runs`: Heavy data with `hex_path` (H3 IDs) → **DELETED on season reset**. Used at midnight to build next snapshot.
- `run_history`: Lightweight stats (distance, time, flips, cv) → **PRESERVED across seasons**.
- `daily_buff_stats`: Team-based buff multipliers (District Leader, Province Range) calculated daily at midnight GMT+2.
- **Snapshot-based flip counting**: Client counts flips against downloaded snapshot, server cap-validates only.
- **No daily flip limit**: Same hex can be flipped multiple times per day.
- **Multiplier**: Team-based buff via `calculate_daily_buffs()` at midnight GMT+2.
- **Sync**: No real-time — all hex data uploaded via `finalize_run()` at run completion.
- All security handled via RLS — **no separate backend API server needed**.

---

## D. Two Data Domains

All app data belongs to exactly one of two domains. **Never mix them.**

### Rule 1 — Running History = Client-side (cross-season, never reset)

- ALL TIME stats computed from local SQLite `runs` table
- Survives season resets (The Void) — personal running history is permanent
- Source: `allRuns.fold()` in `run_history_screen.dart` (synchronous from `runProvider`)
- Also available: `LocalStorage.getAllTimeStats()` (async, for non-UI contexts)
- Period stats (DAY/WEEK/MONTH/YEAR) also from local SQLite `runs` table

| Data | Source | Used By |
|------|--------|---------|
| ALL TIME distance, pace, stability, run count | `allRuns.fold()` from SQLite | RunHistoryScreen ALL TIME panel |
| ALL TIME flip points | `allRuns.fold((sum, run) => sum + run.flipPoints)` | RunHistoryScreen ALL TIME panel |
| Period stats (DAY/WEEK/MONTH/YEAR) | `statsRuns.fold()` from SQLite | RunHistoryScreen period panel |
| Run records | Local SQLite `runs` table | RunHistoryScreen list/calendar |

### Rule 2 — Hexes + TeamScreen + Leaderboard = Server-side (season-based, reset each season)

- Downloaded on app launch / OnResume via prefetch
- Created by server at midnight GMT+2 from all runners' uploaded data
- **NEVER changes from running** — frozen until next prefetch
- **Always anchored to home hex** — `PrefetchService` downloads using `homeHex`/`homeHexAll` (never GPS)

| Data | Source | Used By |
|------|--------|---------|
| Hex map (base layer) | `hex_snapshot` table | MapScreen |
| Leaderboard rankings + season record | `get_leaderboard` RPC → `season_leaderboard_snapshot` (NOT live `users`) | LeaderboardScreen |
| Team rankings / dominance | `get_team_rankings` / `get_hex_dominance` RPC | TeamScreen |
| Buff multiplier | `get_user_buff` RPC (yesterday's data) | BuffService (frozen at run start) |

### Domain Assignment Table

| Screen/Widget | Domain | Data Source |
|--------------|--------|-------------|
| Header FlipPoints | Live (hybrid) | `PointsService.totalSeasonPoints` |
| Run History ALL TIME | **Client-side** | Local SQLite `allRuns.fold()` — NOT `UserModel` server fields |
| Run History period stats | Client-side | Local SQLite runs (run-level granularity) |
| TeamScreen | Server (season) | Server RPCs only (home hex anchored) |
| LeaderboardScreen | Server (season) | `season_leaderboard_snapshot` via `get_leaderboard` RPC (NOT live `users` or `currentUser`) |
| LeaderboardScreen Season Record | Server (season) | Snapshot `LeaderboardEntry` (NOT live `currentUser`) |
| MapScreen display | Server + GPS | GPS hex for camera/territory when outside province; home hex otherwise |
| Hex Map | Server + Client overlay | `hex_snapshot` + own local flips |

**Domain Rules:**
1. `PointsService.totalSeasonPoints` is the ONLY hybrid value (server + local unsynced)
2. ALL TIME stats use local SQLite `runs` table — **NOT server `UserModel` aggregate fields**
3. Period stats (DAY/WEEK/MONTH/YEAR) use local SQLite runs (run-level granularity)
4. TeamScreen and LeaderboardScreen use ONLY server (season) domain — never compute from local runs
5. Server processes all runners' uploads at midnight to create next day's snapshot
6. LeaderboardScreen Season Record stats come from snapshot `LeaderboardEntry`, NOT live `currentUser`
7. `get_leaderboard` RPC reads from `season_leaderboard_snapshot` table, NOT from live `users` table
8. Snapshot downloads always use **home hex** — MapScreen uses **GPS hex** for display only when outside province
9. `UserModel` aggregate fields (`totalDistanceKm`, `avgPaceMinPerKm`, `avgCv`, `totalRuns`) exist on server but are NOT the source of truth for Running History display

### Location Domain Separation (Home vs GPS)

Server data and map display use different location anchors. This prevents server data from changing when the user travels.

| Concern | Location Anchor | Implementation |
|---------|----------------|----------------|
| Hex snapshot download | **Home hex** | `PrefetchService._homeHexAll` in `_downloadHexData()` |
| Leaderboard filtering | **Home hex** | `LeaderboardProvider.filterByScope()` reads `_prefetchService.homeHex` |
| TeamScreen territory/city | **Home hex** | `PrefetchService().homeHexCity` / `homeHex` |
| Season register location | **Home hex** | `PrefetchService().homeHex` |
| MapScreen camera centering | **GPS hex** (outside province) | `PrefetchService().gpsHex` via `isOutsideHomeProvince` |
| MapScreen territory overlay | **GPS hex** (outside province) | `_TeamStatsOverlay` uses `gpsHex` for display hex |
| HexagonMap anchor hex | **GPS hex** (outside province) | `_updateHexagons()` anchors to `gpsHex` when outside |
| Hex capture | **Disabled** outside province | `_OutsideProvinceBanner` on MapScreen |

**PrefetchService getters** (no `activeHex*` — removed to prevent domain conflation):
- `homeHex`, `homeHexCity`, `homeHexAll` — registered home location (server data anchor)
- `gpsHex`, `getGpsHexAtScope()` — current GPS position (map display only)
- `isOutsideHomeProvince` — GPS province ≠ home province

**Outside-province UX flow:**
1. MapScreen shows `_OutsideProvinceBanner` (glassmorphism card) directing user to Profile
2. ProfileScreen `_LocationCard` shows both registered home and GPS locations
3. "UPDATE TO CURRENT" button triggers FROM→TO confirmation dialog with buff reset warning
4. After update: all screens realign to new home location, banner disappears

### Data Flow Summary

```
[Client Prefetch — App Launch / OnResume]
  Download hex_snapshot WHERE snapshot_date = today (yesterday's midnight result)
  Download leaderboard, team rankings, buff multiplier, user aggregates
  Apply local overlay: user's own today's flips (from local SQLite)
  Map shows: snapshot + own local flips (other users' today activity invisible)

[During Run - Local Only]
  Runner GPS → Client validates → Local hex_path list
  Flip counted against snapshot + local overlay (NOT live server state)
  flip_points = total_flips × buff_multiplier (frozen at run start)
  Header FlipPoints updates live: PointsService.addRunPoints()
  NO server communication (battery + cost optimization)

[Run Completion - "The Final Sync"]
  Client uploads: { startTime, endTime, distanceKm, hex_path[], flip_points, buff_multiplier, cv }
  Server RPC: finalize_run() →
    → Cap validate: flip_points ≤ len(hex_path) × buff_multiplier
    → Award capped points: season_points += flip_points
    → Update user aggregates: total_distance_km, avg_pace, avg_cv, total_runs
    → Update live `hexes` table (for buff/dominance, NOT for flip counting)
    → INSERT INTO run_history (lightweight stats, preserved)
    → hex_snapshot NOT modified (immutable until midnight)
  PointsService.onRunSynced() transfers local unsynced → server baseline

[Daily Maintenance — pg_cron (midnight GMT+2)]
  build_daily_hex_snapshot() →
    → Start from yesterday's hex_snapshot
    → Apply all today's runs (end_time within today GMT+2)
    → Conflict: "last run end-time wins" hex color
    → Write to hex_snapshot with snapshot_date = tomorrow
  calculate_daily_buffs() →
    → Calculate team-based buffs for all active users
    → Uses live `hexes` table for dominance data
    → INSERT INTO daily_buff_stats

[D-Day - Reset Path]
  TRUNCATE hexes, hex_snapshot, daily_buff_stats (instant)
  UPDATE users (reset points/team/aggregates)
  DROP runs partitions (heavy data, instant disk reclaim)
  run_history PRESERVED (per-run stats)
  daily_stats PRESERVED (aggregated stats)
```

---

## E. Repository Pattern

### E.1 3-Layer Architecture

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

Screens → Providers → Repositories (Single Source of Truth)
                    ↘ Services (business logic)

Repositories are singletons accessed via `Repository()`.

### E.2 Data Ownership

| Data Type | Owner (State) | Persistence | Mutated By |
|-----------|--------------|-------------|------------|
| User Profile | `UserRepository` | `local_user.json` / Supabase `profiles` | `AppStateProvider`, `AuthService` |
| Hex Colors | `HexRepository` | LRU cache (max 4000) / Supabase `hexes` | `PrefetchService`, `RunProvider` (via capture) |
| Run History | `RunProvider` | SQLite `runs`, `routes`, `laps` | `RunTracker` (via `RunProvider.stopRun()`) |
| Leaderboard | `LeaderboardRepository` | SQLite `leaderboard_cache` | `LeaderboardProvider`, `PrefetchService` |
| Points | `PointsService` | `UserRepository` / SQLite `runs` | `RunProvider` (during run), `appLaunchSync` |
| Game Config | `RemoteConfigService` | `config_cache.json` / Supabase `app_config` | `RemoteConfigService.initialize()` |
| Ads | `AdService` | Google AdMob (BannerAd on MapScreen) | `AdService().initialize()` in main.dart |

### E.3 Provider → Repository Delegation

```
AppStateProvider.currentUser  --> UserRepository.currentUser
HexDataProvider.getCachedHex  --> HexRepository.getHex
LeaderboardProvider.entries   --> LeaderboardRepository.entries
```

```dart
class LeaderboardNotifier extends Notifier<LeaderboardState> {
  @override
  LeaderboardState build() => const LeaderboardState();

  // Delegate to repository
  List<LeaderboardEntry> get entries => LeaderboardRepository().entries;

  Future<void> fetchLeaderboard() async {
    final data = await SupabaseService().getLeaderboard();
    LeaderboardRepository().loadEntries(data);  // Store in repository
    state = state.copyWith(entries: entries);
  }
}
```

### E.4 RunProvider: Multi-Service Coordinator

`RunProvider` coordinates the most complex data flow in the app:

```
LocationService (GPS 0.5Hz)
    -> RunTracker (distance, hex capture, lap tracking, checkpoint save)
        -> HexDataProvider (capture signals)
    -> RunProvider (Run model, timer, UI state)
        -> RunState.liveLocation (every GPS point, accepted or rejected)
        -> RunState.liveHeading (GPS heading, filters invalid: null/≤0)
        -> PointsService (adds points via BuffService multiplier)
        -> LocalStorage (saves runs + laps + route on completion)
        -> SupabaseService.finalizeRun() ("The Final Sync")
            -> SyncRetryService (retry on failure: launch, OnResume, next run)
    RunningScreen reads:
        -> runProvider.liveLocation → RouteMap.liveLocation (camera follow)
        -> runProvider.liveHeading → RouteMap.liveHeading (camera bearing)
        -> runProvider.routeVersion → RouteMap.routeVersion (route updates)

    RouteMap navigation camera:
        -> SmoothCameraController (60fps, 1800ms animation duration)
        -> Primary bearing: GPS heading (liveHeading)
        -> Fallback bearing: route-calculated (last 5 points, min 3m distance)
        -> Camera follows liveLocation even for rejected GPS points
        -> Keep-latest pattern: _pendingRouteUpdate flag prevents dropped updates
```

### E.5 Points Hybrid Model

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

### E.6 OnResume Data Refresh

When app returns to foreground, `AppLifecycleManager` triggers (throttled 30s):
- Hex map data refresh (`PrefetchService` delta sync)
- Leaderboard refresh
- Retry failed syncs (`SyncRetryService`)
- Buff multiplier refresh (`BuffService`)
- Today's points baseline refresh (`appLaunchSync` + `PointsService`)

Skipped during active runs (including during stopRun's Final Sync via `_isStopping` flag).

---

## F. Local Storage — SQLite v15

### F.1 Tables

| Table | Purpose | Key Columns |
|-------|---------|-------------|
| `runs` | Run history (cold) | `id`, `distance_meters`, `durationSeconds`, `hexesColored`, `teamAtRun`, `hex_path`, `buff_multiplier`, `cv`, `sync_status`, `run_date` |
| `routes` | GPS path per run (local only, never uploaded) | `runId`, lat/lng stream |
| `laps` | Per-km segments (cold) | `runId`, `lapNumber`, `distanceMeters`, `durationSeconds` |
| `run_checkpoint` | Crash recovery (hot) | `run_id`, `captured_hex_ids` - saved on every hex flip |
| `prefetch_meta` | Persistent anchors | `home_hex`, daily territory snapshots (JSON) |
| `leaderboard_cache` | Offline leaderboard | `user_id`, `name`, `team`, `flip_points`, `total_distance_km`, `stability_score`, `home_hex` |

### F.2 Schema (v15)

```sql
-- runs table includes sync retry fields:
hex_path TEXT DEFAULT ''         -- Comma-separated hex IDs (for sync retry)
buff_multiplier INTEGER DEFAULT 1 -- Buff at run time (for sync retry)
cv REAL                          -- Coefficient of Variation (null for runs < 1km)
sync_status TEXT DEFAULT 'pending' -- 'pending', 'synced', 'failed'
flip_points INTEGER DEFAULT 0    -- Points earned (hexes × multiplier)
run_date TEXT                    -- GMT+2 date string for today's points

-- Laps table (per-km data for CV):
CREATE TABLE laps (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  runId TEXT NOT NULL,
  lapNumber INTEGER NOT NULL,
  distanceMeters REAL NOT NULL,
  durationSeconds REAL NOT NULL,
  startTimestampMs INTEGER NOT NULL,
  endTimestampMs INTEGER NOT NULL,
  FOREIGN KEY (runId) REFERENCES runs (id) ON DELETE CASCADE
);
CREATE INDEX idx_laps_runId ON laps(runId);

-- Run checkpoint table (crash recovery):
CREATE TABLE run_checkpoint (
  id TEXT PRIMARY KEY DEFAULT 'active',
  run_id TEXT NOT NULL,
  team_at_run TEXT NOT NULL,
  start_time INTEGER NOT NULL,
  distance_meters REAL NOT NULL,
  hexes_colored INTEGER NOT NULL DEFAULT 0,
  captured_hex_ids TEXT NOT NULL DEFAULT '',
  buff_multiplier INTEGER NOT NULL DEFAULT 1,
  last_updated INTEGER NOT NULL
);
```

### F.3 Data Temperature Classification

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

### F.4 Hot vs Cold Data Strategy

| Tier | Data | Storage | Retention | Reset Behavior |
|------|------|---------|-----------|----------------|
| **Hot** | Hex map, Active runs | Supabase (PostgreSQL) | Current season | TRUNCATE (instant) |
| **Seasonal** | `runs` (heavy with hex_path) | Supabase (PostgreSQL) | Current season | DROP PARTITION (instant) |
| **Permanent** | `run_history` (lightweight stats) | Supabase (PostgreSQL) | **Forever** | Never deleted |
| **Permanent** | `daily_stats` (aggregated daily) | Supabase (PostgreSQL) | **Forever** | Never deleted |
| **Cold** | Raw GPS paths | Local SQLite only (`routes`) | Device lifetime | Never uploaded to server (90%+ server storage savings) |

> **Key Design**: Separate `runs` (heavy, deleted) from `run_history` (light, preserved).
> Raw GPS coordinates are stored locally only (SQLite `routes` table for route display). Only `hex_path` (H3 IDs) is uploaded to server in `runs`.

---

## G. Serialization

### G.1 Serialization Formats per Model

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

### G.2 Consistent Naming Pattern

- `fromRow()` / `toRow()` — Supabase PostgreSQL (snake_case keys)
- `fromMap()` / `toMap()` — SQLite local storage (mixed case keys)
- `fromJson()` / `toJson()` — Local file persistence (camelCase keys)

### G.3 LeaderboardEntry Delegation Pattern

`LeaderboardEntry` wraps `UserModel` + `rank` via delegation (9 duplicated fields eliminated):

```dart
class LeaderboardEntry {
  final UserModel user;
  final int rank;

  // Delegate getters forward to user
  String get id => user.id;
  String get name => user.name;
  Team get team => user.team;
  String get avatar => user.avatar;
  int get seasonPoints => user.seasonPoints;
  double get totalDistanceKm => user.totalDistanceKm;
  double? get avgPaceMinPerKm => user.avgPaceMinPerKm;
  double? get avgCv => user.avgCv;
  String? get homeHex => user.homeHex;
  int? get stabilityScore => user.stabilityScore;

  // Convenience factory
  factory LeaderboardEntry.create(UserModel user, int rank) => LeaderboardEntry(user: user, rank: rank);
}
```

### G.4 DailyRunningStat Computed Pace

`avgPaceMinPerKm` is a computed getter (not stored) — derived from `totalDistanceKm` and `totalDurationSeconds`:

```dart
double get avgPaceMinPerKm {
  if (totalDistanceKm <= 0 || totalDurationSeconds <= 0) return 0;
  return (totalDurationSeconds / 60.0) / totalDistanceKm;
}
```

---

## H. Tech Stack

### H.1 Why Supabase over Firebase

| Criterion | Firebase (Firestore) | Supabase (PostgreSQL) | Winner |
|-----------|---------------------|----------------------|--------|
| **Data Model** | NoSQL (Document) | Relational (SQL) | Supabase — user/team/season relationships require JOINs |
| **Query Complexity** | Limited (no JOINs, no aggregation) | Full SQL (JOIN, GROUP BY, SUM, Window functions) | Supabase — leaderboard & multiplier calculations |
| **Cost Model** | Per-read/write operation | Instance-based (flat rate) | Supabase — no per-operation billing explosion at scale |
| **Mass Deletion (D-Day)** | Per-document write cost ($0.18/1M deletes) | TRUNCATE/DROP = $0, instant | Supabase — critical for 40-day reset |
| **Real-time** | Firestore listeners | Supabase Realtime (WebSocket) | Tie |
| **Security** | Firebase Rules (custom DSL) | Row Level Security (SQL policies) | Supabase — standard SQL, no custom language |
| **Backend API** | Requires Cloud Functions for complex logic | RLS + Edge Functions (optional) | Supabase — no separate API server needed |
| **Vendor Lock-in** | Google-proprietary | Open-source (PostgreSQL) | Supabase — can self-host if needed |
| **Scaling** | Auto-scales (but cost scales too) | Predictable instance pricing | Supabase — budget-friendly at scale |

**Decision**: **Supabase (PostgreSQL)** as primary backend.

### H.2 Architecture Overview (Serverless)

```
┌─────────────────────────────────────────────────────┐
│                   Flutter Client                      │
│  ┌──────────┐  ┌──────────┐  ┌───────────────────┐  │
│  │ Provider  │  │ SQLite   │  │ Supabase Client   │  │
│  │ (State)   │  │ (Offline)│  │ (Auth + DB)       │  │
│  └──────────┘  └──────────┘  └───────────────────┘  │
└─────────────────────────┬───────────────────────────┘
                          │
              ┌───────────┴───────────┐
              │   Supabase Platform    │
              │  ┌─────────────────┐  │
              │  │  PostgreSQL DB   │  │
              │  │  (pg_partman)    │  │
              │  ├─────────────────┤  │
              │  │  Supabase Auth   │  │
              │  ├─────────────────┤  │
              │  │  Storage (S3)    │  │
              │  │  (Cold: GPS)     │  │
              │  ├─────────────────┤  │
              │  │  Edge Functions  │  │
              │  │  (D-Day reset)   │  │
              │  └─────────────────┘  │
              └───────────────────────┘
```

**Key Serverless Properties:**
- No backend API server to maintain
- RLS handles all authorization at DB level
- Edge Functions only for scheduled tasks (D-Day reset, partition management, daily multiplier calculation)
- **NO Realtime/WebSocket** — all data synced via REST on app launch and run completion
- Supabase Storage for cold GPS data (replaces AWS S3)

### H.3 Key Package Dependencies

```yaml
# Core
flutter: sdk
flutter_riverpod: ^2.6.1       # Riverpod 3.0 state management
hooks_riverpod: ^2.6.1         # Riverpod + Flutter Hooks integration
go_router: ^14.0.0             # Declarative routing

# Location & Maps
geolocator: ^13.0.2
mapbox_maps_flutter: ^2.3.0
latlong2: ^0.9.0
h3_flutter: ^0.7.1

# Supabase (Auth + Database + Realtime + Storage)
supabase_flutter: ^2.0.0

# Local Storage
sqflite: ^2.3.3+2
path_provider: ^2.1.4

# Sensors (Anti-spoofing)
sensors_plus: ^latest          # Accelerometer validation

# Network
connectivity_plus: ^6.1.0      # Network connectivity check before sync

# Ads
google_mobile_ads: ^5.3.0      # Google AdMob banner ads

# UI
google_fonts: ^6.2.1
animated_text_kit: ^4.2.2
shimmer: ^3.0.0
```

| Package | Purpose |
|---------|---------|
| `flutter_riverpod` | State management (Riverpod 3.0) |
| `hooks_riverpod` | Riverpod + Flutter Hooks integration |
| `go_router` | Declarative routing |
| `geolocator` | GPS location tracking |
| `mapbox_maps_flutter` | Map rendering |
| `h3_flutter` | Hexagonal grid system |
| `supabase_flutter` | Backend (Auth + DB + Storage) |
| `sqflite` | Local SQLite storage |
| `sensors_plus` | Accelerometer (anti-spoofing) |
| `connectivity_plus` | Network connectivity check before sync |
| `google_mobile_ads` | Google AdMob banner ads |

### H.4 Directory Structure

```
lib/
├── main.dart                    # App entry point, ProviderScope setup
├── app/
│   ├── app.dart                 # Root app widget
│   ├── routes.dart              # go_router route definitions
│   ├── home_screen.dart         # Navigation hub + AppBar (FlipPoints)
│   ├── theme.dart               # Theme re-export
│   └── neon_theme.dart          # Neon accent colors (used by route_map)
├── features/
│   ├── auth/
│   │   ├── screens/             # login, profile_register, season_register, team_selection
│   │   ├── providers/           # app_state (Notifier), app_init (AsyncNotifier)
│   │   └── services/            # auth_service
│   ├── run/
│   │   ├── screens/             # running_screen
│   │   ├── providers/           # run_provider (Notifier)
│   │   └── services/            # run_tracker, gps_validator, accelerometer, location, running_score, lap, voice_announcement
│   ├── map/
│   │   ├── screens/             # map_screen
│   │   ├── providers/           # hex_data_provider (Notifier)
│   │   └── widgets/             # hexagon_map, route_map, smooth_camera, glowing_marker
│   ├── leaderboard/
│   │   ├── screens/             # leaderboard_screen
│   │   └── providers/           # leaderboard_provider (Notifier)
│   ├── team/
│   │   ├── screens/             # team_screen, traitor_gate_screen
│   │   └── providers/           # team_stats (Notifier), buff (Notifier)
│   ├── profile/
│   │   └── screens/             # profile_screen
│   └── history/
│       ├── screens/             # run_history_screen
│       └── widgets/             # run_calendar
├── core/
│   ├── config/                  # h3, mapbox, supabase, auth configuration
│   ├── storage/
│   │   └── local_storage.dart   # SQLite v15 (runs, routes, laps, run_checkpoint)
│   ├── utils/                   # country, gmt2_date, lru_cache, route_optimizer
│   ├── widgets/                 # energy_hold_button, flip_points, season_countdown
│   ├── services/                # supabase, remote_config, config_cache, season, ad, lifecycle, sync_retry, points, buff, timezone, prefetch, hex, storage_service, local_storage_service
│   └── providers/               # infrastructure, user_repository, points
├── data/
│   ├── models/                  # team, user, hex, run, lap, location_point, app_config, team_stats
│   └── repositories/            # hex, leaderboard, user
└── theme/
    └── app_theme.dart           # Colors, typography, animations (re-exported via app/theme.dart)
```

### H.5 GPS Anti-Spoofing Architecture

| Validation | Threshold | Action |
|------------|-----------|--------|
| Max Speed | 25 km/h | Discard GPS point |
| Min GPS Accuracy | ≤ 50m | Discard GPS point |
| Accelerometer Correlation | Required in MVP | Flag session if no motion detected |
| Pace Threshold | < 8:00 min/km | Required to capture hexes |

**Moving Average Pace (Hex Capture):**
- Uses MOVING AVERAGE pace (last 20 sec) at hex entry — smooths GPS noise
- 20-sec window provides ~10 samples at 0.5Hz GPS polling for stable calculation
- `canCaptureHex` = `movingAvgPaceMinPerKm < 8.0`

**Accelerometer Platform Behavior:**

| Platform | Behavior |
|----------|----------|
| **Real device** | Accelerometer events validate movement |
| **iOS Simulator** | No hardware → graceful fallback to GPS-only |

When no accelerometer data is available (iOS Simulator, some Android devices, sensor errors), GPS points are allowed — anti-spoofing gracefully degrades to GPS-only validation.

---

## I. App Launch Data Flow

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
+--------v---+    +------v------+  +-----v---------+
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
+--v------+  +---v-----+  +-----v-----+
|MapScreen|  |RunScreen|  |Leaderboard|
|         |  |         |  |Screen     |
+---------+  +---------+  +-----------+
```
