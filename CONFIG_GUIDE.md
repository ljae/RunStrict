# RunStrict Configuration Guide

> Single source of truth for all game constants, secrets, and operational parameters.
> Read this before adding, changing, or debugging any configuration value.

---

## Quick Reference — Where Does This Config Value Go?

```
Is it a secret / API key / build-time credential?
  └─ YES → Tier 1 (build-time)     lib/core/config/*.dart  +  --dart-define
  
Is it a game constant that should change without a release?
  └─ YES → Does the SERVER also need to know it?
       ├─ YES (both SQL and client) → Tier 2 (server-driven)  Supabase app_config + AppConfig model
       └─ NO  (client display only) → Tier 2 (client-only)   Supabase app_config (client-only section)

Is it a balance value baked into SQL that can't change in-season?
  └─ YES → Tier 3 (code-only)     SQL migration + AppConfig model (documentation only)
```

---

## Tier 1 — Build-Time Secrets

These are injected at compile time via `--dart-define`. They **never** appear in the binary as plaintext and **never** come from the server.

| Key | File | Description |
|-----|------|-------------|
| `SUPABASE_URL` | `lib/core/config/supabase_config.dart` | Supabase project URL |
| `SUPABASE_ANON_KEY` | `lib/core/config/supabase_config.dart` | Supabase anon key |
| `MAPBOX_PUBLIC_TOKEN` | `lib/core/config/mapbox_config.dart` | Mapbox public access token |
| `REVENUECAT_API_KEY_IOS` | `lib/core/config/revenuecat_config.dart` | RevenueCat iOS key |
| `REVENUECAT_API_KEY_ANDROID` | `lib/core/config/revenuecat_config.dart` | RevenueCat Android key |

### How to Change

```bash
# Pass at build time
flutter run \
  --dart-define=SUPABASE_URL=https://your-project.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=eyJ... \
  --dart-define=MAPBOX_PUBLIC_TOKEN=pk.eyJ...

# Or in launch.json (VS Code) / xcode scheme / CI env vars
```

⚠️ **Never commit secrets to source control.** These should be in CI secrets or a `.env` file outside the repo.

---

## Tier 2 — Server-Driven Runtime Config

These values live in the Supabase `app_config` table and are fetched by `RemoteConfigService` on:
- Cold start (`AppInitNotifier.build()`)
- App resume (`_onAppResume()` in `app_init_provider.dart`)
- Fallback chain: **Server → File cache (`app_config_cache.json`) → Dart defaults**

**Model file:** `lib/data/models/app_config.dart`  
**Service file:** `lib/core/services/remote_config_service.dart`  
**Cache file:** `lib/core/services/config_cache_service.dart`

### Freeze Rule

Config is **frozen during active runs** via `RemoteConfigService().freezeForRun()`.
It snaps back on `unfreezeAfterRun()`. This ensures a run uses consistent parameters from start to finish. Never read live config values inside a running session — use `RemoteConfigService().configSnapshot`.

### 2a — Truly Server-Shared (SQL reads these from app_config)

These values are used by BOTH Dart client code AND Supabase SQL functions.  
Changing them in `app_config` affects both sides simultaneously.

| Field | Sub-config | SQL Function(s) | Default |
|-------|------------|-----------------|---------|
| `durationDays` | `seasonConfig` | `handle_season_transition()` | 40 |
| `startDate` | `seasonConfig` | `handle_season_transition()`, `app_launch_sync()` | null (set per season) |
| `seasonNumber` | `seasonConfig` | `handle_season_transition()`, `app_launch_sync()` | 1 |

#### How to Roll a New Season

1. Update `app_config` in Supabase:
   ```sql
   UPDATE app_config
   SET config_data = jsonb_set(
     jsonb_set(
       jsonb_set(config_data, '{seasonConfig,seasonNumber}', '2'),
       '{seasonConfig,startDate}', '"2026-04-01"'
     ),
     '{seasonConfig,durationDays}', '40'
   )
   WHERE id = 1;
   ```
2. The `handle_season_transition()` SQL function reads these values directly.
3. No app release required.

### 2b — Client-Only (Dart reads app_config; SQL does NOT)

These live in `app_config` for hot-update convenience, but SQL functions do NOT read them.  
Changing them affects only the Dart client.

