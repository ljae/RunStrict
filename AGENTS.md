# AGENTS.md - RunStrict (The 280-Day Journey)

> Guidelines for AI coding agents working in this Flutter/Dart codebase.

## Project Overview

**RunStrict** is a location-based running game that gamifies territory control through hexagonal maps.

### Core Concept
- **Season**: 280 days (fixed duration)
- **Teams**: Red (FLAME), Blue (WAVE), Purple (CHAOS - unlocks D-140)
- **Hex System**: Displays color of **last runner** - no ownership
- **D-Day Reset**: All territories and scores wiped via TRUNCATE/DROP (The Void)
- **Crew Benefit**: Yesterday's Check-in Multiplier (yesterday's active members = today's multiplier)

### Key Design Principles
- Privacy optimized: No timestamps or runner IDs stored in hexes
- User location shown as **person icon inside a hexagon** (team-colored)
- Performance-optimized (no 3D rendering)
- Serverless architecture: No backend API server (Supabase RLS handles auth)
- **No Realtime/WebSocket**: All data synced on app launch, OnResume, and run completion ("The Final Sync")
- **Server verified**: Points calculated by client, validated by server (≤ hex_count × multiplier)

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
├── main.dart                    # App entry, Provider setup
├── config/
│   ├── mapbox_config.dart       # Mapbox API configuration
│   └── supabase_config.dart     # Supabase URL & anon key
├── models/
│   ├── team.dart                # Team enum (red/blue/purple)
│   ├── user_model.dart          # User with seasonPoints
│   ├── hex_model.dart           # Hex with lastRunnerTeam only
│   ├── crew_model.dart          # Crew with maxMembers/leaderId
│   ├── run_session.dart         # Active run session data
│   ├── run_summary.dart         # Completed run (with hexPath)
│   ├── daily_running_stat.dart  # Daily stats (Warm data)

│   ├── location_point.dart      # GPS point (active run)
│   └── route_point.dart         # Compact route point (cold storage)
├── providers/
│   ├── app_state_provider.dart  # Global app state (team, user)
│   ├── run_provider.dart        # Run lifecycle & hex capture
│   ├── crew_provider.dart       # Crew management
│   └── hex_data_provider.dart   # Hex data cache & state
├── screens/
│   ├── team_selection_screen.dart  # Onboarding / new season
│   ├── home_screen.dart         # Navigation hub + AppBar (FlipPoints)
│   ├── map_screen.dart          # Hex territory exploration
│   ├── running_screen.dart      # Pre-run & active run tracking
│   ├── crew_screen.dart         # Crew management
│   ├── leaderboard_screen.dart  # Rankings (ALL/City/Zone scope)
│   ├── run_history_screen.dart  # Past runs (Calendar)
│   └── profile_screen.dart      # Manifesto, avatar, stats
├── services/
│   ├── supabase_service.dart    # Supabase client init & RPC wrappers
│   ├── hex_service.dart         # H3 hex grid operations
│   ├── location_service.dart    # GPS tracking
│   ├── run_tracker.dart         # Run session & hex capture engine
│   ├── gps_validator.dart       # Anti-spoofing (GPS + accelerometer)
│   ├── storage_service.dart     # Storage interface (abstract)
│   ├── in_memory_storage_service.dart # In-memory (MVP/testing)
│   ├── local_storage_service.dart # SharedPreferences helpers
│   ├── points_service.dart      # Flip points & multiplier calculation
│   ├── season_service.dart      # 280-day season countdown
│   ├── crew_multiplier_service.dart # Yesterday's check-in multiplier (daily batch)
│   ├── running_score_service.dart # Pace validation for capture
│   └── data_manager.dart        # Hot/Cold data separation
├── storage/
│   └── local_storage.dart       # SQLite implementation
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
3. Third-party packages (`package:provider/provider.dart`)
4. Internal imports (relative paths `../models/run_session.dart`)

```dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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

### State Management (Provider)

- Providers extend `ChangeNotifier`
- Call `notifyListeners()` after state changes
- Services injected via constructor

```dart
class RunProvider with ChangeNotifier {
  final LocationService _locationService;

  RunProvider({required LocationService locationService})
      : _locationService = locationService;

  RunSession? _activeRun;
  RunSession? get activeRun => _activeRun;

  Future<void> startRun() async {
    // ... logic
    notifyListeners();
  }
}
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

All colors and styles are centralized in `lib/theme/app_theme.dart`.

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

### Crew Economy: Yesterday's Check-in Multiplier
```dart
// Multiplier = number of crew members who ran YESTERDAY
// Calculated daily at midnight GMT+2 via Edge Function
// Red/Blue: Max 12 members = 12x potential
// Purple: Max 24 members = 24x potential
// Solo runner or new user/crew = 1x (default)
final multiplier = yesterdayActiveMembers; // Fetched on app launch
final points = flipsEarned * multiplier;
```

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

// NO daily flip limit - same hex can be flipped multiple times per day
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

---

## Common Patterns

### Screen with Provider
```dart
class RunningScreen extends StatelessWidget {
  const RunningScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<RunProvider>(
      builder: (context, runProvider, child) {
        return // ... UI using runProvider
      },
    );
  }
}
```

### Supabase RPC Call
```dart
// Call a PostgreSQL function via Supabase
final result = await supabase.rpc('get_crew_multiplier', params: {
  'p_crew_id': crewId,
});
```

### Async Initialization
```dart
@override
void initState() {
  super.initState();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    context.read<MyProvider>().initialize();
  });
}
```

---

## Do's and Don'ts

### Do
- Use `const` constructors for immutable widgets
- Follow the existing Provider pattern for state
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
- Don't create new state management patterns - stick with Provider
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
