# RunStrict UI Structure & Screen Specifications

> Detailed UI reference. Read DEVELOPMENT_SPEC.md (index) first.

---

## 1. Navigation Architecture

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
        ├── Manifesto (30-char, editable anytime)
        ├── Sex (Male/Female/Other)
        ├── Birthday
        └── Nationality
```

**Navigation:** Bottom tab bar with horizontal swipe between tabs. Tab order follows current implementation.

---

## 2. Screen Specifications

### 2.1 Team Selection Screen

| Element | Spec |
|---------|------|
| Purpose | Onboarding (first time) + new season re-selection |
| UI | Animated team cards with gradient text |
| Interaction | Tap to select Red or Blue |
| Lock | Cannot be revisited until next season |
| Purple | Not shown here (accessed via Traitor's Gate anytime) |

### 2.2 Home Screen

| Element | Spec |
|---------|------|
| AppBar Left | Empty |
| AppBar Center | FlipPoints Widget |
| AppBar Right | Season Countdown Badge |
| Body | Selected tab content |
| Navigation | Bottom tabs + horizontal swipe |

**FlipPoints Widget Behavior:**
- Animated flip counter showing **season total points** (not today's points)
- Airport departure board style flip animation for each digit
- On each flip: team-colored glow + scale bounce animation
- Uses `FittedBox` to prevent overflow with large numbers (3+ digits)
- Designed for peripheral vision awareness during runs

### 2.3 Map Screen (The Void)

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

**Scope Boundary Layers:**

The map renders geographic scope boundaries using separate GeoJSON sources:

| Layer | Source | Scope | Style |
|-------|--------|-------|-------|
| Province Boundary | `scope-boundary-source` | PROVINCE only | White, 8px, 15% opacity, 4px blur, solid |
| District Boundaries | `district-boundary-source` | PROVINCE only | White, 3px, 12% opacity, 2px blur, dashed [4,3] |

**Province Boundary (PROVINCE scope):**
- Merged outer boundary of all ~7 district (Res 6) hexes — **irregular polygon** (NOT a single hexagon)
- Algorithm: Collect all directed edges → remove shared internal edges (opposite-direction cancel) → chain remaining outer edges into closed polygon
- Uses 7-decimal coordinate precision for edge matching (~1cm accuracy)

**District Boundaries (PROVINCE scope):**
- Individual dashed outlines for each ~7 district hex
- Hidden in DISTRICT and ZONE scopes

**DISTRICT scope:** Single district hex boundary (solid, same style as province)
**ZONE scope:** No boundaries shown

**Merged Outer Boundary Algorithm (`_computeMergedOuterBoundary`):**
- Collects all directed edges from district hex boundaries
- Removes shared internal edges (opposite-direction edges cancel out)
- Chains remaining outer edges into a closed polygon loop
- Uses 7-decimal coordinate precision for edge matching (~1cm)

**GeoJSON Source + FillLayer Pattern:**

The `hexagon_map.dart` widget uses `GeoJsonSource` + `FillLayer` for atomic hex updates without visual flash.

```dart
// Step 1: Create GeoJsonSource
await mapboxMap.style.addSource(
  GeoJsonSource(id: _hexSourceId, data: '{"type":"FeatureCollection","features":[]}'),
);

// Step 2: Create FillLayer with placeholder values
// NOTE: mapbox_maps_flutter FillLayer has strict typing - fillColor expects int?, not List
await mapboxMap.style.addLayer(
  FillLayer(
    id: _hexLayerId,
    sourceId: _hexSourceId,
    fillColor: Colors.grey.toARGB32(),  // placeholder
    fillOpacity: 0.3,
    fillOutlineColor: Colors.grey.toARGB32(),
    fillAntialias: true,
  ),
);

