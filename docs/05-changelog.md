# RunStrict Development Changelog

> Development history, roadmap, and decision log. Reference only — rarely needed for coding tasks.

---

## 6. Development Roadmap

### Phase 1: Core Gameplay (1–3 months)

| Feature | Status | Notes |
|---------|--------|-------|
| GPS distance tracking | ✅ | geolocator package |
| Offline storage (SQLite) | ✅ | |
| Auth (Supabase Auth) | ✅ | Email/Google/Apple |
| Team selection UI | ✅ | team_selection_screen.dart |
| H3 hex grid overlay | ✅ | hex_service.dart |
| Territory visualization | ✅ | hexagon_map.dart |
| Hex state transitions | ✅ | |
| Running screen (unified) | ✅ | Pre-run + Active |
| Navigation mode (bearing) | ✅ | SmoothCameraController |
| Flip point tracking | ✅ | points_service.dart |
| Accelerometer validation | ⬜ | sensors_plus package |
| Speed filter (25 km/h) | ⬜ | In gps_validator.dart |
| GPS accuracy filter (50m) | ⬜ | In gps_validator.dart |
| Run history tracking | ⬜ | run_history table (preserved) |
| Team-based buff system | ✅ | buff_service.dart |
| Profile screen (manifesto) | ⬜ | |

### Phase 1.5: Backend Migration (Month 2–3)

| Feature | Status | Notes |
|---------|--------|-------|
| Supabase project setup | ⬜ | Auth + DB + Realtime + Storage |
| PostgreSQL schema creation | ⬜ | Tables, indexes, constraints |
| pg_partman partition setup | ⬜ | runs (monthly, seasonal), run_history (monthly, permanent) |
| RLS policies | ⬜ | No backend API needed |
| Supabase Realtime channels | ⬜ | active_runs, hexes, leaderboard |
| Edge Function: D-Day reset | ⬜ | Scheduled TRUNCATE/DROP |
| Firebase → Supabase migration | ⬜ | Replace all Firebase dependencies |
| supabase_service.dart | ⬜ | Client init & RPC wrappers |

### Phase 2: Social & Economy (4–6 months)

| Feature | Status | Notes |
|---------|--------|-------|
| Yesterday's Check-in Multiplier | ⬜ | Edge Function: calculate_yesterday_checkins() at midnight GMT+2 |
| The Final Sync (batch upload) | ⬜ | RPC: finalize_run() with conflict resolution |
| Batch points calculation | ⬜ | RPC: finalize_run (no daily limit) |
| Leaderboard (ALL scope) | ⬜ | SQL function: get_leaderboard() |
| Leaderboard (District/Zone scope) | ⬜ | Based on visible hex count |
| Hex path in RunSummary | ⬜ | hex_path column in runs table |
| SQLite hex cache | ⬜ | Offline support |

### Phase 3: Purple & Season (7–9 months)

| Feature | Status | Notes |
|---------|--------|-------|
| Purple unlock (anytime) | ✅ | Traitor's Gate |
| Points preserved on defection | ✅ | seasonPoints unchanged |
| Purple buff system | ✅ | Participation rate based multiplier |
| 40-day season cycle | ⬜ | |
| D-Day reset protocol | ⬜ | Edge Function: TRUNCATE/DROP (instant) |
| Cold storage archive | ⬜ | Supabase Storage (S3-compatible) |
| New season re-selection | ⬜ | Team re-pick after D-0 |

---

## 7. Success Metrics

### KPIs by Phase

| Category | Metric | Phase 1 | Phase 2 | Phase 3 |
|----------|--------|---------|---------|---------|
| **Users** | DAU | 300 | 1,500 | 5,000 |
| | WAU | 1,000 | 5,000 | 15,000 |
| | MAU | 2,000 | 10,000 | 30,000 |
| **Engagement** | D1 Retention | 50% | 55% | 60% |
| | D7 Retention | 30% | 35% | 40% |
| | D30 Retention | 15% | 20% | 25% |
| | Avg Session | 8 min | 12 min | 15 min |
| **Activity** | Runs/Day | 500 | 2,000 | 6,000 |
| | Avg Distance/Run | 3 km | 4 km | 5 km |
| **Purple** | Defection Rate | — | — | 15% |

### Revenue (Post-Launch)

