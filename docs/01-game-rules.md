# RunStrict Game Rules & Mechanics

> Detailed reference for all game rules. Read DEVELOPMENT_SPEC.md (index) first.

**Cross-references:**
- UI screens and layouts → [02-ui-screens.md](./02-ui-screens.md)
- Data models and SQL schemas → [03-data-architecture.md](./03-data-architecture.md)
- Sync, performance, and GPS config → [04-sync-and-performance.md](./04-sync-and-performance.md)
- Edge Functions and server logic → [05-backend-functions.md](./05-backend-functions.md)

---

## Table of Contents

1. [Season & Time System](#1-season--time-system)
2. [Teams & Factions](#2-teams--factions)
3. [Team-Based Buff System](#3-team-based-buff-system)
4. [Hex Capture Mechanics](#4-hex-capture-mechanics)
5. [Economy & Points](#5-economy--points)
6. [Pace Consistency (CV & Stability Score)](#6-pace-consistency-cv--stability-score)
7. [Ranking & Leaderboard](#7-ranking--leaderboard)
8. [Purple Team: Protocol of Chaos](#8-purple-team-protocol-of-chaos)
9. [D-Day Reset Protocol (The Void)](#9-d-day-reset-protocol-the-void)
10. [Appendix](#10-appendix)

---

## 1. Season & Time System

| Property | Value |
|----------|-------|
| Season Duration | 40 days (D-40 → D-0) |
| Server Timezone | GMT+2 (Israel Standard Time) |
| Season Start | Immediately after previous season ends |
| Purple Unlock | Available anytime during season |

**Rules:**
- The server operates on an absolute countdown. All users share the same timeline.
- Remaining days vary by entry point (e.g., joining at D-40 vs D-5).
- On D-0, all Flip Points, Buff data, and Rankings are wiped.
- Personal running history (Calendar/DailyStats) persists across seasons.
- No daily settlement cycle — points are calculated in real-time.

---

## 2. Teams & Factions

| Team | Code | Display Name | Emoji | Color | Base Multiplier |
|------|------|-------------|-------|-------|-----------------|
| Red | `red` | FLAME | 🔥 | `#FF003C` | 1x |
| Blue | `blue` | WAVE | 🌊 | `#008DFF` | 1x |
| Purple | `purple` | CHAOS | 💜 | `#8B5CF6` | 1x |

**Rules:**
- On first entry, user MUST choose Red or Blue.
- Team choice is locked for the entire season.
- **Exception**: User can defect to Purple anytime (see §8).
- Purple is available anytime during the season.
- All teams have the same base multiplier (1x). Advantage comes from team-based buffs (see §3).

---

## 3. Team-Based Buff System

> **DEPRECATED**: The Crew System has been replaced by the Team-Based Buff System as of 2026-02-01.

### 3.1 Buff Matrix Overview

Each team earns buff multipliers based on different mechanics:

| Team | Buff Basis | Max Multiplier |
|------|-----------|----------------|
| RED | Individual performance (Elite vs Common) + Territory | 4x (Elite) / 2x (Common) |
| BLUE | Territory dominance (District + Province) | 3x |
| PURPLE | District participation rate | 3x (no Province bonus) |

### 3.2 RED Team Buffs (Elite System)

RED rewards **individual excellence** with territory bonuses.

| Scenario | Elite (Top 20%) | Common |
|----------|-----------------|--------|
| Normal (no territory wins) | 2x | 1x |
| District win only | 3x | 1x |
| Province win only | 3x | 2x |
| District + Province win | 4x | 2x |

**Definitions:**
- **Elite**: Top 20% of yesterday's **Flip Points** (points with multiplier applied, NOT raw flip count) among RED runners in the same District. Threshold stored in `daily_buff_stats.red_elite_threshold_points`, computed from `run_history.flip_points`.
- **Common**: Bottom 80% of RED runners in the District.
- **District Win**: RED controls the most hexes in this District (yesterday midnight snapshot).
- **Province Win**: RED controls the most hexes server-wide (yesterday midnight snapshot).

**Calculation Logic:**
- Elite Base: 2x
- Elite + District Win: +1x → 3x
- Elite + Province Win: +1x → 3x
- Elite + Both Wins: +1x + 1x → 4x
- Common Base: 1x
- Common + District Win: +0x → 1x (no district bonus for Common)
- Common + Province Win: +1x → 2x
- Common + Both Wins: +1x → 2x (no district bonus for Common)

### 3.3 BLUE Team Buffs (Union System)

BLUE rewards **collective participation** with equal territory bonuses.

| Scenario | Union (All BLUE) |
|----------|------------------|
| Normal (no territory wins) | 1x |
| District win only | 2x |
| Province win only | 2x |
| District + Province win | 3x |

**Definitions:**
- **Union**: All BLUE users who ran yesterday in the same District benefit equally.
- **District Win**: BLUE controls the most hexes in this District (yesterday midnight snapshot).
- **Province Win**: BLUE controls the most hexes server-wide (yesterday midnight snapshot).

**Calculation Logic:**
- Union Base: 1x
- Union + District Win: +1x → 2x
- Union + Province Win: +1x → 2x
- Union + Both Wins: +1x + 1x → 3x

### 3.4 PURPLE Team Buffs (Chaos System)

PURPLE rewards **participation rate** within District scope.

| Participation Rate (R) | Multiplier | Province Range Bonus |
|------------------------|------------|----------------------|
| R ≥ 60% | 3x | None |
| 30% ≤ R < 60% | 2x | None |
| R < 30% | 1x | None |

**Definitions:**
- **Participation Rate (R)**: Yesterday's PURPLE runners / Total PURPLE users in District.
- **No Province Range**: PURPLE does not receive server-wide dominance bonus.
- **District Leader status**: Does not affect PURPLE buff (same multiplier regardless).

**Examples:**
- 70% of District's PURPLE users ran yesterday = **3x**
- 45% participation = **2x**
- 20% participation = **1x**

### 3.5 Buff Timing & Calculation

| Property | Value |
|----------|-------|
| Calculation Time | Daily at midnight (GMT+2) via Edge Function |
| Display Timing | Shown at run START (frozen for entire run) |
| Scope | District-level (determined by user's home hex) |
| Mid-day changes | Buff frozen at run start; new district = new buff next day |

**Rules:**
- Buff is **frozen** when a run starts. Mid-run location changes don't affect multiplier.
- Users see their buff breakdown before starting a run.
- Server-configurable thresholds via `app_config.buff_config`.

### 3.6 Purple Defection (Unchanged)

| Property | Value |
|----------|-------|
| Unlock Condition | Available anytime during season |
| Entry Cost | Points are **PRESERVED** (not reset) |
| Requirement | Permanent team change for remainder of season |

**Rules:**
- Only users who defect from Red/Blue can become Purple.
- Defection permanently changes team for the remainder of the season.
- No special requirements beyond being Red/Blue.

---

## 4. Hex Capture Mechanics

### 4.1 Hex Grid Configuration

**Base Gameplay Resolution:**

| Property | Value |
|----------|-------|
| H3 Resolution | **9** (Base) |
| Avg Hex Edge Length | ~174m |
| Avg Hex Area | ~0.10 km² |
| Target Coverage | Block level (~170m radius) |

> All flip points are calculated at Resolution 9. This ensures equal point value for every hex regardless of geographic location.

**Geographic Scope Resolutions (for MapScreen & Leaderboard):**

| Scope | Enum | H3 Resolution | Avg Edge | Avg Area | Purpose |
|-------|------|---------------|----------|----------|---------|
| ZONE | `zone` | 8 (Parent of 9) | ~461m | ~0.73 km² | Neighborhood leaderboard |
| DISTRICT | `district` | 6 (Parent of 9) | ~3.2km | ~36 km² | District leaderboard |
| PROVINCE | `province` | 4 (Parent of 9) | ~22.6km | ~1,770 km² | Metro/Regional leaderboard |

> H3 uses Aperture 7: each parent hex contains ~7 children. Scope filtering uses `cellToParent()` to group users by their parent hex at the scope resolution.

### 4.2 Capture Rules

| Rule | Value |
|------|-------|
| Pace Threshold | < 8:00 min/km **moving average (last 20 sec)** |
| Speed Cap | < 25 km/h (anti-spoofing) |
| GPS Accuracy | Must be ≤ 50m to be valid |
| GPS Polling | Fixed 0.5 Hz (every 2 seconds) |
| Trigger | GPS coordinate enters hex boundary (immediate) |
| Color Logic | Hex displays color of LAST runner only |
| Stored Data | `lastRunnerTeam` + `last_flipped_at` (no runner ID) |

**Rules:**
- A hex changes color when a valid runner's GPS enters the hex boundary.
- "Valid runner" = **moving average pace (last 20 sec)** < 8:00 min/km AND speed < 25 km/h AND GPS accuracy ≤ 50m.
- **Moving Average Pace (20 sec)** = average pace over the last 20 seconds of movement.
  - At 0.5Hz GPS polling, provides ~10 samples for stable pace calculation.
  - Smooths out GPS noise and momentary speed fluctuations.
  - Prevents false captures from GPS jumps.
  - This means a runner can walk for 10 minutes, then jog for 20+ seconds to capture hexes.
- Purple runners paint hexes purple (regardless of original team before defection).
- No ownership mechanic — only "who ran here last".
- Accelerometer validation is required even in MVP (anti-spoofing).

### 4.3 Flip Definition

A **Flip** occurs when a hex changes color (any color change counts).

| Transition | Is Flip? | Points? |
|------------|----------|---------|
| Neutral → Red | ✅ Yes | +1 Flip Point |
| Neutral → Blue | ✅ Yes | +1 Flip Point |
| Red → Blue | ✅ Yes | +1 Flip Point |
| Blue → Red | ✅ Yes | +1 Flip Point |
| Red → Purple | ✅ Yes | +1 Flip Point |
| Blue → Purple | ✅ Yes | +1 Flip Point |
| Red → Red (same team) | ❌ No | 0 |

**No streak bonus.** No flip caps of any kind (unlimited flips per day, different users can each flip the same hex independently; same user cannot re-flip own hex due to snapshot isolation).

---

## 5. Economy & Points

### 5.1 Flip Points

| Property | Value |
|----------|-------|
| Earning Method | Flipping a hex (any color change) |
| Base Points Per Flip | 1 |
| Multiplier | Team-based buff (see §3) |
| Scope | Individual |
| Reset | Wiped on D-0 (season end) |

**Rules:**
- All Flip Points belong to the individual.
- Points are calculated at run completion ("The Final Sync").
- Multiplier is determined by team-based buff system (see §3).
- No streak bonuses. No daily total cap. **No daily hex limit** (different users can each flip the same hex independently; same user cannot re-flip own hex due to snapshot isolation).

### 5.2 Team-Based Buff Multiplier

> **Design Goal**: Team-based competitive dynamics with different buff mechanics per team.

The buff multiplier is determined by team, performance tier, and territory dominance (see §3 for full details).

| Team | Condition | Multiplier Range |
|------|-----------|-----------------|
| RED Elite | Base 2x + District Win (+1x) + Province Win (+1x) | 2x - 4x |
| RED Common | Base 1x + Province Win (+1x) | 1x - 2x |
| BLUE | Base 1x + District Win (+1x) + Province Win (+1x) | 1x - 3x |
| PURPLE | Participation Rate (R) | 1x - 3x |

**Rules:**
- Multiplier is calculated once daily at midnight (GMT+2) and fixed for the entire day.
- Users see their buff before starting a run (buff breakdown screen).
- Buff is **frozen** when run starts - no changes mid-run.
- **New users**: Default multiplier is **1x** until they have yesterday's data.
- **District determination**: User's home hex (first run location) determines their District scope.

**Advantages:**
- **Server efficiency**: Buff calculated once per day via Edge Function.
- **Predictability**: Users know their buff at the start of each day.
- **Strategy**: Teams can coordinate district dominance and participation.
- **Competition**: RED rewards individual excellence, BLUE rewards solidarity, PURPLE rewards district-wide consistency.

### 5.3 Hex Snapshot System

> **Design Goal**: Deterministic flip point calculation. All users run against the same daily hex snapshot.

**Core Principle: Separation of Concerns**

| Concern | Source | Purpose |
|---------|--------|---------|
| Flip Points calculation | Yesterday's hex snapshot | Deterministic, same baseline for all users |
| Hex ownership tracking | Today's run activity (hex_path + end_time) | Builds tomorrow's snapshot at midnight |
| Map display | Snapshot + user's own today's runs (local overlay) | Visual feedback |

**Snapshot Lifecycle:**

```
[Midnight GMT+2 — Server builds snapshot via pg_cron]
  1. Start from yesterday's hex_snapshot (previous day's final state)
  2. Apply ALL today's synced runs (from `runs` table, filtered by end_time within today GMT+2)
  3. Conflict resolution: "Last run end-time wins" — later end_time determines hex color
  4. Write result to `hex_snapshot` table with snapshot_date = tomorrow
  5. This becomes tomorrow's "starting point" for all users
  6. Runs that end after midnight (cross-midnight runs) → affect next day's snapshot

[Client Prefetch — App Launch / OnResume / Pre-run]
  1. Download hex_snapshot WHERE snapshot_date = today (yesterday's midnight result)
  2. Load into HexRepository as base layer
  3. Apply local overlay: hexes flipped by THIS USER today (from local SQLite)
  4. Map screen shows: snapshot + own local flips
  5. Other users' today activity is INVISIBLE until tomorrow's snapshot

[During Run — Client-side flip counting]
  For each hex entered:
  1. Look up hex in HexRepository (snapshot + own local overlay)
  2. If hex color ≠ runner's team → FLIP (+1 point)
  3. If hex color = runner's team → NO FLIP
  4. If hex not in cache (neutral/absent from snapshot) → FLIP (+1 point)
  5. Update local overlay with new color
  6. Same hex can only flip once per run (session dedup)
  
  flip_points = total_flips × buff_multiplier (frozen at run start)

[Run Completion — "The Final Sync"]
  Client uploads:
    → hex_path[] (all hexes passed through)
    → flip_points (client-calculated)
    → buff_multiplier (frozen at run start)
    → end_time
  
  Server (finalize_run):
    → Validate: flip_points ≤ len(hex_path) × buff_multiplier (simple cap)
    → Award points: season_points += flip_points
    → Store hex_path + end_time in `runs` table (used at midnight for snapshot build)
    → Update `hexes` table for live buff/dominance calculations
    → INSERT INTO run_history (lightweight stats, preserved)
    → Do NOT modify hex_snapshot (immutable until midnight)
```

**Cross-Run Same-Day Behavior:**
- User runs at 9am → flips hex X (blue→red locally in overlay)
- User runs at 2pm → client has snapshot (blue) + local overlay (red from 9am)
- Hex X shows RED → same team → **no flip** (correct dedup)
- **Different users**: Both see snapshot (blue). Both can flip independently. Both earn points.

**Midnight-Crossing Runs:**
- Run starts 23:45 Feb 15, ends 00:30 Feb 16 (GMT+2)
- `end_time` = Feb 16 → hex_path goes into Feb 16's snapshot build
- Flip points use the buff frozen at run start (Feb 15's buff)

**Conflict Resolution Rule ("Later Run Wins" — Snapshot Build Only):**
- During midnight snapshot build, when multiple runs affect the same hex, the run with the latest `end_time` determines the hex color in the snapshot.
- This is for snapshot construction only — flip points are NOT recalculated.
- The `hexes` table (live state) also uses this rule for buff/dominance calculations.
- Flip points are always calculated by the client against the downloaded snapshot.

---

## 6. Pace Consistency (CV & Stability Score)

### 6.1 Coefficient of Variation (CV)

| Property | Value |
|----------|-------|
| Purpose | Measure pace consistency during runs |
| Formula | `CV = (standard deviation / mean) × 100` of 1km lap paces |
| Denominator | Sample standard deviation (n-1) |
| Calculation | At run completion, from recorded lap data |
| Min Requirement | ≥ 1 km run (at least one complete lap) |
| Single Lap | Returns CV = 0 (no variance possible) |

**Lap Recording:**
- Laps are recorded automatically during runs
- Each lap = 1 kilometer of running
- Lap data: `lapNumber`, `distanceMeters`, `durationSeconds`, `startTimestampMs`, `endTimestampMs`
- Stored in local SQLite `laps` table

**CV Calculation (LapService):**
```dart
static double? calculateCV(List<LapModel> laps) {
  if (laps.isEmpty) return null;
  if (laps.length == 1) return 0.0;

  final paces = laps.map((lap) => lap.avgPaceSecPerKm).toList();
  final mean = paces.reduce((a, b) => a + b) / paces.length;
  
  // Sample standard deviation (n-1 denominator)
  final sumSquaredDiffs = paces.fold<double>(0, (sum, pace) => sum + pow(pace - mean, 2));
  final variance = sumSquaredDiffs / (paces.length - 1);
  final stdev = sqrt(variance);
  
  return (stdev / mean) * 100;
}
```

### 6.2 Stability Score

| Property | Value |
|----------|-------|
| Formula | `Stability Score = 100 - CV` (clamped 0-100) |
| Interpretation | Higher = more consistent pace (better) |
| Display | Badge on leaderboard podium and rank tiles |
| Color Coding | Green (≥80), Yellow (50-79), Red (<50) |

**User Average CV:**
- Users accumulate an **average CV** across all qualifying runs
- Updated incrementally with each run via `finalize_run()` RPC
- Runs < 1km do not contribute to average CV

---

## 7. Ranking & Leaderboard

| Property | Value |
|----------|-------|
| Type | Season cumulative only (no daily/weekly) |
| Ranking Metric | Individual accumulated Flip Points |
| Team Buff Impact | Via team-based buff multipliers |
| Display | Top rankings based on user's "home hex" |
| Stability Badge | Shows user's stability score on podium and rank tiles |

### 7.1 Home Hex System (Asymmetric Definition)

> **Design Goal**: Determine user's ranking scope based on their most recent running location, with privacy-preserving asymmetry.

**Home Hex Definition (Asymmetric):**

| User Type | Home Hex Definition | Rationale |
|-----------|---------------------|-----------|
| **Current User (self)** | **FIRST hexagon** of most recent run (start point) | Privacy: Don't reveal where you ended |
| **Other Users** | **LAST hexagon** of most recent run (end point) | Standard: Most recent location |

- The Home Hex is updated at run completion (part of "The Final Sync").
- Home Hex determines which zone/district/province scope the user belongs to for leaderboard filtering.
- **Privacy Rationale**: By using the START hex for yourself, your actual ending location (potentially your home) is not revealed to others viewing your ranking scope.
- **Zero-hex run**: If `hex_path` is empty (GPS failed, indoor run, etc.), **home hex is NOT updated**. Previous home hex values are preserved.

**Geographic Scope Filters (based on Home Hex):**

| Scope | Enum | H3 Resolution | Definition | Display |
|-------|------|---------------|-----------|---------|
| **ZONE** | `zone` | 8 (Parent of 9) | Users whose Home Hex shares the same Resolution 8 parent | Neighborhood rankings (~461m radius) |
| **DISTRICT** | `district` | 6 (Parent of 9) | Users whose Home Hex shares the same Resolution 6 parent | District rankings (~3.2km radius) |
| **PROVINCE** | `province` | — | All users server-wide | Regional/Global rankings |

**Implementation:**
```dart
// Get user's home hex (asymmetric based on viewer)
String getHomeHex(RunSummary run, {required bool isSelf}) {
  final hexPath = run.hexPath;
  if (hexPath.isEmpty) return '';
  
  // Self sees START hex, others see END hex
  return isSelf ? hexPath.first : hexPath.last;
}

// Get user's scope hex from their home hex
String getHomeHexAtScope(String homeHex, GeographicScope scope) {
  return switch (scope) {
    GeographicScope.zone => h3.cellToParent(homeHex, 8),
    GeographicScope.district => h3.cellToParent(homeHex, 6),
    GeographicScope.province => null, // No filtering
  };
}
```

**Rules:**
- Leaderboard shows top users per selected scope based on shared parent hex.
- **Current user's scope** is determined by their own FIRST hex (start point).
- **Other users' scope** is determined by their LAST hex (end point).
- Users outside top ranks see their own rank in a sticky footer.
- Purple users have a distinct glowing border in the province view.
- Team filter tabs: [ALL] / [RED] / [BLUE] / [PURPLE].
- **Ranking snapshot**: Downloaded once on app launch, NOT polled in real-time.
- Leaderboard reads from `season_leaderboard_snapshot` (NOT live `users` table).

---

## 8. Purple Team: Protocol of Chaos

### 8.1 Unlock & Entry

| Property | Value |
|----------|-------|
| Availability | Anytime during season (no restriction) |
| Entry Name | "Traitor's Gate" |
| Entry Cost | Points **PRESERVED** (not reset) |
| Eligibility | Any Red/Blue user |

**Rules:**
- Purple is available anytime during the 40-day season.
- Once defected, cannot return to Red/Blue for the remainder of the season.
- No minimum Flip Point threshold to defect (anyone can defect).
- Defection is permanent for the remainder of the season.
- Points are preserved upon defection.

### 8.2 Purple Mechanics

| Property | Value |
|----------|-------|
| Buff Basis | District participation rate |
| Max Multiplier | 3x (no Province Range bonus) |
| Hex Color | Purple (distinct from Red/Blue) |
| Role | "Virus/Joker" — rewards consistent district-wide Purple participation |

---

## 9. D-Day Reset Protocol (The Void)

| Step | Action | Method |
|------|--------|--------|
| 1 | Season countdown reaches D-0 | Scheduled Edge Function |
| 2 | All hex colors reset to neutral | `TRUNCATE TABLE hexes` (instant) |
| 3 | All buff stats cleared | `TRUNCATE TABLE daily_buff_stats` (instant) |
| 4 | All Flip Points & team wiped | `UPDATE users SET season_points=0, team=NULL` |
| 5 | Drop season's `runs` partitions (heavy data) | `DROP TABLE runs_p20XX_XX` (instant disk reclaim) |
| 6 | `run_history` preserved | Personal run stats untouched |
| 7 | `daily_stats` preserved | Aggregated daily stats untouched |
| 8 | Next season begins immediately (D-40) | New season record created |
| 9 | All users must re-select Red or Blue | `team = NULL` forces re-selection |

**Data Preservation:**
- ✅ Kept: `run_history` (per-run stats), `daily_stats` (aggregated daily)
- ❌ Wiped: `runs` (heavy hex_path data), Flip Points, Buff stats, Rankings, Hex colors, Team
- ⚡ Deletion Method: `TRUNCATE`/`DROP PARTITION` = **$0 cost, < 1 second**, no performance impact

---

## 10. Appendix

### A. User Identity Rules

| State | Avatar Display | Leaderboard Name |
|-------|---------------|-----------------|
| Red/Blue user | Personal avatar | User name |
| Defected to Purple | Personal avatar | User name |

### B. Team-Based Buff Multiplier Examples

| Team | Scenario | Multiplier | Flip Points per Flip |
|------|----------|------------|---------------------|
| RED | Elite (Top 20%) + District Leader + Province Range | 4x | 4 |
| RED | Elite + District Leader (no Province Range) | 3x | 3 |
| RED | Elite (non-leader district) | 2x | 2 |
| RED | Common (any district) | 1x | 1 |
| BLUE | District Leader + Province Range | 3x | 3 |
| BLUE | District Leader (no Province Range) | 2x | 2 |
| BLUE | Non-leader district | 1x | 1 |
| PURPLE | ≥60% district participation | 3x | 3 |
| PURPLE | 30-59% district participation | 2x | 2 |
| PURPLE | <30% district participation | 1x | 1 |
| Any | New user (no yesterday data) | 1x | 1 |

**Key Points:**
- Multiplier is calculated at midnight (GMT+2), fixed for the entire day.
- Buff is **frozen** when run starts — no changes mid-run.
- Server calculates once per day via Edge Function.
- District scope determined by user's home hex.

### C. Leaderboard Geographic Scope

Geographic scope filtering uses H3's hierarchical parent cell system. Users are grouped by their parent hex ID at the scope's resolution level.

**Implementation (lib/core/config/h3_config.dart):**

| Scope | H3 Resolution | Map Zoom | Filter Logic |
|-------|---------------|----------|--------------|
| **ZONE** | 8 | 15.0 | `cellToParent(userHex, 8)` — Neighborhood (~461m) |
| **DISTRICT** | 6 | 12.0 | `cellToParent(userHex, 6)` — District (~3.2km) |
| **PROVINCE** | 4 | 10.0 | No filter — server-wide ranking |

**Client Flow:**
1. Get user's current base hex (Resolution 9)
2. Convert to scope resolution via `getScopeHexId(baseHex, scope)`
3. Query Supabase RPC with scope hex ID to filter rankings

**Approximate Coverage:**
- ZONE (Res 8): ~7 base hexes, neighborhood-level competition
- DISTRICT (Res 6): ~343 base hexes, district-level competition
- PROVINCE (Res 4): ~16,807 base hexes, metro-wide competition

### D. Slogans

**Korean:**
- "같은 땀, 다른 색" (Same sweat, different colors)
- "우리는 반대로 달려 만났다" (We ran apart, met together)
- "배신은 새로운 시작이다" (Betrayal is a new beginning)

**English:**
- "Run Apart, Meet Together"
- "Same Path, Different Colors"
- "Embrace the Chaos"

### E. Season Flow Diagram

```
D-40 ────────────────────────────────────────────── D-0
 │                                                    │
 ├─ Team Selection (Red/Blue)                         │
 │                                                    │
 ├─ Run → Flip Hexes → Earn Flip Points               │
 │    └─ flip_points = hexes_flipped × buff_multiplier│
 │                                                    │
 ├─ Daily at Midnight (GMT+2):                        │
 │    ├─ Buff recalculated (Elite/Union/Participation) │
 │    └─ hex_snapshot rebuilt ("Later Run Wins")      │
 │                                                    │
 ├─ [Optional] Defect to Purple (irreversible)        │
 │    └─ Entry: "Traitor's Gate" — Points PRESERVED   │
 │                                                    │
 └─────────────────────────────────────────────────── THE VOID
                                                      (All data wiped)
                                                      run_history preserved ✅
```

### F. Key Terminology Glossary

| Term | Definition |
|------|------------|
| **Flip** | A hex changing color from one team to another (or from neutral) |
| **Flip Points** | Points earned per flip × buff multiplier |
| **The Final Sync** | Batch upload of run data at run completion |
| **The Void** | D-Day reset — all season data wiped |
| **FLAME** | Red team display name |
| **WAVE** | Blue team display name |
| **CHAOS** | Purple team display name |
| **Traitor's Gate** | Entry screen for defecting to Purple |
| **Elite** | Top 20% of RED runners by Flip Points in their District |
| **Common** | Bottom 80% of RED runners in their District |
| **Union** | All BLUE runners (equal buff regardless of individual performance) |
| **Home Hex** | The hex used to determine a user's leaderboard scope |
| **Snapshot** | Daily frozen hex state used as baseline for flip counting |
| **Local Overlay** | User's own today's flips applied on top of snapshot |
| **Session Dedup** | Same hex can only flip once per run |
| **District** | H3 Resolution 6 parent hex (~3.2km edge, ~36 km²) |
| **Province** | H3 Resolution 4 parent hex (~22.6km edge, ~1,770 km²) |
| **Zone** | H3 Resolution 8 parent hex (~461m edge, ~0.73 km²) |
| **CV** | Coefficient of Variation — pace consistency metric |
| **Stability Score** | 100 - CV, clamped 0-100 (higher = more consistent) |