// Step 3: Apply data-driven expressions via setStyleLayerProperty
// This bypasses the strict typing limitation
await mapboxMap.style.setStyleLayerProperty(
  _hexLayerId, 'fill-color', ['to-color', ['get', 'fill-color']],
);
await mapboxMap.style.setStyleLayerProperty(
  _hexLayerId, 'fill-opacity', ['get', 'fill-opacity'],
);
await mapboxMap.style.setStyleLayerProperty(
  _hexLayerId, 'fill-outline-color', ['to-color', ['get', 'fill-outline-color']],
);
```

**GeoJSON Feature Properties**: Each hex feature includes styling properties:
```json
{
  "type": "Feature",
  "geometry": { "type": "Polygon", "coordinates": [...] },
  "properties": {
    "fill-color": "#FF003C",
    "fill-opacity": 0.3,
    "fill-outline-color": "#FF003C"
  }
}
```

**Why This Pattern:**
- Atomic updates: Single `updateGeoJSONSourceFeatures()` call updates all hexes
- No flash: Source data swap is instantaneous
- Data-driven: Per-feature colors read from GeoJSON properties
- Performance: GPU-accelerated fill rendering

### 2.4 Running Screen

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
- Show buff multiplier (e.g., "2x Elite" for RED, "2x District Leader" for BLUE)
- New users without buff data: Show "1x" (default)

**Navigation Camera Architecture:**

The running screen uses `RouteMap` + `SmoothCameraController` for real-time navigation:

| Property | Spec |
|----------|------|
| Bearing Source | GPS heading (primary), route-calculated bearing (fallback from last 5 points, min 3m) |
| Camera Follow | Tracks `liveLocation` — follows ALL GPS points including rejected ones |
| Animation | 1800ms `SmoothCameraController` interpolation (undershoots 2s GPS polling for smooth transitions) |
| Marker Position | Fixed at 67.5% from top; camera padding = 0.35 × viewport height |
| Route Updates | Keep-latest pattern — queues pending updates when busy, never drops |

**GPS Heading Flow:**
```
LocationService (0.5Hz GPS) → LocationPoint.heading
  → RunTracker (pass-through) → RunProvider extracts heading
    → RunState.liveHeading (filters invalid: null, ≤ 0)
      → RunningScreen passes to RouteMap.liveHeading
        → _updateNavigationCamera() uses as primary bearing
```

**Camera-follows-rejected-GPS:**
When GPS is rejected by RunTracker (invalid pace/accuracy), `routeVersion` doesn't increment but `liveLocation` still updates. `RouteMap.didUpdateWidget` detects changed `liveLocation` with unchanged `routeVersion` and calls `_updateCameraForLiveLocation()` — ensuring smooth camera tracking even during GPS rejection.

**Keep-Latest Pattern:**
```dart
// In _processRouteUpdate():
// If _isProcessingRouteUpdate == true:
//   _pendingRouteUpdate = true (flag, don't drop)
// After processing completes:
//   if (_pendingRouteUpdate) → process again
```

### 2.5 Leaderboard Screen

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
- Geographic scope filter (Zone/District/Province) - removed for simplicity
- Team filter tabs - all teams shown together

**Electric Manifesto (`_ElectricManifesto` widget):**
- `ShaderMask` + animated `LinearGradient` flowing left-to-right (3s cycle)
- Gradient between `Colors.white54` (dim) and team color (bright neon)
- Team-colored shadow glow, `GoogleFonts.sora()` italic
- Used in podium cards (top 3) and rank tiles (4th+)

### 2.6 Run History Screen (Calendar)

| Element | Spec |
|---------|------|
| Calendar View | Month/Week/Year view with distance indicators |
| Day Indicators | Distance display per day (e.g., "5.2k") matching week view style |
| ALL TIME Stats | Fixed panel at top: points (primary), distance, pace, stability |
| Period Stats | Smaller panel (copies ALL TIME design): points (primary), distance, pace, stability |
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

### 2.7 Profile Screen

| Element | Spec |
|---------|------|
| Access | Via settings/menu (not a main tab) |
| Manifesto | 30-character declaration, editable anytime |
| Sex | User sex (Male/Female/Other), editable |
| Birthday | User birthday, editable |
| Team | Display only (cannot change mid-season) |
| Season Stats | Total flips, distance, runs |
| Buff Status | Current multiplier breakdown (Elite/District Leader/Province Range) |

---

## 3. Widget Library

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

---

## 4. Theme & Visual Language

### 4.1 Colors

| Token | Hex Code | Usage |
|-------|----------|-------|
| `athleticRed` | `#FF003C` | Red team (FLAME) |
| `electricBlue` | `#008DFF` | Blue team (WAVE) |
| `purple` | `#8B5CF6` | Purple team (CHAOS) |
| `backgroundStart` | `#0F172A` | Dark background |
| `surfaceColor` | `#1E293B` | Card/surface |
| `textPrimary` | `#FFFFFF` | Primary text |
| `textSecondary` | `#94A3B8` | Secondary text |

