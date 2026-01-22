# CLAUDE.md - RunStrict (Project Code: 280-Journey)

> Guidelines for AI coding agents working in this Flutter/Dart codebase.

## Project Overview

**RunStrict** is a location-based running game that gamifies territory control through hexagonal maps.

### Core Concept
- **Season**: Fixed **280 days** (Gestation period metaphor)
- **Reset**: On D-Day, all territories and scores are deleted (The Void). Only personal history remains.
- **Teams**: Red (FLAME), Blue (WAVE), Purple (CHAOS - unlocks D-140)

### Key Design
- Hex displays the color of the **last runner** who passed through - NO ownership system
- User location shown as a **person icon inside a hexagon** (team-colored)
- Privacy optimized: No timestamps or runner IDs stored in hexes
- Performance-optimized (no 3D rendering)

### Core Philosophy
| Surface Layer | Hidden Layer |
|--------------|--------------|
| Red vs Blue competition | Connection through rivalry |
| Territory capture | Mutual respect growth |
| Weekly battles | Long-term relationships |
| "Win at all costs" | "We ran together" |

**Tech Stack**: Flutter 3.10+, Dart, Provider (state management), Mapbox, Firebase, H3 (hex grid)

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
├── main.dart                    # App entry point
├── config/
│   └── mapbox_config.dart       # Mapbox API configuration
├── models/
│   ├── team.dart                # Team enum (red/blue/purple)
│   ├── user_model.dart          # User data model
│   ├── hex_model.dart           # Hex tile model (last runner color)
│   ├── crew_model.dart          # Crew & CrewMember models
│   ├── district_model.dart      # Electoral district model
│   ├── run_session.dart         # Running session data
│   ├── daily_running_stat.dart  # Daily stats (Cold/Warm data)
│   └── location_point.dart      # GPS point model
├── providers/
│   ├── app_state_provider.dart  # Global app state
│   ├── running_provider.dart    # Running session state
│   ├── crew_provider.dart       # Crew management state
│   ├── hex_data_provider.dart   # Hex data state
│   └── run_provider.dart        # Run data state
├── screens/
│   ├── team_selection_screen.dart
│   ├── home_screen.dart         # Main navigation hub
│   ├── map_screen.dart          # Hex map view
│   ├── running_screen.dart      # Run screen (pre-run & active tracking)
│   ├── results_screen.dart      # Election-style results
│   ├── crew_screen.dart         # Crew management
│   ├── leaderboard_screen.dart  # Rankings
│   └── run_history_screen.dart  # Past runs (Calendar)
├── services/
│   ├── hex_service.dart         # H3 hex grid operations
│   ├── location_service.dart    # GPS tracking
│   ├── run_tracker.dart         # Run session management
│   ├── gps_validator.dart       # Anti-spoofing validation
│   └── storage_service.dart     # Local storage operations
├── theme/
│   ├── app_theme.dart           # Main theme configuration
│   ├── broadcast_theme.dart     # Election broadcast styling
│   ├── cyberpunk_theme.dart     # Alternative theme
│   └── neon_theme.dart          # Neon accent theme
├── utils/
│   └── image_utils.dart         # Location marker generation
└── widgets/
    ├── hexagon_map.dart         # Hex grid overlay widget
    ├── route_map.dart           # Running route display
    ├── stat_card.dart           # Statistics card
    └── neon_stat_card.dart      # Neon-styled stat card