| Metric | Target |
|--------|--------|
| LTV | $15+ |
| CAC | < $5 |
| LTV:CAC | > 3:1 |
| Monthly Churn | < 5% |

---

## Remaining Open Items

### Completed Decisions (2026-01-26)

| Item | Status | Decision |
|------|--------|----------|
| **Multiplier System** | ✅ Complete | "Yesterday's Check-in" — midnight GMT+2 Edge Function |
| **Data Sync Strategy** | ✅ Complete | "The Final Sync" — batch upload on run completion |
| **Hex Path Storage** | ✅ Complete | Deduplicated H3 IDs only, no timestamps |
| **Conflict Resolution** | ✅ Complete | **Later run wins** (last_flipped_at timestamp, prevents offline abusing) |
| **Battery Strategy** | ✅ Complete | `PRIORITY_BALANCED_POWER_ACCURACY` + 5m distance filter |
| **Performance Config** | ✅ Complete | All Section 9 checkboxes selected |
| **Home Hex System** | ✅ Complete | Asymmetric: Self=FIRST hex, Others=LAST hex. Stored in `home_hex_start`/`home_hex_end` columns |
| **Communication Lifecycle** | ✅ Complete | Pre-patch on launch (1 GET), 0 calls during run, batch on completion (1 POST) |
| **Buff Display** | ✅ Complete | Shows current buff multiplier in UI |
| **Supabase Realtime** | ✅ REMOVED | No WebSocket features needed — all data synced on launch/completion |
| **Run History Timezone** | ✅ Complete | User-selectable timezone for history display |
| **Daily Flip Limit** | ✅ REMOVED | No daily limit — different users can each flip the same hex independently (same user cannot re-flip own hex due to snapshot isolation) |
| **Table Separation** | ✅ Complete | `runs` (heavy, deleted on reset) vs `run_history` (light, preserved 5 years) |
| **Pace Validation** | ✅ Complete | **Moving average pace (10 sec)** at hex entry (GPS noise smoothing) |
| **Points Authority** | ✅ Complete | **Server verified** — points ≤ hex_count × multiplier |
| **Mid-run Buff Change** | ✅ Complete | Buff frozen at run start, no changes mid-run |
| **Zero-hex Run** | ✅ Complete | Keep previous home hex values (no update) |
| **New User Display** | ✅ Complete | **Show 1x** for users without yesterday data |
| **Data Retention** | ✅ Complete | **5 years** for run_history and daily_stats |
| **Model Relationship** | ✅ Complete | RunSummary=upload, RunHistoryModel=display |
| **Table Relationship** | ✅ Complete | Independent tables (no FK between runs and run_history) |
| **iOS Accuracy** | ✅ Complete | `kCLLocationAccuracyHundredMeters` (50m request) |
| **New User Buff** | ✅ Complete | Default to 1x multiplier when no yesterday data |

### Pending Items

| Item | Status | Notes |
|------|--------|-------|
| Supabase project provisioning | Needs setup | Choose region, plan tier |
| pg_partman extension activation | Needs Supabase support | May require Pro plan or self-hosted |
| Leaderboard District/Zone boundaries | Needs proposal | Based on H3 resolution (Res 8 = Zone, Res 6 = District) |
| Korean font (Paperlogyfont) integration | Needs package setup | Custom font from freesentation.blog |
| Stats/Numbers font identification | Needs check | Use current RunningScreen km font |
| Accelerometer threshold calibration | Needs testing | MVP must include but threshold TBD via testing |
| Profile avatar generation | Needs design | How to auto-generate representative images |
| Supabase Realtime channel design | ✅ REMOVED | No real-time features needed — all data synced on app launch/completion |
| Edge Function: Yesterday's Check-in | Needs implementation | Daily midnight GMT+2 cron job |
| Edge Function: D-Day reset | Needs setup | Season reset trigger mechanism |
| `finalize_run` RPC function | Needs implementation | Batch sync endpoint with conflict resolution |
| `app_launch_sync` RPC function | Needs implementation | Combined pre-patch endpoint (§9.6.1) |
| Home Hex update logic | Needs implementation | Store both start_hex and end_hex on run completion |
| Timezone selector UI | ✅ Implemented | Run History Screen dropdown for timezone selection |
| OnResume data refresh | ✅ Implemented | AppLifecycleManager refreshes hex/buff/leaderboard on foreground |

### Next Steps

