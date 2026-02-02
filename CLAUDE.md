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
- **Server verified**: Points calculated by client, validated by server (≤ hex_count × multiplier)

### Core Philosophy
| Surface Layer | Hidden Layer |
|--------------|--------------|
| Red vs Blue competition | Connection through rivalry |
| Territory capture | Mutual respect growth |
| Weekly battles | Long-term relationships |
| "Win at all costs" | "We ran together" |

**Tech Stack**: Flutter 3.10+, Dart, Provider (state management), Mapbox, Supabase (PostgreSQL), H3 (hex grid)

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
├── main.dart                    # App entry point, Provider setup
├── config/
│   ├── mapbox_config.dart       # Mapbox API configuration
│   └── supabase_config.dart     # Supabase URL & anon key
├── models/
│   ├── team.dart                # Team enum (red/blue/purple)
│   ├── user_model.dart          # User data model (with CV aggregates)
│   ├── hex_model.dart           # Hex tile model (lastRunnerTeam only)
│   ├── app_config.dart          # Server-configurable constants (Season, GPS, Scoring, Hex, Timing, Buff)
│   ├── run_session.dart         # Active run session data
│   ├── run_summary.dart         # Completed run (with hexPath, cv)
│   ├── lap_model.dart           # Per-km lap data for CV calculation
│   ├── daily_running_stat.dart  # Daily stats (Warm data)
│   ├── location_point.dart      # GPS point model (active run)
│   └── route_point.dart         # Compact route point (cold storage)
├── providers/
│   ├── app_state_provider.dart  # Global app state (team, user)
│   ├── run_provider.dart        # Run lifecycle & hex capture
│   └── hex_data_provider.dart   # Hex data cache & state
├── screens/
│   ├── team_selection_screen.dart
│   ├── home_screen.dart         # Navigation hub + AppBar (FlipPoints)
│   ├── map_screen.dart          # Hex territory exploration
│   ├── running_screen.dart      # Pre-run & active run tracking
│   ├── leaderboard_screen.dart  # Rankings (Province/District/Zone scope)
│   ├── run_history_screen.dart  # Past runs (Calendar)
│   └── profile_screen.dart      # Manifesto, avatar, stats
├── services/
│   ├── supabase_service.dart    # Supabase client init & RPC wrappers (passes CV to finalize_run)
│   ├── remote_config_service.dart # Server-configurable constants (fallback: server → cache → defaults)
│   ├── config_cache_service.dart # Local JSON cache for remote config
│   ├── hex_service.dart         # H3 hex grid operations
│   ├── location_service.dart    # GPS tracking (uses RemoteConfigService)
│   ├── run_tracker.dart         # Run session & hex capture engine (lap tracking, CV calculation)
│   ├── lap_service.dart         # CV calculation from lap data
│   ├── gps_validator.dart       # Anti-spoofing (GPS + accelerometer, uses RemoteConfigService)
│   ├── accelerometer_service.dart # Accelerometer anti-spoofing (5s no-data warning)
│   ├── storage_service.dart     # Storage interface (abstract)
│   ├── in_memory_storage_service.dart # In-memory (MVP/testing)
│   ├── local_storage_service.dart # SharedPreferences helpers
│   ├── points_service.dart      # Flip points & multiplier calculation
│   ├── season_service.dart      # 40-day season countdown (uses RemoteConfigService)
│   ├── buff_service.dart        # Team-based buff multiplier (frozen during runs)
│   ├── running_score_service.dart # Pace validation for capture
│   ├── app_lifecycle_manager.dart # App foreground/background handling (uses RemoteConfigService)
│   └── data_manager.dart        # Hot/Cold data separation
├── storage/
│   └── local_storage.dart       # SQLite implementation (runs, routes)
├── theme/
│   ├── app_theme.dart           # Colors, typography, animations
│   └── neon_theme.dart          # Neon accent colors (used by route_map)
├── utils/
│   ├── image_utils.dart         # Location marker generation
│   ├── route_optimizer.dart     # Ring buffer + Douglas-Peucker
│   └── lru_cache.dart           # LRU cache for hex data
└── widgets/
    ├── hexagon_map.dart         # Hex grid overlay (GeoJsonSource + FillLayer pattern)
    ├── route_map.dart           # Route display + navigation mode
    ├── smooth_camera_controller.dart # 60fps camera interpolation
    ├── glowing_location_marker.dart  # Team-colored pulsing marker
    ├── flip_points_widget.dart  # Animated flip counter (header)
    ├── season_countdown_widget.dart  # D-day countdown badge
    ├── energy_hold_button.dart  # Hold-to-trigger button
    ├── capturable_hex_pulse.dart # Pulsing effect for capturable hexes
    ├── stat_card.dart           # Statistics card
    └── neon_stat_card.dart      # Neon-styled stat card
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
  String avatar;           // Emoji avatar
  int seasonPoints;        // Preserved when defecting to Purple
  String? manifesto;       // 12-char declaration
  String? homeHexStart;    // H3 index of run start location (self only)
  String? homeHexEnd;      // H3 index of run end location (visible to others)
  double totalDistanceKm;  // Running season aggregate
  double? avgPaceMinPerKm; // Weighted average pace
  double? avgCv;           // Average CV (from runs ≥ 1km)
  int totalRuns;           // Number of completed runs

  /// Stability score (100 - avgCv, clamped 0-100). Higher = better.
  int? get stabilityScore => avgCv == null ? null : (100 - avgCv!).round().clamp(0, 100);
}
```
**Note**: Aggregate fields updated incrementally via `finalize_run()` RPC.
**Home Hex**: Asymmetric visibility - `homeHexStart` for self, `homeHexEnd` for others.

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

---

## Game Mechanics

### Team-Based Buff System
Buff multipliers are calculated daily at midnight GMT+2 via Edge Function:

**RED FLAME:**
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

**PURPLE:** Participation Rate = 1x (<34%), 2x (34-66%), 3x (≥67%)

- **New users** = 1x (default until yesterday's data exists)
- Buff is **frozen** when run starts — no changes mid-run
- Fetched on app launch via `get_user_buff()` RPC

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
- **NO daily flip limit** - same hex can be flipped multiple times per day
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

### Flip Points Calculation
```
flip_points = 1 × buff_multiplier
```
Multiplier fetched on app launch via RPC: `get_user_buff()`

**Server Validation**: Points ≤ hex_count × multiplier (anti-cheat)

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
3. Third-party packages (`package:provider/provider.dart`)
4. Internal imports (`../models/run_session.dart`)

### Widget Construction
- Use `const` constructors wherever possible
- Use `super.key` for widget keys
- Break large widgets into private helper widgets

### State Management (Provider)
- Providers extend `ChangeNotifier`
- Call `notifyListeners()` after state changes
- Services injected via constructor

### Error Handling
- Use `debugPrint()` for logging (not `print()`)
- Use targeted `try-catch` blocks in async methods

---

## Theme & Colors

All colors centralized in `lib/theme/app_theme.dart`.

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
- Follow Provider pattern for state
- Use relative imports for internal files
- Run `flutter analyze` before committing
- Add `///` documentation for public APIs
- Use Supabase RPC for complex queries (multiplier, leaderboard)

