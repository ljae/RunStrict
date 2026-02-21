# AGENTS.md - RunStrict (The 40-Day Journey)

> Guidelines for AI coding agents working in this Flutter/Dart codebase.

## Project Overview

**RunStrict** is a location-based running game that gamifies territory control through hexagonal maps.

### Core Concept
- **Season**: 40 days (fixed duration)
- **Teams**: Red (FLAME), Blue (WAVE), Purple (CHAOS - available anytime)
- **Hex System**: Displays color of **last runner** - no ownership
- **D-Day Reset**: All territories and scores wiped via TRUNCATE/DROP (The Void)
- **Buff System**: Team-based multipliers calculated daily (Red: Elite 2-4x / Common 1-2x, Blue: 1-3x, Purple: Participation 1-3x)

### Key Design Principles
- Privacy optimized: No timestamps or runner IDs stored in hexes
- User location shown as **person icon inside a hexagon** (team-colored)
- Performance-optimized (no 3D rendering)
- Serverless architecture: No backend API server (Supabase RLS handles auth)
- **No Realtime/WebSocket**: All data synced on app launch, OnResume, and run completion ("The Final Sync")
- **Server verified**: Points calculated by client, validated by server (≤ hex_count × multiplier)
- **Offline resilient**: Failed syncs retry automatically via `SyncRetryService` (on launch, OnResume, next run)
- **Crash recovery**: `run_checkpoint` table saves state on each hex flip; recovered on next app launch

**Tech Stack**: Flutter 3.10+, Dart, Riverpod 3.0 (state management), Mapbox, Supabase (PostgreSQL), H3 (hex grid)

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

### Analysis & Linting
```bash
flutter analyze          # Run static analysis (linter)
dart format .            # Format code
```

### Testing
```bash
flutter test                              # Run all tests
flutter test test/widget_test.dart        # Run single test file
flutter test --plain-name "App smoke test" # Run specific test
flutter test --coverage                   # Run with coverage
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

1. Dart SDK imports (`dart:async`, `dart:io`)
2. Flutter imports (`package:flutter/material.dart`)
3. Third-party packages (`package:hooks_riverpod/hooks_riverpod.dart`)
4. Internal imports (relative paths `../models/run_session.dart`)

```dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../models/run_session.dart';
import '../services/location_service.dart';
```

### Formatting

- Use trailing commas for multi-line parameter lists
- Run `dart format .` before committing
- Max line length: 80 characters (Dart default)

```dart
// Good - trailing comma forces multi-line formatting
return RunSession(
  id: id,
  startTime: startTime,
  distanceMeters: distanceMeters,
  route: route,
);
```

### Widget Construction

- Use `const` constructors wherever possible
- Use `super.key` for widget keys
- Break large widgets into private helper widgets in the same file

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
  // ...
}
```

### State Management (Riverpod 3.0)

- Use `Notifier<T>` / `AsyncNotifier<T>` class-based providers
- Use `NotifierProvider` / `AsyncNotifierProvider` declarations
- Use `ConsumerWidget` / `ConsumerStatefulWidget` for widgets
- Use `ref.watch()` for reactive state, `ref.read()` for one-off actions
- Always check `ref.mounted` after async ops in notifiers

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

final runProvider = NotifierProvider<RunNotifier, RunState>(
  RunNotifier.new,
);
```

### Error Handling

- Use targeted `try-catch` blocks in async methods
- Use `debugPrint()` for debug logging (not `print()`)
- Throw specific exceptions with descriptive messages

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

### Documentation

- Use `///` for public API documentation
- Document non-obvious behavior
- Keep comments concise

```dart
/// Represents a complete running session with all tracking data.
///
/// Use [copyWith] to create modified copies of this session.
class RunSession {
  /// Distance in kilometers (derived from [distanceMeters])
  double get distanceKm => distanceMeters / 1000;
}
```

### Models

- Immutable data classes with `final` fields
- Implement `copyWith()` for modifications
- Implement `fromJson()` factory and `toJson()` for serialization
- Use `fromRow()` / `toRow()` for Supabase row serialization

