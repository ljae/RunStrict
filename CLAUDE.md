# CLAUDE.md - RunStrict (The 40-Day Journey)

> Guidelines for AI coding agents working in this Flutter/Dart codebase.

## Project Overview

**RunStrict** is a location-based running game that gamifies territory control through hexagonal maps.

### Core Concept
- **Season**: Fixed **40 days**
- **Reset**: On D-Day, all territories and scores are deleted (The Void). Only personal history remains.
- **Teams**: Red (FLAME), Blue (WAVE), Purple (CHAOS - available anytime)

### Key Design
- Hex displays the color of the **last runner** who passed through - NO ownership system
- User location shown as a **person icon inside a hexagon** (team-colored)
- Privacy optimized: No timestamps or runner IDs stored in hexes
- Performance-optimized (no 3D rendering)
- Serverless: No backend API server (Supabase RLS + Edge Functions)
- **No Realtime/WebSocket**: All data synced on app launch, OnResume, and run completion ("The Final Sync")
- **Server verified**: Points calculated by client, validated by server (≤ hex_count × multiplier). **Accepted risk**: Client-authoritative scoring means a sophisticated attacker could forge hex paths. Full server-side GPS validation would require storing raw GPS traces, which conflicts with the privacy-first design. The cap validation (`flip_points ≤ hex_count × multiplier`) bounds the maximum damage.
- **Offline resilient**: Failed syncs retry automatically via `SyncRetryService` (on launch, OnResume, next run)
- **Crash recovery**: `run_checkpoint` table saves state on each hex flip (including serialized `config_snapshot`); recovered on next app launch

### Core Philosophy
| Surface Layer | Hidden Layer |
|--------------|--------------|
| Red vs Blue competition | Connection through rivalry |
| Territory capture | Mutual respect growth |
| Weekly battles | Long-term relationships |
| "Win at all costs" | "We ran together" |

**Tech Stack**: Flutter 3.10+, Dart, Riverpod 3.0 (state management), Mapbox, Supabase (PostgreSQL), H3 (hex grid)

### Riverpod 3.0 Coding Rules
- **MUST** follow all patterns and best practices defined in [`riverpod_rule.md`](./riverpod_rule.md)
- Use manual provider definitions (NO code generation / build_runner)
- Use `Notifier<T>` / `AsyncNotifier<T>` class-based providers (NOT legacy `StateNotifier` or function-based providers)
- Use unified `Ref` (no type parameters), `ConsumerWidget` / `ConsumerStatefulWidget` for widgets
- Always check `ref.mounted` after async ops in notifiers, `context.mounted` in widgets
- Use `ref.onDispose()` for resource cleanup (subscriptions, timers, cancel tokens)
- Use `ref.watch()` for reactive state, `ref.read()` for one-off actions
- Use `select()` for selective rebuilds to minimize unnecessary widget rebuilds
- Use exhaustive `switch` pattern matching on `AsyncValue` states

---

## Build & Run Commands

### Development
```bash
flutter pub get          # Install dependencies
flutter run              # Run on connected device/emulator
flutter run -d ios       # Run on iOS
flutter run -d android   # Run on Android
flutter run -d macos     # Run on macOS
```

### Build
```bash
flutter build ios
flutter build apk
flutter build web
flutter build macos
```

### Analysis & Testing
```bash
flutter analyze          # Run static analysis
dart format .            # Format code
flutter test             # Run all tests
flutter test --coverage  # Run with coverage
```

### GPS Simulation (iOS Simulator)
```bash
./simulate_run.sh        # Simulate a 2km run
./simulate_run_fast.sh   # Fast simulation
```

---

## Project Structure

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

---

## Data Models Reference

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