```

---

## Data Models Reference

### Team Enum
```dart
enum Team {
  red,    // Display: "FLAME" 🔥 - "Passion & Energy" - 1x multiplier
  blue,   // Display: "WAVE" 🌊 - "Trust & Harmony" - 1x multiplier
  purple; // Display: "CHAOS" 💜 - "The Betrayer's Path" - 2x multiplier
}
```

### User Model (Firestore: users/{userId})
```dart
class UserModel {
  String id;
  String name;
  Team team;              // 'red' | 'blue' | 'purple'
  String avatar;
  String? crewId;
  int seasonPoints;       // Reset to 0 when joining Purple
}
```
**Note**: Distance stats calculated from `dailyStats/` on-demand.

### Hex Model (Firestore: hexes/{hexId})
```dart
class HexModel {
  String id;              // H3 hex index
  LatLng center;
  Team? lastRunnerTeam;   // null = neutral
}
```
**Important**: No timestamps, no runner IDs - privacy optimized.

### Crew Model (Firestore: crews/{crewId})
```dart
class CrewModel {
  String id;
  String name;
  Team team;
  List<String> memberIds; // Max 12 (Red/Blue) or 24 (Purple)

  bool get isPurple => team == Team.purple;
  int get multiplier => isPurple ? 2 : 1;
  int get maxMembers => isPurple ? 24 : 12;
}
```
**Note**: Stats calculated from `runs/` and `dailyStats/` on-demand.

### DailyRunningStat (Firestore: dailyStats/{dateKey}/{userId})
```dart
class DailyRunningStat {
  String userId;
  String dateKey;         // 'YYYY-MM-DD'
  double totalDistanceKm;
  int totalDurationSeconds;
  double avgPaceSeconds;
  int flipCount;
}
```

---

## Game Mechanics

### Crew Economy: Winner-Takes-All
- **Red/Blue Crew**: Max **12 members**
- **Purple Crew**: Max **24 members** (larger to accommodate defectors)
- **Pool**: Sum of all members' flip points
- **Winner**: Only **Top 4** members split the pool
- **Loser**: Remaining members get **0 Points**

### Purple Crew (The Protocol of Chaos)
- **Unlock**: D-140 (halfway point)
- **Entry Cost**: Total Season Score Reset to **0**
- **Benefit**: **2x point multiplier**
- **Rule**: Irreversible - cannot return to Red/Blue

### Hex Capture Rules
- Must be running at valid pace (< 8:00 min/km)
- Hex color changes to runner's team color
- Purple tiles pulse slowly (visual indicator)

### Tie-Breaking Protocol
1. Flip Count (Quantity)
2. Achievement Timestamp (Time Priority)
3. Equal Division (The Blood Split)

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
Neutral:  #2A3550 @ 0.15 opacity, Gray border (#6B7280), 1px
Blue:     #33A4FF @ 0.3 opacity, Blue border, 1.5px
Red:      #FF335F @ 0.3 opacity, Red border, 1.5px
Purple:   #A78BFA @ 0.3 opacity (pulsing), Purple border, 1.5px
Current:  Team color @ 0.5 opacity, 2.5px border
```

---

## Do's and Don'ts

### Do
- Use `const` constructors for immutable widgets
- Follow Provider pattern for state
- Use relative imports for internal files
- Run `flutter analyze` before committing
- Add `///` documentation for public APIs

### Don't
- Don't use `print()` - use `debugPrint()`
- Don't suppress lint rules without good reason
- Don't put business logic in widgets
- Don't hardcode colors - use `AppTheme`
- Don't create new state management patterns

---

## Firestore Collections

```
users/{userId}
  - name, team, crewId, seasonPoints, avatar

crews/{crewId}
  - name, team, memberIds[]  # Max 12 (Red/Blue) or 24 (Purple)

hexes/{hexId}
  - lastRunnerTeam: 'red' | 'blue' | 'purple' | null

runs/{runId}
  - userId, teamAtRun, startTime, endTime
  - distance, avgPace, hexesColored

dailyStats/{dateKey}/{userId}
  - totalDistanceKm, totalDurationSeconds
  - avgPaceSeconds, flipCount
```

---

## Dependencies (Key Packages)

| Package | Purpose |
|---------|---------|
| `provider` | State management |
| `geolocator` | GPS location tracking |
| `mapbox_maps_flutter` | Map rendering |
| `h3_flutter` | Hexagonal grid system |
| `firebase_core` | Firebase integration |
| `cloud_firestore` | Database |
| `sqflite` | Local SQLite storage |
