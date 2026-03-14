# AGENTS.md - RunStrict (The 40-Day Journey)

> Guidelines for AI coding agents working in this Flutter/Dart codebase.

---

## Project Overview

**RunStrict** is a location-based running game that gamifies territory control through hexagonal maps.

### Core Concept
- **Season**: Fixed **40 days**; on D-Day all territories and scores are deleted (The Void)
- **Teams**: Red (FLAME), Blue (WAVE), Purple (CHAOS - available anytime)
- **Hex System**: Displays color of **last runner** — no ownership system
- **Buff System**: Team-based multipliers calculated daily (Red: Elite 2-4x / Common 1-2x, Blue: 1-3x, Purple: 1-3x)
- **Reset**: Only personal run history survives The Void

### Key Design Principles
- Privacy optimized: No timestamps or runner IDs stored in hexes
- User location shown as **person icon inside a hexagon** (team-colored)
- Performance-optimized (no 3D rendering)
- Serverless: No backend API server (Supabase RLS + Edge Functions)
- **No Realtime/WebSocket**: All data synced on app launch, OnResume, and run completion ("The Final Sync"). ALL completed runs are uploaded, regardless of flip count.
- **Server verified**: Points calculated by client, validated by server (≤ hex_count × multiplier). Accepted risk: client-authoritative scoring; cap validation bounds maximum damage.
- **Offline resilient**: Failed syncs retry automatically via `SyncRetryService` (on launch, OnResume, next run). 0-flip runs are now included in sync retries.
- **Crash recovery**: `run_checkpoint` table saves state on each hex flip (including serialized `config_snapshot`); recovered on next app launch

**Tech Stack**: Flutter 3.10+, Dart, Riverpod 3.0 (state management), Mapbox, Supabase (PostgreSQL), H3 (hex grid)

### Riverpod 3.0 Rules
**MUST** follow all patterns defined in [riverpod_rule.md](./riverpod_rule.md)
- Use manual provider definitions (NO code generation / build_runner)
- Use `Notifier<T>` / `AsyncNotifier<T>` class-based providers (NOT legacy `StateNotifier`)
- Use unified `Ref` (no type parameters), `ConsumerWidget` / `ConsumerStatefulWidget` for widgets
- Always check `ref.mounted` after async ops in notifiers, `context.mounted` in widgets
- Use `ref.onDispose()` for resource cleanup; `ref.watch()` for reactive state, `ref.read()` for one-off actions
- Use `select()` for selective rebuilds; exhaustive `switch` on `AsyncValue` states

---

## Build & Run Commands

```bash
# Development
flutter pub get          # Install dependencies
flutter run              # Run on connected device/emulator
flutter run -d ios       # Run on iOS
flutter run -d android   # Run on Android
flutter run -d macos     # Run on macOS

# Build
flutter build ios && flutter build apk && flutter build web && flutter build macos

# Analysis & Testing
flutter analyze          # Run static analysis (linter)
dart format .            # Format code
flutter test             # Run all tests
flutter test test/widget_test.dart        # Run single test file
flutter test --plain-name "App smoke test" # Run specific test
flutter test --coverage  # Run with coverage

# GPS Simulation (iOS Simulator)
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

## Code Style Guidelines

### Naming Conventions

| Type | Convention | Example |
|------|------------|---------|
| Files | `snake_case.dart` | `run_session.dart`, `hex_service.dart` |
| Classes | `UpperCamelCase` | `RunProvider`, `LocationService` |
| Methods/Variables | `lowerCamelCase` | `startRun()`, `distanceMeters` |
| Constants | `lowerCamelCase` | `const defaultZoom = 14.0` |
| Private members | Prefix with `_` | `_isTracking`, `_locationController` |
| Enums | `UpperCamelCase` | `enum Team { red, blue, purple }` |

### Import Order
1. Dart SDK (`dart:async`, `dart:io`)
2. Flutter (`package:flutter/material.dart`)
3. Third-party packages (`package:hooks_riverpod/hooks_riverpod.dart`)
4. Internal imports (relative paths `../models/run_session.dart`)

### Formatting
- Use trailing commas for multi-line parameter lists; `dart format .` before committing
- Max line length: 80 characters (Dart default)

### Widget Construction
```dart
class MyScreen extends StatelessWidget {
  const MyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        _HeaderSection(),
        _ContentSection(),
      ],
    );
  }
}

class _HeaderSection extends StatelessWidget {
  const _HeaderSection();  // Private widget, no key needed
}
```

### State Management (Riverpod 3.0)
```dart
class RunNotifier extends Notifier<RunState> {
  @override
  RunState build() => const RunState();

  Future<void> startRun() async {
    final locationService = ref.read(locationServiceProvider);
    // ... logic
    state = state.copyWith(activeRun: run);
  }
}

final runProvider = NotifierProvider<RunNotifier, RunState>(RunNotifier.new);
```

### Error Handling
```dart
Future<void> startTracking() async {
  try {
    await _locationService.startTracking();
  } on LocationPermissionException catch (e) {
    _setError(e.message);
    rethrow;
  } catch (e) {
    debugPrint('Unexpected error: $e');
    _setError('Failed to start tracking');
  }
}
```

### Models — fromRow/toRow Pattern
```dart
class UserModel {
  final String id;
  final String name;
  final Team team;
  final int seasonPoints;

  const UserModel({required this.id, required this.name, required this.team, this.seasonPoints = 0});