### Don't
- Don't use `print()` - use `debugPrint()`
- Don't suppress lint rules without good reason
- Don't put business logic in widgets
- Don't hardcode colors - use `AppTheme`
- Don't create new state management patterns
- Don't store derived/calculated data in database
- Don't create backend API endpoints - use RLS

---

## Supabase Schema (Key Tables)

```sql
users            -- id, name, team, avatar, season_points, manifesto,
                 -- home_hex_start, home_hex_end, total_distance_km, avg_pace_min_per_km,
                 -- avg_cv, total_runs, cv_run_count
hexes            -- id (H3 index), last_runner_team, last_flipped_at (conflict resolution)
runs             -- id, user_id, team_at_run, distance_meters, hex_path[] (partitioned monthly)
run_history      -- id, user_id, run_date, distance_km, duration_seconds, cv (preserved across seasons)
daily_stats      -- id, user_id, date_key, total_distance_km, flip_count (partitioned monthly)
daily_buff_stats -- user_id, date, buff_multiplier, is_elite, is_district_leader, has_province_range
```

**Key RPC Functions:**
- `finalize_run(...)` → batch sync on run completion, accepts `p_cv`, updates user aggregates
- `get_user_buff(user_id)` → get user's current buff multiplier
- `calculate_daily_buffs()` → daily Edge Function to compute all buffs at midnight
- `get_leaderboard(limit)` → ranked users by season_points with CV aggregates
- `app_launch_sync(...)` → pre-patch data on launch with CV fields

---

## Dependencies (Key Packages)

| Package | Purpose |
|---------|---------|
| `provider` | State management |
| `geolocator` | GPS location tracking |
| `mapbox_maps_flutter` | Map rendering |
| `h3_flutter` | Hexagonal grid system |
| `supabase_flutter` | Backend (Auth + DB + Storage) |
| `sqflite` | Local SQLite storage |
| `sensors_plus` | Accelerometer (anti-spoofing) |

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

## Accelerometer Anti-Spoofing

The `AccelerometerService` validates GPS movement against physical device motion.

| Platform | Behavior |
|----------|----------|
| **Real device** | Accelerometer events validate movement |
| **iOS Simulator** | No hardware → graceful fallback to GPS-only (5s warning logged) |
