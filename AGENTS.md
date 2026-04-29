# AGENTS.md — RunStrict (The 40-Day Journey)

> Project overview + critical architecture rules for AI agents working in this codebase.
> For detail, follow the links — do not read every doc.

**Tech**: Flutter ≥ 3.27 · Dart SDK ≥ 3.11 · Riverpod 3.0 (manual providers, NO codegen) · Mapbox · Supabase (PostgreSQL + RLS) · H3 hex grid · SQLite v26.

---

## Quick Doc Map

| Need | Read |
|---|---|
| Routing index for AI | [`CLAUDE.md`](./CLAUDE.md) |
| Full doc index | [`docs/INDEX.md`](./docs/INDEX.md) |
| Code style + 500-line file ceiling | [`docs/style/code-style.md`](./docs/style/code-style.md) |
| Do's & Don'ts + pre-edit checklist | [`docs/style/dos-and-donts.md`](./docs/style/dos-and-donts.md) |
| Build / run / test commands | [`docs/style/build-commands.md`](./docs/style/build-commands.md) |
| Riverpod 3.0 rules (MUST follow) | [`riverpod_rule.md`](./riverpod_rule.md) |
| Game mechanics (buff, capture, scoring) | [`docs/01-game-rules.md`](./docs/01-game-rules.md) |
| Screens / widgets / theme / Mapbox | [`docs/02-ui-screens.md`](./docs/02-ui-screens.md) |
| Models / DB schema / RPC / data flow | [`docs/03-data-architecture.md`](./docs/03-data-architecture.md) |
| GPS / sync / battery / remote config | [`docs/04-sync-and-performance.md`](./docs/04-sync-and-performance.md) |
| Production-bug invariants (61 rules) | [`error-fix-history.md`](./error-fix-history.md) |
| Full bug postmortems | [`docs/invariants/fix-archive.md`](./docs/invariants/fix-archive.md) |

---

## Project Overview

**RunStrict** is a location-based running game that gamifies territory control through hexagonal maps.

### Core Concept
- **Season**: Fixed **40 days**; on D-Day all territories and scores are deleted (The Void)
- **Teams**: Red (FLAME), Blue (WAVE), Purple (CHAOS — available anytime)
- **Hex System**: Displays color of **last runner** — no ownership system
- **Buff System**: Team-based multipliers calculated daily (Red 1–4×, Blue 1–3×, Purple 1–3×)
- **Reset**: Only personal run history survives The Void

### Key Design Principles
- Privacy-optimized: no timestamps or runner IDs stored in hexes
- Performance-optimized (no 3D rendering)
- **Serverless**: Supabase RLS + Edge Functions, no backend API server
- **No Realtime/WebSocket**: synced on app launch, OnResume, and run completion ("The Final Sync"). ALL completed runs are uploaded.
- **Server-verified**: client calculates points; server cap-validates `flip_points ≤ hex_count × multiplier`
- **Offline-resilient**: failed syncs retry via `SyncRetryService` (launch, OnResume, next run)
- **Crash recovery**: `run_checkpoint` table saves state on each hex flip

Game mechanics detail → [`docs/01-game-rules.md`](./docs/01-game-rules.md).

---

## Critical Architecture Rules

### Two Data Domains — NEVER Mix (Invariant #7)

**Domain 1 — Running History (client-side, cross-season, never reset)**:
- ALL TIME stats computed from local SQLite `runs.fold()`. Survives season resets.
- Includes: distance, pace, stability, run count, flip points
- Source of truth: `LocalStorage.getAllTimeStats()` or sync `allRuns.fold()`
- Period stats (DAY/WEEK/MONTH/YEAR) also from local SQLite

**Domain 2 — Hexes + TeamScreen + Leaderboard (server-side, season-based, reset each season)**:
- Downloaded on app launch / OnResume via `PrefetchService`
- **Always anchored to home hex** (never GPS for server data)
- Leaderboard: `season_leaderboard_snapshot` (NOT live `users`)
- Includes: hex map base, leaderboard rankings, team stats, buff multiplier

**Only hybrid value**: `PointsService.totalSeasonPoints` = server `season_points` + local unsynced. Used for header FlipPoints.

| Screen | Domain | Rule |
|---|---|---|
| TeamScreen | Server (season) | Server RPCs only, home-hex anchored |
| LeaderboardScreen | Server (season) | `season_leaderboard_snapshot` — not live `users` |
| MapScreen display | Server + GPS | GPS hex for camera/territory when outside province |
| ALL TIME stats | **Client** | Local SQLite — NOT `UserModel` server fields |
| Header FlipPoints | Hybrid | `PointsService.totalSeasonPoints` |

### Location Domain Separation (Home vs GPS)

| Concern | Anchor | Source |
|---|---|---|
| Hex snapshot download | **Home hex** | `PrefetchService.homeHex` / `homeHexProvince` (Res 5) |
| Leaderboard filtering | **Home hex** | `LeaderboardProvider.filterByScope()` |
| TeamScreen territory | **Home hex** | `PrefetchService.homeHexDistrict` (Res 6) / `homeHex` |
| MapScreen camera (when outside province) | **GPS hex** | `PrefetchService.gpsHex` |
| Hex capture | **Disabled** when outside province | Floating banner on MapScreen |