| Field | Sub-config | Used by | Default |
|-------|------------|---------|---------|
| `serverTimezoneOffsetHours` | `seasonConfig` | `Gmt2DateUtils`, `SeasonService`, `TimezoneConfig` | 2 |
| `maxSpeedMps` | `gpsConfig` | `GpsValidator` | 6.94 m/s (25 km/h) |
| `minSpeedMps` | `gpsConfig` | `GpsValidator` | 0.3 m/s |
| `maxAccuracyMeters` | `gpsConfig` | `GpsValidator` | 50 m |
| `maxAltitudeChangeMps` | `gpsConfig` | `GpsValidator` | 5 m/s |
| `maxJumpDistanceMeters` | `gpsConfig` | `GpsValidator` | 100 m |
| `movingAvgWindowSeconds` | `gpsConfig` | `RunTracker` | 20 s |
| `maxCapturePaceMinPerKm` | `gpsConfig` | `RunTracker` | 8.0 min/km |
| `pollingRateHz` | `gpsConfig` | `LocationService` | 0.5 Hz |
| `minTimeBetweenPointsMs` | `gpsConfig` | `LocationService` | 1500 ms |
| `baseResolution` | `hexConfig` | `H3Config`, `RunTracker` | 9 |
| `zoneResolution` | `hexConfig` | `H3Config`, scope UI | 8 |
| `districtResolution` | `hexConfig` | `H3Config`, scope UI | 6 |
| `provinceResolution` | `hexConfig` | `H3Config`, scope UI | 5 |
| `captureCheckDistanceMeters` | `hexConfig` | `RunTracker` | 20 m |
| `maxCacheSize` | `hexConfig` | `HexRepository` | 4000 |
| `accelerometerSamplingPeriodMs` | `timingConfig` | `AccelerometerService` | 200 ms |
| `refreshThrottleSeconds` | `timingConfig` | `PrefetchService`, resume logic | 30 s |