All colors and styles are centralized in `lib/theme/app_theme.dart` (re-exported via `lib/app/theme.dart`).

```dart
// Team-aware coloring helper
AppTheme.teamColor(isRed)
```

### 4.2 Typography

| Usage | Font | Weight | Notes |
|-------|------|--------|-------|
| Headers | Bebas Neue | Bold | English display text |
| Body | Bebas Neue | Regular | General English text |
| Stats/Numbers | (Current RunningScreen km font) | Medium | Monospace-style for data |
| Korean | Paperlogyfont | Regular | From freesentation.blog |

> **Korean Font Source**: https://freesentation.blog/paperlogyfont

### 4.3 UI Conventions

**Stat Panel Display Order** (all screens follow this order):
1. **Points** (primary/large display)
2. **Distance** (secondary)
3. **Pace** (secondary)
4. **Rank or Stability** (secondary)

Applies to: TeamScreen (yesterday stats), RunHistoryScreen (ALL TIME + period panels), LeaderboardScreen (season stats).

**Pace Format**: Unified across all screens — `X'XX` (apostrophe separator, no trailing `"`).
- Examples: `5'30`, `6'05`, `-'--` (for null/invalid)
- Applied in: `run_provider.dart`, `team_screen.dart`, `run_history_screen.dart`, `leaderboard_screen.dart`

**Google AdMob**: BannerAd displayed on MapScreen via `_NativeAdCard` widget.
- Shows on all scope views (zone, district, province)
- Shows in both portrait and landscape orientations
- `AdService` singleton manages SDK initialization (`lib/core/services/ad_service.dart`)
- Test ad unit IDs during development; replace with production IDs before release

**Landscape Layout**: MapScreen shows ad + zoom selector in column. LeaderboardScreen uses single `CustomScrollView` for full scrollability.

### 4.4 Animation Standards

| Animation | Duration | Curve | Notes |
|-----------|----------|-------|-------|
| Flip point increment | Current implementation | Current implementation | Keep as-is |
| Camera interpolation | Per-frame (60fps) | Linear interpolation | SmoothCameraController |
| Hold button progress | 1.5s | Linear | Start/Stop buttons |

---

## 5. Geographic Scope Reference

**Geographic Scope Categories** (zone/district/province):

| Scope | Enum Value | H3 Resolution | Description |
|-------|------------|---------------|-------------|
| ZONE | `zone` | 8 | Neighborhood (~461m) |
| DISTRICT | `district` | 6 | District (~3.2km) |
| PROVINCE | `province` | 4 | Metro/Regional (server-wide) |

**Location Domain Separation (Home vs GPS):**
- **Server data** (TeamScreen, Leaderboard, hex snapshot, season register) → always **home hex**
- **MapScreen** district/province views → **GPS hex** when outside province, home hex otherwise
- **Hex capture** → **disabled** when outside province (floating banner on MapScreen)
- **ProfileScreen** → shows BOTH registered home and GPS location when outside province

`PrefetchService` getters: `homeHex`/`homeHexCity`/`homeHexAll` (server anchor), `gpsHex`/`getGpsHexAtScope()` (map display), `isOutsideHomeProvince` (detection).
