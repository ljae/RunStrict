# RunStrict Development Specification: "The 40-Day Journey"

> **Last Updated**: 2026-02-01  
> **App Name**: RunStrict (The 40-Day Journey)  
> **Current Season Status**: D-40 (Pre-season)

---

## Table of Contents

1. [Project Overview](#1-project-overview)
2. [Rule Definitions](#2-rule-definitions)
   - 2.1 Season & Time System
   - 2.2 Teams & Factions
   - 2.3 Team-Based Buff System
   - 2.4 Hex Capture Mechanics
   - 2.5 Economy & Points
   - 2.6 Pace Consistency (CV & Stability Score)
   - 2.7 Ranking & Leaderboard
   - 2.8 Purple Team: Protocol of Chaos
   - 2.9 D-Day Reset Protocol
3. [UI Structure](#3-ui-structure)
   - 3.1 Navigation Architecture
   - 3.2 Screen Specifications
   - 3.3 Widget Library
   - 3.4 Theme & Visual Language
4. [Data Structure](#4-data-structure)
   - 4.1 Client Models
   - 4.2 Database Schema (PostgreSQL)
   - 4.3 Data Lifecycle & Partitioning Strategy
   - 4.4 Hot vs Cold Data Strategy
   - 4.5 Local Storage (SQLite)
5. [Tech Stack & Architecture](#5-tech-stack--architecture)
   - 5.1 Backend Platform Decision
   - 5.2 Package Dependencies
   - 5.3 Directory Structure
   - 5.4 GPS Anti-Spoofing
6. [Development Roadmap](#6-development-roadmap)
7. [Success Metrics](#7-success-metrics)
8. [Appendix](#8-appendix)
9. [Performance & Optimization Configuration](#9-performance--optimization-configuration)
   - 9.1 Background Location Tracking Strategy
   - 9.2 GPS Polling & Battery Optimization
   - 9.3 Signal Processing & Noise Reduction
   - 9.4 Local Database (SQLite) Configuration
   - 9.5 Mapbox SDK & Cost Optimization
   - 9.6 Data Synchronization Strategy ("The Final Sync")
   - 9.7 Pace Visualization (Data-Driven Styling)
   - 9.8 Location Marker & Animation
   - 9.9 Privacy & Security
   - 9.10 Real-time Computation
   - 9.11 Recommended Configuration Summary
   - 9.12 Remote Configuration System

---

## 1. Project Overview

### Concept

A location-based running game that gamifies territory control through hexagonal maps.

- **Season**: Fixed **40 days**.
- **Reset**: On D-Day (D-0), all territories and scores are deleted (The Void). Only personal history remains.

### Core Philosophy

| Surface Layer | Hidden Layer |
|---------------|--------------|
| Red vs Blue competition | Connection through rivalry |
| Territory capture | Mutual respect growth |
| Weekly battles | Long-term relationships |
| "Win at all costs" | "We ran together" |

### Key Differentiators

- **Natural unity discovery** through competition phases
- **Team-Based Buff System**: Different buff mechanics per team (RED=Elite, BLUE=Union, PURPLE=Participation)
- **District Dominance**: Hex count determines District Leader status and buff bonuses
- **The Final Sync**: No real-time hex updates — batch upload at run completion (cost optimized)
- **Server-verified points**: Points calculated by client, validated by server (≤ hex_count × multiplier)
- **Privacy-first hex system**: Minimal timestamps for fairness (last_flipped_at), no runner IDs stored

---

## 2. Rule Definitions

### 2.1 Season & Time System

| Property | Value |
|----------|-------|
| Season Duration | 40 days (D-40 → D-0) |
| Server Timezone | GMT+2 (Israel Standard Time) |
| Season Start | Immediately after previous season ends |
| Purple Unlock | Available anytime during season |

**Rules:**
- The server operates on an absolute countdown. All users share the same timeline.
- Remaining days vary by entry point (e.g., joining at D-260 vs D-5).
- On D-0, all Flip Points, Buff data, and Rankings are wiped.
- Personal running history (Calendar/DailyStats) persists across seasons.
- No daily settlement cycle — points are calculated in real-time.

### 2.2 Teams & Factions

| Team | Code | Display Name | Emoji | Color | Base Multiplier |
|------|------|-------------|-------|-------|-----------------|
| Red | `red` | FLAME | 🔥 | `#FF003C` | 1x |
| Blue | `blue` | WAVE | 🌊 | `#008DFF` | 1x |
| Purple | `purple` | CHAOS | 💜 | `#8B5CF6` | 1x |

**Rules:**
- On first entry, user MUST choose Red or Blue.
- Team choice is locked for the entire season.
- **Exception**: User can defect to Purple anytime (see §2.8).
- Purple is available anytime during the season.
- All teams have the same base multiplier (1x). Advantage comes from team-based buffs (see §2.3).

### 2.3 Team-Based Buff System

> **DEPRECATED**: The Crew System has been replaced by the Team-Based Buff System as of 2026-02-01.

#### 2.3.1 Buff Matrix Overview

Each team earns buff multipliers based on different mechanics:

| Team | Buff Basis | Max Multiplier |
|------|-----------|----------------|
| RED | Individual performance (Elite vs Common) + Territory | 4x (Elite) / 2x (Common) |
| BLUE | Territory dominance (District + Province) | 3x |
| PURPLE | District participation rate | 3x (no Province bonus) |

#### 2.3.2 RED Team Buffs (Elite System)

RED rewards **individual excellence** with territory bonuses.

| Scenario | Elite (Top 20%) | Common |
|----------|-----------------|--------|
| Normal (no territory wins) | 2x | 1x |
| District win only | 3x | 1x |
| Province win only | 3x | 2x |
| District + Province win | 4x | 2x |

**Definitions:**
- **Elite**: Top 20% of yesterday's Flip Points among RED runners in the same District.
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

#### 2.3.3 BLUE Team Buffs (Union System)

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

#### 2.3.4 PURPLE Team Buffs (Chaos System)

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

#### 2.3.5 Buff Timing & Calculation

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

#### 2.3.6 Purple Defection (Unchanged)

| Property | Value |
|----------|-------|
| Unlock Condition | Available anytime during season |
| Entry Cost | Points are **PRESERVED** (not reset) |
| Requirement | Permanent team change for remainder of season |

**Rules:**
- Only users who defect from Red/Blue can become Purple.
- Defection permanently changes team for the remainder of the season.
- No special requirements beyond being Red/Blue.

### 2.4 Hex Capture Mechanics

#### 2.4.1 Hex Grid Configuration

**Base Gameplay Resolution:**

| Property | Value |
|----------|-------|
| H3 Resolution | **9** (Base) |
| Avg Hex Edge Length | ~174m |
| Avg Hex Area | ~0.10 km² |
| Target Coverage | Block level (~170m radius) |

> All flip points are calculated at Resolution 9. This ensures equal point value for every hex regardless of geographic location.

**Geographic Scope Resolutions (for MapScreen & Leaderboard):**

| Scope | H3 Resolution | Avg Edge | Avg Area | Purpose |
|-------|---------------|----------|----------|---------|
| ZONE | 8 (Parent of 9) | ~461m | ~0.73 km² | Neighborhood leaderboard |
| DISTRICT | 6 (Parent of 9) | ~3.2km | ~36 km² | District leaderboard |
| PROVINCE | 4 (Parent of 9) | ~22.6km | ~1,770 km² | Metro/Regional leaderboard |

> H3 uses Aperture 7: each parent hex contains ~7 children. Scope filtering uses `cellToParent()` to group users by their parent hex at the scope resolution.

#### 2.4.2 Capture Rules

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

#### 2.4.3 Flip Definition

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

**No streak bonus.** No flip caps of any kind (unlimited flips per day, same hex can be flipped multiple times).

### 2.5 Economy & Points

#### 2.5.1 Flip Points

| Property | Value |
|----------|-------|
| Earning Method | Flipping a hex (any color change) |
| Base Points Per Flip | 1 |
| Multiplier | Team-based buff (see §2.3) |
| Scope | Individual |
| Reset | Wiped on D-0 (season end) |

**Rules:**
- All Flip Points belong to the individual.
- Points are calculated at run completion ("The Final Sync").
- Multiplier is determined by team-based buff system (see §2.3).
- No streak bonuses. No daily total cap. **No daily hex limit** (same hex can be flipped multiple times per day).

#### 2.5.2 Team-Based Buff Multiplier

> **Design Goal**: Team-based competitive dynamics with different buff mechanics per team.

The buff multiplier is determined by team, performance tier, and territory dominance (see §2.3 for full details).

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
- **Strategy**: Teams can coordinate city dominance and participation.
- **Competition**: RED rewards individual excellence, BLUE rewards solidarity, PURPLE rewards district-wide consistency.

#### 2.5.3 Points Calculation Flow ("The Final Sync")

> **Design Goal**: Eliminate real-time hex synchronization. All data is uploaded at run completion.

```
[During Run - Local Only]
  Runner GPS → Client validates locally
  Hex flip detected → Client records to local hex_path list
  Points calculated locally using buff multiplier (frozen at run start)
  NO server communication during run

[Run Completion - Batch Sync]
  RunSession.endTime = now()
  Client uploads:
    → run_summary: { endTime, distanceKm, hex_path[], buffMultiplier }
  
  Server processes (RPC: finalize_run):
    → Count flips in hex_path (color changes from current hex state)
    → Award points: total_flips × buffMultiplier
    → Validate: buffMultiplier ≤ max allowed for user's team/tier
    → Conflict Resolution: Later endTime wins hex color
    → UPDATE hexes SET last_runner_team = team WHERE endTime > existing
    → UPDATE users SET season_points += total_points_earned
    → INSERT INTO run_history (lightweight stats, preserved across seasons)
```

**Conflict Resolution Rule ("Later Run Wins"):**
- `hexes` table stores `last_flipped_at` timestamp (run's endTime when hex was flipped).
- When multiple runners pass through the same hex, **the runner whose run ended later wins** the hex color.
- This prevents offline abusing: a runner cannot submit an old run to overwrite recent activity.
- Server compares `run_endTime` with existing `last_flipped_at`:
  - If `run_endTime > last_flipped_at` → Update hex color and timestamp
  - If `run_endTime ≤ last_flipped_at` → Skip update (hex already claimed by later run)
- Example: User A (run ends 10:00) passes Hex #123. User B (run ends 09:30) syncs later.
  - **User A wins** because their run ended later, regardless of sync order.
- **Flip points**: Calculated by client, **validated by server** (points ≤ hex_count × multiplier).

### 2.6 Pace Consistency (CV & Stability Score)

#### 2.6.1 Coefficient of Variation (CV)

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

#### 2.6.2 Stability Score

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

### 2.7 Ranking & Leaderboard

| Property | Value |
|----------|-------|
| Type | Season cumulative only (no daily/weekly) |
| Ranking Metric | Individual accumulated Flip Points |
| Team Buff Impact | Via team-based buff multipliers |
| Display | Top rankings per geographic scope (Zone/District/Province) based on user's "home hex" |
| Stability Badge | Shows user's stability score on podium and rank tiles |

#### 2.7.1 Home Hex System (Asymmetric Definition)

> **Design Goal**: Determine user's ranking scope based on their most recent running location, with privacy-preserving asymmetry.

**Home Hex Definition (Asymmetric):**

| User Type | Home Hex Definition | Rationale |
|-----------|---------------------|-----------|
| **Current User (self)** | **FIRST hexagon** of most recent run (start point) | Privacy: Don't reveal where you ended |
| **Other Users** | **LAST hexagon** of most recent run (end point) | Standard: Most recent location |

- The Home Hex is updated at run completion (part of "The Final Sync").
- Home Hex determines which ZONE/DISTRICT/PROVINCE scope the user belongs to for leaderboard filtering.
- **Privacy Rationale**: By using the START hex for yourself, your actual ending location (potentially your home) is not revealed to others viewing your ranking scope.
- **Zero-hex run**: If `hex_path` is empty (GPS failed, indoor run, etc.), **home hex is NOT updated**. Previous home hex values are preserved.

**Geographic Scope Filters (based on Home Hex):**

| Scope | H3 Resolution | Definition | Display |
|-------|---------------|-----------|---------|
| **ZONE** | 8 (Parent of 9) | Users whose Home Hex shares the same Resolution 8 parent | Neighborhood rankings (~461m radius) |
| **DISTRICT** | 6 (Parent of 9) | Users whose Home Hex shares the same Resolution 6 parent | District rankings (~3.2km radius) |
| **PROVINCE** | — | All users server-wide | Regional/Global rankings |

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
String getHomeHexAtScope(String homeHex, LeaderboardScope scope) {
  return switch (scope) {
    LeaderboardScope.zone => h3.cellToParent(homeHex, 8),
    LeaderboardScope.district => h3.cellToParent(homeHex, 6),
    LeaderboardScope.province => null, // No filtering
  };
}
```

**Rules:**
- Leaderboard shows top users per selected scope based on shared parent hex.
- **Current user's scope** is determined by their own FIRST hex (start point).
- **Other users' scope** is determined by their LAST hex (end point).
- Users outside top ranks see their own rank in a sticky footer.
- Purple users have a distinct glowing border in the [PROVINCE] view.
- Team filter tabs: [ALL] / [RED] / [BLUE] / [PURPLE].
- **Ranking snapshot**: Downloaded once on app launch, NOT polled in real-time.

### 2.8 Purple Team: Protocol of Chaos

#### 2.8.1 Unlock & Entry

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

#### 2.8.2 Purple Mechanics

| Property | Value |
|----------|-------|
| Buff Basis | District participation rate |
| Max Multiplier | 3x (no Province Range bonus) |
| Hex Color | Purple (distinct from Red/Blue) |
| Role | "Virus/Joker" — rewards consistent district-wide Purple participation |

### 2.9 D-Day Reset Protocol (The Void)

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

## 3. UI Structure

### 3.1 Navigation Architecture

```
App Entry
├── Team Selection Screen (first-time / new season)
└── Home Screen (Navigation Hub)
    ├── AppBar
    │   ├── [Left] Empty
    │   ├── [Center] FlipPoints Widget (animated counter, team-colored glow)
    │   └── [Right] Season Countdown Badge (D-day)
     ├── Bottom Tab Bar + Swipe Navigation
     │   ├── Tab: Map Screen
     │   ├── Tab: Running Screen
     │   ├── Tab: Leaderboard Screen
     │   └── Tab: Run History Screen (Calendar)
    └── Profile Screen (accessible from settings/menu)
        └── Manifesto (12-char, editable anytime)
```

**Navigation:** Bottom tab bar with horizontal swipe between tabs. Tab order follows current implementation.

### 3.2 Screen Specifications

#### 3.2.1 Team Selection Screen

| Element | Spec |
|---------|------|
| Purpose | Onboarding (first time) + new season re-selection |
| UI | Animated team cards with gradient text |
| Interaction | Tap to select Red or Blue |
| Lock | Cannot be revisited until next season |
| Purple | Not shown here (accessed via Traitor's Gate anytime) |

#### 3.2.2 Home Screen

| Element | Spec |
|---------|------|
| AppBar Left | Empty |
| AppBar Center | FlipPoints Widget |
| AppBar Right | Season Countdown Badge |
| Body | Selected tab content |
| Navigation | Bottom tabs + horizontal swipe |

**FlipPoints Widget Behavior:**
- Animated flip counter showing current season points
- On each flip: team-colored glow + scale bounce animation (current implementation)
- Designed for peripheral vision awareness during runs

#### 3.2.3 Map Screen (The Void)

| Element | Spec |
|---------|------|
| Default State | Grey/transparent hexes |
| Colored Hexes | Painted by running activity |
| User Location | Person icon inside a hexagon (team-colored) |
| Hex Interaction | None (view only) |
| Camera | Smooth pan to user location |

**Hex Visual States:**

| State | Fill Color | Opacity | Border | Animation |
|-------|-----------|---------|--------|-----------|
| Neutral | `#2A3550` | 0.15 | Gray `#6B7280`, 1px | None |
| Blue | Blue light | 0.3 | Blue, 1.5px | None |
| Red | Red light | 0.3 | Red, 1.5px | None |
| Purple | Purple light | 0.3 | Purple, 1.5px | None |
| Capturable | Different team color | 0.3 | Team color, 1.5px | **Pulsing** (see below) |
| Current (runner here) | Team color | 0.5 | Team color, 2.5px | None |


#### 3.2.4 Running Screen

**Pre-Run State:**

| Element | Spec |
|---------|------|
| Map | Visible with hex grid overlay |
| Status Indicator | "READY" text |
| Start Button | Pulsing hold-to-start (Energy Hold Button, 1.5s) |
| Top Bar | Team indicator |

**Active Run State:**

| Element | Spec |
|---------|------|
| User Marker | Glowing ball (team-colored, pulsing) |
| Camera Mode | Navigation mode — map rotates based on direction |
| Camera FPS | 60fps smooth interpolation (SmoothCameraController) |
| Route Trail | Tracing line draws running path |
| Stats Overlay | Distance, Time, Pace |
| Top Bar | "RUNNING" + team-colored pulsing dot |
| Stop Button | Hold-to-stop (1.5s hold, no confirmation dialog) |
| Buff Multiplier | Show current buff (e.g., "2x") — based on team buff system |

**Important:** FlipPoints are shown in AppBar header ONLY (not duplicated in running screen).

**Multiplier Display:**
- Show buff multiplier (e.g., "2x Elite" for RED, "2x City Leader" for BLUE)
- New users without buff data: Show "1x" (default)

#### 3.2.5 Leaderboard Screen

| Element | Spec |
|---------|------|
| Period Toggle | TOTAL / WEEK / MONTH / YEAR (height 36, borderRadius 18) |
| Range Navigation | Prev/Next arrows with date range display |
| List | Top rankings for selected period, all users |
| Podium | Top 3 users with team-colored cards |
| Sticky Footer | "My Rank" (if user outside top displayed) |
| Purple Users | Glowing border |
| Per User | Avatar, Name, Flip Points, Stability Badge |

**Removed Features:**
- Geographic scope filter (Zone/City/All) - removed for simplicity
- Team filter tabs - all teams shown together

#### 3.2.6 Run History Screen (Calendar)

| Element | Spec |
|---------|------|
| Calendar View | Month/Week/Year view with distance indicators |
| Day Indicators | Distance display per day (e.g., "5.2k") matching week view style |
| ALL TIME Stats | Fixed panel at top with distance, pace, flips, runs |
| Period Stats | Smaller panel (copies ALL TIME design) for WEEK/MONTH/YEAR period |
| Period Toggle | TOTAL/WEEK/MONTH/YEAR selector (height 36, borderRadius 18) |
| Range Navigation | Prev/Next arrows for period navigation |
| **Timezone Selector** | Dropdown to select display timezone |
| Timezone Persistence | User's timezone preference saved locally |
| Default Timezone | Device's local timezone on first launch |

**Stats Panel Design:**

| Panel | Padding | Border Radius | Distance Font | Mini Stat Font |
|-------|---------|---------------|---------------|----------------|
| ALL TIME | 20h/16v | 16 | 32px | 16px |
| Period (WEEK/MONTH/YEAR) | 16h/12v | 12 | 24px | 14px |

**Calendar Distance Display:**
- Month view: Shows distance per day (e.g., "5.2k") below the day number
- Week view: Shows distance per day in the same style
- Replaces previous dot/badge indicators with consistent distance display

**Timezone Selection Feature:**
- Users can select and change the timezone for displaying run history.
- Affects how run dates/times are displayed in the calendar and run details.
- Stored locally in SharedPreferences, NOT synced to server.
- Server stores all timestamps in UTC; client converts to selected timezone for display.
- Useful for users who travel frequently or review runs from different time zones.

**Supported Timezones:**
- All standard IANA timezones (e.g., `Asia/Seoul`, `America/New_York`, `Europe/London`)
- Common options shown at top of dropdown: device local, UTC, GMT+2 (server time)

#### 3.2.7 Profile Screen

| Element | Spec |
|---------|------|
| Access | Via settings/menu (not a main tab) |
| Manifesto | 12-character declaration, editable anytime |
| Avatar | Personal emoji |
| Team | Display only (cannot change mid-season) |
| Season Stats | Total flips, distance, runs |
| Buff Status | Current multiplier breakdown (Elite/City Leader/All Range) |

### 3.3 Widget Library

| Widget | Purpose | Location |
|--------|---------|----------|
| `FlipPointsWidget` | Animated flip counter | AppBar |
| `SeasonCountdownWidget` | D-day countdown badge | AppBar |
| `EnergyHoldButton` | Hold-to-trigger button (1.5s) | Running Screen |
| `GlowingLocationMarker` | Team-colored pulsing marker | Map/Running |
| `SmoothCameraController` | 60fps camera interpolation | Running Screen |
| `HexagonMap` | Hex grid overlay | Map Screen |
| `RouteMap` | Route display + nav mode | Running Screen |
| `StatCard` | Statistics card | Various |
| `NeonStatCard` | Neon-styled stat card | Various |

### 3.4 Theme & Visual Language

#### Colors

| Token | Hex Code | Usage |
|-------|----------|-------|
| `athleticRed` | `#FF003C` | Red team (FLAME) |
| `electricBlue` | `#008DFF` | Blue team (WAVE) |
| `purple` | `#8B5CF6` | Purple team (CHAOS) |
| `backgroundStart` | `#0F172A` | Dark background |
| `surfaceColor` | `#1E293B` | Card/surface |
| `textPrimary` | `#FFFFFF` | Primary text |
| `textSecondary` | `#94A3B8` | Secondary text |

#### Typography

| Usage | Font | Weight | Notes |
|-------|------|--------|-------|
| Headers | Bebas Neue | Bold | English display text |
| Body | Bebas Neue | Regular | General English text |
| Stats/Numbers | (Current RunningScreen km font) | Medium | Monospace-style for data |
| Korean | Paperlogyfont | Regular | From freesentation.blog |

> **Korean Font Source**: https://freesentation.blog/paperlogyfont

#### Animation Standards

| Animation | Duration | Curve | Notes |
|-----------|----------|-------|-------|
| Flip point increment | Current implementation | Current implementation | Keep as-is |
| Camera interpolation | Per-frame (60fps) | Linear interpolation | SmoothCameraController |
| Hold button progress | 1.5s | Linear | Start/Stop buttons |

---

## 4. Data Structure

### 4.1 Client Models

#### Team Enum

```dart
enum Team {
  red,    // Display: "FLAME" 🔥
  blue,   // Display: "WAVE" 🌊
  purple; // Display: "CHAOS" 💜

  String get displayName => switch (this) {
    red => 'FLAME',
    blue => 'WAVE',
    purple => 'CHAOS',
  };
}
```

#### UserModel

```dart
class UserModel {
  final String id;
  final String name;           // Display name
  final Team team;             // Current team (purple = defected)
  final String avatar;         // Emoji avatar
  final int seasonPoints;      // Flip points this season (preserved on Purple defection)
  final String? manifesto;     // 12-char declaration, editable anytime
  final double totalDistanceKm; // Running season aggregate
  final double? avgPaceMinPerKm; // Weighted average pace (min/km)
  final double? avgCv;         // Average Coefficient of Variation (null if no CV data)
  final int totalRuns;         // Number of completed runs

  /// Stability score from average CV (higher = better, 0-100)
  int? get stabilityScore => avgCv == null ? null : (100 - avgCv!).round().clamp(0, 100);
}
```

**Aggregate Fields (incremental update via `finalize_run`):**
- `totalDistanceKm` → cumulative distance from all runs
- `avgPaceMinPerKm` → incremental average pace (updated on each run)
- `avgCv` → incremental average CV from runs with CV data (≥1km)
- `totalRuns` → count of completed runs

#### HexModel

```dart
class HexModel {
  final String id;             // H3 hex index (resolution 9)
  final LatLng center;         // Geographic center
  Team? lastRunnerTeam;        // null = neutral, else team color
  DateTime? lastFlippedAt;     // Run's endTime when hex was flipped (for conflict resolution)

  // NO runner IDs (privacy)

  /// Returns true if color actually changed (= a flip occurred)
  bool setRunnerColor(Team runnerTeam, DateTime runEndTime) {
    if (lastRunnerTeam == runnerTeam) return false;
    // Only update if this run ended later (conflict resolution)
    if (lastFlippedAt != null && runEndTime.isBefore(lastFlippedAt!)) return false;
    lastRunnerTeam = runnerTeam;
    lastFlippedAt = runEndTime;
    return true;
  }
}
```

#### RunSession (Active Run — Hot Data)

```dart
class RunSession {
  final String id;
  final DateTime startTime;
  DateTime? endTime;
  double distanceMeters;
  List<LocationPoint> route;    // Full GPS path (active tracking)
  int hexesColored;             // Flip count during this run
  Team teamAtRun;               // Team at time of run
  List<String> hexesPassed;     // H3 hex IDs passed through

  double get distanceKm => distanceMeters / 1000;
  Duration get duration => (endTime ?? DateTime.now()).difference(startTime);
  double get paceMinPerKm => /* calculation */;
  bool get canCaptureHex => paceMinPerKm < 8.0;
}
```

#### RunSummary (Completed Run — Warm Data, Storage-Minimized)

```dart
class RunSummary {
  final String id;
  final DateTime endTime;           // Conflict resolution: later endTime wins hex
  final double distanceKm;
  final int durationSeconds;
  final double avgPaceMinPerKm;     // min/km (e.g., 6.0 = 6:00 min/km)
  final int hexesColored;           // Flip count
  final Team teamAtRun;
  final List<String> hexPath;       // H3 hex IDs passed (deduplicated, no timestamps)
  final int buffMultiplier;         // Applied multiplier from buff system
  final double? cv;                 // Coefficient of Variation (null for runs < 1km)

  /// Stability score (100 - CV, clamped 0-100). Higher = more consistent pace.
  int? get stabilityScore => cv == null ? null : (100 - cv!).round().clamp(0, 100);
}
```

> **Storage Optimization**:
> - `hexPath` stores deduplicated H3 hex IDs only (no individual timestamps).
> - Raw GPS trace is NOT stored (90%+ storage savings).
> - Route shape can be reconstructed by connecting hex centers.
> - `endTime` is the sole timestamp used for conflict resolution.

#### RunHistoryModel (Per-Run Stats — Preserved Across Seasons)

```dart
/// Lightweight run history preserved across season resets.
/// Contains stats only, no heavy hex_path data.
class RunHistoryModel {
  final String id;
  final String userId;
  final DateTime runDate;           // Date of the run
  final DateTime startTime;
  final DateTime endTime;
  final double distanceKm;
  final int durationSeconds;
  final double avgPaceMinPerKm;     // min/km (e.g., 6.0 = 6:00 min/km)
  final int flipCount;              // Flips earned this run
  final int pointsEarned;           // Points with multiplier
  final Team teamAtRun;

  Duration get duration => Duration(seconds: durationSeconds);
}
```

> **Design Note**: `run_history` is separate from `runs` table.
> - `runs`: Heavy data with `hex_path` → **DELETED on season reset**
> - `run_history`: Lightweight stats → **PRESERVED across seasons** (5-year retention)

**Model Usage Clarification:**

| Model | Purpose | Contains hex_path | Used For |
|-------|---------|-------------------|----------|
| `RunSummary` | Server upload payload | ✅ Yes | `finalize_run()` RPC call |
| `RunHistoryModel` | UI display model | ❌ No | Run History Screen, Calendar |

- `RunSummary` is used ONLY for uploading to server at run completion.
- `RunHistoryModel` is used for all UI display (history list, calendar, stats).
- `runs` table (DB) stores `hex_path` for season data; `run_history` table (DB) stores stats only.
- Both tables are **independent** with no foreign key relationship.

#### DailyRunningStat (Aggregated — Preserved Across Seasons)

```dart
class DailyRunningStat {
  final String userId;
  final String dateKey;             // "2026-01-24" format
  final double totalDistanceKm;
  final int totalDurationSeconds;
  final double avgPaceMinPerKm;     // min/km (e.g., 6.0 = 6:00)
  final int flipCount;              // Total flips that day
}
```

#### LapModel (Per-km Lap Data)

```dart
/// Represents a single 1km lap during a run
class LapModel {
  final int lapNumber;         // which lap (1, 2, 3...)
  final double distanceMeters; // should be 1000.0 for complete laps
  final double durationSeconds; // time to complete this lap
  final int startTimestampMs;  // when lap started
  final int endTimestampMs;    // when lap ended

  /// Derived: average pace in seconds per kilometer
  double get avgPaceSecPerKm => durationSeconds / (distanceMeters / 1000);
}
```

**Purpose**: Used to calculate Coefficient of Variation (CV) for pace consistency analysis.

#### LocationPoint (Active GPS — Ephemeral)

```dart
class LocationPoint {
  final double latitude;
  final double longitude;
  final double altitude;
  final double speed;               // m/s
  final double accuracy;            // meters (must be ≤ 50m)
  final DateTime timestamp;
}
```

#### RoutePoint (Cold Storage — Compact)

```dart
class RoutePoint {
  final double lat;
  final double lng;
  // Minimal data for route replay (Douglas-Peucker compressed)
}
```

### 4.2 Database Schema (PostgreSQL via Supabase)

#### Core Tables

```sql
-- Users table (permanent, survives season reset)
CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  auth_id UUID REFERENCES auth.users(id) NOT NULL,
  name TEXT NOT NULL,
  team TEXT CHECK (team IN ('red', 'blue', 'purple')),
  avatar TEXT NOT NULL DEFAULT '🏃',
  season_points INTEGER NOT NULL DEFAULT 0,
  manifesto TEXT CHECK (char_length(manifesto) <= 12),
  home_hex_start TEXT,                        -- First hex of last run (used for SELF leaderboard scope)
  home_hex_end TEXT,                          -- Last hex of last run (used for OTHERS leaderboard scope)
  total_distance_km DOUBLE PRECISION NOT NULL DEFAULT 0,
  avg_pace_min_per_km DOUBLE PRECISION,
  avg_cv DOUBLE PRECISION,
  total_runs INTEGER NOT NULL DEFAULT 0,
  cv_run_count INTEGER NOT NULL DEFAULT 0,   -- For incremental CV average
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Hex map (deleted on season reset)
CREATE TABLE hexes (
  id TEXT PRIMARY KEY,                       -- H3 index string (resolution 9)
  last_runner_team TEXT CHECK (last_runner_team IN ('red', 'blue', 'purple')),
  last_flipped_at TIMESTAMPTZ               -- Run's endTime when hex was flipped (for conflict resolution)
  -- NO runner IDs (privacy)
);

-- Daily buff stats (calculated at midnight GMT+2 via Edge Function)
CREATE TABLE daily_buff_stats (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id),
  date DATE NOT NULL,
  buff_multiplier INTEGER NOT NULL DEFAULT 1,
  is_elite BOOLEAN NOT NULL DEFAULT false,        -- RED: Top 20%
  is_district_leader BOOLEAN NOT NULL DEFAULT false,  -- Team has most hexes in district
  has_province_range BOOLEAN NOT NULL DEFAULT false,   -- Team has most hexes server-wide
  participation_rate DOUBLE PRECISION,            -- PURPLE: District participation %
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (user_id, date)
);

-- Daily province range stats (tracks server-wide hex dominance)
CREATE TABLE daily_province_range_stats (
  date DATE PRIMARY KEY,
  leading_team TEXT CHECK (leading_team IN ('red', 'blue')),  -- PURPLE excluded
  red_hex_count INTEGER NOT NULL DEFAULT 0,
  blue_hex_count INTEGER NOT NULL DEFAULT 0,
  calculated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

#### Season-Partitioned Tables (pg_partman)

```sql
-- Runs table: partitioned by season (40-day periods)
CREATE TABLE runs (
  id UUID NOT NULL DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id),
  team_at_run TEXT NOT NULL CHECK (team_at_run IN ('red', 'blue', 'purple')),
  start_time TIMESTAMPTZ NOT NULL,
  end_time TIMESTAMPTZ,
  distance_meters DOUBLE PRECISION NOT NULL DEFAULT 0,
  avg_pace_min_per_km DOUBLE PRECISION,      -- min/km (e.g., 6.0)
  hexes_colored INTEGER NOT NULL DEFAULT 0,
  hex_path TEXT[] NOT NULL DEFAULT '{}',      -- H3 hex IDs passed
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (id, created_at)
) PARTITION BY RANGE (created_at);

-- Daily stats: partitioned by month
CREATE TABLE daily_stats (
  id UUID NOT NULL DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id),
  date_key DATE NOT NULL,
  total_distance_km DOUBLE PRECISION NOT NULL DEFAULT 0,
  total_duration_seconds INTEGER NOT NULL DEFAULT 0,
  avg_pace_min_per_km DOUBLE PRECISION,
  flip_count INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (id, created_at),
  UNIQUE (user_id, date_key, created_at)
) PARTITION BY RANGE (created_at);

-- Run history: lightweight stats preserved across seasons
-- Separate from runs table which contains heavy hex_path data
CREATE TABLE run_history (
  id UUID NOT NULL DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id),
  run_date DATE NOT NULL,                       -- Date of the run
  start_time TIMESTAMPTZ NOT NULL,
  end_time TIMESTAMPTZ NOT NULL,
  distance_km DOUBLE PRECISION NOT NULL,
  duration_seconds INTEGER NOT NULL,
  avg_pace_min_per_km DOUBLE PRECISION,
  flip_count INTEGER NOT NULL DEFAULT 0,        -- Flips earned this run
  points_earned INTEGER NOT NULL DEFAULT 0,     -- Points with multiplier
  team_at_run TEXT NOT NULL CHECK (team_at_run IN ('red', 'blue', 'purple')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (id, created_at)
) PARTITION BY RANGE (created_at);

-- NOTE: run_history is PRESERVED across season resets (personal history)
-- NOTE: daily_flips table REMOVED — no daily flip limit
```

#### Partition Management (pg_partman)

```sql
-- Auto-create partitions for runs (monthly)
SELECT partman.create_parent(
  p_parent_table := 'public.runs',
  p_control := 'created_at',
  p_type := 'native',
  p_interval := '1 month',
  p_premake := 3
);

-- Auto-create partitions for daily_stats (monthly)
SELECT partman.create_parent(
  p_parent_table := 'public.daily_stats',
  p_control := 'created_at',
  p_type := 'native',
  p_interval := '1 month',
  p_premake := 3
);

-- Auto-create partitions for run_history (monthly, PERMANENT - never deleted)
SELECT partman.create_parent(
  p_parent_table := 'public.run_history',
  p_control := 'created_at',
  p_type := 'native',
  p_interval := '1 month',
  p_premake := 3
  -- NO p_retention: run_history is preserved across seasons
);
```

#### Row Level Security (RLS)

```sql
-- Users can only read/update their own profile
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
CREATE POLICY users_self ON users
  USING (auth_id = auth.uid())
  WITH CHECK (auth_id = auth.uid());

-- Hexes are readable by all, writable by authenticated runners
ALTER TABLE hexes ENABLE ROW LEVEL SECURITY;
CREATE POLICY hexes_read ON hexes FOR SELECT USING (true);
CREATE POLICY hexes_write ON hexes FOR UPDATE USING (auth.role() = 'authenticated');

-- Active runs: DEPRECATED - RLS policies removed
-- Table kept for potential future use but no RLS policies defined
-- ALTER TABLE active_runs ENABLE ROW LEVEL SECURITY;  -- Disabled
```

#### Key Indexes

```sql
CREATE INDEX idx_users_team ON users(team);
CREATE INDEX idx_users_season_points ON users(season_points DESC);
CREATE INDEX idx_daily_stats_user_date ON daily_stats(user_id, date_key);
CREATE INDEX idx_hexes_team ON hexes(last_runner_team);
CREATE INDEX idx_daily_buff_stats_user_date ON daily_buff_stats(user_id, date);
```

#### Useful Views & Functions

```sql
-- Get user's current buff multiplier (from today's daily_buff_stats)
CREATE OR REPLACE FUNCTION get_user_buff(p_user_id UUID)
RETURNS INTEGER AS $$
  SELECT COALESCE(buff_multiplier, 1)
  FROM daily_buff_stats
  WHERE user_id = p_user_id AND date = CURRENT_DATE
  LIMIT 1;
$$ LANGUAGE sql STABLE;

-- Leaderboard query (efficient with index on season_points)
CREATE OR REPLACE FUNCTION get_leaderboard(p_limit INTEGER DEFAULT 20)
RETURNS TABLE(user_id UUID, name TEXT, team TEXT, season_points INTEGER, rank BIGINT) AS $$
  SELECT id, name, team, season_points,
         ROW_NUMBER() OVER (ORDER BY season_points DESC) as rank
  FROM users
  WHERE season_points > 0
  ORDER BY season_points DESC
  LIMIT p_limit;
$$ LANGUAGE sql STABLE;

-- Finalize run: batch process hex flips and award points ("The Final Sync")
CREATE OR REPLACE FUNCTION finalize_run(
  p_user_id UUID,
  p_start_time TIMESTAMPTZ,
  p_end_time TIMESTAMPTZ,
  p_distance_km DOUBLE PRECISION,
  p_duration_seconds INTEGER,
  p_hex_path TEXT[],
  p_cv DOUBLE PRECISION DEFAULT NULL,  -- Coefficient of Variation (null for runs < 1km)
  p_client_points INTEGER DEFAULT NULL  -- Optional: client-calculated points for validation
)
RETURNS jsonb AS $$
DECLARE
  v_hex_id TEXT;
  v_total_flips INTEGER := 0;
  v_team TEXT;
  v_points INTEGER;
  v_multiplier INTEGER;
  v_current_team TEXT;
  v_current_flipped_at TIMESTAMPTZ;
  v_max_allowed_points INTEGER;
BEGIN
  -- Get user's team and buff multiplier
  SELECT team INTO v_team FROM users WHERE id = p_user_id;
  SELECT COALESCE(buff_multiplier, 1) INTO v_multiplier 
  FROM daily_buff_stats WHERE user_id = p_user_id AND date = CURRENT_DATE;
  IF v_multiplier IS NULL THEN v_multiplier := 1; END IF;
  
  -- Process each hex in the path (NO daily limit - all flips count)
  FOREACH v_hex_id IN ARRAY p_hex_path LOOP
    -- Check current hex color and timestamp
    SELECT last_runner_team, last_flipped_at 
    INTO v_current_team, v_current_flipped_at 
    FROM hexes WHERE id = v_hex_id;
    
    -- Only update if this run ended LATER than the existing flip
    IF v_current_flipped_at IS NULL OR p_end_time > v_current_flipped_at THEN
      -- Count as flip if color changes (or hex is new/neutral)
      IF v_current_team IS DISTINCT FROM v_team THEN
        v_total_flips := v_total_flips + 1;
      END IF;
      
      -- Update hex color with timestamp (conflict resolution: later run_endTime wins)
      INSERT INTO hexes (id, last_runner_team, last_flipped_at)
      VALUES (v_hex_id, v_team, p_end_time)
      ON CONFLICT (id) DO UPDATE
      SET last_runner_team = v_team,
          last_flipped_at = p_end_time
      WHERE hexes.last_flipped_at IS NULL OR hexes.last_flipped_at < p_end_time;
    END IF;
  END LOOP;
  
  -- Calculate points with buff multiplier
  v_points := v_total_flips * v_multiplier;
  
  -- [SECURITY] Server-side validation: points cannot exceed hex_count × multiplier
  v_max_allowed_points := array_length(p_hex_path, 1) * v_multiplier;
  IF p_client_points IS NOT NULL AND p_client_points > v_max_allowed_points THEN
    RAISE WARNING 'Client claimed % points but max allowed is %', p_client_points, v_max_allowed_points;
  END IF;
  
  -- Award points to user, update home hex, and update aggregates
  UPDATE users SET 
    season_points = season_points + v_points,
    home_hex_start = CASE WHEN array_length(p_hex_path, 1) > 0 THEN p_hex_path[1] ELSE home_hex_start END,
    home_hex_end = CASE WHEN array_length(p_hex_path, 1) > 0 THEN p_hex_path[array_length(p_hex_path, 1)] ELSE home_hex_end END,
    total_distance_km = total_distance_km + p_distance_km,
    total_runs = total_runs + 1,
    avg_pace_min_per_km = CASE 
      WHEN p_distance_km > 0 THEN 
        (COALESCE(avg_pace_min_per_km, 0) * total_runs + (p_duration_seconds / 60.0) / p_distance_km) / (total_runs + 1)
      ELSE avg_pace_min_per_km 
    END,
    avg_cv = CASE 
      WHEN p_cv IS NOT NULL THEN 
        (COALESCE(avg_cv, 0) * cv_run_count + p_cv) / (cv_run_count + 1)
      ELSE avg_cv 
    END,
    cv_run_count = CASE WHEN p_cv IS NOT NULL THEN cv_run_count + 1 ELSE cv_run_count END
  WHERE id = p_user_id;
  
  -- Insert lightweight run history (PRESERVED across seasons)
  INSERT INTO run_history (
    user_id, run_date, start_time, end_time,
    distance_km, duration_seconds, avg_pace_min_per_km,
    flip_count, points_earned, team_at_run, cv
  ) VALUES (
    p_user_id, p_end_time::DATE, p_start_time, p_end_time,
    p_distance_km, p_duration_seconds,
    CASE WHEN p_distance_km > 0 THEN (p_duration_seconds / 60.0) / p_distance_km ELSE NULL END,
    v_total_flips, v_points, v_team, p_cv
  );
  
  -- Return summary
  RETURN jsonb_build_object(
    'flips', v_total_flips,
    'multiplier', v_multiplier,
    'points_earned', v_points,
    'server_validated', true
  );
END;
$$ LANGUAGE plpgsql;
```

**Design Principles:**
- `hexes`: Only stores `last_runner_team`. No timestamps or runner IDs → privacy + cost.
- `users`: Aggregate stats updated incrementally via `finalize_run()`.
- `runs`: Heavy data with `hex_path` (H3 IDs) → **DELETED on season reset**.
- `run_history`: Lightweight stats (distance, time, flips, cv) → **PRESERVED across seasons**.
- `daily_buff_stats`: Team-based buff multipliers (District Leader, Province Range) calculated daily at midnight GMT+2.
- **No daily flip limit**: Same hex can be flipped multiple times per day.
- **Multiplier**: Team-based buff via `calculate_daily_buffs()` Edge Function at midnight GMT+2.
- **Sync**: No real-time — all hex data uploaded via `finalize_run()` at run completion.
- All security handled via RLS — **no separate backend API server needed**.

### 4.3 Data Lifecycle & Partitioning Strategy

#### Why Partitioning Matters

The 40-day season cycle means data accumulates and must be efficiently deleted. Traditional row-by-row DELETE is expensive and causes:
- Index fragmentation
- VACUUM overhead
- Performance degradation during reset

**Solution**: PostgreSQL table partitioning via `pg_partman`.

#### Partition Strategy by Table

| Table | Partition Interval | Retention | D-Day Reset Method |
|-------|-------------------|-----------|-------------------|
| `runs` | Monthly | Season data only | `DROP PARTITION` (instant) |
| `run_history` | Monthly | **5 years** (then auto-deleted) | Never deleted on D-Day |
| `daily_stats` | Monthly | **5 years** (then auto-deleted) | Never deleted on D-Day |
| `hexes` | Not partitioned | Season only | `TRUNCATE TABLE` (instant) |
| `daily_buff_stats` | Not partitioned | Season only | `TRUNCATE TABLE` (instant) |

**Data Retention Policy:**
- `run_history` and `daily_stats` are retained for **5 years** from creation date.
- pg_partman `p_retention` is set to `'5 years'` for these tables.
- Data older than 5 years is automatically dropped during partition maintenance.
- Account deletion triggers immediate deletion of all user data (GDPR compliance).

#### D-Day Reset Execution (The Void)

```sql
-- Season reset: executes in < 1 second regardless of data volume
BEGIN;
  -- 1. Instant wipes (TRUNCATE = instant, no row-by-row cost)
  TRUNCATE TABLE hexes;
  TRUNCATE TABLE daily_buff_stats;
  TRUNCATE TABLE daily_province_range_stats;
  
  -- 2. Reset user season data (UPDATE, not DELETE)
  UPDATE users SET
    season_points = 0,
    team = NULL,  -- Forces re-selection
    total_distance_km = 0,
    avg_pace_min_per_km = NULL,
    avg_cv = NULL,
    total_runs = 0,
    cv_run_count = 0;
  
  -- 3. Drop season's runs partitions (heavy data, instant disk reclaim)
  -- pg_partman handles this via retention policy, or manual:
  -- DROP TABLE runs_p2026_01, runs_p2026_02, ... ;
  
  -- 4. PRESERVED tables (personal history across seasons):
  --    - run_history (per-run lightweight stats)
  --    - daily_stats (aggregated daily stats)
COMMIT;
```

**Key Advantage over Firebase/Firestore:**
- Firebase charges per-document for deletion (100万 docs = 100万 write ops = ~$0.18+)
- Supabase/PostgreSQL: `TRUNCATE`/`DROP PARTITION` = **$0, instant, no performance impact**

#### Data Flow Summary

```
[During Run - Local Only]
  Runner GPS → Client Kalman filter → Local hex_path list
  Hex flip detected → Local calculation using cached buff multiplier
  NO server communication (battery + cost optimization)
  NO daily flip limit (same hex can be flipped multiple times)

[Run Completion - "The Final Sync"]
  Client uploads: { startTime, endTime, distanceKm, hex_path[], cv }
  Server RPC: finalize_run() →
    → Fetch buff_multiplier from daily_buff_stats
    → Count flips (color changes from current hex state)
    → Conflict resolution: later endTime wins hex color
    → UPDATE hexes, users (including CV aggregate)
    → INSERT INTO run_history (lightweight stats + cv, preserved)
  
[Daily Maintenance - Edge Function (midnight GMT+2)]
  calculate_daily_buffs() →
    → Calculate team-based buffs for all active users
    → RED: Elite (Top 20%) + City Leader + All Range
    → BLUE: City Leader + All Range
    → PURPLE: City Participation Rate
    → INSERT INTO daily_buff_stats

[D-Day - Reset Path]
  TRUNCATE hexes, daily_buff_stats (instant)
  UPDATE users (reset points/team/aggregates)
  DROP runs partitions (heavy data, instant disk reclaim)
  run_history PRESERVED (per-run stats)
  daily_stats PRESERVED (aggregated stats)
```

### 4.4 Hot vs Cold Data Strategy

| Tier | Data | Storage | Retention | Reset Behavior |
|------|------|---------|-----------|----------------|
| **Hot** | Hex map, Active runs | Supabase (PostgreSQL) | Current season | TRUNCATE (instant) |
| **Seasonal** | `runs` (heavy with hex_path) | Supabase (PostgreSQL) | Current season | DROP PARTITION (instant) |
| **Permanent** | `run_history` (lightweight stats) | Supabase (PostgreSQL) | **Forever** | Never deleted |
| **Permanent** | `daily_stats` (aggregated daily) | Supabase (PostgreSQL) | **Forever** | Never deleted |
| **Cold** | ~~Raw GPS paths~~ **NOT STORED** | — | — | 90%+ storage savings |

> **Key Design**: Separate `runs` (heavy, deleted) from `run_history` (light, preserved).
> Raw GPS coordinates are NOT stored. Only `hex_path` (H3 IDs) is in `runs`.

**Batch Points Calculation Flow ("The Final Sync"):**

```
[Run Completion - Client uploads run_summary]
  Server RPC: finalize_run(run_summary_jsonb)
    → For each hex_id in hex_path:
      → Check current hex color
      → If color differs from runner's team → count as flip
    → Conflict Resolution:
      → UPDATE hexes SET last_runner_team = team
        WHERE endTime > existing (later run wins)
    → Calculate points: total_flips × buffMultiplier
    → UPDATE users SET season_points += points
    → INSERT INTO run_history (lightweight stats, preserved)
```

> **Note**: No daily flip limit. Same hex can be flipped multiple times per day.

**Supabase Realtime Integration (Minimal Scope):**
- **NO real-time features currently required** — all data synced on app launch and run completion
- `hexes` and `users.season_points` → NO real-time broadcast (poll on app foreground)
- **Cost Optimization**: Eliminated ALL WebSocket usage for maximum cost savings
- Future consideration: May add real-time for social features if needed later

### 4.5 Local Storage (SQLite)

| Table | Purpose | Sync Strategy |
|-------|---------|---------------|
| `runs` | Offline run data (active session) | Upload to Supabase on connectivity |
| `routes` | GPS points during active run | Compress → Supabase Storage on completion |
| `laps` | Per-km lap data for CV calculation | Local only, used for CV computation |
| `run_history` | Local cache of run history | Pull from Supabase |
| `daily_stats` | Local cache of daily stats | Pull from Supabase |
| `hex_cache` | Nearby hex data for offline | Cache visible + surrounding hexes |

**Schema v6 (CV Support):**
```sql
-- runs table now includes:
cv REAL  -- Coefficient of Variation (null for runs < 1km)

-- New laps table:
CREATE TABLE laps (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  runId TEXT NOT NULL,
  lapNumber INTEGER NOT NULL,
  distanceMeters REAL NOT NULL,
  durationSeconds REAL NOT NULL,
  startTimestampMs INTEGER NOT NULL,
  endTimestampMs INTEGER NOT NULL,
  FOREIGN KEY (runId) REFERENCES runs (id) ON DELETE CASCADE
);
CREATE INDEX idx_laps_runId ON laps(runId);
```

---

## 5. Tech Stack & Architecture

### 5.1 Backend Platform Decision

#### Why Supabase over Firebase

| Criterion | Firebase (Firestore) | Supabase (PostgreSQL) | Winner |
|-----------|---------------------|----------------------|--------|
| **Data Model** | NoSQL (Document) | Relational (SQL) | Supabase — user/team/season relationships require JOINs |
| **Query Complexity** | Limited (no JOINs, no aggregation) | Full SQL (JOIN, GROUP BY, SUM, Window functions) | Supabase — leaderboard & multiplier calculations |
| **Cost Model** | Per-read/write operation | Instance-based (flat rate) | Supabase — no per-operation billing explosion at scale |
| **Mass Deletion (D-Day)** | Per-document write cost ($0.18/1M deletes) | TRUNCATE/DROP = $0, instant | Supabase — critical for 40-day reset |
| **Real-time** | Firestore listeners | Supabase Realtime (WebSocket) | Tie |
| **Security** | Firebase Rules (custom DSL) | Row Level Security (SQL policies) | Supabase — standard SQL, no custom language |
| **Backend API** | Requires Cloud Functions for complex logic | RLS + Edge Functions (optional) | Supabase — no separate API server needed |
| **Vendor Lock-in** | Google-proprietary | Open-source (PostgreSQL) | Supabase — can self-host if needed |
| **Scaling** | Auto-scales (but cost scales too) | Predictable instance pricing | Supabase — budget-friendly at scale |

**Decision**: **Supabase (PostgreSQL)** as primary backend.

#### Architecture Overview

```
┌─────────────────────────────────────────────────────┐
│                   Flutter Client                      │
│  ┌──────────┐  ┌──────────┐  ┌───────────────────┐  │
│  │ Provider  │  │ SQLite   │  │ Supabase Client   │  │
│  │ (State)   │  │ (Offline)│  │ (Auth + DB)       │  │
│  └──────────┘  └──────────┘  └───────────────────┘  │
└─────────────────────────┬───────────────────────────┘
                          │
              ┌───────────┴───────────┐
              │   Supabase Platform    │
              │  ┌─────────────────┐  │
              │  │  PostgreSQL DB   │  │
              │  │  (pg_partman)    │  │
              │  ├─────────────────┤  │
              │  │  Supabase Auth   │  │
              │  ├─────────────────┤  │
              │  │  Storage (S3)    │  │
              │  │  (Cold: GPS)     │  │
              │  ├─────────────────┤  │
              │  │  Edge Functions  │  │
              │  │  (D-Day reset)   │  │
              │  └─────────────────┘  │
              └───────────────────────┘
```

**Key Serverless Properties:**
- No backend API server to maintain
- RLS handles all authorization at DB level
- Edge Functions only for scheduled tasks (D-Day reset, partition management, daily multiplier calculation)
- **NO Realtime/WebSocket** — all data synced via REST on app launch and run completion
- Supabase Storage for cold GPS data (replaces AWS S3)

### 5.2 Package Dependencies

```yaml
# Core
flutter: sdk
provider: ^6.1.2

# Location & Maps
geolocator: ^13.0.2
mapbox_maps_flutter: ^2.3.0
latlong2: ^0.9.0
h3_flutter: ^0.7.1

# Supabase (Auth + Database + Realtime + Storage)
supabase_flutter: ^2.0.0

# Local Storage
sqflite: ^2.3.3+2
path_provider: ^2.1.4

# Sensors (Anti-spoofing)
sensors_plus: ^latest          # Accelerometer validation

# UI
google_fonts: ^6.2.1
animated_text_kit: ^4.2.2
shimmer: ^3.0.0
```

> **Migration Note**: `firebase_core`, `cloud_firestore`, and `firebase_auth` are replaced by single `supabase_flutter` package which provides auth, database, realtime, and storage in one SDK.

### 5.3 Directory Structure

```
lib/
├── main.dart                    # App entry point, Provider setup
├── config/
│   ├── mapbox_config.dart       # Mapbox API configuration
│   └── supabase_config.dart     # Supabase URL & anon key
├── models/
│   ├── team.dart                # Team enum (red/blue/purple)
│   ├── user_model.dart          # User data model (with CV aggregates)
│   ├── hex_model.dart           # Hex tile (lastRunnerTeam only)
│   ├── app_config.dart          # Server-configurable constants (Season, GPS, Scoring, Hex, Timing, Buff)
│   ├── run_session.dart         # Active run session data
│   ├── run_summary.dart         # Completed run (with hexPath, cv) - seasonal
│   ├── run_history_model.dart   # Lightweight run stats (preserved)
│   ├── lap_model.dart           # Per-km lap data for CV calculation
│   ├── daily_running_stat.dart  # Daily stats (preserved)
│   ├── location_point.dart      # GPS point (active run)
│   └── route_point.dart         # Compact route point (Cold storage)
├── providers/
│   ├── app_state_provider.dart  # Global app state (team, user)
│   ├── run_provider.dart        # Run lifecycle & hex capture
│   └── hex_data_provider.dart   # Hex data cache & state
├── screens/
│   ├── team_selection_screen.dart
│   ├── home_screen.dart         # Main navigation hub + AppBar
│   ├── map_screen.dart          # Hex map exploration view
│   ├── running_screen.dart      # Pre-run & active run (unified)
│   ├── leaderboard_screen.dart  # Rankings (Province/District/Zone scope)
│   ├── run_history_screen.dart  # Past runs (Calendar)
│   └── profile_screen.dart      # Manifesto, avatar, stats
├── services/
│   ├── supabase_service.dart    # Supabase client init & RPC wrappers (passes CV to finalize_run)
│   ├── remote_config_service.dart      # Server-configurable constants (fetch, cache, provide)
│   ├── config_cache_service.dart       # Local JSON cache for remote config
│   ├── prefetch_service.dart    # Home hex anchoring & scope data prefetch (2,401 hexes)
│   ├── hex_service.dart         # H3 hex grid operations
│   ├── location_service.dart    # GPS tracking (uses RemoteConfigService)
│   ├── run_tracker.dart         # Run session & hex capture engine (lap tracking, CV calculation)
│   ├── lap_service.dart         # CV calculation from lap data
│   ├── gps_validator.dart       # Anti-spoofing (GPS + accelerometer, uses RemoteConfigService)
│   ├── accelerometer_service.dart      # Accelerometer anti-spoofing (5s no-data warning)
│   ├── storage_service.dart     # Storage interface (abstract)
│   ├── in_memory_storage_service.dart  # In-memory (MVP/testing)
│   ├── local_storage_service.dart      # SharedPreferences helpers
│   ├── points_service.dart      # Flip points & multiplier calculation
│   ├── season_service.dart      # 40-day season countdown (uses RemoteConfigService)
│   ├── buff_service.dart        # Team-based buff multiplier (frozen during runs)
│   ├── running_score_service.dart      # Pace validation for capture
│   ├── app_lifecycle_manager.dart      # App foreground/background handling (uses RemoteConfigService)
│   └── data_manager.dart        # Hot/Cold data separation
├── storage/
│   └── local_storage.dart       # SQLite implementation
├── theme/
│   ├── app_theme.dart           # Main theme (colors, typography)
│   └── neon_theme.dart          # Neon accent colors
├── utils/
│   ├── image_utils.dart         # Location marker generation
│   ├── route_optimizer.dart     # Ring buffer + Douglas-Peucker
│   └── lru_cache.dart           # LRU cache for hex data
└── widgets/
    ├── hexagon_map.dart         # Hex grid overlay
    ├── route_map.dart           # Running route display + navigation mode
    ├── smooth_camera_controller.dart  # 60fps camera interpolation
    ├── glowing_location_marker.dart   # Team-colored pulsing marker
    ├── flip_points_widget.dart  # Animated flip counter (header)
    ├── season_countdown_widget.dart   # D-day countdown badge
    ├── energy_hold_button.dart  # Hold-to-trigger button
    ├── capturable_hex_pulse.dart     # Pulsing effect for capturable hexes
    ├── stat_card.dart           # Statistics card
    └── neon_stat_card.dart      # Neon-styled stat card
```

### 5.4 GPS Anti-Spoofing

| Validation | Threshold | Action |
|------------|-----------|--------|
| Max Speed | 25 km/h | Discard GPS point |
| Min GPS Accuracy | ≤ 50m | Discard GPS point |
| Accelerometer Correlation | Required in MVP | Flag session if no motion detected |
| Pace Threshold | < 8:00 min/km | Required to capture hexes |

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
| Leaderboard (City/Zone scope) | ⬜ | Based on visible hex count |
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

## 8. Appendix

### A. User Identity Rules

| State | Avatar Display | Leaderboard Name |
|-------|---------------|-----------------|
| Red/Blue user | Personal avatar | User name |
| Defected to Purple | Personal avatar | User name |

### B. Team-Based Buff Multiplier Examples

| Team | Scenario | Multiplier | Flip Points per Flip |
|------|----------|------------|---------------------|
| RED | Elite (Top 20%) + City Leader + All Range | 4x | 4 |
| RED | Elite + City Leader (no All Range) | 3x | 3 |
| RED | Elite (non-leader city) | 2x | 2 |
| RED | Common (any city) | 1x | 1 |
| BLUE | City Leader + All Range | 3x | 3 |
| BLUE | City Leader (no All Range) | 2x | 2 |
| BLUE | Non-leader city | 1x | 1 |
| PURPLE | ≥60% city participation | 3x | 3 |
| PURPLE | 30-59% city participation | 2x | 2 |
| PURPLE | <30% city participation | 1x | 1 |
| Any | New user (no yesterday data) | 1x | 1 |

**Key Points:**
- Multiplier is calculated at midnight (GMT+2), fixed for the entire day.
- Buff is **frozen** when run starts — no changes mid-run.
- Server calculates once per day via Edge Function.
- City scope determined by user's home hex.

### C. Leaderboard Geographic Scope

Geographic scope filtering uses H3's hierarchical parent cell system. Users are grouped by their parent hex ID at the scope's resolution level.

**Implementation (lib/config/h3_config.dart):**

| Scope | H3 Resolution | Map Zoom | Filter Logic |
|-------|---------------|----------|--------------|
| **ZONE** | 8 | 15.0 | `cellToParent(userHex, 8)` — Neighborhood (~461m) |
| **CITY** | 6 | 12.0 | `cellToParent(userHex, 6)` — District (~3.2km) |
| **ALL** | 4 | 10.0 | No filter — server-wide ranking |

**Client Flow:**
1. Get user's current base hex (Resolution 9)
2. Convert to scope resolution via `getScopeHexId(baseHex, scope)`
3. Query Supabase RPC with scope hex ID to filter rankings

**Approximate Coverage:**
- ZONE (Res 8): ~7 base hexes, neighborhood-level competition
- CITY (Res 6): ~343 base hexes, district-level competition
- ALL (Res 4): ~16,807 base hexes, metro-wide competition

### D. Slogans

**Korean:**
- "같은 땀, 다른 색" (Same sweat, different colors)
- "우리는 반대로 달려 만났다" (We ran apart, met together)
- "배신은 새로운 시작이다" (Betrayal is a new beginning)

**English:**
- "Run Apart, Meet Together"
- "Same Path, Different Colors"
- "Embrace the Chaos"

### E. Changelog

| Date | Change |
|------|--------|
| 2026-01-27 | **Session 5 - GPS Polling Optimization**: |
| | — Fixed 0.5Hz GPS polling (disabled adaptive polling for battery + lag prevention) |
| | — Moving average window: 10s → 20s (~10 samples at 0.5Hz for stable pace calculation) |
| | — Min time between points: 100ms → 1500ms (allows 0.5Hz with margin) |
| | — Pace validation now uses 20-second moving average instead of 10-second |
| 2026-01-26 | **Session 4 - Data Architecture**: |
| | — Daily flip limit REMOVED — same hex can be flipped multiple times per day |
| | — Table separation: `runs` (heavy, seasonal) vs `run_history` (light, permanent) |
| | — `daily_flips` table and `has_flipped_today()` function removed |
| | — D-Day reset now preserves `run_history` (personal run stats survive) |
| 2026-01-26 | **Session 3 - Design Refinements**: |
| | — Conflict Resolution: "Run-Level endTime" — ALL hexes get run's endTime, not individual passage times |
| | — Home Hex Asymmetric: Self=FIRST hex (start), Others=LAST hex (end) for privacy |
| | — UI: "Yesterday's Crew Runners (어제 뛴 크루원)" replaces "Active Crew Runners" |
| | — Run History: Added timezone selector feature |
| | — `active_runs` table marked DEPRECATED, crew run-start notifications removed |
| 2026-01-26 | **Major Cost Optimization Update**: |
| | — "The Final Sync": Replaced real-time hex sync with batch upload on run completion |
| | — "Yesterday's Check-in": Replaced real-time multiplier with daily check-in count |
| | — Battery-first GPS config: `PRIORITY_BALANCED_POWER_ACCURACY`, 5m filter, 0.5Hz polling |
| | — Storage: 90%+ savings via hex_path only (no raw GPS trace) |
| | — Conflict Resolution: Later `endTime` wins hex color |
| | — Supabase Realtime: ALL notifications removed (no WebSocket usage) |
| | — All Section 9 performance checkboxes selected |
| 2026-01-26 | Added Section 9: Performance & Optimization Configuration (GPS, Kalman filter, Mapbox SDK, SQLite, sync strategy, privacy zones) |
| 2026-01-24 | Backend migration: Firebase → Supabase (PostgreSQL) for cost/performance optimization |
| 2026-01-24 | Added pg_partman partitioning strategy for D-Day instant reset ($0, <1s) |
| 2026-01-24 | Added RLS policies (no backend API server needed) |
| 2026-01-24 | Added Supabase Realtime for live multiplier & hex updates |
| 2026-01-24 | Cold storage: AWS S3 → Supabase Storage |
| 2026-01-24 | Major restructure: Simultaneous Runner Multiply replaces Top 4/Settlement system |
| 2026-01-24 | Purple 2x base multiplier removed → advantage is crew size (24 max) |
| 2026-01-24 | Results Screen removed |
| 2026-01-24 | ~~Daily hex flip limit added (same hex once per day)~~ — **REMOVED in Session 4** |
| 2026-01-24 | All [❓ DEFINE] markers resolved |
| 2026-01-23 | FlipPoints moved to header, GPS timeout fix |
| 2026-01-22 | Running screen unified (removed active_run_screen) |
| 2026-01-20 | Data optimization: removed redundant stored fields |
| 2026-01-20 | Purple crew capacity 12→24, Twin Crew system removed |

---

## 9. Performance & Optimization Configuration

> **Configuration Checklist**: Select options below to optimize battery, accuracy, cost, and user experience.

### 9.1 Background Location Tracking Strategy

#### 9.1.1 Android Configuration

| Setting | Options | Selected |
|---------|---------|----------|
| **Foreground Service Type** | ☑ `FOREGROUND_SERVICE_LOCATION` (Required) | ✅ |
| **Wakelock Strategy** | ☐ Partial Wakelock (CPU active during run) | |
| | ☑ No Wakelock (battery priority, may miss points) | ✅ |
| **Location Provider** | ☑ Fused Location Provider Client (FLPC) | ✅ |
| | ☐ Raw GPS only (higher accuracy, higher battery) | |
| **FLPC Priority** | ☐ `PRIORITY_HIGH_ACCURACY` (GPS always on) | |
| | ☑ `PRIORITY_BALANCED_POWER_ACCURACY` (battery saving) | ✅ |

#### 9.1.2 iOS Configuration

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

### 9.2 GPS Polling & Battery Optimization

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

### 9.3 Signal Processing & Noise Reduction

> **Strategy**: Use Kalman Filter to smooth hardware noise. NO Map Matching API (cost + trail accuracy).

#### 9.3.1 Kalman Filter Configuration

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

#### 9.3.2 Map Matching Strategy

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

### 9.4 Local Database (SQLite) Configuration

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

### 9.5 Mapbox SDK & Cost Optimization

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

#### Cost Model Comparison

| SDK | Billing | Free Tier | Running App Fit |
|-----|---------|-----------|-----------------|
| **Maps SDK** | MAU (Monthly Active Users) | 50,000 MAU/month | ✅ Excellent |
| **Navigation SDK** | Per Trip | 1,000 trips/month | ⚠️ Only for premium features |

### 9.6 Data Synchronization Strategy ("The Final Sync")

> **Strategy**: NO real-time hex synchronization during runs. All data uploaded at run completion.

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

**Storage Optimization:**
- Raw GPS coordinates are NOT uploaded (only `hex_path`).
- `hex_path` = deduplicated list of H3 hex IDs passed.
- Estimated 90%+ reduction in storage compared to full GPS trace.

#### 9.6.1 Communication Lifecycle (Pre-patch Strategy)

> **Principle**: Minimize server calls during active running. Pre-load data on app launch, compute locally during run, batch upload on completion.

**App Launch (1 GET request)**:
```
┌─────────────────────────────────────────────────────────────┐
│  GET /rpc/app_launch_sync                                   │
│  ─────────────────────────────────────────────────────────  │
│  Returns:                                                   │
│  1. hex_map[]        - Latest hexagon colors (visible area) │
│  2. ranking_snapshot - Leaderboard data (ALL/City/Zone)     │
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

**Communication Summary**:

| Phase | Server Calls | Data Flow |
|-------|--------------|-----------|
| App Launch | 1 GET | Server → Client (pre-patch) |
| OnResume (foreground) | 0-1 GET | Server → Client (conditional refresh) |
| Run Start | 0 | — |
| During Run | 0 | Local only |
| Run End | 1 POST | Client → Server (batch sync) |
| **Total per run** | **2 requests** | Minimal bandwidth |

**Offline Resilience**:
- If app launch fails: Use cached data from last session
- If finalize_run fails: Queue in SQLite `sync_queue` table
- Retry on next app launch or network restoration
- Never lose user's run data

**OnResume Data Refresh (Foreground Trigger)**:
- When app returns to foreground from background (iOS `applicationWillEnterForeground`, Android `onResume`):
  - Refresh hex map data for visible area
  - Update buff multiplier (in case midnight passed)
  - Refresh ranking snapshot
- **Throttling**: Skip refresh if last refresh was < 30 seconds ago
- **During Active Run**: Skip refresh (avoid interrupting tracking)
- This ensures map data stays current even after extended background periods

### 9.7 Pace Visualization (Data-Driven Styling)

| Setting | Options | Selected |
|---------|---------|----------|
| **Route Color** | ☐ Gradient by pace (green=fast, red=slow) — Recommended | ☐ |
| | ☐ Solid team color | |
| **Gradient Implementation** | ☐ Mapbox `line-gradient` + `line-progress` — Recommended | ☐ |
| | ☐ Multiple polyline segments (less smooth) | |
| **lineMetrics** | ☐ `true` (required for gradient) — Recommended | ☐ |
| **Pace Color Ramp** | ☐ 5-color (4:00→green, 6:00→yellow, 8:00→red) | ☐ |
| | ☐ 3-color (fast→medium→slow) | |

### 9.8 Location Marker & Animation

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

### 9.9 Privacy & Security

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

### 9.10 Real-time Computation

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

### 9.11 Recommended Configuration Summary

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

### 9.12 Remote Configuration System

> **Strategy**: All 50+ game constants are server-configurable via Supabase, with local caching and graceful fallback to hardcoded defaults.

#### 9.12.1 Architecture Overview

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

#### 9.12.2 Database Schema

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

#### 9.12.3 AppConfig Model Structure

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

#### 9.12.4 Configurable Constants by Category

| Category | Constants | Example Values |
|----------|-----------|----------------|
| **Season** | `durationDays`, `serverTimezoneOffsetHours` | 40, 2 |
| **GPS** | `maxSpeedMps`, `minSpeedMps`, `maxAccuracyMeters`, `maxAltitudeChangeMps`, `maxJumpDistanceMeters`, `movingAvgWindowSeconds`, `maxCapturePaceMinPerKm`, `pollingRateHz`, `minTimeBetweenPointsMs` | 6.94, 0.3, 50.0, 5.0, 100, 20, 8.0, 0.5, 1500 |
| **Hex** | `baseResolution`, `zoneResolution`, `cityResolution`, `allResolution`, `captureCheckDistanceMeters`, `maxCacheSize` | 9, 8, 6, 4, 20.0, 4000 |
| **Timing** | `accelerometerSamplingPeriodMs`, `refreshThrottleSeconds` | 200, 30 |
| **Buff** | `elitePercentile`, `participationRateHigh`, `participationRateMid` | 20, 60, 30 |

#### 9.12.5 Run Consistency (Freeze/Unfreeze)

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

#### 9.12.6 Initialization

```dart
// In main.dart (after SupabaseService, before HexService)
await RemoteConfigService().initialize();
```

**Initialization Flow:**
1. Try fetch from server via `app_launch_sync` RPC
2. If success: Cache to `config_cache.json`, use server config
3. If fail: Try load from cache
4. If no cache: Use `AppConfig.defaults()`

#### 9.12.7 Files

| File | Purpose |
|------|---------|
| `supabase/migrations/20260128_create_app_config.sql` | Database table with JSONB schema |
| `supabase/migrations/20260128_update_app_launch_sync.sql` | RPC returns config |
| `lib/models/app_config.dart` | Typed model with nested classes |
| `lib/services/config_cache_service.dart` | Local JSON caching |
| `lib/services/remote_config_service.dart` | Singleton service |
| `test/services/remote_config_service_test.dart` | Unit tests (7 tests) |

#### 9.12.8 Services Using RemoteConfigService

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
| **Daily Flip Limit** | ✅ REMOVED | No daily limit — same hex can be flipped multiple times per day |
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
| Leaderboard City/Zone boundaries | Needs proposal | Based on H3 resolution (Res 8 = Zone, Res 6 = City) |
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
| 1 | Removed geographic scope filter | **리팩토링/UI** | Removed Zone/City/All scope dropdown - now shows all users |
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
- Updated Leaderboard boundaries note (H3 Res 8 = Zone, Res 6 = City)

**Updated: Next Steps**
- Reprioritized: `app_launch_sync` RPC now Priority 1
- Added: Home Hex display to profile/leaderboard screens (Priority 6)

### 2026-01-26 (Session 1)

**Major cost optimization updates:**
- §2.5.2: Changed multiplier from "Simultaneous Runner" (real-time) to "Yesterday's Check-in" (daily batch)
- §2.5.3: Added "The Final Sync" — no server communication during runs
- §2.6: Added Home Hex System for ranking scope (ZONE/CITY/ALL)
- §4.1: Updated RunSummary model with `endTime`, `buffMultiplier`
- §9.1-9.3: Selected battery-first GPS settings
- §9.6: Added Data Synchronization Strategy section
- Added SQL functions: `calculate_yesterday_checkins()`, `finalize_run()`
- Updated Appendix B examples

---

*This document is the single source of truth for RunStrict game rules, UI structure, and data architecture. All implementations must align with this specification.*
