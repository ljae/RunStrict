# RunStrict Sync, Performance & Configuration

> Data sync strategy, GPS configuration, performance optimization, and remote config. Read DEVELOPMENT_SPEC.md (index) first.

---

## A. THE FINAL SYNC — Data Synchronization Strategy

### Communication Lifecycle (Pre-patch Strategy)

> **Principle**: Minimize server calls during active running. Pre-load data on app launch, compute locally during run, batch upload on completion. **0 API calls during run.**

**App Launch (1 GET request)**:
```
┌─────────────────────────────────────────────────────────────┐
│  GET /rpc/app_launch_sync                                   │
│  ─────────────────────────────────────────────────────────  │
│  Returns:                                                   │
│  1. hex_map[]        - Latest hexagon colors (visible area) │
│  2. ranking_snapshot - Leaderboard data (Province/District/Zone) │
│  3. buff_multiplier  - Today's team-based buff (from daily) │
│  4. user_stats       - Personal season points, home_hex     │
│  5. app_config       - Server-configurable constants        │
└─────────────────────────────────────────────────────────────┘
```

**Running Start**: **No communication** (skip entirely)
- All required data already pre-patched
- User can start running immediately
- Zero latency, zero server dependency

**During Running** (0 server calls):
```
┌─────────────────────────────────────────────────────────────┐
│  LOCAL COMPUTATION ONLY                                     │
│  ─────────────────────────────────────────────────────────  │
│  1. Hex display      → Use pre-patched hex_map data         │
│  2. Hex detection    → Local H3 library (geoToCell)         │
│  3. Flip detection   → Compare runner team vs hex color     │
│  4. Points calc      → Local: flips × yesterday_multiplier  │
│  5. Distance/Pace    → Local Haversine formula              │
│  6. Route recording  → Local SQLite (ring buffer)           │
└─────────────────────────────────────────────────────────────┘
```

**Run Completion (1 POST request)**:
```
┌─────────────────────────────────────────────────────────────┐
│  POST /rpc/finalize_run                                     │
│  ─────────────────────────────────────────────────────────  │
│  Payload:                                                   │
│  {                                                          │
│    "run_id": "uuid",                                        │
│    "start_time": "2026-01-26T19:00:00+09:00",              │
│    "end_time": "2026-01-26T19:30:00+09:00",                 │
│    "distance_km": 5.2,                                      │
│    "duration_seconds": 1800,                                │
│    "hex_path": ["8f28308280fffff", "8f28308281fffff", ...], │
│    "cv": 8.5                               // Optional      │
│  }                                                          │
│  ─────────────────────────────────────────────────────────  │
│  Server actions:                                            │
│  1. Fetch buff_multiplier from daily_buff_stats             │
│  2. Update hex colors (ALL hexes get run's endTime)         │
│  3. Calculate final points (server-side verification)       │
│  4. Store start_hex (first) and end_hex (last) for home     │
│  5. Update user aggregates (distance, pace, cv)             │
│  6. Return updated user_stats                               │
└─────────────────────────────────────────────────────────────┘
```

### Communication Summary

| Phase | Server Calls | Data Flow |
|-------|--------------|-----------|
| App Launch | 1 GET | Server → Client (pre-patch) |
| OnResume (foreground) | 0-1 GET | Server → Client (conditional refresh) |
| Run Start | 0 | — |
| During Run | 0 | Local only |
| Run End | 1 POST | Client → Server (batch sync) |
| **Total per run** | **2 requests** | Minimal bandwidth |

**Storage Optimization:**
- Raw GPS coordinates are NOT uploaded to server (stored locally in SQLite `routes` table for route display; only `hex_path` uploaded).
- `hex_path` = deduplicated list of H3 hex IDs passed.
- Estimated 90%+ reduction in storage compared to full GPS trace.

### Sync Strategy Options

| Setting | Options | Selected |
|---------|---------|----------|
| **Sync Timing** | ☐ Real-time (during run) | |
| | ☑ On run completion only ("The Final Sync") | ✅ |
| **Sync Engine** | ☑ Custom RPC Bulk Insert | ✅ |
| | ☐ PowerSync (auto-sync, simpler dev) | |
| | ☐ Standard REST API (inefficient for high-volume) | |
| **Bulk Insert RPC** | ☑ `finalize_run(jsonb)` function | ✅ |
| **Payload Contents** | ☑ endTime, distanceKm, hex_path[], buffMultiplier | ✅ |
| **Compression** | ☑ Compress JSON payload (gzip) | ✅ |
| | ☐ No compression | |
| **Conflict Resolution** | ☑ Later `endTime` wins hex color | ✅ |
| **Offline Queue** | ☑ SQLite `sync_queue` table | ✅ |
| | ☐ In-memory only (data loss risk) | |