  UserModel copyWith({String? name, Team? team, int? seasonPoints}) => UserModel(
    id: id, name: name ?? this.name, team: team ?? this.team,
    seasonPoints: seasonPoints ?? this.seasonPoints,
  );

  factory UserModel.fromRow(Map<String, dynamic> row) => UserModel(
    id: row['id'] as String,
    name: row['name'] as String,
    team: Team.values.byName(row['team'] as String),
    seasonPoints: (row['season_points'] as num?)?.toInt() ?? 0,
  );

  Map<String, dynamic> toRow() => {'name': name, 'team': team.name, 'season_points': seasonPoints};
}
```

---

## Data Models Reference

### Team Enum
```dart
enum Team {
  red,    // Display: "FLAME" 🔥
  blue,   // Display: "WAVE" 🌊
  purple; // Display: "CHAOS" 💜

  String get displayName => switch (this) { red => 'FLAME', blue => 'WAVE', purple => 'CHAOS' };
}
```

### UserModel (Supabase: users table)
```dart
class UserModel {
  String id;
  String name;
  Team team;               // 'red' | 'blue' | 'purple'
  String avatar;           // Emoji avatar (legacy, not displayed)
  int seasonPoints;        // Preserved when defecting to Purple
  String? manifesto;       // 30-char declaration
  String sex;              // 'male' | 'female' | 'other'
  DateTime birthday;
  String? nationality;     // ISO country code (e.g., 'KR', 'US')
  String? homeHex;         // H3 index of run start location (self only)
  String? homeHexEnd;      // H3 index of run end location (visible to others)
  String? districtHex;     // Res 6 H3 parent hex, set by update_home_location()
  String? seasonHomeHex;   // Home hex for current season
  double totalDistanceKm;
  double? avgPaceMinPerKm;
  double? avgCv;           // Average CV (from runs ≥ 1km)
  int totalRuns;

  int? get stabilityScore => avgCv == null ? null : (100 - avgCv!).round().clamp(0, 100);
}
```
**Note**: Aggregate fields updated incrementally via `finalize_run()` RPC. `homeHex` is self-only; `homeHexEnd` visible to others.

### HexModel (Supabase: hexes table)
```dart
class HexModel {
  String id;              // H3 hex index (resolution 9)
  LatLng center;
  Team? lastRunnerTeam;   // null = neutral
  DateTime? lastFlippedAt; // Run's endTime when hex was flipped (conflict resolution)
  // parent_hex = Res 5 province (used for snapshot/delta download filtering)
}
```
**Delta Sync**: `HexRepository.mergeFromServer()` skips server data older than local `lastFlippedAt`.

### LapModel (Local SQLite: laps table)
```dart
class LapModel {
  int lapNumber;           // which lap (1, 2, 3...)
  double distanceMeters;   // 1000.0 for complete laps
  double durationSeconds;
  int startTimestampMs;
  int endTimestampMs;

  double get avgPaceSecPerKm => durationSeconds / (distanceMeters / 1000);
}
```

### Unified Run Model
The `Run` model (`lib/models/run.dart`) replaces `RunSession`, `RunSummary`, `RunHistoryModel`:
```dart
class Run {
  final String id;
  final DateTime startTime;
  DateTime? endTime;
  double distanceMeters;
  int hexesPassed;
  int hexesColored;

  double get distanceKm => distanceMeters / 1000;
  double get avgPaceMinPerKm => ...;
  int? get stabilityScore => cv != null ? (100 - cv!).round().clamp(0, 100) : null;
  int get flipPoints => (hexesColored * buffMultiplier).round();

  void addPoint(LocationPoint point) { ... }
  void recordFlip() { ... }
  void complete() { ... }

  Map<String, dynamic> toMap();    // SQLite (hex_path as comma-separated, buff_multiplier)
  Map<String, dynamic> toRow();    // Supabase
}
```

---

## Game Mechanics

### Team-Based Buff System
Calculated daily at midnight GMT+2 via Edge Function. Frozen at run start.

**RED FLAME** — Elite = Top 20% by yesterday's Flip Points among RED runners in same District:

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

**PURPLE**: Participation Rate = 1x (<30%), 2x (30-59%), 3x (≥60%) — no territory bonus
**New users** = 1x (default until yesterday's data exists)
- Elite threshold stored in `daily_buff_stats.red_elite_threshold_points` (from `run_history.flip_points`)
- District scoping uses `users.district_hex` (Res 6 H3 parent, set by `finalize_run()`)
- **Province Win** = the user's local **H3 Res-5 province** (`users.province_hex`, set by `finalize_run()` from `p_hex_parents[1]`). This matches exactly what the Territory section in TeamScreen displays. It does **NOT** mean server-wide global dominance.
- `daily_province_range_stats` keyed by `(stat_date, province_hex)` — one row per Res-5 province per day

### Purple Team (Protocol of Chaos)

| Property | Value |
|----------|-------|
| Availability | Anytime during season |
| Entry Name | "Traitor's Gate" |
| Entry Cost | Points **PRESERVED** (not reset) |
| Eligibility | Any Red/Blue user |
| Reversibility | **Irreversible** for remainder of season |

```dart
void defectToPurple() {
  // Points are PRESERVED - do NOT reset seasonPoints
  user = user.copyWith(team: Team.purple);
}
```

### Hex Capture Rules
```dart
// Must be running at valid pace to capture hex
// Uses MOVING AVERAGE pace (last 20 sec) at hex entry - smooths GPS noise
bool get canCaptureHex => movingAvgPaceMinPerKm < 8.0;
// Also: speed < 25 km/h AND GPS accuracy ≤ 50m
// GPS Polling: Fixed 0.5 Hz (every 2 seconds) for battery optimization