### User Model (Supabase: users table)
```dart
class UserModel {
  String id;
  String name;
  Team team;               // 'red' | 'blue' | 'purple'
  String avatar;           // Emoji avatar (legacy, not displayed)
  int seasonPoints;        // Preserved when defecting to Purple
  String? manifesto;       // 30-char declaration
  String sex;              // 'male' | 'female' | 'other'
  DateTime birthday;       // User birthday
  String? nationality;     // ISO country code (e.g., 'KR', 'US')
  String? homeHex;         // H3 index of run start location (self only)
  String? homeHexEnd;      // H3 index of run end location (visible to others)
  String? districtHex;     // Res 6 H3 parent hex, set by update_home_location()
  String? seasonHomeHex;   // Home hex for current season
  double totalDistanceKm;  // Running season aggregate
  double? avgPaceMinPerKm; // Weighted average pace
  double? avgCv;           // Average CV (from runs ≥ 1km)
  int totalRuns;           // Number of completed runs

  /// Stability score (100 - avgCv, clamped 0-100). Higher = better.
  int? get stabilityScore => avgCv == null ? null : (100 - avgCv!).round().clamp(0, 100);
}
```
**Note**: Aggregate fields updated incrementally via `finalize_run()` RPC.
**Home Hex**: Asymmetric visibility - `homeHex` for self, `homeHexEnd` for others.
**Profile**: No avatar display. Profile shows manifesto (30 chars), sex, birthday, nationality (server-persisted).

### Hex Model (Supabase: hexes table)
```dart
class HexModel {
  String id;              // H3 hex index (resolution 8)
  LatLng center;
  Team? lastRunnerTeam;   // null = neutral
  DateTime? lastFlippedAt; // Run's endTime when hex was flipped (conflict resolution)
}
```
**Important**: Minimal timestamp for fairness (last_flipped_at), no runner IDs - privacy optimized.
**Delta Sync Conflict Resolution**: `HexRepository.mergeFromServer()` skips server data older than local `lastFlippedAt` (newer local wins).

### DailyRunningStat (Supabase: daily_stats table)
```dart
class DailyRunningStat {
  String userId;
  String dateKey;         // 'YYYY-MM-DD'
  double totalDistanceKm;
  int totalDurationSeconds;
  double avgPaceMinPerKm; // min/km (e.g., 6.0 = 6:00)
  int flipCount;
}
```

### LapModel (Local SQLite: laps table)
```dart
/// Per-km lap data for CV calculation
class LapModel {
  int lapNumber;           // which lap (1, 2, 3...)
  double distanceMeters;   // should be 1000.0 for complete laps
  double durationSeconds;  // time to complete this lap
  int startTimestampMs;
  int endTimestampMs;

  double get avgPaceSecPerKm => durationSeconds / (distanceMeters / 1000);
}
```

### RunSummary (Supabase: runs table)
```dart
class RunSummary {
  String id;
  DateTime endTime;        // Used for conflict resolution
  double distanceKm;
  int durationSeconds;
  double avgPaceMinPerKm;
  int hexesColored;        // Flip count
  Team teamAtRun;
  List<String> hexPath;    // H3 hex IDs passed (route shape)
  double? cv;              // Coefficient of Variation (null for runs < 1km)

  /// Stability score (100 - CV, clamped 0-100). Higher = better.
  int? get stabilityScore => cv == null ? null : (100 - cv!).round().clamp(0, 100);
}
```
**SQLite Storage**: `Run.toMap()` includes `hex_path` (comma-separated) and `buff_multiplier` for offline sync retry.

---

## Game Mechanics

### Team-Based Buff System
Buff multipliers are calculated daily at midnight GMT+2 via Edge Function:

**RED FLAME:**
- **Elite** = Top 20% by yesterday's **Flip Points** (points with multiplier, NOT raw flip count) among RED runners in the same District
- **Common** = Bottom 80%

| Scenario | Elite (Top 20%) | Common |
|----------|-----------------|--------|
| Normal (no wins) | 2x | 1x |
| District win only | 3x | 1x |
| Province win only | 3x | 2x |
| District + Province | 4x | 2x |

**BLUE WAVE:**
| Scenario | Union |
|----------|-------|
| Normal (no wins) | 1x |
| District win only | 2x |
| Province win only | 2x |
| District + Province | 3x |

**PURPLE:** Participation Rate = 1x (<30%), 2x (30-59%), 3x (≥60%)