```dart
class UserModel {
  final String id;
  final String name;
  final Team team;
  final int seasonPoints;

  const UserModel({
    required this.id,
    required this.name,
    required this.team,
    this.seasonPoints = 0,
  });

  UserModel copyWith({String? name, Team? team, int? seasonPoints}) {
    return UserModel(
      id: id,
      name: name ?? this.name,
      team: team ?? this.team,
      seasonPoints: seasonPoints ?? this.seasonPoints,
    );
  }

  factory UserModel.fromRow(Map<String, dynamic> row) => UserModel(
    id: row['id'] as String,
    name: row['name'] as String,
    team: Team.values.byName(row['team'] as String),
    seasonPoints: (row['season_points'] as num?)?.toInt() ?? 0,
  );

  Map<String, dynamic> toRow() => {
    'name': name,
    'team': team.name,
    'season_points': seasonPoints,
  };
}
```

---

## Theme & Colors

All colors and styles are centralized in `lib/theme/app_theme.dart` (re-exported via `lib/app/theme.dart`).

```dart
// Team colors
AppTheme.athleticRed      // #FF003C - Red team (FLAME)
AppTheme.electricBlue     // #008DFF - Blue team (WAVE)
// Purple team: #8B5CF6    // Purple team (CHAOS)

// Backgrounds
AppTheme.backgroundStart  // #0F172A - Dark background
AppTheme.surfaceColor     // #1E293B - Card/surface color

// Text
AppTheme.textPrimary      // White
AppTheme.textSecondary    // #94A3B8
```

Use `AppTheme.teamColor(isRed)` for team-aware coloring.

---

## Game-Specific Guidelines

### Team-Based Buff System
```dart
// Buff multiplier determined by team, performance, and territory dominance
// Calculated daily at midnight GMT+2 via Edge Function
//
// RED FLAME:
// Elite = Top 20% by yesterday's FLIP POINTS (points with multiplier, NOT raw flip count)
//         among RED runners in the same District
// Common = Bottom 80%
// | Scenario              | Elite (Top 20%) | Common |
// |-----------------------|-----------------|--------|
// | Normal (no wins)      | 2x              | 1x     |
// | District win only     | 3x              | 1x     |
// | Province win only     | 3x              | 2x     |
// | District + Province   | 4x              | 2x     |
//
// BLUE WAVE:
// | Scenario              | Union |
// |-----------------------|-------|
// | Normal (no wins)      | 1x    |
// | District win only     | 2x    |
// | Province win only     | 2x    |
// | District + Province   | 3x    |
//
// PURPLE: Participation Rate = 1x (<30%), 2x (30-59%), 3x (≥60%) (no territory bonus)
// New users = 1x (default until yesterday's data exists)
final multiplier = BuffService().currentBuff; // Frozen at run start
final points = flipsEarned * multiplier;
```

### Snapshot-Based Flip Points
```dart
// Flip points are counted against the daily hex snapshot (frozen at midnight GMT+2).
// All users start each day with the same snapshot baseline.
//
// Client flow:
// 1. Download hex_snapshot on app launch / OnResume
// 2. Apply local overlay (user's own today's flips from SQLite)
// 3. During run: count flips against snapshot + overlay
// 4. flip_points = total_flips × buff_multiplier (frozen at run start)
// 5. Upload to server: hex_path[] + flip_points + buff_multiplier
// 6. Server cap-validates: flip_points ≤ len(hex_path) × buff_multiplier
//
// Map shows: snapshot + own local flips (other users invisible until tomorrow)
// Different users CAN flip the same hex independently (both earn points)
// Same user CANNOT flip same hex twice in same run (session dedup)
// Cross-run same-day: local overlay prevents double-counting own hexes

// PointsService tracks points from two sources:
// _serverTodayBaseline: synced runs (from appLaunchSync)
// _localUnsyncedToday: unsynced runs on this device
// Total = _serverTodayBaseline + _localUnsyncedToday
//
// On sync success, onRunSynced() transfers points between baselines
// to prevent points from disappearing during the sync window.
```

### Two Data Domains (Critical Architecture Rule)

All app data belongs to exactly one of two domains. **Never mix them.**