bool setRunnerColor(Team runnerTeam, DateTime runEndTime) {
  if (lastRunnerTeam == runnerTeam) return false;
  if (lastFlippedAt != null && runEndTime.isBefore(lastFlippedAt)) return false;
  lastRunnerTeam = runnerTeam;
  lastFlippedAt = runEndTime;
  return true; // Color changed (flip)
}
// NO daily flip limit — different users can each flip the same hex independently
// Same user cannot re-flip own hex on same day (snapshot isolation)
// Conflict resolution: Later run_endTime wins
```

### CV & Stability Score
```dart
// CV (Coefficient of Variation) measures pace consistency
// Calculated from 1km lap paces using sample stdev (n-1 denominator)
// CV = (stdev / mean) × 100  |  Lower CV = more consistent pace

static double? calculateCV(List<LapModel> laps) {
  if (laps.isEmpty) return null;
  if (laps.length == 1) return 0.0; // No variance with single lap
  // ... sample stdev calculation
}

// Stability Score = 100 - CV (clamped 0-100, higher = better)
// Color coding: Green (≥80), Yellow (50-79), Red (<50)
```

### Flip Points (Snapshot-Based)
```
flip_points = flips_against_snapshot × buff_multiplier
```
- All users run against yesterday's midnight hex snapshot (deterministic baseline)
- Client counts flips against snapshot + own local overlay (today's own runs)
- Server cap-validates only: `flip_points ≤ len(hex_path) × buff_multiplier`
- Other users' today activity invisible until tomorrow's snapshot
- Midnight-crossing runs: `end_time` determines which day's snapshot they affect
- **Hybrid Points**: `PointsService` tracks `_serverTodayBaseline` + `_localUnsyncedToday`; `onRunSynced()` transfers between baselines to prevent disappearing points

---

## Architecture Rules

### Two Data Domains (CRITICAL — Never Mix)

**Rule 1 — Running History = Client-side (cross-season, never reset):**
- ALL TIME stats computed from local SQLite `runs` table (`allRuns.fold()`)
- Survives season resets (The Void) — personal running history is permanent
- Includes: distance, pace, stability, run count, flip points
- Source of truth: `LocalStorage.getAllTimeStats()` or synchronous `allRuns.fold()` in UI
- Period stats (DAY/WEEK/MONTH/YEAR) also from local SQLite

**Rule 2 — Hexes + TeamScreen + Leaderboard = Server-side (season-based, reset each season):**
- Downloaded on app launch/OnResume via PrefetchService. NEVER changes from running.
- **Always anchored to home hex** — `PrefetchService` uses `homeHex`/`homeHexAll` (never GPS)
- Leaderboard: `get_leaderboard` reads from `season_leaderboard_snapshot` (NOT live `users`)
- Season Record on LeaderboardScreen uses snapshot `LeaderboardEntry`, NOT live `currentUser`
- Includes: hex map base, leaderboard rankings, team stats, buff multiplier

**Only hybrid value**: `PointsService.totalSeasonPoints` = server `season_points` + local unsynced. Used for header FlipPoints only.

| Screen | Domain | Rule |
|--------|--------|------|
| TeamScreen | Server (season) | Server RPCs only (home hex anchored) |
| LeaderboardScreen | Server (season) | `season_leaderboard_snapshot` via RPC (NOT live `users` or `currentUser`) |
| MapScreen display | Server + GPS | GPS hex for camera/territory when outside province |
| ALL TIME stats | **Client-side** | Local SQLite `runs` table (`allRuns.fold()`) — NOT `UserModel` server fields |
| Period stats | Client-side | Local SQLite runs (DAY/WEEK/MONTH/YEAR) |
| Header FlipPoints | Live (hybrid) | `PointsService.totalSeasonPoints` |

### Location Domain Separation (Home vs GPS)

| Concern | Location Anchor | Source |
|---------|----------------|--------|
| Hex snapshot download | **Home hex** | `PrefetchService.homeHex` / `homeHexAll` |
| Leaderboard filtering | **Home hex** | `LeaderboardProvider.filterByScope()` |
| TeamScreen territory | **Home hex** | `PrefetchService.homeHexCity` / `homeHex` |
| Season register | **Home hex** | `PrefetchService.homeHex` |
| MapScreen camera/territory | **GPS hex** (when outside province) | `PrefetchService.gpsHex` |
| HexagonMap anchor | **GPS hex** (when outside province) | `PrefetchService.gpsHex` |
| Hex capture | **Disabled** when outside province | Floating banner on MapScreen |

`PrefetchService` getters: `homeHex`/`homeHexCity`/`homeHexAll` (server anchor), `gpsHex`/`getGpsHexAtScope()` (map display), `isOutsideHomeProvince` (detection). No `activeHex*` getters (removed to prevent domain conflation).

**Outside-province UX**: `_OutsideProvinceBanner` (glassmorphism floating card) appears when GPS is outside home province. `ProfileScreen._LocationCard` shows both registered home and GPS location with "UPDATE TO CURRENT" button.

### OnResume Data Refresh
When app returns to foreground, `AppLifecycleManager` triggers:
- Hex map data refresh (PrefetchService), Leaderboard refresh
- Retry failed syncs (SyncRetryService), Buff multiplier refresh (BuffService)
- Today's points baseline refresh (appLaunchSync + PointsService)

Skipped during active runs (including stopRun via `_isStopping` flag). Throttled to max once per 30 seconds.

### Hex Data Architecture (Snapshot + Local Overlay)
`HexRepository` is the **single source of truth** for hex data (no duplicate caches):
- `PrefetchService.getCachedHex()` delegates to `HexRepository().getHex()`
- `HexDataProvider.getHex()` reads directly from `HexRepository`
- PrefetchService downloads from `hex_snapshot` table (NOT live `hexes`) into HexRepository
- **Local overlay**: User's own today's flips stored in SQLite, applied on top of snapshot
- **Live `hexes` table**: Updated by `finalize_run()` for buff/dominance only, NOT for flip counting
- **District scoping**: `users.district_hex` (Res 6 H3 parent) set by `finalize_run()`
- **Province scoping**: `users.province_hex` (Res 5) set by `finalize_run()` from `p_hex_parents[1]` (first hex's province parent). Used for buff province win — scoped to user's local Res-5 area, matching TeamScreen Territory display.
- **Hex parent_hex**: Res 5 province (for snapshot/delta download), NOT Res 6 district
- **Dominance query**: `get_hex_dominance(p_parent_hex)` filters by Res 5 province hex

### Repository Pattern
```
┌─────────────────────────────────────────────────────────────┐
│   Screens → Providers → Repositories (Single Source of Truth)│
│                      ↘ Services (business logic)             │
│   Repositories are singletons accessed via Repository()      │
└─────────────────────────────────────────────────────────────┘
```

| Repository | Purpose | Key Methods |
|------------|---------|-------------|
| `UserRepository()` | User data, season points | `setUser()`, `updateSeasonPoints()`, `saveToDisk()` |
| `HexRepository()` | Hex cache (LRU), delta sync | `getHex()`, `updateHexColor()`, `mergeFromServer()` |
| `LeaderboardRepository()` | Leaderboard entries | `loadEntries()`, `filterByScope()`, `filterByTeam()` |

**Provider Delegation Pattern:**
```dart
class LeaderboardNotifier extends Notifier<LeaderboardState> {
  @override
  LeaderboardState build() => const LeaderboardState();