> **`serverTimezoneOffsetHours` WARNING:** This shifts client-side Domain A behavior (buffs display,
> countdown, run_date derivation) but does **NOT** change SQL timezone. All RPCs independently
> hardcode `AT TIME ZONE 'Etc/GMT-2'`. See [Changing the Server Timezone](#changing-the-server-timezone).

#### How to Update a Client-Only Value

```sql
-- Example: loosen GPS accuracy requirement from 50m → 80m
UPDATE app_config
SET config_data = jsonb_set(config_data, '{gpsConfig,maxAccuracyMeters}', '80')
WHERE id = 1;
```

Next time any user resumes the app, they pick up the new value.  
Running sessions are protected by the freeze.

---

## Tier 3 — Code-Only (Hardcoded in SQL / Dart)

These values cannot be changed via `app_config`. They are baked into SQL migrations or Dart constants.  
The `BuffConfig` Dart model documents them for reference but **does not control** SQL behavior.

### Buff Multipliers (Hardcoded in SQL)

| Team / Tier | Scenario | Multiplier | SQL Function |
|-------------|----------|------------|-------------|
| RED Elite | No wins | 2× | `get_user_buff()`, `calculate_daily_buffs()` |
| RED Elite | District win | 3× | ← same |
| RED Elite | Province win | 3× | ← same |
| RED Elite | District + Province | 4× | ← same |
| RED Common | No wins / District win | 1× | ← same |
| RED Common | Province win / Both | 2× | ← same |
| BLUE | No wins | 1× | ← same |
| BLUE | District win | 2× | ← same |
| BLUE | Province win | 2× | ← same |
| BLUE | District + Province | 3× | ← same |
| PURPLE | Participation < 30% | 1× | ← same |
| PURPLE | Participation 30–59% | 2× | ← same |
| PURPLE | Participation ≥ 60% | 3× | ← same |
| RED Elite threshold | Top percentile | 20% | `calculate_daily_buffs()` |

**To change a buff value:** Write a new SQL migration updating `get_user_buff()` and `calculate_daily_buffs()`.  
Also update `BuffConfig.defaults()` in `lib/data/models/app_config.dart` to keep documentation in sync.

### Server Timezone (Hardcoded in SQL)

`'Etc/GMT-2'` appears in every date-sensitive RPC. This is **not** read from `app_config`.

```
-- Pattern found in ALL of these functions:
AT TIME ZONE 'Etc/GMT-2'
```

Affected functions: `calculate_daily_buffs`, `get_user_buff`, `build_daily_hex_snapshot`,
`get_leaderboard`, `finalize_run`, `handle_season_transition`, `app_launch_sync`.

See [Changing the Server Timezone](#changing-the-server-timezone) for the full procedure.

---

## Fallback Chain

```
RemoteConfigService.refresh()
  │
  ├─[success]─→ AppConfig.fromJson(serverResponse) ──→ used live + written to cache file
  │
  └─[failure]─→ ConfigCacheService.load()
                 │
                 ├─[cache hit]─→ AppConfig.fromJson(cachedJson) ──→ used for this session
                 │
                 └─[cache miss]─→ AppConfig.defaults() ──────────→ hardcoded Dart fallback
```

The Dart defaults in `AppConfig.defaults()` are the **last line of defense**. They should always match production intent. If you change a default, also update `app_config` in Supabase.

---

## Changing the Server Timezone

> **This is a two-step operation. Missing step 2 causes silent date drift.**

Suppose you want to move from GMT+2 to GMT+3:

**Step 1 — Update app_config (affects Dart client):**
```sql
UPDATE app_config
SET config_data = jsonb_set(config_data, '{seasonConfig,serverTimezoneOffsetHours}', '3')
WHERE id = 1;
```

**Step 2 — Write a migration to update ALL RPCs (affects SQL server behavior):**
```sql
-- Find all occurrences first:
-- grep -r "Etc/GMT-2" supabase/migrations/

-- Then write a new migration replacing each function body with 'Etc/GMT-3'
-- See: supabase/migrations/ for the latest versions of each function
```

⚠️ **Both steps are required.** After step 1 only: client shows GMT+3, server computes GMT+2 — leaderboard, buff calc, and hex snapshots will drift by 1 hour at midnight.

---

## Config Architecture Decision Log

### Why BuffConfig exists but doesn't control SQL

`BuffConfig` in `AppConfig` is **documentation-only**. A previous migration
(`20260221000000_config_driven_buff_multipliers.sql`) attempted to make buff SQL read from
`app_config`, but this was superseded by `20260306000003_province_win_scoped_to_res5.sql` which
hardcoded the values again while adding province-win logic.

**Decision (Oracle):** Do not restore config-driven SQL for buffs. It's a maintenance trap —
it requires keeping Dart defaults, app_config JSON, and SQL fallbacks all in sync. The values
rarely change and are balance decisions, not operational tuning. Tier 3 is the right home.

### Why serverTimezoneOffsetHours is client-only

Adding a SQL lookup for timezone on every RPC invocation adds latency and a failure mode.
The server timezone almost never changes. Hardcoding `'Etc/GMT-2'` is explicit and reviewable.
The client offset is useful for making Domain A utilities timezone-aware without SQL coupling.

### Why config refreshes on resume (not just cold start)

Before this change, a 3-day-old device would use cached config from 3 days ago. Season start
date, duration, and GPS thresholds could be stale. `_onAppResume()` now calls
`RemoteConfigService().refresh()` before `PrefetchService().refresh()` so all downstream
services see fresh config.

---

## Key Files at a Glance

| File | Purpose |
|------|---------|
| `lib/data/models/app_config.dart` | `AppConfig` + all sub-configs with defaults + JSON serialization |
| `lib/core/services/remote_config_service.dart` | Fetch, cache, freeze lifecycle |
| `lib/core/services/config_cache_service.dart` | JSON file cache (`app_config_cache.json`) |
| `lib/core/config/timezone_config.dart` | Timezone architecture docs + `serverOffsetHours` accessor |
| `lib/core/config/h3_config.dart` | H3 resolution accessors (read from `HexConfig`) |
| `lib/core/config/supabase_config.dart` | Supabase URL/key (Tier 1) |
| `lib/core/config/mapbox_config.dart` | Mapbox token (Tier 1) |
| `lib/core/utils/gmt2_date_utils.dart` | Canonical GMT+2 date utilities for Domain A |
| `supabase/migrations/` | All SQL, including hardcoded buff values and timezone strings |