### Offline Resilience

- If app launch fails: Use cached data from last session
- If `finalize_run` fails: Run stays `'pending'` in SQLite `runs` table (with `hex_path` + `buff_multiplier` stored for retry)
- `SyncRetryService` checks connectivity via `connectivity_plus` before retrying
- Retry triggers: app launch, OnResume, after next run completion
- Never lose user's run data
- **Crash Recovery**: `run_checkpoint` table saves state on each hex flip; recovered on next app launch

### OnResume Data Refresh

When app returns to foreground (`applicationWillEnterForeground` on iOS, `onResume` on Android):

- Refresh hex map data for visible area (`PrefetchService.refresh`)
- Refresh leaderboard data
- Retry failed syncs (`SyncRetryService.retryUnsyncedRuns`)
- Refresh buff multiplier via `BuffService.refresh` (in case midnight passed)
- Refresh today's points baseline via `appLaunchSync` + `PointsService`

**Throttling**: Skip refresh if last refresh was < 30 seconds ago  
**During Active Run**: Skip refresh (avoid interrupting tracking)  
This ensures map data stays current even after extended background periods.

---

## B. GPS & BACKGROUND LOCATION

### Android Configuration

| Setting | Options | Selected |
|---------|---------|----------|
| **Foreground Service Type** | ☑ `FOREGROUND_SERVICE_LOCATION` (Required) | ✅ |
| **Wakelock Strategy** | ☐ Partial Wakelock (CPU active during run) | |
| | ☑ No Wakelock (battery priority, may miss points) | ✅ |
| **Location Provider** | ☑ Fused Location Provider Client (FLPC) | ✅ |
| | ☐ Raw GPS only (higher accuracy, higher battery) | |
| **FLPC Priority** | ☐ `PRIORITY_HIGH_ACCURACY` (GPS always on) | |
| | ☑ `PRIORITY_BALANCED_POWER_ACCURACY` (battery saving) | ✅ |

### iOS Configuration

| Setting | Options | Selected |
|---------|---------|----------|
| **Background Mode** | ☑ `UIBackgroundModes: location` (Required) | ✅ |
| **Pause Updates Automatically** | ☑ `pausesLocationUpdatesAutomatically = false` — Required | ✅ |
| | ☐ `true` (iOS may stop tracking when stationary — NOT recommended) | |
| **Activity Type** | ☑ `CLActivityType.fitness` | ✅ |
| | ☐ `CLActivityType.other` | |
| **Desired Accuracy** | ☐ `kCLLocationAccuracyBest` | |
| | ☐ `kCLLocationAccuracyNearestTenMeters` | |
| | ☑ `kCLLocationAccuracyHundredMeters` (battery saving, matches 50m rule) | ✅ |
| **Distance Filter** | ☑ 5 meters (battery optimization) | ✅ |

### GPS Polling & Battery Optimization

> **Strategy**: Battery efficiency is prioritized over data precision. Fixed 0.5Hz polling with 20-second moving average window compensates for lower sample rates.

| Setting | Options | Selected |
|---------|---------|----------|
| **Polling Strategy** | ☐ Adaptive Polling (variable rate based on speed) | |
| | ☑ Fixed 0.5 Hz (every 2 seconds) — battery saving, consistent behavior | ✅ |
| **Moving Average Window** | ☐ 10 seconds (~5 samples at 0.5Hz — unstable) | |
| | ☑ 20 seconds (~10 samples at 0.5Hz — stable) | ✅ |
| **Min Time Between Points** | ☐ 100ms (allows up to 10Hz) | |
| | ☑ 1500ms (allows 0.5Hz with margin) | ✅ |
| **Distance Filter (iOS)** | ☑ 5 meters — Required for battery optimization | ✅ |
| | ☐ 10 meters | |
| | ☐ `kCLDistanceFilterNone` (all updates — high battery) | |
| **Batch Buffer Size** | ☐ 10 points (write every ~20 seconds at 0.5Hz) | |
| | ☑ 20 points (write every ~40 seconds at 0.5Hz) — fewer I/O ops | ✅ |
| | ☐ 1 point (immediate write — high I/O) | |