| Priority | Task | Owner |
|----------|------|-------|
| 1 | Write `app_launch_sync` RPC (combined pre-patch endpoint) | TBD |
| 2 | Write `finalize_run` RPC with conflict resolution logic | TBD |
| 3 | Write `calculate_yesterday_checkins` Supabase SQL function | TBD |
| 4 | Update UI to show "Yesterday's Multiplier" instead of live count | TBD |
| 5 | Add Home Hex display to profile/leaderboard screens | TBD |

---

## Changelog

### 2026-01-30 (Session 10)

**Run History Screen UI Redesign**

| # | Change | Type | Description |
|---|--------|------|-------------|
| 1 | `_buildPeriodStatsSection` | **기능/UI** | New period stats panel - smaller copy of ALL TIME design (16h/12v padding, radius 12, 24px distance font) |
| 2 | `_buildMiniStatSmall` | **기능/UI** | Smaller mini stat helper (14px value, 8px label) for period panel |
| 3 | Month calendar distance | **기능/UI** | Month view now shows distance (e.g., "5.2k") like week view instead of run count badge |
| 4 | Removed `_buildStatsRow` | **리팩토링** | Replaced with `_buildPeriodStatsSection` in both portrait and landscape |
| 5 | Removed `_buildStatCard` | **리팩토링** | Unused after `_buildStatsRow` replacement |
| 6 | Removed `_buildActivityIndicator` | **리팩토링** | Unused after month calendar redesign |

**Leaderboard Screen Simplification**

| # | Change | Type | Description |
|---|--------|------|-------------|
| 1 | Removed geographic scope filter | **리팩토링/UI** | Removed Zone/District/Province scope dropdown - now shows all users |
| 2 | Removed `_scopeFilter` state | **리팩토링** | No longer tracking geographic scope state |
| 3 | Removed `_buildFilterBar` | **리팩토링** | Removed filter bar containing scope dropdown |
| 4 | Removed `_buildScopeDropdown` | **리팩토링** | Removed scope dropdown widget |
| 5 | Removed `_getScopeIcon` | **리팩토링** | Removed scope icon helper |
| 6 | Simplified `_getFilteredRunners` | **리팩토링** | No longer applies scope filtering |
| 7 | Removed h3_config import | **리팩토링** | GeographicScope no longer used |

**Files Modified:**
- `lib/screens/run_history_screen.dart` — New period stats section, removed unused methods
- `lib/widgets/run_calendar.dart` — Month view shows distance instead of activity indicator
- `lib/screens/leaderboard_screen.dart` — Removed geographic scope filter, simplified to date-range only

**Document Updates:**
- DEVELOPMENT_SPEC.md: Updated §3.2.5 Leaderboard Screen, §3.2.6 Run History Screen specs, added changelog

---

### 2026-01-28 (Session 9)

**CV & Stability Score Feature**

| # | Change | Type | Description |
|---|--------|------|-------------|
| 1 | `LapModel` | **기능/모델** | Per-km lap data model for CV calculation |
| 2 | `LapService` | **기능/서비스** | CV and Stability Score calculation (sample stdev, n-1 denominator) |
| 3 | `RunSummary.cv` | **기능/모델** | Added CV field to run summary |
| 4 | `UserModel` aggregates | **기능/모델** | Added `totalDistanceKm`, `avgPaceMinPerKm`, `avgCv`, `totalRuns`, `stabilityScore` |
| 5 | SQLite schema v6 | **기능/DB** | Added `cv` column to runs, new `laps` table |
| 6 | Server migration 003 | **기능/DB** | `finalize_run()` now accepts `p_cv`, updates user aggregates incrementally |
| 7 | Leaderboard stability badge | **기능/UI** | Shows stability score on podium and rank tiles (green/yellow/red) |
| 8 | `RunTracker` lap tracking | **기능/로직** | Automatic lap recording during runs, CV calculation on stop |

**Timezone Conversion in Run History**

| # | Change | Type | Description |
|---|--------|------|-------------|
| 1 | Timezone selector | **기능/UI** | Dropdown to select display timezone (Local, UTC, KST, SAST, EST, PST) |
| 2 | `_convertToDisplayTimezone()` | **기능/로직** | Converts UTC times to selected timezone |
| 3 | `RunCalendar` callback | **기능/UI** | `timezoneConverter` parameter for calendar and run tiles |