- **New users** = 1x (default until yesterday's data exists)
- Buff is **frozen** when run starts — no changes mid-run
- Fetched on app launch via `get_user_buff()` RPC
- Elite threshold stored in `daily_buff_stats.red_elite_threshold_points` (computed from `run_history.flip_points`)
- District scoping uses `users.district_hex` (Res 6 H3 parent, set by `finalize_run()`)

### Purple Team (The Protocol of Chaos)
- **Unlock**: Available **anytime** during season
- **Entry Cost**: Points are **PRESERVED** (not reset)
- **Eligibility**: Any Red/Blue user
- **Rule**: Irreversible - cannot return to Red/Blue for remainder of season

### Hex Capture Rules
- Must be running at valid **moving average pace (last 20 sec)** (< 8:00 min/km)
- 20-sec window provides ~10 samples at 0.5Hz GPS polling for stable calculation
- Speed must be < 25 km/h (anti-spoofing)
- GPS accuracy must be ≤ 50m
- GPS Polling: Fixed 0.5 Hz (every 2 seconds) for battery optimization
- Any color change = Flip (including neutral → team color)
- **NO daily flip limit** - different users can each flip the same hex independently (same user cannot re-flip own hex due to snapshot isolation)
- Conflict resolution: **Later run_endTime wins** (compared via last_flipped_at timestamp)
- Capturable hexes pulse (2s, 1.2x scale, glow)

### CV & Stability Score
CV (Coefficient of Variation) measures pace consistency during runs.

```dart
// Calculated from 1km lap paces using sample stdev (n-1 denominator)
// CV = (stdev / mean) × 100
// Lower CV = more consistent pace

// LapService.calculateCV()
if (laps.isEmpty) return null;
if (laps.length == 1) return 0.0;  // No variance with single lap
// ... sample stdev calculation

// Stability Score = 100 - CV (clamped 0-100)
// Higher = better consistency
// Color coding: Green (≥80), Yellow (50-79), Red (<50)
```

**Lap Recording**: Automatic during runs, stored in local SQLite `laps` table.
**User Aggregate**: Average CV calculated incrementally via `finalize_run()` RPC.

### Flip Points Calculation (Snapshot-Based)
```
flip_points = flips_against_snapshot × buff_multiplier
```
Multiplier fetched on app launch via RPC: `get_user_buff()`

**Snapshot Model**: All users run against yesterday's midnight hex snapshot. Client counts flips against this snapshot + own local overlay (today's own runs). Server cap-validates only: `flip_points ≤ len(hex_path) × buff_multiplier`.

**Key Rules**:
- All users start each day with the same snapshot (deterministic)
- Other users' today activity is invisible until tomorrow's snapshot
- Cross-run same-day: user's own flips persist via local overlay (prevents double-counting)
- Different users can independently flip the same hex (both earn points from snapshot)
- Midnight-crossing runs: `end_time` determines which day's snapshot they affect

**Hybrid Points**: `PointsService` tracks `_serverTodayBaseline` + `_localUnsyncedToday`. On sync, `onRunSynced()` transfers points between baselines to prevent disappearing points.

### Two Data Domains (Critical Architecture Rule)

All app data belongs to exactly one of two domains. Mixing them causes bugs.

**Snapshot Domain** (Server → Local, read-only until next midnight):
- Hex map base, leaderboard rankings + season record, team stats, buff multiplier, user aggregates
- Downloaded on app launch/OnResume. NEVER changes from running.
- **Always anchored to home hex** — `PrefetchService` downloads hex snapshot and leaderboard using `homeHex`/`homeHexAll`
- Leaderboard: `get_leaderboard` reads from `season_leaderboard_snapshot` table (NOT live `users`)
- Season Record on LeaderboardScreen uses snapshot `LeaderboardEntry`, NOT live `currentUser`
- Used by: TeamScreen, LeaderboardScreen, ALL TIME stats (distance, pace, stability, run count)

**Live Domain** (Local creation → Upload):
- Header FlipPoints, run records, hex overlay (own runs only)
- Created/updated by running actions. Uploaded via Final Sync.
- Used by: FlipPointsWidget, RunHistoryScreen (recent runs, period stats)

**The Only Hybrid Value**: `PointsService.totalSeasonPoints` = server `season_points` + local unsynced today. Used for BOTH header FlipPoints AND ALL TIME points (ensures they match).