**Key values:**
- GPS Polling: Fixed **0.5 Hz** (every 2 seconds) — not adaptive
- Moving average window: **20 seconds** (~10 samples at 0.5Hz) for stable pace validation

---

## C. SIGNAL PROCESSING

> **Strategy**: Use Kalman Filter to smooth hardware noise. NO Map Matching API (cost + trail accuracy).

### Kalman Filter Configuration

| Setting | Options | Selected |
|---------|---------|----------|
| **Kalman Filter** | ☑ Enabled | ✅ |
| | ☐ Disabled (raw GPS only) | |
| **State Variables** | ☑ 2D (lat/lng + velocity) | ✅ |
| | ☐ 3D (lat/lng/altitude + velocity) | |
| **Dynamic Noise Covariance** | ☑ Use GPS `accuracy` field dynamically | ✅ |
| | ☐ Fixed noise covariance | |
| **Outlier Rejection Speed** | ☐ 44 m/s (≈100 mph, Usain Bolt = 12.4 m/s) | |
| | ☑ 25 m/s (≈56 mph, matches speed cap rule) | ✅ |
| | ☐ 15 m/s (≈34 mph, very strict) | |

### Map Matching Strategy

| Setting | Options | Selected |
|---------|---------|----------|
| **Real-time Display** | ☑ Smoothed Raw Trace (Kalman filtered) | ✅ |
| | ☐ Mapbox Map Matching API (snaps to roads) | |
| **Post-run Display** | ☑ Same as real-time | ✅ |
| | ☐ Mapbox Map Matching API (prettier for sharing) | |
| **Map Matching API Usage** | ☑ Never (cost optimization) | ✅ |
| | ☐ Optional for post-run sharing only | |
| | ☐ Always (higher cost, road-snapped routes) | |

> **Note**: Running apps should NOT use Map Matching by default. Runners often use parks, trails, and tracks that aren't on road networks. Map Matching forces routes onto roads, distorting actual distance.

---

## D. LOCAL DATABASE CONFIGURATION

| Setting | Options | Selected |
|---------|---------|----------|
| **Journal Mode** | ☐ WAL (Write-Ahead Logging) — Recommended | ☐ |
| | ☐ DELETE (default, may cause UI jank) | |
| **Synchronous Mode** | ☐ `NORMAL` — Recommended | ☐ |
| | ☐ `FULL` (safest, slower) | |
| | ☐ `OFF` (fastest, risk of corruption on crash) | |
| **Batch Insert Size** | ☐ 10-20 rows per transaction — Recommended | ☐ |
| | ☐ 1 row per transaction (high I/O overhead) | |
| **Cache Size** | ☐ 2000 pages (≈8MB) — Recommended | ☐ |
| | ☐ Default (2000 pages) | |

---

## E. MAPBOX SDK & COST

### SDK Selection

| Setting | Options | Selected |
|---------|---------|----------|
| **Primary SDK** | ☐ Maps SDK for Mobile (MAU-based) — Recommended | ☐ |
| | ☐ Navigation SDK (Trip-based, expensive) | |
| **Navigation SDK Usage** | ☐ Not used (cost optimization) — Recommended | ☐ |
| | ☐ Premium feature only (voice-guided runs) | |
| **Tile Type** | ☐ Vector Tiles — Recommended (smaller, zoomable) | ☐ |
| | ☐ Raster Tiles (larger, static quality) | |
| **Offline Tile Limit** | ☐ 6,000 tiles per device (free tier limit) | ☐ |
| | ☐ Custom limit (requires paid plan) | |
| **Offline Cache Strategy** | ☐ LRU (auto-delete oldest) — Recommended | ☐ |
| | ☐ Manual management | |
| **Max Offline Zoom** | ☐ Zoom 15 — Recommended | ☐ |
| | ☐ Zoom 17 (more detail, larger download) | |

### Cost Model Comparison

| SDK | Billing | Free Tier | Running App Fit |
|-----|---------|-----------|-----------------|
| **Maps SDK** | MAU (Monthly Active Users) | 50,000 MAU/month | ✅ Excellent |
| **Navigation SDK** | Per Trip | 1,000 trips/month | ⚠️ Only for premium features |

---

## F. PACE VISUALIZATION

### Route Color Settings

