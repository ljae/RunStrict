# RunStrict Development Specification: "The 40-Day Journey"

> **App Name**: RunStrict (The 40-Day Journey)
> **Tech Stack**: Flutter 3.10+, Dart, Riverpod 3.0, Mapbox, Supabase (PostgreSQL), H3, SQLite v15
> **Architecture**: Serverless (Flutter → Supabase RLS, no backend API server)

---

## Quick Reference

A location-based running game that gamifies territory control through hexagonal maps.

- **Season**: Fixed 40 days → D-Day reset (The Void)
- **Teams**: Red (FLAME), Blue (WAVE), Purple (CHAOS - available anytime, irreversible)
- **Hex System**: Displays color of **last runner** — no ownership. H3 Resolution 9.
- **Sync Model**: No Realtime/WebSocket. Data synced on app launch, OnResume, and run completion ("The Final Sync")
- **Scoring**: `flip_points = hexes_flipped × buff_multiplier` — server cap-validated (≤ hex_count × multiplier)
- **Privacy**: No runner IDs stored in hexes. Minimal timestamps for conflict resolution only.

---

## Critical Architecture Rules

### Two Data Domains (NEVER mix)

| Domain | Source | Trigger | Used By |
|--------|--------|---------|---------|
| **Snapshot** | Server → Local (read-only) | App launch, OnResume | TeamScreen, LeaderboardScreen, ALL TIME stats |
| **Live** | Local creation → Upload | Running, Final Sync | FlipPointsWidget, RunHistory period stats |

**Only hybrid value**: `PointsService.totalSeasonPoints` = server `season_points` + local unsynced.

### Location Domain Separation

| Concern | Anchor |
|---------|--------|
| Server data (hex snapshot, leaderboard, team stats) | **Home hex** (always) |
| MapScreen camera/territory display | **GPS hex** (when outside province) |
| Hex capture | **Disabled** when outside province |