**Snapshot Domain** (Server → Local, read-only until next midnight):
- Hex map base, leaderboard rankings + season record, team stats, buff, user aggregates (`UserModel`)
- Downloaded on app launch/OnResume. NEVER changes from running.
- **Always anchored to home hex** — downloads use `PrefetchService.homeHex`/`homeHexAll` (never GPS)
- Leaderboard: `get_leaderboard` RPC reads from `season_leaderboard_snapshot` (NOT live `users` table)
- LeaderboardScreen Season Record uses snapshot `LeaderboardEntry`, NOT live `currentUser`
- Used by: TeamScreen, LeaderboardScreen, ALL TIME stats (distance, pace, stability, run count)

**Live Domain** (Local creation → Upload):
- Header FlipPoints, run records, hex overlay (own runs only)
- Created/updated by running. Uploaded via Final Sync.
- Used by: FlipPointsWidget, RunHistoryScreen period stats (DAY/WEEK/MONTH/YEAR)

**Only hybrid value**: `PointsService.totalSeasonPoints` = server `season_points` + local unsynced. Used for header AND ALL TIME points.

| Screen | Domain | Rule |
|--------|--------|------|
| TeamScreen | Snapshot | Server RPCs only (home hex anchored) |
| LeaderboardScreen | Snapshot | `season_leaderboard_snapshot` via RPC (NOT live `users` or `currentUser`) |
| MapScreen display | Snapshot + GPS | GPS hex for camera/territory when outside province |
| ALL TIME stats | Snapshot + hybrid points | `UserModel` + `totalSeasonPoints` |
| Period stats | Live | Local SQLite runs |
| Header FlipPoints | Live (hybrid) | `totalSeasonPoints` |

### Location Domain Separation (Home vs GPS)

Server data and map display use different location anchors:
- **Server data** (TeamScreen, Leaderboard, hex snapshot, season register) → always **home hex**
- **MapScreen** district/province views → **GPS hex** when outside province, home hex otherwise
- **Hex capture** → **disabled** when outside province (floating banner on MapScreen)
- **ProfileScreen** → shows BOTH registered home and GPS location when outside province

`PrefetchService` getters: `homeHex`/`homeHexCity`/`homeHexAll` (server anchor), `gpsHex`/`getGpsHexAtScope()` (map display), `isOutsideHomeProvince` (detection). No `activeHex*` getters (removed to prevent domain conflation).

### OnResume Data Refresh
When app returns to foreground, `AppLifecycleManager` triggers:
- Hex map data refresh (PrefetchService)
- Leaderboard refresh
- Retry failed syncs (SyncRetryService)
- Buff multiplier refresh (BuffService)
- Today's points baseline refresh (appLaunchSync + PointsService)

Skipped during active runs (including stopRun via `_isStopping` flag). Throttled to max once per 30 seconds.