| Setting | Options | Selected |
|---------|---------|----------|
| **Route Color** | ☐ Gradient by pace (green=fast, red=slow) — Recommended | ☐ |
| | ☐ Solid team color | |
| **Gradient Implementation** | ☐ Mapbox `line-gradient` + `line-progress` — Recommended | ☐ |
| | ☐ Multiple polyline segments (less smooth) | |
| **lineMetrics** | ☐ `true` (required for gradient) — Recommended | ☐ |
| **Pace Color Ramp** | ☐ 5-color (4:00→green, 6:00→yellow, 8:00→red) | ☐ |
| | ☐ 3-color (fast→medium→slow) | |

### Location Marker & Animation Settings

| Setting | Options | Selected |
|---------|---------|----------|
| **Location Puck** | ☐ Custom team-colored marker — Recommended | ☐ |
| | ☐ Default blue dot | |
| **Interpolation** | ☐ Tween animation between GPS updates — Recommended | ☐ |
| | ☐ Jump to new position (choppy) | |
| **Interpolation FPS** | ☐ 60 fps — Recommended | ☐ |
| | ☐ 30 fps | |
| **Bearing (Heading)** | ☐ Smooth rotation based on movement direction — Recommended | ☐ |
| | ☐ No rotation | |

---

## G. PRIVACY & SECURITY

### Privacy Zones Configuration

| Setting | Options | Selected |
|---------|---------|----------|
| **Privacy Zones** | ☐ Enabled (user-defined) — Recommended | ☐ |
| | ☐ Disabled | |
| **Default Privacy Radius** | ☐ 500 meters — Recommended | ☐ |
| | ☐ 200 meters | |
| | ☐ 1000 meters | |
| **Masking Strategy** | ☐ Client-side (before upload) — Recommended | ☐ |
| | ☐ Server-side (after upload) | |
| **Masking Method** | ☐ Truncate coordinates in zone | ☐ |
| | ☐ Replace with random nearby coordinates | |
| | ☐ Shift start/end points outside zone | |

**Privacy-Optimized Hex Storage:**
- No timestamps or runner IDs stored in hexes
- Only `last_runner_team` and `last_flipped_at` (for conflict resolution only)
- Raw GPS coordinates stored locally in SQLite only — never uploaded to server

---

## H. REAL-TIME COMPUTATION

| Setting | Options | Selected |
|---------|---------|----------|
| **Distance Calculation** | ☐ Local (Haversine formula) — Recommended | ☐ |
| | ☐ Server-dependent (adds latency) | |
| **Pace Calculation** | ☐ Local (immediate UI update) — Recommended | ☐ |
| | ☐ Server-dependent | |
| **Hex Detection** | ☐ Local H3 library — Recommended | ☐ |
| | ☐ Server RPC call | |

> **Principle**: All real-time UI feedback MUST be computed locally. Server data is for persistence and backup only.

---

## I. RECOMMENDED CONFIGURATION SUMMARY

For **RunStrict** optimal balance of battery, accuracy, and cost:

| Category | Recommended Setting |
|----------|---------------------|
| **Android Location** | FLPC `PRIORITY_BALANCED_POWER_ACCURACY`, No Wakelock |
| **iOS Background** | `kCLLocationAccuracyNearestTenMeters`, 5m distance filter, `fitness` activity type |
| **Polling** | Adaptive (0.5Hz base, 0.1Hz when stationary) |
| **Distance Filter** | 5 meters |
| **Kalman Filter** | Enabled with dynamic noise covariance, 25 m/s outlier rejection |
| **Map Matching** | Disabled (Smoothed Raw Trace only) |
| **SQLite** | WAL mode, 20 row batch inserts |
| **Mapbox SDK** | Maps SDK only (no Navigation SDK) |
| **Tiles** | Vector, 6000 tile limit, LRU cache |
| **Data Sync** | "The Final Sync" — batch upload on run completion only |
| **Multiplier** | "Yesterday's Check-in" — daily calculation, no real-time tracking |
| **Storage** | hex_path only (no raw GPS trace) — 90%+ savings |
| **Conflict Resolution** | Later `endTime` wins hex color |
| **Privacy Zones** | Enabled, 500m radius, client-side masking |
| **Real-time** | All local computation (distance, pace, hex detection) |

---

## J. REMOTE CONFIGURATION SYSTEM

> **Strategy**: All 50+ game constants are server-configurable via Supabase, with local caching and graceful fallback to hardcoded defaults.

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

**Fallback Chain:**
1. **Server**: Fetch from `app_config` table via `app_launch_sync` RPC
2. **Cache**: Load from `config_cache.json` if server unreachable
3. **Defaults**: Use `AppConfig.defaults()` if no cache available