**Files Created:**
- `lib/models/lap_model.dart` — Lap data model
- `lib/services/lap_service.dart` — CV calculation service
- `test/models/lap_model_test.dart` — 6 unit tests
- `test/services/lap_service_test.dart` — 12 unit tests
- `supabase/migrations/003_cv_aggregates.sql` — Server migration

**Files Modified:**
- `lib/storage/local_storage.dart` — Schema v6 with cv column and laps table
- `lib/models/run_summary.dart` — Added cv field and stabilityScore getter
- `lib/models/user_model.dart` — Added aggregate fields
- `lib/services/run_tracker.dart` — Lap tracking and CV calculation
- `lib/services/supabase_service.dart` — Pass p_cv to finalize_run
- `lib/providers/leaderboard_provider.dart` — LeaderboardEntry with CV fields
- `lib/screens/leaderboard_screen.dart` — Stability badge on podium and tiles
- `lib/screens/run_history_screen.dart` — Timezone conversion
- `lib/widgets/run_calendar.dart` — timezoneConverter parameter

---

### 2026-01-28 (Session 8)

**Remote Configuration System**

| # | Change | Type | Description |
|---|--------|------|-------------|
| 1 | `app_config` Supabase table | **기능/DB** | Single-row JSONB table for all 50+ game constants |
| 2 | `app_launch_sync` RPC extended | **기능/API** | Returns config alongside user data on app launch |
| 3 | `AppConfig` Dart model | **기능/클라이언트** | Typed model with nested classes (Season, GPS, Scoring, Hex, Timing, Buff) |
| 4 | `ConfigCacheService` | **기능/클라이언트** | Local JSON caching for offline fallback |
| 5 | `RemoteConfigService` | **기능/클라이언트** | Singleton with fallback chain (server → cache → defaults) |
| 6 | Config freeze for runs | **기능/로직** | `freezeForRun()` / `unfreezeAfterRun()` prevents mid-run config changes |
| 7 | 11 services migrated | **리팩토링** | All hardcoded constants now read from RemoteConfigService |

**AccelerometerService Improvements**

| # | Change | Type | Description |
|---|--------|------|-------------|
| 1 | 5-second no-data warning | **버그수정/UX** | Clear diagnostic when running on iOS Simulator (no hardware) |
| 2 | Reduced log spam | **버그수정/UX** | Removed per-GPS-point "No recent data" messages |

**Files Changed:**
- `supabase/migrations/20260128_create_app_config.sql` — New config table
- `supabase/migrations/20260128_update_app_launch_sync.sql` — RPC extension
- `lib/models/app_config.dart` — New typed config model
- `lib/services/config_cache_service.dart` — New cache service
- `lib/services/remote_config_service.dart` — New config service
- `lib/services/accelerometer_service.dart` — Improved diagnostics
- `lib/main.dart` — Added RemoteConfigService initialization
- 11 service/widget files updated to use RemoteConfigService

**Document Updates:**
- AGENTS.md: Added Remote Configuration System section
- CLAUDE.md: Added Remote Configuration System section
- DEVELOPMENT_SPEC.md: Added §9.12 Remote Configuration System

---

### 2026-01-27 (Session 7)

**Fixed: Hex Map Flashing on Filter Change**

| # | Change | Type | Description |
|---|--------|------|-------------|
| 1 | GeoJsonSource + FillLayer pattern | **버그수정/UX** | Migrated from PolygonAnnotationManager to GeoJsonSource for atomic hex updates |
| 2 | Data-driven styling via setStyleLayerProperty | **기술/Mapbox** | Bypasses FillLayer constructor's strict typing limitation for expression support |
| 3 | Landscape overflow fixes | **버그수정/UI** | Fixed overflow errors on landscape orientation across all screens |

**Technical Details:**
- `PolygonAnnotationManager.deleteAll()` + `createMulti()` caused visible flash
- Solution: Use `GeoJsonSource` with `FillLayer` for data-driven styling
- `mapbox_maps_flutter` FillLayer constructor expects `int?` for fillColor, not expression `List`
- Workaround: Create layer with placeholder values, then apply expressions via `setStyleLayerProperty()`

