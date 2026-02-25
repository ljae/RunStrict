# RunStrict Launch Readiness & Stress Test Plan

> **Created**: 2026-02-21
> **Season**: Season 2 (D-28 remaining)
> **Target**: Official App Store / Google Play launch

---

## Table of Contents

1. [Overview](#1-overview)
2. [Pre-Launch Checklist](#2-pre-launch-checklist)
3. [Server Load Testing (Virtual Runners)](#3-server-load-testing-virtual-runners)
4. [Data Integrity Verification](#4-data-integrity-verification)
5. [Historical Data Backfill (D-40 to D-28)](#5-historical-data-backfill-d-40-to-d-28)
6. [Daily Operation Workflow](#6-daily-operation-workflow)
7. [Stress Test Metrics & Acceptance Criteria](#7-stress-test-metrics--acceptance-criteria)
8. [Edge Case & Failure Scenario Testing](#8-edge-case--failure-scenario-testing)
9. [Client-Side Verification](#9-client-side-verification)
10. [Monitoring & Alerting](#10-monitoring--alerting)
11. [Rollback Plan](#11-rollback-plan)

---

## 1. Overview

### Goals

- Validate server infrastructure can handle target concurrent user load
- Verify midnight snapshot generation and buff calculation are correct under load
- Confirm data integrity across the full pipeline: run → finalize_run → hex_snapshot → leaderboard
- Simulate realistic season activity with virtual runners to populate historical data
- Establish daily operation runbook for production monitoring

### Architecture Summary

| Component | Technology | Key Concern |
|-----------|-----------|-------------|
| Database | Supabase PostgreSQL | RPC throughput, partition performance |
| Auth | Supabase Auth (Google/Apple) | Session concurrency |
| Hex Grid | H3 Resolution 9 (~174m edge) | Snapshot build time, hex volume |
| Cron Jobs | pg_cron (midnight GMT+2) | `build_daily_hex_snapshot()`, `calculate_daily_buffs()` |
| Client Sync | "The Final Sync" (single POST) | `finalize_run()` RPC |
| Ads | Google AdMob + RevenueCat Pro | Ad load latency, pro entitlement check |

### H3 Resolution Reference

| Scope | H3 Res | Avg Edge | Avg Area | Hexes per District (~36 km²) |
|-------|--------|----------|----------|-------------------------------|
| Base (gameplay) | 9 | ~174m | ~0.10 km² | ~360 |
| Zone | 8 | ~461m | ~0.73 km² | ~49 |
| District | 6 | ~3.2km | ~36 km² | 1 |
| Province | 4 | ~22.6km | ~1,770 km² | 1 |

---

## 2. Pre-Launch Checklist

### 2.1 Infrastructure

- [ ] Supabase project on Pro tier (or higher) with connection pooling enabled
- [ ] pg_cron extension enabled and verified
- [ ] `build_daily_hex_snapshot()` cron job scheduled at `0 22 * * *` UTC (= 00:00 GMT+2)
- [ ] `calculate_daily_buffs()` cron job scheduled at `0 22 * * *` UTC (= 00:00 GMT+2)
- [ ] `build_season_leaderboard_snapshot()` cron job scheduled at `5 22 * * *` UTC
- [ ] Database indexes verified on hot paths (see Section 4.3)
- [ ] Monthly table partitions created for `runs` and `daily_stats` (Feb, Mar, Apr 2026)
- [ ] RLS policies verified for all tables

### 2.2 App Store / Google Play

- [ ] iOS App registered in RevenueCat dashboard (replace Test Store)
- [ ] Android App registered in RevenueCat dashboard
- [ ] Production RevenueCat API keys configured (per-platform)
- [ ] Lifetime IAP product created in App Store Connect and Google Play Console
- [ ] AdMob production ad unit IDs configured (replace test IDs)
- [ ] `GADApplicationIdentifier` set in `Info.plist` (production)
- [ ] `APPLICATION_ID` set in `AndroidManifest.xml` (production)
- [ ] Mapbox production access token with URL restrictions
- [ ] App privacy labels completed (App Store)
- [ ] Data safety form completed (Google Play)

### 2.3 Configuration

- [ ] `app_config.config_data` verified with production values:
  - `season`: durationDays=40, serverTimezoneOffsetHours=2
  - `gps`: maxSpeedMps=6.94, pollingRateHz=0.5, maxAccuracyMeters=50
  - `scoring`: maxCapturePaceMinPerKm=8.0, minMovingAvgWindowSec=20
  - `hex`: baseResolution=9, maxCacheSize=4000
  - `buff`: all 15 multiplier values (config-driven via migration 20260221)
- [ ] Season 2 seed data verified (`season2_seed.sql`)
- [ ] `remote_config` cache TTL set appropriately

### 2.4 Security

- [ ] Supabase RLS policies audit (no public write to `users`, `hexes`, `runs`)
- [ ] `finalize_run()` SECURITY DEFINER — caller cannot bypass cap validation
- [ ] `get_user_buff()` SECURITY DEFINER — cross-user data access controlled
- [ ] No exposed service role keys in client code
- [ ] API rate limiting configured on Supabase (requests per second)

---

## 3. Server Load Testing (Virtual Runners)

### 3.1 Virtual Runner Simulation Design

Generate synthetic run data that mimics real user behavior to stress-test the entire data pipeline.

**Virtual Runner Profiles:**

| Profile | Count | Behavior | Team Distribution |
|---------|-------|----------|-------------------|
| Casual | 60% of total | 1 run/day, 2-4 km, 6:00-7:30 pace | Even Red/Blue |
| Regular | 30% of total | 1-2 runs/day, 4-8 km, 5:00-6:30 pace | Even Red/Blue |
| Hardcore | 8% of total | 2-3 runs/day, 8-15 km, 4:30-5:30 pace | Slightly Red-heavy |
| Purple | 2% of total | 1 run/day, 3-6 km, mixed pace | All Purple |

**Target Load Tiers:**

| Tier | Total Users | DAU (30%) | Peak Concurrent Runs | Purpose |
|------|------------|-----------|---------------------|---------|
| T1 - Baseline | 100 | 30 | 5-10 | Validate basic pipeline |
| T2 - Growth | 500 | 150 | 25-40 | Stress midnight cron jobs |
| T3 - Target | 1,000 | 300 | 50-80 | Production target |
| T4 - Headroom | 5,000 | 1,500 | 250-400 | 5x safety margin |

### 3.2 Virtual Run Generation (Edge Function)

Create a Supabase Edge Function `simulate_virtual_runs` that:

```
Input:
  - runner_count: number of virtual runners
  - district_hex: H3 Res 6 hex to anchor runs
  - date: target run date (for backfill)
  - team_distribution: { red: 0.45, blue: 0.45, purple: 0.10 }

Process:
  1. For each virtual runner:
     a. Generate random start point within district_hex
     b. Generate realistic hex_path (H3 Res 9) using random walk
        - Path length: 20-150 hexes (based on profile)
        - Direction bias: 70% forward, 30% random (mimics route)
     c. Calculate run metrics:
        - distance_km = hex_count × 0.174 (avg edge length)
        - duration_seconds = distance_km × pace × 60
        - flip_points = hex_count × buff_multiplier
        - cv = random(3.0 - 25.0) based on profile
     d. Call finalize_run() with generated data
     e. Insert into run_history

  2. Log results: success/failure count, total time, avg RPC latency

Output:
  - { runners_processed, runs_created, errors, avg_latency_ms }
```

### 3.3 Hex Path Generation Algorithm

```
function generateHexPath(startHex, targetLength):
  path = [startHex]
  current = startHex
  direction = random(0-5)  // H3 has 6 neighbors

  while path.length < targetLength:
    neighbors = h3.gridDisk(current, 1)  // 7 hexes (center + 6)

    // 70% continue forward, 20% slight turn, 10% random
    if random() < 0.70:
      next = neighbors[direction % 6]  // same direction
    elif random() < 0.90:
      direction = (direction + randomChoice(-1, 1)) % 6
      next = neighbors[direction % 6]
    else:
      next = randomChoice(neighbors)

    if next not in path:  // prevent loops
      path.append(next)
      current = next
    else:
      direction = (direction + 2) % 6  // turn around

  return path
```

### 3.4 Load Test Execution Sequence

```
Phase 1: Sequential Validation (T1 - 100 users)
  - Create 100 virtual users across 3 districts
  - Run 30 virtual runs sequentially
  - Verify: finalize_run() returns correct season_points
  - Verify: hex_snapshot contains correct hex colors after midnight build
  - Duration: ~30 minutes

Phase 2: Concurrent Stress (T2 - 500 users)
  - Create 500 virtual users across 10 districts
  - Execute 150 concurrent finalize_run() calls
  - Monitor: PostgreSQL connection pool usage
  - Monitor: RPC response times (p50, p95, p99)
  - Duration: ~2 hours

Phase 3: Production Simulation (T3 - 1,000 users)
  - Create 1,000 virtual users across 20 districts
  - Simulate full day cycle:
    - 06:00-09:00 GMT+2: Morning runs (30% of DAU)
    - 12:00-14:00 GMT+2: Lunch runs (15% of DAU)
    - 17:00-21:00 GMT+2: Evening runs (55% of DAU)
  - Trigger midnight cron jobs
  - Verify snapshot + buff + leaderboard integrity
  - Duration: ~4 hours (simulated 24h cycle)

Phase 4: Breaking Point (T4 - 5,000 users)
  - Maximum concurrent finalize_run() calls
  - Find connection pool saturation point
  - Identify first failure mode
  - Duration: ~1 hour
```

---

## 4. Data Integrity Verification

### 4.1 Midnight Snapshot Verification

After each simulated midnight, verify:

```sql
-- 1. Snapshot completeness: all today's hexes captured
SELECT COUNT(DISTINCT unnest(hex_path)) AS unique_hexes_in_runs
FROM public.runs
WHERE end_time >= (CURRENT_DATE AT TIME ZONE 'Etc/GMT-2')
  AND end_time < (CURRENT_DATE AT TIME ZONE 'Etc/GMT-2' + INTERVAL '1 day');

SELECT COUNT(*) AS hexes_in_snapshot
FROM public.hex_snapshot
WHERE snapshot_date = CURRENT_DATE + 1;

-- These should match (snapshot captures all hexes from today's runs)

-- 2. Conflict resolution: latest end_time wins
SELECT hs.hex_id, hs.last_runner_team, r.team_at_run, r.end_time
FROM public.hex_snapshot hs
JOIN public.runs r ON hs.hex_id = ANY(r.hex_path)
WHERE hs.snapshot_date = CURRENT_DATE + 1
ORDER BY r.end_time DESC;
-- Verify: snapshot team matches the run with the latest end_time for each hex

-- 3. No orphaned snapshots (snapshot date must align with cron schedule)
SELECT snapshot_date, COUNT(*)
FROM public.hex_snapshot
GROUP BY snapshot_date
ORDER BY snapshot_date;
```

### 4.2 Buff Calculation Verification

```sql
-- 1. RED Elite threshold consistency
SELECT dbs.city_hex,
       dbs.red_elite_threshold_points,
       COUNT(DISTINCT rh.user_id) AS red_runners,
       CEIL(COUNT(DISTINCT rh.user_id) * 0.20) AS expected_elite_count
FROM public.daily_buff_stats dbs
JOIN public.run_history rh ON rh.run_date = dbs.stat_date - 1
JOIN public.users u ON u.id = rh.user_id AND u.team = 'red'
  AND u.district_hex = dbs.city_hex
WHERE dbs.stat_date = CURRENT_DATE
GROUP BY dbs.city_hex, dbs.red_elite_threshold_points;

-- 2. PURPLE participation rate consistency
SELECT dbs.city_hex,
       dbs.purple_participation_rate,
       COUNT(DISTINCT CASE WHEN u.team = 'purple' THEN rh.user_id END)::NUMERIC /
       NULLIF(COUNT(DISTINCT CASE WHEN u.team = 'purple' THEN u.id END), 0) AS computed_rate
FROM public.daily_buff_stats dbs
LEFT JOIN public.run_history rh ON rh.run_date = dbs.stat_date - 1
LEFT JOIN public.users u ON u.id = rh.user_id AND u.district_hex = dbs.city_hex
WHERE dbs.stat_date = CURRENT_DATE
GROUP BY dbs.city_hex, dbs.purple_participation_rate;

-- 3. Config-driven buff values match app_config
SELECT config_data->'buff' AS buff_config FROM public.app_config WHERE id = 1;
-- Compare with get_user_buff() output for sample users
```

### 4.3 Critical Index Verification

```sql
-- Verify indexes exist on hot query paths
SELECT indexname, tablename
FROM pg_indexes
WHERE schemaname = 'public'
  AND tablename IN ('runs', 'run_history', 'hexes', 'hex_snapshot',
                    'daily_buff_stats', 'daily_stats', 'users',
                    'season_leaderboard_snapshot')
ORDER BY tablename, indexname;

-- Required indexes (create if missing):
-- runs: (user_id, end_time), (end_time) for partition pruning
-- run_history: (user_id, run_date), (run_date, user_id)
-- hexes: (id), (parent_hex)
-- hex_snapshot: (snapshot_date, hex_id), (snapshot_date, parent_hex)
-- daily_buff_stats: (stat_date, city_hex)
-- users: (id), (district_hex, team)
-- season_leaderboard_snapshot: (season_number, rank)
```

### 4.4 Points Integrity Check

```sql
-- Season points must match sum of run_history flip_points
SELECT u.id, u.name, u.season_points,
       COALESCE(SUM(rh.flip_points), 0) AS computed_season_points,
       u.season_points - COALESCE(SUM(rh.flip_points), 0) AS drift
FROM public.users u
LEFT JOIN public.run_history rh ON rh.user_id = u.id
GROUP BY u.id, u.name, u.season_points
HAVING u.season_points != COALESCE(SUM(rh.flip_points), 0);

-- If any rows returned, there is a points drift that needs investigation
```

### 4.5 Leaderboard Snapshot Verification

```sql
-- Leaderboard snapshot must match users table at time of snapshot
SELECT sls.user_id, sls.season_points AS snapshot_points,
       u.season_points AS live_points,
       sls.total_distance_km AS snapshot_distance,
       u.total_distance_km AS live_distance
FROM public.season_leaderboard_snapshot sls
JOIN public.users u ON u.id = sls.user_id
WHERE sls.season_number = (SELECT config_data->'season'->>'seasonNumber'
                           FROM public.app_config WHERE id = 1)::INT
ORDER BY sls.rank
LIMIT 50;

-- Note: snapshot is frozen at midnight, live values may differ during the day.
-- Verify at midnight: snapshot_points = live_points (within tolerance of 0).
```

---

## 5. Historical Data Backfill (D-40 to D-28)

### 5.1 Purpose

Season 2 started on 2026-02-11 (D-40). As of launch prep (D-28), 12 days of history need realistic data to populate:
- Leaderboard rankings
- Buff calculations (require "yesterday" data)
- Team territory (hex map colors)
- Run history (calendar view)

### 5.2 Backfill Strategy

```
Day 1-3 (Feb 11-13): Seed phase
  - 20 virtual runners per district
  - Low activity (10-15 runs/day)
  - Establishes initial hex coloring

Day 4-7 (Feb 14-17): Growth phase
  - 50 virtual runners per district
  - Medium activity (25-40 runs/day)
  - Purple defections begin (5% rate)

Day 8-12 (Feb 18-22): Active phase
  - 100 virtual runners per district
  - High activity (50-80 runs/day)
  - Realistic team distribution (45/45/10 Red/Blue/Purple)
```

### 5.3 Backfill Execution Steps

```
For each backfill_date from 2026-02-11 to 2026-02-22:

  1. SET session timezone to 'Etc/GMT-2'

  2. Generate virtual runs for the day:
     - Call simulate_virtual_runs(date: backfill_date, ...)
     - Ensure run end_times fall within the day (GMT+2)

  3. Build hex snapshot for next day:
     - Call build_daily_hex_snapshot() with date override
     - Verify snapshot_date = backfill_date + 1

  4. Calculate daily buffs:
     - Call calculate_daily_buffs() with date override
     - Verify daily_buff_stats populated for backfill_date + 1

  5. Build leaderboard snapshot:
     - Call build_season_leaderboard_snapshot()
     - Verify rankings reflect cumulative points

  6. Verify daily_stats aggregates:
     SELECT date_key, COUNT(*)
     FROM public.daily_stats
     WHERE date_key = backfill_date::TEXT
     GROUP BY date_key;

  7. Commit and proceed to next day
```

### 5.4 Backfill Verification Queries

```sql
-- Verify continuous daily data exists
SELECT run_date, COUNT(*) AS runs, SUM(flip_points) AS total_points
FROM public.run_history
WHERE run_date >= '2026-02-11' AND run_date <= '2026-02-22'
GROUP BY run_date
ORDER BY run_date;

-- Verify hex snapshots exist for each day
SELECT snapshot_date, COUNT(*) AS hex_count
FROM public.hex_snapshot
GROUP BY snapshot_date
ORDER BY snapshot_date;

-- Verify daily_buff_stats exist for each day
SELECT stat_date, COUNT(*) AS districts
FROM public.daily_buff_stats
GROUP BY stat_date
ORDER BY stat_date;

-- Verify no gaps in leaderboard data
SELECT season_number, COUNT(*) AS ranked_users, MAX(rank) AS max_rank
FROM public.season_leaderboard_snapshot
GROUP BY season_number;
```

---

## 6. Daily Operation Workflow

### 6.1 Standard Day Timeline (GMT+2)

```
┌─────────────────────────────────────────────────────────────┐
│  00:00  MIDNIGHT CRON JOBS (automated)                      │
│         ├─ build_daily_hex_snapshot()     ~30s-2min         │
│         ├─ calculate_daily_buffs()        ~10s-30s          │
│         └─ build_season_leaderboard_snapshot()  ~5s-15s     │
│                                                             │
│  00:05  POST-MIDNIGHT VERIFICATION (automated alert)        │
│         ├─ Verify hex_snapshot row count > 0                │
│         ├─ Verify daily_buff_stats populated                │
│         └─ Verify leaderboard_snapshot updated              │
│                                                             │
│  06:00  EARLY MORNING                                       │
│  ~      ├─ Users open app → PrefetchService downloads       │
│  09:00  │  new hex_snapshot + buff                          │
│         └─ First runs of the day begin                      │
│                                                             │
│  09:00  PEAK MORNING (monitoring window)                    │
│  ~      ├─ Monitor: finalize_run() p95 latency             │
│  12:00  ├─ Monitor: connection pool usage                   │
│         └─ Monitor: error rates in Supabase logs            │
│                                                             │
│  12:00  MIDDAY                                              │
│  ~      ├─ Lunch runners                                    │
│  14:00  └─ Lower traffic period                             │
│                                                             │
│  17:00  PEAK EVENING (highest load)                         │
│  ~      ├─ 55% of daily runs happen here                    │
│  21:00  ├─ Monitor: concurrent finalize_run() calls         │
│         ├─ Monitor: hex_path sizes (route complexity)       │
│         └─ Monitor: SyncRetryService failure rates          │
│                                                             │
│  21:00  WIND DOWN                                           │
│  ~      ├─ Late runners finishing                           │
│  23:59  └─ Cross-midnight runs start (rare, handled by      │
│            end_time logic)                                   │
└─────────────────────────────────────────────────────────────┘
```

### 6.2 Monitoring Dashboard Queries

Run these periodically during operation hours:

```sql
-- Active users today (runs completed)
SELECT COUNT(DISTINCT user_id) AS active_runners,
       COUNT(*) AS total_runs,
       AVG(distance_km) AS avg_distance,
       AVG(flip_points) AS avg_points
FROM public.run_history
WHERE run_date = CURRENT_DATE;

-- Runs in the last hour
SELECT COUNT(*) AS recent_runs,
       AVG(EXTRACT(EPOCH FROM (NOW() - created_at))) AS avg_age_seconds
FROM public.runs
WHERE end_time >= NOW() - INTERVAL '1 hour';

-- Failed syncs (runs without matching run_history)
SELECT COUNT(*) AS potential_unsynced
FROM public.runs r
LEFT JOIN public.run_history rh ON rh.user_id = r.user_id
  AND rh.run_date = (r.end_time AT TIME ZONE 'Etc/GMT-2')::DATE
WHERE r.end_time >= CURRENT_DATE AT TIME ZONE 'Etc/GMT-2'
  AND rh.id IS NULL;

-- Team distribution
SELECT team, COUNT(*) AS users,
       COUNT(CASE WHEN season_points > 0 THEN 1 END) AS active_users
FROM public.users
GROUP BY team;

-- Hex coloring status (live)
SELECT last_runner_team, COUNT(*) AS hex_count
FROM public.hexes
WHERE last_runner_team IS NOT NULL
GROUP BY last_runner_team;
```

### 6.3 Incident Response Playbook

| Incident | Detection | Mitigation |
|----------|-----------|------------|
| Midnight cron fails | hex_snapshot count = 0 for today+1 | Manually run `SELECT build_daily_hex_snapshot()` |
| finalize_run() timeout | p95 > 5s in logs | Check connection pool, kill long queries |
| Points drift | Points integrity query returns rows | Run reconciliation: update from run_history sum |
| Leaderboard stale | snapshot timestamp > 25 hours old | Manually run `SELECT build_season_leaderboard_snapshot()` |
| Buff returns 1x for all | daily_buff_stats empty for today | Manually run `SELECT calculate_daily_buffs()` |
| App crash on launch | Sentry/Crashlytics alert | Check PrefetchService timeout, hex_snapshot availability |

---

## 7. Stress Test Metrics & Acceptance Criteria

### 7.1 API Response Time Targets

| RPC Function | p50 Target | p95 Target | p99 Target | Max Acceptable |
|-------------|-----------|-----------|-----------|----------------|
| `finalize_run()` | < 200ms | < 500ms | < 1s | 3s |
| `get_user_buff()` | < 100ms | < 300ms | < 500ms | 1s |
| `app_launch_sync()` | < 300ms | < 800ms | < 1.5s | 3s |
| `get_hex_snapshot()` | < 500ms | < 1.5s | < 3s | 5s |
| `get_leaderboard()` | < 200ms | < 500ms | < 1s | 2s |
| `get_team_rankings()` | < 200ms | < 500ms | < 1s | 2s |

### 7.2 Midnight Cron Performance

| Operation | Target Duration | Max Acceptable |
|-----------|----------------|----------------|
| `build_daily_hex_snapshot()` (1K users) | < 30s | 2 min |
| `build_daily_hex_snapshot()` (5K users) | < 2 min | 5 min |
| `calculate_daily_buffs()` | < 15s | 1 min |
| `build_season_leaderboard_snapshot()` | < 10s | 30s |
| Total midnight window | < 3 min | 10 min |

### 7.3 Concurrency Targets

| Metric | T1 (100) | T2 (500) | T3 (1K) | T4 (5K) |
|--------|----------|----------|---------|---------|
| Concurrent connections | 10 | 40 | 80 | 400 |
| finalize_run()/min | 5 | 20 | 40 | 200 |
| app_launch_sync()/min | 10 | 50 | 100 | 500 |
| Error rate | 0% | < 0.1% | < 0.5% | < 1% |

### 7.4 Data Volume Projections

| Metric | Per Day (T3) | Per Season (40 days) | Storage |
|--------|-------------|---------------------|---------|
| Runs | ~300 | ~12,000 | ~50 MB |
| Run history rows | ~300 | ~12,000 | ~5 MB |
| Hex snapshot rows | ~5,000 | ~5,000 (overwritten daily) | ~2 MB |
| Daily stats rows | ~300 | ~12,000 | ~3 MB |
| Unique hexes touched | ~3,000/day | ~15,000 cumulative | ~5 MB |
| Total estimated DB size | - | - | ~100 MB |

### 7.5 Client Performance Targets

| Metric | Target | Measurement |
|--------|--------|-------------|
| App cold start to map | < 4s | Timer from main() to MapScreen rendered |
| Hex snapshot download | < 3s | PrefetchService.initialize() duration |
| Run start (GPS lock) | < 5s | LocationService first valid fix |
| Hex capture latency | < 100ms | GPS event → HexRepository update |
| FlipPoints animation | 60fps | No frame drops during digit flip |
| Map pan/zoom | 60fps | Mapbox FillLayer rendering |

---

## 8. Edge Case & Failure Scenario Testing

### 8.1 Network Failure Scenarios

| Scenario | Expected Behavior | Verification |
|----------|-------------------|-------------|
| Network lost during run | Run continues locally, sync retries later | Kill network mid-run, verify checkpoint saved |
| Network lost at finalize | SyncRetryService queues retry | Verify `is_synced=0` in local SQLite |
| Slow network (>5s RTT) | Timeout + retry, no duplicate runs | Verify no duplicate run_history entries |
| App killed during sync | Checkpoint recovery on next launch | Force-kill app, relaunch, verify run data |

### 8.2 Midnight Boundary Scenarios

| Scenario | Expected Behavior | Verification |
|----------|-------------------|-------------|
| Run crosses midnight | end_time determines snapshot day | Start at 23:50, end at 00:10, verify correct snapshot |
| App open at midnight | OnResume downloads new snapshot | Hold app open, verify hex colors change after midnight |
| Buff changes mid-day | Buff frozen at run start | Start run with 2x, verify 2x used even if server updates |
| Snapshot build failure | Previous day's snapshot persists | Simulate cron failure, verify app still loads old snapshot |

### 8.3 Concurrency Conflict Scenarios

| Scenario | Expected Behavior | Verification |
|----------|-------------------|-------------|
| Two users flip same hex simultaneously | Both earn points (snapshot isolation) | Two concurrent finalize_run() with overlapping hex_path |
| Same user double-tap run stop | Single finalize_run() call (debounced) | Rapid double-tap, verify single run_history entry |
| Duplicate finalize_run() (retry) | Idempotent (no double points) | Send same payload twice, verify season_points correct |

### 8.4 Data Edge Cases

| Scenario | Expected Behavior | Verification |
|----------|-------------------|-------------|
| User with 0 runs yesterday | Buff = 1x (default) | New user buff check |
| Empty district (no other runners) | RED elite = true (top 20% of 1 = self) | Single runner in district |
| All hexes same team | 0 flips for same team runner | Verify flip_points = 0 |
| Very long run (>500 hexes) | finalize_run() handles large hex_path | Generate 500+ hex path |
| Cross-district run | District determined by home hex, not run path | Verify buff uses home district |

---

## 9. Client-Side Verification

### 9.1 Functional Test Matrix

| Screen | Test Case | Pass Criteria |
|--------|-----------|--------------|
| Login | Google Sign-In | Auth → profile → team select → map |
| Login | Apple Sign-In | Auth → profile → team select → map |
| Login | Guest mode | Limited access, no server sync |
| Map | Hex display (zone/district/province) | Correct colors, smooth zoom transitions |
| Map | Scope boundary rendering | Province merged boundary, district dashed lines |
| Map | Outside province banner | Banner shows when GPS ≠ home province |
| Map | Ad display (non-pro) | AdMob banner loads without error |
| Map | Ad hidden (pro) | No ad after purchase/debug toggle |
| Run | Start → capture → stop | Hexes flip, points accumulate, final sync |
| Run | Pause/resume | Timer pauses, GPS continues (no hex capture) |
| Run | Crash recovery | Checkpoint restore on relaunch |
| Run | Voice announcements | Per-km announcements play correctly |
| Leaderboard | Rankings display | Correct rank, points, stability score |
| Leaderboard | Scope filtering | Zone/District/Province filters work |
| Team | Buff display | Correct multiplier breakdown |
| Team | Territory stats | Hex dominance percentages correct |
| Team | Purple defection | Irreversible, points preserved |
| Profile | Location update | FROM → TO confirmation dialog |
| Profile | Remove Ads (debug) | Debug toggle works in development |
| Profile | Remove Ads (production) | RevenueCat purchase flow completes |
| Profile | Restore purchases | Pro status restored from RevenueCat |
| History | Run calendar | Correct day markers, run details |
| History | Period stats | DAY/WEEK/MONTH/YEAR aggregates correct |

### 9.2 Device Matrix

| Device | OS Version | Screen Size | Priority |
|--------|-----------|-------------|----------|
| iPhone 15 Pro | iOS 17+ | 6.1" | P0 |
| iPhone SE 3 | iOS 16+ | 4.7" | P0 |
| iPhone 15 Pro Max | iOS 17+ | 6.7" | P1 |
| iPad Air | iPadOS 17+ | 10.9" | P2 |
| Pixel 8 | Android 14+ | 6.2" | P0 |
| Samsung Galaxy S24 | Android 14+ | 6.2" | P1 |
| Budget Android | Android 12+ | 6.5" | P1 |

### 9.3 GPS Simulation Tests

```bash
# Available simulation scripts
./simulate_run.sh        # Standard 2km run (5:30 pace)
./simulate_run_fast.sh   # Fast 2km run (4:30 pace)

# Manual simulation via Xcode
# Debug → Simulate Location → Custom GPX file
```

Verify:
- Moving average pace calculation (20-sec window)
- Hex capture triggers at correct boundaries
- Speed cap (25 km/h) rejects spoofed locations
- GPS accuracy filter (≤50m) rejects poor signals
- Accelerometer validation (real device only)

---

## 10. Monitoring & Alerting

### 10.1 Supabase Dashboard Monitors

| Metric | Warning Threshold | Critical Threshold |
|--------|-------------------|-------------------|
| API requests/min | > 500 | > 1,000 |
| Database connections | > 60% pool | > 85% pool |
| Response time p95 | > 1s | > 3s |
| Error rate (5xx) | > 0.5% | > 2% |
| Database size | > 500 MB | > 1 GB |
| Edge Function invocations | > 1,000/hr | > 5,000/hr |

### 10.2 Custom Health Check Query

Run every 5 minutes via external monitor:

```sql
SELECT jsonb_build_object(
  'status', 'healthy',
  'timestamp', NOW(),
  'active_users_today', (
    SELECT COUNT(DISTINCT user_id)
    FROM public.run_history
    WHERE run_date = CURRENT_DATE
  ),
  'latest_snapshot_date', (
    SELECT MAX(snapshot_date)
    FROM public.hex_snapshot
  ),
  'latest_buff_date', (
    SELECT MAX(stat_date)
    FROM public.daily_buff_stats
  ),
  'total_users', (
    SELECT COUNT(*) FROM public.users
  )
) AS health;
```

### 10.3 Alerting Rules

| Alert | Condition | Channel |
|-------|-----------|---------|
| Snapshot missing | No snapshot for tomorrow by 00:10 GMT+2 | Slack + SMS |
| Buff stats missing | No buff stats for today by 00:10 GMT+2 | Slack + SMS |
| High error rate | > 2% 5xx errors in 5 min window | Slack |
| Slow RPC | finalize_run() p95 > 3s for 5 min | Slack |
| Points drift detected | Points integrity check fails | Slack + SMS |
| Database near capacity | > 80% storage used | Email |

---

## 11. Rollback Plan

### 11.1 Database Rollback

```sql
-- If config-driven buff multipliers cause issues, revert to hardcoded:
-- (Rollback migration 20260221000000)
-- Delete buff config from app_config
UPDATE public.app_config
SET config_data = config_data - 'buff',
    updated_at = NOW()
WHERE id = 1;

-- Restore original get_user_buff() from migration 20260219000000
-- (Keep as separate rollback SQL file)
```

### 11.2 App Version Rollback

| Scenario | Action |
|----------|--------|
| Critical client bug | Expedite review for hotfix build |
| Server incompatibility | Toggle `force_update` flag in app_config |
| RevenueCat integration failure | Disable pro check (show ads to all) |
| AdMob crash | Disable ad loading via remote config flag |

### 11.3 Emergency Procedures

```
1. TOTAL OUTAGE (Supabase down)
   - App continues in offline mode (cached data)
   - Runs save locally, sync when restored
   - Status page: communicate via social media

2. DATA CORRUPTION
   - Identify scope (which table, which date range)
   - Restore from Supabase daily backup (available on Pro tier)
   - Re-run affected midnight cron jobs
   - Reconcile user season_points from run_history

3. SEASON RESET FAILURE (D-Day)
   - Manual TRUNCATE of season tables
   - Re-seed season configuration
   - Force-refresh all clients via remote config version bump
```

---

## Appendix A: SQL Templates

### A.1 Create Virtual User

```sql
INSERT INTO public.users (id, name, team, avatar, season_points, district_hex, home_hex, total_distance_km, total_runs)
VALUES (
  gen_random_uuid(),
  'VRunner_' || floor(random() * 10000)::TEXT,
  (ARRAY['red', 'blue', 'purple'])[floor(random() * 2 + 1)::INT],  -- 50/50 red/blue
  '🏃',
  0,
  '861203a4fffffff',  -- example district hex
  '891203a4003ffff',  -- example home hex (Res 9)
  0,
  0
);
```

### A.2 Cleanup Virtual Data

```sql
-- Remove all virtual runners (prefix-based)
DELETE FROM public.run_history WHERE user_id IN (
  SELECT id FROM public.users WHERE name LIKE 'VRunner_%'
);
DELETE FROM public.runs WHERE user_id IN (
  SELECT id FROM public.users WHERE name LIKE 'VRunner_%'
);
DELETE FROM public.daily_stats WHERE user_id IN (
  SELECT id FROM public.users WHERE name LIKE 'VRunner_%'
);
DELETE FROM public.users WHERE name LIKE 'VRunner_%';

-- Rebuild snapshots after cleanup
SELECT build_daily_hex_snapshot();
SELECT calculate_daily_buffs();
SELECT build_season_leaderboard_snapshot();
```

---

## Appendix B: Reference Documents

| Document | Purpose |
|----------|---------|
| `CLAUDE.md` | Codebase conventions, architecture rules, data domains |
| `DEVELOPMENT_SPEC.md` | Full game rules, buff calculations, hex mechanics |
| `DATA_FLOW_ANALYSIS.md` | Data models, field redundancy, flow diagrams |
| `AGENTS.md` | Agent-focused project reference |
| `riverpod_rule.md` | Riverpod 3.0 patterns and best practices |
| `supabase/migrations/` | All database schema and function definitions |