### Database Schema

```sql
-- Single-row table with all config as JSONB
CREATE TABLE app_config (
  id INTEGER PRIMARY KEY DEFAULT 1 CHECK (id = 1),  -- Single-row constraint
  config_version INTEGER NOT NULL DEFAULT 1,
  config_data JSONB NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Returned via app_launch_sync RPC
-- { user, buff_multiplier, hexes_in_viewport, app_config: { version, data } }
```

### AppConfig Model Structure

```dart
class AppConfig {
  final int configVersion;
  final SeasonConfig seasonConfig;
  final GpsConfig gpsConfig;
  final ScoringConfig scoringConfig;
  final HexConfig hexConfig;
  final TimingConfig timingConfig;
  final BuffConfig buffConfig;
  
  factory AppConfig.defaults() => AppConfig(...);  // All hardcoded defaults
  factory AppConfig.fromJson(Map<String, dynamic> json) => ...;
}
```

### Configurable Constants by Category

| Category | Constants | Example Values |
|----------|-----------|----------------|
| **Season** | `durationDays`, `serverTimezoneOffsetHours` | 40, 2 |
| **GPS** | `maxSpeedMps`, `minSpeedMps`, `maxAccuracyMeters`, `maxAltitudeChangeMps`, `maxJumpDistanceMeters`, `movingAvgWindowSeconds`, `maxCapturePaceMinPerKm`, `pollingRateHz`, `minTimeBetweenPointsMs` | 6.94, 0.3, 50.0, 5.0, 100, 20, 8.0, 0.5, 1500 |
| **Hex** | `baseResolution`, `zoneResolution`, `districtResolution`, `provinceResolution`, `captureCheckDistanceMeters`, `maxCacheSize` | 9, 8, 6, 4, 20.0, 4000 |
| **Timing** | `accelerometerSamplingPeriodMs`, `refreshThrottleSeconds` | 200, 30 |
| **Buff** | `elitePercentile`, `participationRateHigh`, `participationRateMid` | 20, 60, 30 |

### Run Consistency: freezeForRun() / unfreezeAfterRun()

During an active run, config is frozen to prevent mid-run changes:

```dart
// In RunTracker.startNewRun()
RemoteConfigService().freezeForRun();

// In RunTracker.stopRun()
RemoteConfigService().unfreezeAfterRun();
```

**Usage Pattern in Services:**

```dart
// For run-critical values (frozen during runs)
static double get maxSpeedMps => 
    RemoteConfigService().configSnapshot.gpsConfig.maxSpeedMps;

// For non-critical values (can change anytime)
static int get maxCacheSize => 
    RemoteConfigService().config.hexConfig.maxCacheSize;
```

### Initialization Flow

```dart
// In main.dart (after SupabaseService, before HexService)
await RemoteConfigService().initialize();
```

1. Try fetch from server via `app_launch_sync` RPC
2. If success: Cache to `config_cache.json`, use server config
3. If fail: Try load from cache
4. If no cache: Use `AppConfig.defaults()`

### Key Files

| File | Purpose |
|------|---------|
| `supabase/migrations/20260128_create_app_config.sql` | Database table with JSONB schema |
| `supabase/migrations/20260128_update_app_launch_sync.sql` | RPC returns config |
| `lib/data/models/app_config.dart` | Typed model with nested classes |
| `lib/core/services/config_cache_service.dart` | Local JSON caching |
| `lib/core/services/remote_config_service.dart` | Singleton service |
| `test/services/remote_config_service_test.dart` | Unit tests (7 tests) |

### Services Using RemoteConfigService

| Service | Config Used |
|---------|-------------|
| `SeasonService` | `seasonConfig.durationDays`, `serverTimezoneOffsetHours` |
| `GpsValidator` | All 8 GPS validation constants |
| `LocationService` | `gpsConfig.pollingRateHz` |
| `RunTracker` | `hexConfig.baseResolution`, `captureCheckDistanceMeters` |
| `HexDataProvider` | `hexConfig.maxCacheSize` |
| `HexagonMap` | `hexConfig.baseResolution` |
| `AccelerometerService` | `timingConfig.accelerometerSamplingPeriodMs` |
| `AppLifecycleManager` | `timingConfig.refreshThrottleSeconds` |
| `H3Config` | All 4 resolution constants |
| `BuffService` | `buffConfig.elitePercentile`, `participationRateHigh`, `participationRateMid` |
