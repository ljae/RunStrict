# Draft: RunStrict Architecture Change - 40-Day Season & Two Home-Hex System

## Requirements (confirmed from user request)

1. **Season Duration Change**: 280 days → 40 days
   - Update `app_config.dart` default: `durationDays: 40`
   - Update SQL migration for server default
   - Update tests expecting 280

2. **Two Home-Hex Concepts** (NEW):
   - **location-home-hex**: Dynamic, for MapScreen display (current GPS location's H3 parent)
   - **season-home-hex**: Fixed for season, set once at season participation (for Leaderboard)
   - Add `seasonHomeHex` to UserModel and database

3. **MapScreen Scope**: H3 Parent Cell fixed regions
   - Remove per-user k-ring approach for CITY/ALL
   - Use `location-home-hex` to determine which fixed H3 Parent Cell to show
   - CITY = all hexes within the Res 6 parent cell containing current location
   - ALL = all hexes within the Res 4 parent cell containing current location

4. **Leaderboard Scope**: H3 Parent Cell fixed regions
   - Uses **season-home-hex** (not current location)
   - MY LEAGUE = All users with same Res 4 parent cell as user's season-home-hex
   - GLOBAL = All users, no filter

5. **Multiplier Advantage**:
   - User can flip hexes in ANY region (not restricted)
   - Multiplier bonus ONLY applies when flipping within season-home-hex's parent cell region
   - Flips outside home region = 1x points (no multiplier)

6. **Dummy Data**: 4 years of run history (2022-present)
   - ~1,460 daily runs (365 days × 4 years)
   - 5-10km distance per run
   - Realistic pace, CV, hexes colored
   - Team distribution (red/blue)

---

## Current Architecture Analysis

### Season Config
- **File**: `lib/models/app_config.dart` (line 99-100)
- **Current**: `durationDays: 280`
- **Used by**: `SeasonService` for D-day countdown

### Home Hex System (CURRENT - SINGLE CONCEPT)
- **UserModel.homeHex**: Single field (Res 9), set once on first GPS fix
- **PrefetchService**: Sets `_homeHex` from GPS, computes parents at Res 8/6/4
- **Used for**:
  - MapScreen CITY/ALL hex generation (k-ring from home hex center)
  - Leaderboard scope filtering (same parent cell matching)
  - Data prefetching boundary

### MapScreen Hex Generation (CURRENT)
- **ZONE**: k-ring(5) from camera center (~91 hexes)
- **CITY**: k-ring(10) from home hex center (~331 hexes)
- **ALL**: k-ring(35) from home hex center (~3,781 hexes)

### Leaderboard Filtering (CURRENT)
- Uses `filterByScope()` which compares home hex parent cells
- `LeagueScope` enum in screen (myLeague, globalTop100) - partially connected

### Multiplier System (CURRENT)
- Yesterday's Check-in Multiplier (crew-based)
- NO region-based restrictions currently
- Formula: `points = flipped_hexes × crew_multiplier`

### Local Storage runs Table
- Columns: id, startTime, endTime, distanceKm, durationSeconds, avgPaceSecPerKm, hexesColored, teamAtRun, isPurpleRunner, cv

---

## Technical Decisions (CONFIRMED)

### 1. season-home-hex Setting Trigger
**DECISION**: First app launch of the season (from GPS)
- Set from GPS on first login of the season
- Not from first run

### 2. H3 Parent Cell Boundaries for MapScreen
**DECISION**: Strict boundary
- Only show hexes within the parent cell
- Clean boundary, consistent with "fixed region" concept

### 3. Multiplier Region Definition
**DECISION**: Res 4 - ALL scope (~22.6km)
- Same as MY LEAGUE leaderboard
- Consistent with leaderboard filtering

### 4. Dummy Data Distribution
**DECISION**: 50/50 Red/Blue
- Even distribution, no purple
- Run summaries only (no route points)

---

## Research Findings

### Files That Need Changes

**Season Duration (280 → 40)**:
- `lib/models/app_config.dart` - SeasonConfig.defaults()
- `supabase/migrations/20260128_create_app_config.sql` - default value
- Tests referencing 280

**Two Home-Hex System**:
- `lib/models/user_model.dart` - add seasonHomeHex field
- `lib/services/prefetch_service.dart` - separate location-home-hex logic
- `lib/providers/leaderboard_provider.dart` - use seasonHomeHex for filtering
- Database migration - add season_home_hex column
- Supabase RPC updates

**MapScreen Parent Cell Boundaries**:
- `lib/widgets/hexagon_map.dart` - change CITY/ALL generation logic
- `lib/services/hex_service.dart` - add method to get all children of parent cell

**Multiplier Region Bonus**:
- `lib/services/crew_multiplier_service.dart` or new service
- `lib/providers/run_provider.dart` - check if hex is in home region
- `supabase/migrations/...` - server-side validation update

**Dummy Data**:
- New script or migration to insert into local SQLite `runs` table
- ~1,460 run records

---

## Scope Boundaries

### INCLUDE
- Season duration change (280 → 40)
- Two home-hex data model (location vs season)
- MapScreen parent cell boundary display
- Leaderboard using season-home-hex
- Multiplier home-region bonus logic
- Dummy data generation

### EXCLUDE (per user request)
- Season home-hex setting UI
- Any UI for choosing/changing home region

---

## Open Questions

**ALL RESOLVED** - Ready for plan generation.