→ Full details: [docs/03-data-architecture.md](./docs/03-data-architecture.md#two-data-domains)

---

## Documentation Manuals

Read this INDEX first, then the relevant manual for your task.

| Manual | Content | When to Read |
|--------|---------|-------------|
| [01-game-rules.md](./docs/01-game-rules.md) | Season, teams, buff system, hex capture, scoring, CV/stability, leaderboard, purple defection, D-Day reset | Buff changes, scoring logic, team mechanics, game constant changes |
| [02-ui-screens.md](./docs/02-ui-screens.md) | Navigation, all screen specs, widget library, theme/colors, Mapbox rendering, animations | Screen redesigns, widget changes, theme updates, Mapbox layers, layout bugs |
| [03-data-architecture.md](./docs/03-data-architecture.md) | Client models (Dart), DB schema (SQL), repositories, data flow, Two Data Domains, SQLite, tech stack | Adding/modifying models, DB changes, sync bugs, RPC implementation, data flow questions |
| [04-sync-and-performance.md](./docs/04-sync-and-performance.md) | The Final Sync, GPS config, signal processing, battery optimization, remote config system | GPS tuning, sync strategy, performance optimization, remote config changes |
| [05-changelog.md](./docs/05-changelog.md) | Development roadmap, success metrics, session-by-session changelog | Historical context, "why was X designed this way?" |

### Task → Manual Routing

| Task Type | Read This |
|-----------|-----------|
| Buff multiplier, scoring formula, team rules | `01-game-rules.md` |
| Screen layout, widget, theme, Mapbox visual | `02-ui-screens.md` |
| Model field, DB schema, RPC, repository, data flow | `03-data-architecture.md` |
| GPS, sync, battery, remote config, performance | `04-sync-and-performance.md` |
| Past decisions, roadmap, changelog | `05-changelog.md` |
| Riverpod patterns, state management | [`riverpod_rule.md`](./riverpod_rule.md) |
| Code style, build commands, do's/don'ts | [`AGENTS.md`](./AGENTS.md) |
| **Multiple domains** | INDEX + both relevant manuals |

---

## Project Structure

```
lib/
├── main.dart                    # App entry point, ProviderScope setup
├── app/                         # Root app widget, routes, theme re-export
├── features/
│   ├── auth/                    # Login, registration, team selection
│   │   ├── screens/             # login, profile_register, season_register, team_selection
│   │   ├── providers/           # app_state (Notifier), app_init (AsyncNotifier)
│   │   └── services/            # auth_service
│   ├── run/                     # Active running session
│   │   ├── screens/             # running_screen
│   │   ├── providers/           # run_provider (Notifier)
│   │   └── services/            # run_tracker, gps_validator, accelerometer, location, running_score, lap, voice_announcement
│   ├── map/                     # Hex map display
│   │   ├── screens/             # map_screen
│   │   ├── providers/           # hex_data_provider (Notifier)
│   │   └── widgets/             # hexagon_map, route_map, smooth_camera, glowing_marker
│   ├── leaderboard/             # Rankings
│   ├── team/                    # Team stats, traitor gate
│   ├── profile/                 # User profile
│   └── history/                 # Run history, calendar
├── core/
│   ├── config/                  # h3, mapbox, supabase, auth configuration
│   ├── storage/                 # SQLite v15 (runs, routes, laps, run_checkpoint)
│   ├── utils/                   # country, gmt2_date, lru_cache, route_optimizer
│   ├── widgets/                 # energy_hold_button, flip_points, season_countdown
│   ├── services/                # supabase, remote_config, config_cache, season, ad, lifecycle, sync_retry, points, buff, timezone, prefetch, hex, storage_service, local_storage_service
│   └── providers/               # infrastructure, user_repository, points
├── data/
│   ├── models/                  # team, user, hex, run, lap, location_point, app_config, team_stats
│   └── repositories/            # hex, leaderboard, user
└── theme/
    └── app_theme.dart           # Colors, typography, animations
```

---

## Key Packages

| Package | Purpose |
|---------|---------|
| `flutter_riverpod` / `hooks_riverpod` | State management (Riverpod 3.0, NO code gen) |
| `go_router` | Declarative routing |
| `geolocator` | GPS location tracking |
| `mapbox_maps_flutter` | Map rendering |
| `h3_flutter` | Hexagonal grid system |
| `supabase_flutter` | Backend (Auth + DB + Storage) |
| `sqflite` | Local SQLite storage |
| `sensors_plus` | Accelerometer (anti-spoofing) |
| `connectivity_plus` | Network connectivity check |
| `google_mobile_ads` | Google AdMob banner ads |

---

## Key RPC Functions

| Function | Purpose |
|----------|---------|
| `finalize_run(...)` | Accept client flip_points with cap validation, update live hexes, store district_hex |
| `get_user_buff(user_id)` | Get user's current buff multiplier |
| `calculate_daily_buffs()` | Daily cron: compute all buffs at midnight GMT+2 |
| `build_daily_hex_snapshot()` | Daily cron: build tomorrow's hex snapshot |
| `get_hex_snapshot(parent_hex, date)` | Download hex snapshot for prefetch |
| `get_leaderboard(limit)` | Ranked users from `season_leaderboard_snapshot` |
| `app_launch_sync(...)` | Pre-patch data on launch |

---

## Related Configuration Files

| File | Purpose |
|------|---------|
| [`AGENTS.md`](./AGENTS.md) | AI coding guidelines: code style, build commands, patterns, do's/don'ts |
| [`riverpod_rule.md`](./riverpod_rule.md) | Riverpod 3.0 state management rules (MUST follow) |
| [`CLAUDE_INTEGRATION_GUIDE.md`](./CLAUDE_INTEGRATION_GUIDE.md) | Claude Code environment setup guide |
| [`docs/`](./docs/) | Detailed manual files (see table above) |
