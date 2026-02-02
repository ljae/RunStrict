# RunStrict - The 40-Day Journey

**"우리는 같은 길을 달린다"** (We run the same path)

A location-based running game that gamifies territory control through hexagonal maps. Run to flip territories, compete with rival teams, and climb the leaderboard during 40-day seasons.

## Core Concept

- **Season**: 40 days (fixed duration)
- **Teams**: Red (FLAME), Blue (WAVE), Purple (CHAOS - available anytime)
- **Hex System**: Shows the color of the **last runner** - no permanent ownership
- **D-Day Reset**: All territories and scores wiped (The Void)
- **Buff System**: Team-based multipliers calculated daily

## Key Features

### Team-Based Competition
- Choose Red Team or Blue Team at season start
- Switch to Purple (CHAOS) anytime - **irreversible** for the season
- Points are **preserved** when defecting to Purple

### Hexagonal Territory System
- H3 resolution 9 hexes (~175m edge length)
- Hex displays last runner's team color
- "Flip" = changing hex color from opponent to yours
- Conflict resolution: Later run end-time wins

### GPS Running Tracker
- Real-time distance, pace, and time tracking
- Pace validation: Must run < 8 min/km to capture hexes
- Speed cap: 25 km/h max (anti-spoofing)
- GPS accuracy requirement: ≤ 50m
- Accelerometer verification on real devices

### Buff System (Team Multipliers)
| Team | Scenario | Multiplier |
|------|----------|------------|
| RED Elite | Normal / District / Province / Both | 2x / 3x / 3x / 4x |
| RED Common | Normal / District / Province / Both | 1x / 1x / 2x / 2x |
| BLUE | Normal / District / Province / Both | 1x / 2x / 2x / 3x |
| PURPLE | Participation Rate (<34% / 34-66% / ≥67%) | 1x / 2x / 3x |

### Scoring
- **Flip Points** = hexes flipped × buff multiplier
- Points validated server-side (≤ hex_count × multiplier)
- CV (Coefficient of Variation) tracks pace consistency
- Stability Score = 100 - CV (higher = better)

### Leaderboard
- Scopes: Province, District, Zone
- Real-time rankings
- Stability score color coding (Green ≥80, Yellow 50-79, Red <50)

## Tech Stack

| Layer | Technology |
|-------|------------|
| **Frontend** | Flutter 3.10+, Dart |
| **State Management** | Provider |
| **Maps** | Mapbox GL |
| **Hex Grid** | H3 (resolution 9) |
| **Backend** | Supabase (PostgreSQL + RLS) |
| **Local Storage** | SQLite (sqflite) |
| **Sensors** | Geolocator, sensors_plus |

## Project Structure

```
lib/
├── main.dart                    # App entry, Provider setup
├── config/                      # Mapbox & Supabase config
├── models/                      # Data models (User, Hex, Run, Lap, etc.)
├── providers/                   # State management (AppState, Run, HexData)
├── screens/                     # UI screens
├── services/                    # Business logic & API
├── theme/                       # Colors, typography
├── utils/                       # Utilities (LRU cache, route optimizer)
└── widgets/                     # Reusable UI components

supabase/
├── migrations/                  # Database schema migrations
└── functions/                   # Edge Functions

test/                            # Unit & widget tests
test_data/                       # Seed data for testing
```

## Getting Started

### Prerequisites
- Flutter 3.10+
- Xcode (for iOS)
- Android Studio (for Android)
- Supabase project

### Development
```bash
flutter pub get          # Install dependencies
flutter run              # Run on connected device
flutter analyze          # Static analysis
flutter test             # Run tests
```

### Build
```bash
flutter build ios        # iOS release
flutter build apk        # Android release
flutter build macos      # macOS release
```

### GPS Simulation (iOS Simulator)
```bash
./simulate_run.sh        # Simulate a 2km run around Apple Park
```

## Architecture Highlights

### No Real-time Updates
- Data synced on: App launch, OnResume, Run completion ("The Final Sync")
- No WebSocket connections during runs
- Battery-optimized GPS polling at 0.5 Hz

### Server-Verified Scoring
- Points calculated client-side
- Validated server-side: points ≤ hex_count × multiplier
- Prevents cheating while enabling offline runs

### Remote Configuration
- 50+ game constants server-configurable
- Fallback chain: Server → Cache → Defaults
- Config frozen during active runs

### Privacy-Optimized Hex Storage
- No timestamps or runner IDs stored in hexes
- Only `last_runner_team` and `last_flipped_at` (for conflict resolution)

## Season Flow

```
D-40 ────────────────────────────────────────────── D-0
 │                                                    │
 ├─ Team Selection (Red/Blue)                         │
 │                                                    │
 ├─ Run → Flip Hexes → Earn Points                    │
 │                                                    │
 ├─ [Optional] Defect to Purple (irreversible)        │
 │                                                    │
 └─────────────────────────────────────────────────── THE VOID
                                                      (All data wiped)
```

## Key Files

| File | Purpose |
|------|---------|
| `lib/models/app_config.dart` | All game constants (Season, GPS, Scoring, Hex, Timing) |
| `lib/services/run_tracker.dart` | Run session & hex capture engine |
| `lib/services/buff_service.dart` | Team-based multiplier calculation |
| `lib/widgets/hexagon_map.dart` | Hex grid rendering (GeoJsonSource + FillLayer) |
| `supabase/migrations/` | Database schema evolution |

## Testing

```bash
flutter test                              # All tests
flutter test test/models/lap_model_test.dart  # Single file
flutter test --coverage                   # With coverage
```

## Contributing

1. Follow existing code patterns (see `AGENTS.md` for style guide)
2. Run `flutter analyze` before committing
3. Add tests for new features
4. Use `///` documentation for public APIs

## License

Proprietary - All rights reserved.

---

**Remember**: "화합은 선언되지 않습니다. 경쟁 속에서 자연스럽게 쌓입니다."
*(Unity is not declared. It naturally accumulates through competition.)*