### OnResume Refresh (Invariant #5)

When app returns to foreground, `AppLifecycleManager` triggers all server-derived providers:
hex map (PrefetchService), leaderboard, sync retries, buff, points baseline. Skipped during active runs (`_isStopping` flag). Throttled to once per 30s. **Adding a new server provider? Add it to `_onAppResume()` too.**

### Hex Data Architecture (Invariants #3, #4, #16, #44, #52)

`HexRepository` is the **single source of truth** (no duplicate caches):
- `_hexCache` (LRU) holds the snapshot
- `_localOverlayHexes` (plain Map, eviction-immune) holds today's own flips
- Always read via `getHex()` which merges both — never raw `_hexCache.get()`
- `clearAll()` is for **province change only** — never season reset (territory persists), never day rollover

### Timezone Architecture (Invariant #11)

| Domain | Timezone | Source |
|---|---|---|
| Running history (SQLite, calendar display) | **Device local** | `DateTime.now()` |
| Season countdown, D-day, currentSeasonDay | **GMT+2** | `SeasonService.serverTime` |
| Daily buff "yesterday" | **GMT+2** | `Gmt2DateUtils.todayGmt2.subtract(Duration(days: 1))` |
| Hex snapshots (`snapshot_date`) | **GMT+2** | `Gmt2DateUtils.todayGmt2String` |
| `run_date` in `run_history` | **GMT+2** | Server: `end_time AT TIME ZONE 'Etc/GMT-2'` |
| Fallback dates in server-domain models | **GMT+2** | `Gmt2DateUtils.todayGmt2` (NEVER `DateTime.now()`) |

Full timezone rules + when local-time is correct → [`docs/03-data-architecture.md`](./docs/03-data-architecture.md) § Timezone Architecture.

### Riverpod 3.0 Rules

**MUST** follow [`riverpod_rule.md`](./riverpod_rule.md). TL;DR:
- Manual provider definitions (no codegen / build_runner)
- `Notifier<T>` / `AsyncNotifier<T>` (NOT `StateNotifier`)
- Unified `Ref` (no type parameters); `ConsumerWidget` / `ConsumerStatefulWidget`
- Always check `ref.mounted` after async ops in notifiers, `context.mounted` in widgets
- Use `select()` for selective rebuilds; exhaustive `switch` on `AsyncValue` states

---

## Project Structure (lib/)

```
lib/
├── main.dart                # ProviderScope entry
├── app/                     # Root widget, routes, theme re-export
├── features/
│   ├── auth/                # login, register, team selection, app_init AsyncNotifier
│   ├── run/                 # active running session (run_provider, run_tracker, gps_validator)
│   ├── map/                 # hex map (hex_data_provider, hexagon_map, route_map)
│   ├── leaderboard/         # rankings
│   ├── team/                # team stats, traitor gate, buff
│   ├── profile/
│   └── history/             # run history, calendar
├── core/
│   ├── config/              # h3, mapbox, supabase, auth
│   ├── storage/             # SQLite v26 (runs, routes, laps, run_checkpoint, hex_cache, leaderboard_cache, prefetch_meta, sync_queue)
│   ├── utils/               # gmt2_date, lru_cache, route_optimizer
│   ├── widgets/             # energy_hold_button, flip_points, season_countdown
│   ├── services/            # supabase, remote_config, season, lifecycle, sync_retry, points, buff, prefetch, hex
│   └── providers/           # infrastructure, user_repository, points
├── data/
│   ├── models/              # team, user, hex, run, lap, location_point, app_config, team_stats
│   └── repositories/        # hex, leaderboard, user (singletons)
└── theme/                   # app_theme.dart
```

Full layered detail → [`docs/03-data-architecture.md`](./docs/03-data-architecture.md).

---

## Hard Rules — Always

- **Riverpod 3.0 only.** No `ChangeNotifier`/`StateNotifier`/legacy `provider`.
  - Exception: `_RouterRefreshNotifier` (GoRouter adapter, see `lib/app/routes.dart`).
- **Logging**: `debugPrint()` — never `print()`.
- **File size**: new/substantially-modified `.dart`/`.kt`/`.swift` files ≤ 500 lines. See [`docs/style/code-style.md`](./docs/style/code-style.md).
- **Before commit**: `flutter analyze` (0 issues) + `./scripts/post-revision-check.sh` (auto pre-commit hook).
- **Before any edit**: search [`error-fix-history.md`](./error-fix-history.md) for related invariants.
- **Two data domains**: never mix (Invariant #7).
- **OnResume**: every server-derived provider must be refreshed in `_onAppResume()` (Invariant #5).
- **Timezone**: GMT+2 for game logic, device-local for run history display (Invariant #11).
- **Hex repo**: always `getHex()`, never raw `_hexCache.get()` (Invariant #16).

---

## Pre-Edit / Pre-Commit Tools

```bash
./scripts/pre-edit-check.sh                   # Interactive checklist
./scripts/pre-edit-check.sh --search <term>   # Grep error history (index + archive)
./scripts/post-revision-check.sh              # Full audit (auto pre-commit hook)
```

Detailed checklist → [`docs/style/dos-and-donts.md`](./docs/style/dos-and-donts.md).