| Screen | Domain | Never compute from local SQLite |
|--------|--------|---------------------------------|
| TeamScreen | Snapshot only | All values from server RPCs (home hex anchored) |
| LeaderboardScreen | Snapshot only | Rankings AND Season Record from `season_leaderboard_snapshot` (NOT live `UserModel`) |
| MapScreen display | Snapshot + GPS | GPS hex for camera/territory when outside province; home hex otherwise |
| Run History ALL TIME | Snapshot + hybrid points | Use `UserModel` aggregates + `totalSeasonPoints` |
| Run History period stats | Live | Local SQLite runs (DAY/WEEK/MONTH/YEAR) |
| Header FlipPoints | Live (hybrid) | `PointsService.totalSeasonPoints` |

### Location Domain Separation (Home vs GPS)

Server data and map display use different location anchors:

| Concern | Location Anchor | Source |
|---------|----------------|--------|
| Hex snapshot download | **Home hex** | `PrefetchService.homeHex` / `homeHexAll` |
| Leaderboard filtering | **Home hex** | `LeaderboardProvider.filterByScope()` uses `homeHex` |
| TeamScreen territory | **Home hex** | `PrefetchService.homeHexCity` / `homeHex` |
| Season register | **Home hex** | `PrefetchService.homeHex` |
| MapScreen camera/territory | **GPS hex** (when outside province) | `PrefetchService.gpsHex` via `isOutsideHomeProvince` |
| HexagonMap anchor | **GPS hex** (when outside province) | `PrefetchService.gpsHex` via `isOutsideHomeProvince` |
| Hex capture | **Disabled** when outside province | Floating banner on MapScreen |

**PrefetchService getters**:
- `homeHex`, `homeHexCity`, `homeHexAll` — registered home location (server data anchor)
- `gpsHex`, `getGpsHexAtScope()` — current GPS position (map display only)
- `isOutsideHomeProvince` — true when GPS province ≠ home province

**MapScreen outside-province UX**: `_OutsideProvinceBanner` (glassmorphism floating card) appears when GPS is outside home province, directing user to update location in Profile.

**ProfileScreen dual-location**: `_LocationCard` shows both registered home and GPS location when outside province, with "UPDATE TO CURRENT" button and FROM→TO confirmation dialog.

---

## Code Style Guidelines

### Naming Conventions
| Type | Convention | Example |
|------|------------|---------|
| Files | `snake_case.dart` | `run_session.dart` |
| Classes | `UpperCamelCase` | `RunProvider` |
| Methods/Variables | `lowerCamelCase` | `startRun()` |
| Constants | `lowerCamelCase` | `const defaultZoom = 14.0` |
| Private members | Prefix with `_` | `_isTracking` |

### Import Order
1. Dart SDK (`dart:async`)
2. Flutter (`package:flutter/material.dart`)
3. Third-party packages (`package:hooks_riverpod/hooks_riverpod.dart`)
4. Internal imports (`../models/run_session.dart`)

### Widget Construction
- Use `const` constructors wherever possible
- Use `super.key` for widget keys
- Break large widgets into private helper widgets

### State Management (Riverpod 3.0)
- Use `Notifier<T>` / `AsyncNotifier<T>` class-based providers
- Use `NotifierProvider` / `AsyncNotifierProvider` declarations
- Use `ConsumerWidget` / `ConsumerStatefulWidget` for widgets
- Use `ref.watch()` for reactive state, `ref.read()` for one-off actions
- Follow patterns defined in `riverpod_rule.md`

### Error Handling
- Use `debugPrint()` for logging (not `print()`)
- Use targeted `try-catch` blocks in async methods

---

## Theme & Colors

All colors centralized in `lib/theme/app_theme.dart` (re-exported via `lib/app/theme.dart`).

```dart
// Team colors
AppTheme.athleticRed      // #FF003C - Red team
AppTheme.electricBlue     // #008DFF - Blue team
// Purple: #8B5CF6

// Hex Visual States
Neutral:    #2A3550 @ 0.15 opacity, Gray border (#6B7280), 1px
Blue:       Blue light @ 0.3 opacity, Blue border, 1.5px
Red:        Red light @ 0.3 opacity, Red border, 1.5px
Purple:     Purple light @ 0.3 opacity, Purple border, 1.5px
Capturable: Team color @ 0.3, pulsing (2s, 1.2x scale + glow)
Current:    Team color @ 0.5 opacity, 2.5px border
```