**Files Changed:**
- `lib/widgets/hexagon_map.dart` — Complete rewrite of hex rendering logic
- `lib/screens/running_screen.dart` — Landscape layout (OrientationBuilder)
- `lib/screens/home_screen.dart` — Reduced sizes in landscape
- `lib/screens/leaderboard_screen.dart` — Responsive podium heights
- `lib/screens/leaderboard_screen.dart` — Responsive ranking grid
- `lib/screens/profile_screen.dart` — Landscape adjustments
- `lib/screens/run_history_screen.dart` — Side-by-side layout in landscape

**Document Updates:**
- AGENTS.md: Added Mapbox Patterns section with GeoJsonSource + FillLayer documentation
- CLAUDE.md: Added Mapbox Patterns section with GeoJsonSource + FillLayer documentation

---

### 2026-01-26 (Session 6)

**Security & Fairness Enhancements:**

| # | Change | Type | Description |
|---|--------|------|-------------|
| 1 | Server-side points validation | **필수/보안** | Points cannot exceed hex_count × multiplier (anti-cheat) |
| 2 | Hex timestamp for conflict resolution | **필수/공정성** | Added `last_flipped_at` to hexes table; later run_endTime wins (prevents offline abusing) |
| 3 | OnResume data refresh | **필수/UX** | App refreshes map data when returning to foreground |
| 4 | Moving Average Pace (10 sec) | **권장/로직** | Changed from instantaneous pace to 10-second moving average (GPS noise smoothing) |

**Schema Changes:**
- Added `last_flipped_at TIMESTAMPTZ` to hexes table
- Updated `finalize_run()` to compare run_endTime with existing timestamp
- Added `p_client_points` parameter for server validation

**Document Updates:**
- §1: Updated key differentiators (server-verified, minimal timestamps)
- §2.4.2: Pace validation changed to moving average (10 sec)
- §2.5.3: Conflict resolution changed from "Last Sync Wins" to "Later Run Wins"
- §4.1: HexModel updated with lastFlippedAt field
- §4.2: hexes table schema updated
- §9.7.1: Added OnResume data refresh trigger

---

### 2026-01-26 (Session 5)

**Specification Clarifications & Contradiction Resolutions:**

| # | Decision | Selected Option |
|---|----------|-----------------|
| 1 | Hex conflict resolution | **Last sync wins** (no timestamp stored) |
| 2 | Home hex storage | **Add both start & end** columns to users |
| 3 | Pace validation | **Instantaneous pace** at hex entry |
| 4 | Mid-run buff change | **Freeze buff** at run start |
| 5 | Points authority | **Client authoritative** (server stores as-is) |
| 6 | Avatar preservation | **Preserve & restore** via `original_avatar` column |
| 7 | Zero-hex run | **Keep previous** home hex |
| 8 | Buff calculation | **Keep bundled** with finalize_run |
| 9 | Purple after reset | **Force Red/Blue choice** |
| 10 | Solo runner display | **Hide multiplier** UI |
| 11 | Data retention | **5-year retention** for run_history/daily_stats |
| 12 | Model relationship | **RunSummary=upload, History=display** |
| 13 | Table relationship | **Independent tables** (no FK) |
| 14 | Deprecated RLS | **Remove policies** from active_runs |
| 15 | Architecture diagram | **Remove Realtime** component |
| 16 | iOS accuracy | **50m request** (kCLLocationAccuracyHundredMeters) |
| 17 | Service description | **Update** buff_service to team-based system |
| 18 | New user | **Default to 1x** multiplier |

**Schema Changes:**
- Added `original_avatar TEXT` to users table
- Added `home_hex_start TEXT` to users table (for self leaderboard scope)
- Added `home_hex_end TEXT` to users table (for others leaderboard scope)
- Updated `finalize_run()` to update home_hex columns (only if hex_path not empty)

**Document Updates:**
- §2.3.1: Avatar preserve & restore rule
- §2.4.2: Instantaneous pace clarification
- §2.5.2: Mid-run buff freeze, new user default
- §2.5.3: "Last sync wins" conflict resolution, client authoritative points
- §2.6.1: Zero-hex run preserves previous home hex
- §3.2.4: Multiplier hidden for solo runners
- §3.2.8: Avatar behavior documentation
- §4.1: RunSummary vs RunHistoryModel clarification
- §4.2: users table schema, removed active_runs RLS
- §4.3: 5-year data retention policy
- §5.1: Removed Realtime from architecture diagram
- §5.3: buff_service description updated
- §9.1.2: iOS accuracy changed to 50m

---

### 2026-01-26 (Session 4)