  List<LeaderboardEntry> get entries => LeaderboardRepository().entries;

  Future<void> fetchLeaderboard() async {
    final data = await SupabaseService().getLeaderboard();
    LeaderboardRepository().loadEntries(data);  // Store in repository
    state = state.copyWith(entries: entries);
  }
}
```

### Hex Snapshot Prefetch
```dart
// Download today's snapshot for the user's area
final hexes = await supabase.getHexSnapshot(parentHex, snapshotDate: today);
HexRepository().bulkLoadFromServer(hexes);

// Apply local overlay: user's own today's flips from SQLite
final localFlips = await localStorage.getTodayFlips();
HexRepository().applyLocalOverlay(localFlips);
// Map shows: snapshot + own local flips. Other users invisible until tomorrow.
```

---

## Timezone Architecture

### The Two-Domain Rule (NEVER VIOLATE)

| Domain | Timezone | Dart Source |
|--------|----------|-------------|
| Running History (SQLite: runs, laps, calendar display) | **Device Local Time** | `DateTime.now()` / `DateTime.fromMillisecondsSinceEpoch()` |
| Season countdown, D-day, `daysRemaining`, `currentSeasonDay` | **GMT+2** | `SeasonService.serverTime` |
| Daily buff calculation ("yesterday") | **GMT+2** | `Gmt2DateUtils.todayGmt2.subtract(Duration(days: 1))` |
| Hex snapshots (`snapshot_date`) | **GMT+2** | `Gmt2DateUtils.todayGmt2String` |
| Leaderboard rankings | **GMT+2** | Server `CURRENT_DATE` (`Etc/GMT-2`) |
| TeamScreen FLAME RANKINGS | **GMT+2** | Server `CURRENT_DATE` (`Etc/GMT-2`) |
| Midnight timer / daily reset trigger | **GMT+2** | `SeasonService.serverTime` |
| `run_date` in `run_history` table | **GMT+2** | Server: `end_time AT TIME ZONE 'Etc/GMT-2'` |
| Fallback dates in server-domain models (`YesterdayStats`) | **GMT+2** | `Gmt2DateUtils.todayGmt2` |

### Client-Side GMT+2 Sources
- **`Gmt2DateUtils.todayGmt2`** — canonical "what date is it in GMT+2?" for all game logic
- **`Gmt2DateUtils.todayGmt2String`** — formatted `YYYY-MM-DD` for Supabase date params
- **`Gmt2DateUtils.toGmt2DateString(dt)`** — convert any DateTime to GMT+2 date string
- **`SeasonService.serverTime`** — full `DateTime` in GMT+2 (for countdowns, timer scheduling)

### Server-Side
All RPCs use `AT TIME ZONE 'Etc/GMT-2'` for date derivation.
```sql
-- run_date in finalize_run:
(p_end_time AT TIME ZONE 'Etc/GMT-2')::DATE
-- yesterday in get_user_buff, get_team_rankings:
v_yesterday := (CURRENT_TIMESTAMP AT TIME ZONE 'Etc/GMT-2')::DATE - 1;
```

### When `DateTime.now()` Is CORRECT (Local / Wall-Clock Concerns)
- Throttle/debounce timestamps (`_lastPrefetchTime`, `_lastRefreshTime`)
- GPS timing and polling intervals
- Cache TTL calculations
- Animation timestamps
- `run_calendar.dart` grouping (Running History domain — local is correct)
- `Run.startTime` / `Run.endTime` storage (stored as UTC epoch ms, displayed in local)
- `_resolveCurrentSeason()` elapsed-days math (UTC-to-UTC duration, not a date display)

### When `DateTime.now()` Is WRONG (Must Use GMT+2)
- "Yesterday" / "today" logic for buffs, stats, snapshots
- Season day calculations (`currentSeasonDay`, `daysRemaining`)
- Midnight timer scheduling (`_scheduleMidnightTimer`)
- `run_date` derivation (use `Gmt2DateUtils.toGmt2DateString`)
- Fallback/empty dates in server-domain models (e.g., `YesterdayStats`, `TeamRankings`)

### Midnight-Crossing Runs
A run's `end_time` (UTC) determines its GMT+2 date. A run starting 23:50 GMT+2 and ending
00:10 GMT+2 records `run_date = tomorrow` and affects the next day's snapshot.
`AppLifecycleManager` tracks `_midnightCrossedDuringRun` and defers snapshot refresh until
after the run completes.

### Season Boundary Math
`_resolveCurrentSeason()` uses `DateTime.now().toUtc()` (NOT `serverTime`) because it computes
elapsed days between two UTC-anchored epoch values. This is pure duration math, not a date
display. Using `serverTime` here would incorrectly shift season boundaries by 2 hours.

---

## Theme & Colors

All colors centralized in `lib/theme/app_theme.dart` (re-exported via `lib/app/theme.dart`).

```dart
AppTheme.athleticRed      // #FF003C - Red team (FLAME)
AppTheme.electricBlue     // #008DFF - Blue team (WAVE)
// Purple: #8B5CF6
AppTheme.backgroundStart  // #0F172A - Dark background
AppTheme.surfaceColor     // #1E293B - Card/surface color
AppTheme.textPrimary      // White
AppTheme.textSecondary    // #94A3B8