---

## Do's and Don'ts

### Do
- Use `const` constructors for immutable widgets
- Follow Riverpod Notifier pattern per `riverpod_rule.md`
- Use relative imports for internal files
- Run `flutter analyze` before committing
- Add `///` documentation for public APIs
- Use Supabase RPC for complex queries (multiplier, leaderboard)

### Don't
- Don't use `print()` - use `debugPrint()`
- Don't suppress lint rules without good reason
- Don't put business logic in widgets
- Don't hardcode colors - use `AppTheme`
- Don't use `ChangeNotifier`, `StateNotifier`, or the legacy `provider` package — Riverpod 3.0 (`flutter_riverpod` / `hooks_riverpod`) is the sole state management solution
- Don't create new state management patterns
- Don't store derived/calculated data in database
- Don't create backend API endpoints - use RLS

---

## Supabase Schema (Key Tables)

```sql
users            -- id, name, team, avatar, season_points, manifesto,
                 -- sex, birthday, nationality,
                 -- home_hex, home_hex_end, season_home_hex, district_hex,
                 -- total_distance_km, avg_pace_min_per_km,
                 -- avg_cv, total_runs, cv_run_count
hexes            -- id (H3 index), last_runner_team, last_flipped_at (live state for buff/dominance only)
hex_snapshot     -- hex_id, last_runner_team, snapshot_date, parent_hex (frozen daily snapshot for flip counting)
runs             -- id, user_id, team_at_run, distance_meters, hex_path[] (partitioned monthly)
run_history      -- id, user_id, run_date, distance_km, duration_seconds, flip_count, flip_points, cv
                 -- (preserved across seasons. flip_points = flip_count × buff, used for RED Elite threshold)
daily_stats      -- id, user_id, date_key, total_distance_km, flip_count (partitioned monthly)
daily_buff_stats -- stat_date, city_hex, dominant_team, red/blue/purple_hex_count,
                 -- red_elite_threshold_points (from run_history.flip_points), purple_participation_rate
season_leaderboard_snapshot -- user_id, season_number, rank, name, team, avatar, season_points,
                 -- total_distance_km, avg_pace_min_per_km, avg_cv, total_runs,
                 -- home_hex, home_hex_end, manifesto, nationality (frozen at midnight)
```

**Key RPC Functions:**
- `finalize_run(...)` → accept client flip_points with cap validation, update live hexes for buff/dominance, store district_hex
- `get_user_buff(user_id)` → get user's current buff multiplier
- `calculate_daily_buffs()` → daily cron to compute all buffs at midnight GMT+2
- `build_daily_hex_snapshot()` → daily cron to build tomorrow's hex snapshot at midnight GMT+2
- `get_hex_snapshot(parent_hex, snapshot_date)` → download hex snapshot for prefetch
- `get_leaderboard(limit)` → ranked users from `season_leaderboard_snapshot` (Snapshot Domain, frozen at midnight)
- `app_launch_sync(...)` → pre-patch data on launch with CV fields

---

## Dependencies (Key Packages)

| Package | Purpose |
|---------|---------|
| `flutter_riverpod` | State management (Riverpod 3.0) |
| `hooks_riverpod` | Riverpod + Flutter Hooks integration |
| `geolocator` | GPS location tracking |
| `mapbox_maps_flutter` | Map rendering |
| `h3_flutter` | Hexagonal grid system |
| `supabase_flutter` | Backend (Auth + DB + Storage) |
| `sqflite` | Local SQLite storage |
| `sensors_plus` | Accelerometer (anti-spoofing) |
| `connectivity_plus` | Network connectivity check before sync |
| `google_mobile_ads` | Google AdMob banner ads |
| `go_router` | Declarative routing |

---

## Mapbox Patterns

### Hex Grid Rendering (GeoJsonSource + FillLayer)

The `hexagon_map.dart` widget uses `GeoJsonSource` + `FillLayer` for atomic hex updates without visual flash.

**Problem**: `PolygonAnnotationManager.deleteAll()` + `createMulti()` causes visible flash when updating hexes.

**Solution**: Use `GeoJsonSource` with `FillLayer` for data-driven styling:

```dart
// Step 1: Create GeoJsonSource
await mapboxMap.style.addSource(
  GeoJsonSource(id: _hexSourceId, data: '{"type":"FeatureCollection","features":[]}'),
);

// Step 2: Create FillLayer with placeholder values
// NOTE: mapbox_maps_flutter FillLayer has strict typing - fillColor expects int?, not List
await mapboxMap.style.addLayer(
  FillLayer(
    id: _hexLayerId,
    sourceId: _hexSourceId,
    fillColor: Colors.grey.toARGB32(),  // placeholder
    fillOpacity: 0.3,
    fillOutlineColor: Colors.grey.toARGB32(),
    fillAntialias: true,
  ),
);

// Step 3: Apply data-driven expressions via setStyleLayerProperty
// This bypasses the strict typing limitation
await mapboxMap.style.setStyleLayerProperty(
  _hexLayerId, 'fill-color', ['to-color', ['get', 'fill-color']],
);
await mapboxMap.style.setStyleLayerProperty(
  _hexLayerId, 'fill-opacity', ['get', 'fill-opacity'],
);
await mapboxMap.style.setStyleLayerProperty(
  _hexLayerId, 'fill-outline-color', ['to-color', ['get', 'fill-outline-color']],
);
```

**GeoJSON Feature Properties**: Each hex feature includes styling properties:
```json
{
  "type": "Feature",
  "geometry": { "type": "Polygon", "coordinates": [...] },
  "properties": {
    "fill-color": "#FF003C",
    "fill-opacity": 0.3,
    "fill-outline-color": "#FF003C"
  }
}
```

**Why This Pattern**:
- Atomic updates: Single `updateGeoJSONSourceFeatures()` call updates all hexes
- No flash: Source data swap is instantaneous
- Data-driven: Per-feature colors read from GeoJSON properties
- Performance: GPU-accelerated fill rendering

### Scope Boundary Layers (Province + District)

The `hexagon_map.dart` widget renders geographic scope boundaries using two additional GeoJSON sources:

**Province Boundary** (`scope-boundary-source` / `scope-boundary-line`):
- **PROVINCE scope**: Merged outer boundary of all ~7 district (Res 6) hexes — irregular polygon, NOT a single hexagon
- **DISTRICT scope**: Single district hex boundary
- **ZONE scope**: Hidden (no boundary)
- Styling: white, 8px width, 15% opacity, 4px blur, solid

**District Boundaries** (`district-boundary-source` / `district-boundary-line`):
- **PROVINCE scope**: Individual dashed outlines for each ~7 district hex
- **DISTRICT/ZONE scope**: Hidden
- Styling: white, 3px width, 12% opacity, 2px blur, dashed [4,3]

**Merged Outer Boundary Algorithm** (`_computeMergedOuterBoundary`):
- Collects all directed edges from all district hex boundaries
- Removes shared internal edges (edges appearing in opposite directions cancel out)
- Chains remaining outer edges into a closed polygon loop
- Uses 7-decimal coordinate precision for edge matching (~1cm accuracy)

### Leaderboard Electric Manifesto

The `_ElectricManifesto` widget in `leaderboard_screen.dart` shows user manifestos with a flowing electric sign effect:
- `ShaderMask` + animated `LinearGradient` flowing left-to-right
- 3-second animation cycle, loops continuously
- Gradient between `Colors.white54` (dim) and team color (bright neon)
- Team-colored shadow glow effect
- Font: `GoogleFonts.sora()`, italic

---

## Remote Configuration System

All game constants (50+) are server-configurable via the `app_config` table in Supabase.

### Usage Pattern

```dart
// For values frozen during runs (use configSnapshot)
static double get maxSpeedMps =>
    RemoteConfigService().configSnapshot.gpsConfig.maxSpeedMps;

// For values that can change anytime (use config)
static int get maxCacheSize =>
    RemoteConfigService().config.hexConfig.maxCacheSize;
```

### Run Consistency

Config is frozen during active runs:
```dart
RemoteConfigService().freezeForRun();   // In startNewRun()
RemoteConfigService().unfreezeAfterRun(); // In stopRun()
```

### Configurable Constants