### Hex Data Architecture (Snapshot + Local Overlay)
`HexRepository` is the **single source of truth** for hex data (no duplicate caches).
- `PrefetchService.getCachedHex()` delegates to `HexRepository().getHex()`
- `HexDataProvider.getHex()` reads directly from `HexRepository`
- PrefetchService downloads from `hex_snapshot` table (NOT live `hexes`) into HexRepository
- **Local overlay**: User's own today's flips stored in SQLite, applied on top of snapshot
- **Map display**: Snapshot + own local flips (other users' today activity invisible)
- **Live `hexes` table**: Updated by `finalize_run()` for buff/dominance only, NOT for flip counting
- **District scoping**: `users.district_hex` (Res 6 H3 parent) set by `finalize_run()`, used by `get_user_buff()` and `get_team_rankings()` for district-level filtering

### Hex Capture & Flip
```dart
// Hex stores lastRunnerTeam + lastFlippedAt (for conflict resolution)
bool setRunnerColor(Team runnerTeam, DateTime runEndTime) {
  if (lastRunnerTeam == runnerTeam) return false;
  // Only update if this run ended later (prevents offline abusing)
  if (lastFlippedAt != null && runEndTime.isBefore(lastFlippedAt)) return false;
  lastRunnerTeam = runnerTeam;
  lastFlippedAt = runEndTime;
  return true; // Color changed (flip)
}

// NO daily flip limit - different users can each flip the same hex independently
// (same user cannot re-flip own hex on same day — snapshot isolation by design)
// Conflict resolution: Later run_endTime wins (compared via last_flipped_at)
```

### Pace Validation
```dart
// Must be running at valid pace to capture hex
// Uses MOVING AVERAGE pace (last 20 sec) at hex entry - smooths GPS noise
// 20-sec window provides ~10 samples at 0.5Hz GPS polling for stable calculation
bool get canCaptureHex => movingAvgPaceMinPerKm < 8.0;
// Also: speed < 25 km/h AND GPS accuracy ≤ 50m
// GPS Polling: Fixed 0.5 Hz (every 2 seconds) for battery optimization
```

### CV & Stability Score
```dart
// CV (Coefficient of Variation) measures pace consistency
// Calculated from 1km lap paces using sample stdev (n-1 denominator)
// CV = (stdev / mean) * 100
// Lower CV = more consistent pace

// LapService calculates CV at run completion
static double? calculateCV(List<LapModel> laps) {
  if (laps.isEmpty) return null;
  if (laps.length == 1) return 0.0; // No variance with single lap
  // ... sample stdev calculation
}

// Stability Score = 100 - CV (clamped 0-100, higher = better)
static int? calculateStabilityScore(double? cv) {
  if (cv == null) return null;
  return (100 - cv).round().clamp(0, 100);
}

// Color coding on leaderboard:
// Green: ≥80 (excellent), Yellow: 50-79 (good), Red: <50 (needs work)
```

### Purple Team Defection (Protocol of Chaos)

| Property | Value |
|----------|-------|
| Availability | Anytime during season (no restriction) |
| Entry Name | "Traitor's Gate" |
| Entry Cost | Points are **PRESERVED** (not reset) |
| Eligibility | Any Red/Blue user |
| Reversibility | **Irreversible** for remainder of season |

**Rules:**
- Purple is available anytime during the 40-day season
- Defection is permanent - cannot return to Red/Blue until next season
- All accumulated Flip Points are preserved upon defection
- No minimum point threshold to defect (anyone can defect)

**Implementation:**
```dart
// In TraitorGateScreen / AppStateProvider
void defectToPurple() {
  // Points are PRESERVED - do NOT reset seasonPoints
  user = user.copyWith(team: Team.purple);
  // Team change is permanent for remainder of season
}
```

---

## Common Patterns

### Screen with Riverpod
```dart
class RunningScreen extends ConsumerWidget {
  const RunningScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final runState = ref.watch(runProvider);
    return // ... UI using runState
  }
}
```

### Supabase RPC Call
```dart
// Call a PostgreSQL function via Supabase
final result = await supabase.rpc('get_user_buff', params: {
  'p_user_id': userId,
});
```

### Async Initialization
```dart
// Use AsyncNotifier for async initialization
class AppInitNotifier extends AsyncNotifier<AppInitState> {
  @override
  Future<AppInitState> build() async {
    // ... async initialization logic
    return const AppInitState.ready();
  }
}
```

---

## Do's and Don'ts

### Do
- Use `const` constructors for immutable widgets
- Follow the existing Riverpod 3.0 Notifier pattern for state
- Use relative imports for internal files
- Run `flutter analyze` before committing
- Add `///` documentation for public APIs
- Use derived getters (`isPurple`, `maxMembers`) instead of stored fields
- Use Supabase RPC for complex queries (multiplier, leaderboard)

### Don't
- Don't use `print()` - use `debugPrint()` instead
- Don't suppress lint rules without good reason
- Don't put business logic in widgets - use services/providers
- Don't hardcode colors - use `AppTheme` constants
- Don't create new state management patterns - stick with Riverpod 3.0
- Don't store derived/calculated data in database (calculate on-demand)
- Don't create backend API endpoints - use RLS + Edge Functions

---

## Testing

Test files mirror the `lib/` structure in `test/`.

```dart
// test/widget_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:runner/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const RunnerApp());
    expect(find.textContaining('RUN'), findsOneWidget);
  });
}
```

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

Two additional GeoJSON sources render geographic scope boundaries:

**Province Boundary** (`scope-boundary-source` / `scope-boundary-line`):
- **PROVINCE scope**: Merged outer boundary of all ~7 district (Res 6) hexes — irregular polygon (NOT a single hexagon)
- **DISTRICT scope**: Single district hex boundary
- **ZONE scope**: Hidden
- Styling: white, 8px width, 15% opacity, 4px blur, solid

**District Boundaries** (`district-boundary-source` / `district-boundary-line`):
- **PROVINCE scope**: Individual dashed outlines for each ~7 district hex
- **DISTRICT/ZONE scope**: Hidden
- Styling: white, 3px width, 12% opacity, 2px blur, dashed [4,3]

**Merged Outer Boundary Algorithm** (`_computeMergedOuterBoundary`):
- Collects all directed edges from district hex boundaries
- Removes shared internal edges (opposite-direction edges cancel out)
- Chains remaining outer edges into a closed polygon loop
- Uses 7-decimal coordinate precision for edge matching (~1cm)

### Leaderboard Electric Manifesto

`_ElectricManifesto` widget in `leaderboard_screen.dart`:
- `ShaderMask` + animated `LinearGradient` flowing left-to-right (3s cycle)
- Gradient between `Colors.white54` (dim) and team color (bright neon)
- Team-colored shadow glow, `GoogleFonts.sora()` italic
- Used in podium cards (top 3) and rank tiles (4th+)

---

## Remote Configuration System

All game constants (50+) are server-configurable via the `app_config` table in Supabase. This allows tuning without app updates.

### Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    RemoteConfigService                       │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐ │
│  │   Server    │→ │   Cache     │→ │   Defaults          │ │
│  │ (Supabase)  │  │ (JSON file) │  │ (AppConfig.defaults)│ │
│  └─────────────┘  └─────────────┘  └─────────────────────┘ │
│                  Fallback Chain: server → cache → defaults   │
└─────────────────────────────────────────────────────────────┘
```

### Key Files

| File | Purpose |
|------|---------|
| `lib/data/models/app_config.dart` | Typed config model with nested classes (SeasonConfig, GpsConfig, ScoringConfig, HexConfig, TimingConfig, BuffConfig) |
| `lib/core/services/remote_config_service.dart` | Singleton service with `config`, `configSnapshot`, `freezeForRun()` |
| `lib/core/services/config_cache_service.dart` | Local JSON caching for offline fallback |
| `supabase/migrations/20260128_create_app_config.sql` | Database table with JSONB schema |

### Usage Pattern

Services access configuration via `RemoteConfigService()`:

```dart
// For values that should NOT change during a run (use configSnapshot)
static double get maxSpeedMps =>
    RemoteConfigService().configSnapshot.gpsConfig.maxSpeedMps;

// For values that can change anytime (use config)
static int get maxCacheSize =>
    RemoteConfigService().config.hexConfig.maxCacheSize;
```

### Run Consistency

During an active run, config is frozen to prevent mid-run changes:

```dart
// In RunTracker.startNewRun()
RemoteConfigService().freezeForRun();

// In RunTracker.stopRun()
RemoteConfigService().unfreezeAfterRun();
```

### Configurable Constants (by Category)

| Category | Examples |
|----------|----------|
| **Season** | `durationDays` (40), `serverTimezoneOffsetHours` (2) |
| **GPS** | `maxSpeedMps` (6.94), `pollingRateHz` (0.5), `maxAccuracyMeters` (50) |
| **Scoring** | `maxCapturePaceMinPerKm` (8.0), `minMovingAvgWindowSec` (20) |
| **Hex** | `baseResolution` (9), `maxCacheSize` (4000) |
| **Timing** | `refreshThrottleSeconds` (30), `accelerometerSamplingPeriodMs` (200) |

---

## Accelerometer Anti-Spoofing

The `AccelerometerService` validates GPS movement against physical device motion.

### Platform Behavior

| Platform | Behavior |
|----------|----------|
| **Real device** | Accelerometer events validate movement |
| **iOS Simulator** | No hardware → graceful fallback to GPS-only |

### Diagnostics

The service provides clear diagnostic logging:

```
// On start
AccelerometerService: Started listening at 5Hz

// If accelerometer works (real device)
AccelerometerService: First event received - accelerometer active

// If no events after 5 seconds (simulator)
AccelerometerService: WARNING - No accelerometer events received after 5s.
Likely running on iOS Simulator or device without accelerometer.
GPS-only validation will be used (anti-spoofing disabled).

// On stop
AccelerometerService: Stopped listening (received 0 events)
```

### Graceful Fallback

When no accelerometer data is available, GPS points are allowed:
- iOS Simulator: No hardware accelerometer
- Some Android devices: Sensor may not be available
- Sensor errors: Gracefully continue with GPS-only validation

---

## Repository Pattern (Data Architecture)

The app uses a **Repository Pattern** where repositories serve as the single source of truth for all data.

### Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    DATA FLOW                                 │
│                                                              │
│   Screens → Providers → Repositories (Single Source of Truth)│
│                      ↘ Services (business logic)             │
│                                                              │
│   Repositories are singletons accessed via Repository()      │
└─────────────────────────────────────────────────────────────┘
```

### Repositories

| Repository | Purpose | Key Methods |
|------------|---------|-------------|
| `UserRepository()` | User data, season points | `setUser()`, `updateSeasonPoints()`, `saveToDisk()` |
| `HexRepository()` | Hex cache (LRU), delta sync, single source of truth | `getHex()`, `updateHexColor()`, `mergeFromServer()` |
| `LeaderboardRepository()` | Leaderboard entries | `loadEntries()`, `filterByScope()`, `filterByTeam()` |

### Provider Delegation Pattern

Providers delegate storage to repositories while maintaining their own UI-facing API:

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

### Unified Run Model

The `Run` model (`lib/models/run.dart`) replaces three legacy models:
- `RunSession` (active runs) → `Run`
- `RunSummary` (completed runs) → `Run`
- `RunHistoryModel` (history display) → `Run`

```dart
class Run {
  // Core fields
  final String id;
  final DateTime startTime;
  DateTime? endTime;
  double distanceMeters;
  int hexesPassed;
  int hexesColored;
  
  // Computed getters
  double get distanceKm => distanceMeters / 1000;
  double get avgPaceMinPerKm => ...;
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
}
```

### Hex Snapshot Prefetch

Hex data is downloaded from the daily snapshot (frozen at midnight GMT+2):

```dart
// Download today's snapshot for the user's area
final hexes = await supabase.getHexSnapshot(parentHex, snapshotDate: today);

// Load snapshot into HexRepository as base layer
HexRepository().bulkLoadFromServer(hexes);

// Apply local overlay: user's own today's flips from SQLite
final localFlips = await localStorage.getTodayFlips();
HexRepository().applyLocalOverlay(localFlips);

// Map shows: snapshot + own local flips
// Other users' today activity is invisible until tomorrow's snapshot
```

### UI Conventions

**Geographic Scope Categories** (zone/district/province):

| Scope | Enum Value | H3 Resolution | Description |
|-------|------------|---------------|-------------|
| ZONE | `zone` | 8 | Neighborhood (~461m) |
| DISTRICT | `district` | 6 | District (~3.2km) |
| PROVINCE | `province` | 4 | Metro/Regional (server-wide) |

**Stat Panel Display Order** (consistent across all screens):
1. Points (primary) → 2. Distance → 3. Pace → 4. Rank/Stability

**Pace Format**: Unified `X'XX` (e.g., `5'30`). No trailing `"`.

**FlipPoints Header**: Shows season total points (not today's). Uses `FittedBox` for overflow prevention.

**Google AdMob**: BannerAd on MapScreen (all scope views, portrait + landscape). `AdService` singleton manages SDK initialization.

**Landscape Layout**: MapScreen shows ad + zoom selector in column. LeaderboardScreen uses single `CustomScrollView` for full scrollability.

### Database Version

Current SQLite version: **v15**
- v9: Added `sync_status`, `flip_points`, `run_date` to runs table
- v10: Dropped legacy `sync_queue` table
- v12: Added `hex_path`, `buff_multiplier` columns to runs table (for sync retry); added `run_checkpoint` table (crash recovery)
- v15: Current schema version