**REMOVED: Daily Flip Limit**
- Deleted `daily_flips` table and `has_flipped_today()` function
- Removed `DailyHexFlipRecord` client model
- Same hex can now be flipped multiple times per day
- Simplifies logic and reduces database complexity

**Added: Table Separation (`runs` vs `run_history`)**
- `runs` table: Heavy data with `hex_path` → **DELETED on season reset**
- `run_history` table: Lightweight stats (date, distance, time, flips, points) → **PRESERVED across seasons**
- Personal run history now survives D-Day reset

**Updated: §4.2 Database Schema**
- Replaced `daily_flips` with `run_history` table
- Updated `finalize_run()` RPC to insert into `run_history`
- Updated partition management (run_history = permanent)

**Updated: §4.3 Partition Strategy**
- `runs`: Monthly partitions, seasonal (deleted on reset)
- `run_history`: Monthly partitions, permanent (never deleted)
- Removed `daily_flips` from partition table

**Updated: §4.4 Hot/Cold Data Strategy**
- New tier: "Seasonal" for `runs` (deleted on reset)
- New tier: "Permanent" for `run_history` and `daily_stats`

**Updated: §2.8 D-Day Reset Protocol**
- `runs` partitions dropped (heavy data)
- `run_history` preserved (lightweight stats)
- Updated SQL reset script

**Updated: Development Roadmap**
- Replaced "Daily hex flip dedup" with "Run history tracking"
- Updated pg_partman setup notes

---

### 2026-01-26 (Session 3)

**Updated: §2.5.3 Conflict Resolution ("Run-Level endTime")**
- Clarified that ALL hexagons in a run are assigned the run's `endTime`
- Example: User B (ends 11:00) beats User A (ends 10:00) for ALL their hexes, regardless of actual passage time
- Flip points calculated locally and uploaded as-is

**Updated: §2.6.1 Home Hex System (Asymmetric Definition)**
- Current user's home = FIRST hex (start point) — privacy protection
- Other users' home = LAST hex (end point) — standard behavior
- Privacy rationale: Don't reveal where you ended (potentially your actual home)

**Updated: §3.2.4 Running Screen**
- Replaced "Active Crew Runners" with "Yesterday's Crew Runners (어제 뛴 크루원)"

**Updated: §3.2.6 Run History Screen**
- Added timezone selector feature for displaying run history
- User can change timezone in history screen
- Stored locally, not synced to server

**Removed: Real-time features**
- `active_runs` table marked as DEPRECATED
- Supabase Realtime: ALL WebSocket features removed
- Maximum cost savings achieved

**Updated: Completed Decisions table**
- Added 6 new completed items

---

### 2026-01-26 (Session 2)

**Added: §9.7.1 Communication Lifecycle (Pre-patch Strategy)**
- Documented complete client-server communication flow
- App Launch: 1 GET request (`app_launch_sync` RPC) for all pre-patch data
- Running Start: No communication (zero latency start)
- During Run: 0 server calls (all local computation)
- Run Completion: 1 POST request (`finalize_run` RPC) for batch sync
- Total: 2 requests per run session

**Updated: Completed Decisions table**
- Added "Home Hex System" — last hex of run = user's home for ranking scope
- Added "Communication Lifecycle" — pre-patch on launch, 0 calls during run, batch on completion

**Updated: Pending Items**
- Added `app_launch_sync` RPC function
- Added Home Hex update logic
- Updated Leaderboard boundaries note (H3 Res 8 = Zone, Res 6 = District)

**Updated: Next Steps**
- Reprioritized: `app_launch_sync` RPC now Priority 1
- Added: Home Hex display to profile/leaderboard screens (Priority 6)

---

### 2026-01-26 (Session 1)

**Major cost optimization updates:**
- §2.5.2: Changed multiplier from "Simultaneous Runner" (real-time) to "Yesterday's Check-in" (daily batch)
- §2.5.3: Added "The Final Sync" — no server communication during runs
- §2.6: Added Home Hex System for ranking scope (ZONE/DISTRICT/PROVINCE)
- §4.1: Updated RunSummary model with `endTime`, `buffMultiplier`
- §9.1-9.3: Selected battery-first GPS settings
- §9.6: Added Data Synchronization Strategy section
- Added SQL functions: `calculate_yesterday_checkins()`, `finalize_run()`
- Updated Appendix B examples

---