| Category | Examples |
|----------|----------|
| **Season** | `durationDays`, `serverTimezoneOffsetHours` |
| **GPS** | `maxSpeedMps`, `pollingRateHz`, `maxAccuracyMeters` |
| **Scoring** | `maxCapturePaceMinPerKm`, `minMovingAvgWindowSec` |
| **Hex** | `baseResolution`, `maxCacheSize` |
| **Timing** | `refreshThrottleSeconds`, `accelerometerSamplingPeriodMs` |

---

## OnResume Data Refresh

When app returns to foreground, `AppLifecycleManager` triggers:
- Hex map data refresh (PrefetchService)
- Leaderboard refresh
- Retry failed syncs (SyncRetryService)
- Buff multiplier refresh (BuffService)
- Today's points baseline refresh (appLaunchSync + PointsService)

Skipped during active runs. Throttled to max once per 30 seconds.

---

## Hex Data Architecture (Snapshot + Local Overlay)

**Single Source of Truth**: `HexRepository` (LRU cache) is the sole hex data store.
- `PrefetchService.getCachedHex()` delegates to `HexRepository().getHex()`
- `HexDataProvider.getHex()` reads directly from `HexRepository`
- No duplicate caches — PrefetchService downloads into HexRepository, does not maintain its own cache

---

## UI Conventions

### Geographic Scope Categories
The app uses three geographic scope levels. Code enum is `GeographicScope`:

| Scope | Enum Value | H3 Resolution | Description |
|-------|------------|---------------|-------------|
| **ZONE** | `zone` | 8 | Neighborhood (~461m) |
| **DISTRICT** | `district` | 6 | District (~3.2km) |
| **PROVINCE** | `province` | 4 | Metro/Regional (server-wide) |

**Note**: Legacy code references `city` (now `district`) and `all` (now `province`). All UI labels and documentation use zone/district/province.

### Stat Panel Display Order
All stat panels across screens use a consistent display order:
1. **Points** (primary/large, flip points)
2. **Distance** (secondary)
3. **Pace** (secondary)
4. **Rank or Stability** (secondary)

Applies to: TeamScreen, RunHistoryScreen (ALL TIME & period panels), LeaderboardScreen (season stats).

### Pace Format
Unified pace format across the entire app: `X'XX` (apostrophe separator, no trailing `"`).

```dart
// Standard pace formatting
String formatPace(double paceMinPerKm) {
  final min = paceMinPerKm.floor();
  final sec = ((paceMinPerKm - min) * 60).round();
  return "$min'${sec.toString().padLeft(2, '0')}";
}
// Examples: 5'30, 6'05, -'-- (for null/invalid)
```

### FlipPoints Header Widget
- Shows **season total points** (not today's points)
- Uses `FittedBox` to prevent overflow with large numbers (3+ digits)
- Airport departure board style flip animation for each digit

### Google AdMob Integration
- `AdService` singleton in `lib/core/services/ad_service.dart` manages AdMob SDK
- BannerAd displayed on MapScreen (all scope views: zone, district, province)
- Shows in both portrait and landscape orientations
- Test ad unit IDs used during development (replace with production IDs before release)
- Platform configs: iOS `GADApplicationIdentifier` in Info.plist, Android `APPLICATION_ID` in AndroidManifest.xml

### Landscape Layout
- MapScreen: Ad + zoom selector shown in landscape column layout
- LeaderboardScreen: All content (stats, toggle, navigation, rankings) in single `CustomScrollView` for landscape scrolling

**Snapshot Model**:
- **Base layer**: `hex_snapshot` table (frozen daily at midnight GMT+2). Downloaded on app launch/OnResume.
- **Local overlay**: User's own today's flips (stored in local SQLite, applied on top of snapshot)
- **Map display**: Snapshot + own local flips. Other users' today activity invisible until tomorrow.
- **Live `hexes` table**: Still updated by `finalize_run()` for buff/dominance calculations only. NOT used for flip counting.
- **Prefetch**: Downloads from `hex_snapshot` (not `hexes`). Delta sync uses `snapshot_date`.

---

## Accelerometer Anti-Spoofing

The `AccelerometerService` validates GPS movement against physical device motion.

| Platform | Behavior |
|----------|----------|
| **Real device** | Accelerometer events validate movement |
| **iOS Simulator** | No hardware → graceful fallback to GPS-only (5s warning logged) |