// Hex Visual States
// Neutral:    #2A3550 @ 0.15 opacity, Gray border (#6B7280), 1px
// Team color: 0.3 opacity, team border, 1.5px
// Capturable: Team color @ 0.3, pulsing (2s, 1.2x scale + glow)
// Current:    Team color @ 0.5 opacity, 2.5px border
```
Use `AppTheme.teamColor(isRed)` for team-aware coloring.

---

## Mapbox Patterns

### Hex Grid Rendering (GeoJsonSource + FillLayer)

**Problem**: `PolygonAnnotationManager.deleteAll()` + `createMulti()` causes visible flash.
**Solution**: `GeoJsonSource` + `FillLayer` for atomic, data-driven updates:

```dart
// Step 1: Create GeoJsonSource
await mapboxMap.style.addSource(
  GeoJsonSource(id: _hexSourceId, data: '{"type":"FeatureCollection","features":[]}'),
);

// Step 2: Create FillLayer with placeholder values
// NOTE: FillLayer has strict typing - fillColor expects int?, not List
await mapboxMap.style.addLayer(
  FillLayer(
    id: _hexLayerId, sourceId: _hexSourceId,
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

**GeoJSON Feature Properties:**
```json
{
  "type": "Feature",
  "geometry": { "type": "Polygon", "coordinates": [...] },
  "properties": { "fill-color": "#FF003C", "fill-opacity": 0.3, "fill-outline-color": "#FF003C" }
}
```
Single `updateGeoJSONSourceFeatures()` call updates all hexes atomically — no flash, GPU-accelerated.

### Scope Boundary Layers

**Province Boundary** (`scope-boundary-source` / `scope-boundary-line`):
- PROVINCE scope: Merged outer boundary of all ~7 district hexes — irregular polygon (NOT a single hexagon)
- DISTRICT scope: Single district hex boundary; ZONE scope: Hidden
- Styling: white, 8px width, 15% opacity, 4px blur, solid

**District Boundaries** (`district-boundary-source` / `district-boundary-line`):
- PROVINCE scope: Individual dashed outlines for each ~7 district hex
- DISTRICT/ZONE scope: Hidden; Styling: white, 3px width, 12% opacity, 2px blur, dashed [4,3]

**Merged Outer Boundary Algorithm** (`_computeMergedOuterBoundary`):
- Collects all directed edges from district hex boundaries
- Removes shared internal edges (opposite-direction edges cancel out)
- Chains remaining outer edges into a closed polygon loop
- Uses 7-decimal coordinate precision for edge matching (~1cm accuracy)

### Running Screen Navigation Camera

`route_map.dart` uses `SmoothCameraController` for 60fps camera interpolation:

| Aspect | Implementation |
|--------|---------------|
| Bearing Source | GPS heading (primary), route-calculated bearing (fallback from last 5 points, min 3m) |
| Camera Follow | Tracks `liveLocation` — follows ALL GPS points including rejected ones |
| Animation Duration | 1800ms (undershoots 2s GPS polling for smooth transitions) |
| Route Updates | Keep-latest pattern — queues pending update when busy |
| Marker Position | Fixed at 67.5% from top; camera padding = 0.35 × viewport height |

```dart
// GPS Heading Flow:
// LocationService (0.5Hz GPS) → LocationPoint.heading
//   → RunTracker (pass-through) → RunProvider extracts heading
//     → RunState.liveHeading (filters invalid: null, ≤ 0)
//       → RunningScreen → RouteMap.liveHeading
//         → _updateNavigationCamera() (primary bearing source)

// Keep-Latest Pattern in _processRouteUpdate():
// If _isProcessingRouteUpdate == true: _pendingRouteUpdate = true
// After processing completes: if (_pendingRouteUpdate) → process again
```

**Camera-Follows-Rejected-GPS**: When GPS is rejected by RunTracker, `routeVersion` doesn't increment but `liveLocation` still updates. `didUpdateWidget` detects this and calls `_updateCameraForLiveLocation()`.

### Leaderboard Electric Manifesto
`_ElectricManifesto` widget in `leaderboard_screen.dart`:
- `ShaderMask` + animated `LinearGradient` flowing left-to-right (3s cycle)
- Gradient between `Colors.white54` (dim) and team color (bright neon)
- Team-colored shadow glow, `GoogleFonts.sora()` italic
- Used in podium cards (top 3) and rank tiles (4th+)

---

## Remote Configuration System

All game constants (50+) are server-configurable via `app_config` table. Fallback chain: server → cache → defaults.

```
┌─────────────────────────────────────────────────────────────┐
│                    RemoteConfigService                       │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐ │
│  │   Server    │→ │   Cache     │→ │   Defaults          │ │
│  │ (Supabase)  │  │ (JSON file) │  │ (AppConfig.defaults)│ │
│  └─────────────┘  └─────────────┘  └─────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

```dart
// Values frozen during runs (use configSnapshot)
static double get maxSpeedMps =>
    RemoteConfigService().configSnapshot.gpsConfig.maxSpeedMps;

// Values that can change anytime (use config)
static int get maxCacheSize =>
    RemoteConfigService().config.hexConfig.maxCacheSize;

// Freeze/unfreeze around runs
RemoteConfigService().freezeForRun();    // In startNewRun()
RemoteConfigService().unfreezeAfterRun(); // In stopRun()
```

| Category | Examples |
|----------|----------|
| **Season** | `durationDays` (40), `serverTimezoneOffsetHours` (2) |
| **GPS** | `maxSpeedMps` (6.94), `pollingRateHz` (0.5), `maxAccuracyMeters` (50) |
| **Scoring** | `maxCapturePaceMinPerKm` (8.0), `minMovingAvgWindowSec` (20) |
| **Hex** | `baseResolution` (9), `maxCacheSize` (4000) |
| **Timing** | `refreshThrottleSeconds` (30), `accelerometerSamplingPeriodMs` (200) |

---

## Accelerometer Anti-Spoofing

`AccelerometerService` validates GPS movement against physical device motion.

| Platform | Behavior |
|----------|----------|
| **Real device** | Accelerometer events validate movement |
| **iOS Simulator** | No hardware → graceful fallback to GPS-only (5s warning logged) |

Diagnostic logs: `"Started listening at 5Hz"` → `"First event received"` or `"WARNING - No accelerometer events received after 5s. GPS-only validation will be used."` → `"Stopped listening (received N events)"`.

Graceful fallback when no accelerometer: iOS Simulator, some Android devices, sensor errors — GPS points allowed.

---

## UI Conventions

### Geographic Scope Categories

| Scope | Enum Value | H3 Resolution | Description |
|-------|------------|---------------|-------------|
| **ZONE** | `zone` | 8 | Neighborhood (~461m) |
| **DISTRICT** | `district` | 6 | District (~3.2km) — `users.district_hex`, `daily_buff_stats.district_hex` |
| **PROVINCE** | `province` | 5 | Province/Metro — `hexes.parent_hex`, `hex_snapshot.parent_hex` |

Legacy code references `city` (now `district`) and `all` (now `province`). These are fully renamed.
- `hexes.parent_hex` = Res 5 (province) — used for snapshot/delta/dominance queries
- `users.district_hex` = Res 6 (district) — used for buff/rankings scoping
- Base gameplay hex = Res 9

### Stat Panel Display Order (consistent across all screens)
1. **Points** (primary/large) → 2. **Distance** → 3. **Pace** → 4. **Rank or Stability**

### Pace Format
Unified: `X'XX` (apostrophe separator, no trailing `"`). Examples: `5'30`, `6'05`, `-'--` (null/invalid).

### Other Conventions
- **FlipPoints Header**: Shows season total points (not today's). Uses `FittedBox` for overflow. Airport departure board flip animation.
- **Google AdMob**: BannerAd on MapScreen (all scope views, portrait + landscape). `AdService` singleton. Test IDs during dev.
- **Landscape Layout**: MapScreen — ad + zoom selector in column. LeaderboardScreen — single `CustomScrollView`.
- **SQLite version**: v19 (v12 added `hex_path`, `buff_multiplier`, `run_checkpoint`; v15 added lap tracking; v17 added `has_flips` to runs; v19 renamed `hex_city_parents` → `hex_district_parents`)

---

## Supabase Schema

```sql
users            -- id, name, team, avatar, season_points, manifesto,
                 -- sex, birthday, nationality,
                 -- home_hex, home_hex_end, season_home_hex, district_hex, province_hex,
                 -- total_distance_km, avg_pace_min_per_km, avg_cv, total_runs, cv_run_count
hexes            -- id (H3 index), last_runner_team, last_flipped_at, parent_hex (Res 5 province), district_hex (Res 6)
hex_snapshot     -- hex_id, last_runner_team, snapshot_date, parent_hex (frozen daily snapshot)
runs             -- id, user_id, team_at_run, distance_meters, hex_path[] (partitioned monthly)
run_history      -- id, user_id, run_date, distance_km, duration_seconds, flip_count, flip_points, cv, has_flips
daily_stats      -- id, user_id, date_key, total_distance_km, flip_count (partitioned monthly)
daily_buff_stats -- stat_date, district_hex, dominant_team, red/blue/purple_hex_count,
                 -- red_elite_threshold_points, purple_participation_rate
daily_province_range_stats -- stat_date, province_hex (Res 5), leading_team, red/blue/purple_hex_count
                 -- (one row per Res-5 province per day; used for province win in buff)
season_leaderboard_snapshot -- user_id, season_number, rank, name, team, season_points,
                 -- total_distance_km, avg_pace_min_per_km, avg_cv, total_runs,
                 -- home_hex, home_hex_end, manifesto, nationality (frozen at midnight)
```

**Key RPC Functions:**
- `finalize_run(...)` → cap-validate flip_points, update live hexes for buff/dominance, store district_hex + province_hex. Handles 0-flip runs safely.
- `get_user_buff(user_id)` → get user's current buff multiplier
- `calculate_daily_buffs()` → daily cron at midnight GMT+2
- `build_daily_hex_snapshot()` → daily cron to build tomorrow's snapshot at midnight GMT+2
- `get_hex_snapshot(parent_hex, snapshot_date)` → download hex snapshot for prefetch
- `get_leaderboard(limit)` → ranked users from `season_leaderboard_snapshot` (Snapshot Domain)
- `app_launch_sync(...)` → pre-patch data on launch with CV fields

---

## Dependencies (Key Packages)

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

---

## Do's and Don'ts

### Do
- Use `const` constructors for immutable widgets
- Follow Riverpod 3.0 Notifier pattern per `riverpod_rule.md`
- Use relative imports for internal files
- Run `flutter analyze` before committing
- Add `///` documentation for public APIs
- Use derived getters (`isPurple`, `maxMembers`) instead of stored fields
- Use Supabase RPC for complex queries (multiplier, leaderboard)
- Use `debugPrint()` for logging

### Don't
- Don't use `print()` — use `debugPrint()`
- Don't suppress lint rules without good reason
- Don't put business logic in widgets — use services/providers
- Don't hardcode colors — use `AppTheme` constants
- Don't use `ChangeNotifier`, `StateNotifier`, or legacy `provider` package — Riverpod 3.0 only
  - **Exception:** `_RouterRefreshNotifier` in `lib/app/routes.dart` extends `ChangeNotifier` as a `GoRouter.refreshListenable` adapter. This is a private, scoped adapter following the GoRouter team's official Riverpod integration pattern — `GoRouter.refreshListenable` requires a `Listenable`, not a Riverpod primitive. Do not replace without a concrete benefit.
- Don't create new state management patterns
- Don't store derived/calculated data in database (calculate on-demand)
- Don't create backend API endpoints — use RLS + Edge Functions
- Don't mix client-side (Running History) and server-side (Season) data domains
- Don't use `UserModel` server aggregate fields for ALL TIME stats — use local SQLite `runs` table

---

## Testing

Test files mirror the `lib/` structure in `test/`.

```dart
// test/widget_test.dart
void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const RunnerApp());
    expect(find.textContaining('RUN'), findsOneWidget);
  });
}
```

```bash
flutter test                              # All tests
flutter test test/models/lap_model_test.dart  # Single file
flutter test --coverage                   # With coverage
```

---

## Domain Knowledge

> For detailed game rules, data architecture, sync strategy, and UI specs → see [DEVELOPMENT_SPEC.md](./DEVELOPMENT_SPEC.md)


---

## Post-Revision Hook

Run `./scripts/post-revision-check.sh` **after every code change** before committing.

```bash
./scripts/post-revision-check.sh            # Full audit of lib/ (82 Dart files)
./scripts/post-revision-check.sh --staged   # Git hook mode: staged files only
SKIP_REVISION_CHECK=1 git commit             # Emergency bypass (leaves audit trail)
```

Installed as a git pre-commit hook (`ln -sf ../../scripts/post-revision-check.sh .git/hooks/pre-commit`).
The hook runs automatically on every `git commit`.

### What It Checks (21 rules across 10 groups)

| Group | Rules | Maps To |
|-------|-------|---------|
| A — Code quality | withOpacity, print(), lint suppression, StateNotifier, ChangeNotifier | AGENTS.md |
| B — Riverpod 3.0 | ref.watch(.notifier) misuse | riverpod_rule.md |
| C — Data domain | UserModel server fields in display layer | Invariant #7 |
| D — Points & sync | Client flipPoints to onRunSynced, math.max(totalSeasonPoints) | Invariants #2, #12 |
| E — HexRepository | _hexCache.get() bypass, clearAll() misuse, computeHexDominance overlay | Invariants #3, #4, #16, #18 |
| F — Timezone | DateTime.now() in server-domain models | Invariant #11 |
| G — (disabled) | Snapshot date +1 offset — enforced server-side; undetectable via grep | Invariant #1 |
| H — SQL partition | created_at vs run_date in queries | Invariant #8 |
| I — SQLite DDL | local_storage.dart modified (single advisory WARN) | Missing comma crash |
| J — AdMob | App ID vs ad unit publisher mismatch | SIGABRT crash |
| K — OnResume | _onAppResume() missing provider refreshes | Invariant #5 |

**FAILs** block the commit. **WARNs** are advisory (do not block).

### Sentinel Comments (suppress known-good false positives)

If you add a new `_hexCache.get()` call that is legitimately outside `getHex()`
(cache-merge or dedup context), add one of these comments on the same line:

```dart
final existing = _hexCache.get(id); // cache-merge: intentional
if (_hexCache.get(id) != null) continue; // dedup: intentional
HexRepository().clearAll(); // province-change: clearAll() is correct here
```

---

## Coding Process — Regression Prevention

> **Why this exists**: Every bug in `error-fix-history.md` was caused by an edit that didn't trace the full data flow before changing code. This section encodes the hard-won lessons into a mandatory process.

### Pre-Edit Checklist (MANDATORY before any code change)

Run through ALL of these before touching any file:

```
[ ] 1. READ error-fix-history.md — search for the component/RPC you're about to edit.
       Is there a prior bug related to this area? If yes, understand it before proceeding.

[ ] 2. TRACE the data flow (both directions):
       - Who WRITES the data? (which RPC, which service, which notifier)
       - Who READS it? (which provider reads this, which screen consumes that provider)
       - Who CALLS the function you're changing? Grep for it.

[ ] 3. LIST all consumers of the function/provider you're modifying.
       A change to get_hex_snapshot() affects: PrefetchService → HexRepository → HexDataProvider
       → hexagon_map.dart → MapScreen. Touch one, verify all.

[ ] 4. IDENTIFY the data domain (never mix):
       - Running History = local SQLite only (allRuns, laps, cv, pace)
       - Hex + Leaderboard + Team = server-side (hex_snapshot, season_leaderboard_snapshot)
       - Points header = hybrid (PointsService: server baseline + local unsynced)

[ ] 5. CHECK OnResume completeness — if your change adds a new stateful provider,
       add its refresh to _onAppResume() in app_init_provider.dart.

[ ] 6. RUN flutter analyze before AND after your edit. Must be 0 errors both times.
```

### Post-Edit Verification (MANDATORY before marking any task done)

```
[ ] 1. flutter analyze — 0 issues
[ ] 2. LSP diagnostics on every modified file — 0 errors
[ ] 3. Trace the actual app call path (not just the RPC in isolation).
       Direct RPC test ≠ fix verified. Trace from widget → provider → service → RPC.
[ ] 4. Update error-fix-history.md with:
       - Problem description
       - Root cause
       - Fix applied (with code snippet)
       - Verification steps taken
       - Lesson learned
```

### Critical Invariants (Never Violate)

These encode the most expensive lessons from `error-fix-history.md`:

| # | Invariant | Where it applies |
|---|-----------|-----------------|
| 1 | **Snapshot date = D + 1** | `get_hex_snapshot()` queries `snapshot_date = GMT+2_date + 1`. The write and read must both use `+ 1`. | 
| 2 | **Server response is truth** | After `finalize_run()`, use `syncResult['points_earned']`, NOT client-calculated `flipPoints`. | 
| 3 | **Local overlay is eviction-immune** | `_localOverlayHexes` in HexRepository is a plain Map — NEVER put it in the LRU cache. | 
| 4 | **clearAll() is nuclear** | Only call `HexRepository().clearAll()` on season reset or province change. Use `clearLocalOverlay()` for day rollover. | 
| 5 | **OnResume refreshes ALL stateful providers** | `_onAppResume()` must refresh: hex, leaderboard, points, buff, teamStats. Adding a new server-derived provider? Add it here too. | 
| 6 | **initState fires once** | `TeamScreen._loadData()` is called from `initState` — it does NOT re-fire on app resume if screen is in stack. Server data must be pushed via `_onAppResume()`. | 
| 7 | **Two data domains — never mix** | ALL TIME stats = local SQLite `runs.fold()`. Season data = server RPCs. Never read `UserModel.totalDistanceKm` for display (it's a server aggregate, resets on season). | 
| 8 | **Season boundary awareness** | All RPCs querying `run_history` for 'yesterday' must check if yesterday < current season start. On Day 1, yesterday = last season's last day. | 
| 9 | **RPC shape = client parser shape** | When an RPC response changes keys, `fromJson` silently returns 0. Always verify JSON key names match between RPC and client parser. | 
| 10 | **AppLifecycleManager singleton** | Only the first `initialize()` call wins. Do not call it from multiple places. | 

### Debugging Protocol

When a bug is reported:
1. **Search `error-fix-history.md`** for the affected screen/provider/RPC first — it may be a repeat.
2. **Trace the full call path** (widget → provider → service → RPC → DB) before forming a hypothesis.
3. **Verify via app call path**, not direct RPC test. The bug is often in *when* the RPC is called, not *what* it returns.
4. After 2 failed fix attempts → consult Oracle with full failure context.
5. **Never fix + refactor simultaneously.** Fix minimally. Document. Then refactor separately if needed.

### Editing a Supabase RPC

Extra care when changing server-side functions:
```
[ ] 1. Check what client-side parser reads the response (grep for RPC name in lib/).
[ ] 2. Verify JSON key names match between the RPC SELECT and the Dart fromJson parser.
[ ] 3. Test the RPC directly in SQL to confirm output shape.
[ ] 4. Re-run the app call path (not just the SQL query) to confirm end-to-end.
[ ] 5. Write a migration (never edit existing migrations).
[ ] 6. Document the date/offset convention if time math is involved.
```

### Editing a Provider or Notifier

```
[ ] 1. List every widget that calls ref.watch(thisProvider) or ref.read(thisProvider).
[ ] 2. If state shape changes (new field, renamed field), update ALL consumers.
[ ] 3. If provider holds server data: confirm it's refreshed in _onAppResume().
[ ] 4. If provider holds local data: confirm it survives app resume (no unintended clearAll).
[ ] 5. Check ref.mounted after every await — stale state after async ops is silent.
```
