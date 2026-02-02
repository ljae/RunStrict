# Draft: Team-Based Buff Matrix Implementation

## Research Findings

### Current Architecture (being replaced)
- **Crew Multiplier**: `CrewMultiplierService` fetches "yesterday's active crew members" via RPC
- **Points Flow**: Client calculates, server validates via `finalize_run` RPC
- **Config Pattern**: `AppConfig` with nested config classes (Season, Crew, GPS, Scoring, Hex, Timing)
- **Remote Config**: Server → Cache → Defaults fallback chain in `RemoteConfigService`
- **Run Freezing**: Config frozen during active run via `freezeForRun()`

### H3 Structure (already implemented)
- **Resolution 9**: Base gameplay hex (~0.1 km²)
- **Resolution 6**: City level (~36 km², contains 343 res-9 hexes)
- **Resolution 5**: "All Range" level
- **Hex Ownership**: `last_runner_team` + `last_flipped_at` in `hexes` table
- **No user_id on hex**: Privacy-optimized, only team color stored

### PostgreSQL H3 Support
- `h3_cell_to_parent(cell, resolution)` for aggregation
- `DISTINCT ON` pattern for finding dominant team per city
- `pg_cron` for scheduled daily jobs (01:00 AM)

### DEVELOPMENT_SPEC.md Structure
- Section 2: Rule Definitions (insert at §2.10)
- Section 4: Data Structure (update schema)
- Appendix: Detailed examples
- Uses tables, mermaid diagrams, quote blocks for design goals

---

## Requirements (confirmed)

### New Buff System Rules
| Team | Target Type | City Leader (1st) | City Non-Leader | All Range Leader (+) |
|------|-------------|-------------------|-----------------|---------------------|
| RED | Top 20% Elite | 3x | 2x | +1x |
| RED | Bottom 80% Common | 1x | 1x | +1x |
| BLUE | All Participants (Union) | 2x | 1x | +1x |
| PURPLE | All Participants | [Rate-based] | [Rate-based] | No change |

### Purple Participation Rate Tiers
| Rate (R) | Buff | Visual Effect |
|----------|------|---------------|
| R ≥ 60% | 3x | Purple particles exploding |
| 30% ≤ R < 60% | 2x | Gauge glowing purple |
| R < 30% | 1x | Faint purple mist |

### Key Definitions
- **City dominance**: Team with most CONTROLLED HEXES in City (H3 Res 6)
- **All Range dominance**: Team with most CONTROLLED HEXES server-wide
- **RED Elite**: Top 20% by YESTERDAY's Flip Points within City's RED runners
- **Purple Rate (R)**: (Purple users who ran yesterday in City) / (Total Purple users in City)

### Changes from Old System
- [x] Crew multiplier REMOVED (no longer affects points)
- [x] Purple defection: Points PRESERVED (was: reset to 0)
- [x] All thresholds server-configurable via RemoteConfigService

---

## Decisions (User Confirmed)

### D1: Controlled Hexes Definition
**DECISION**: Yesterday's midnight snapshot
- Count hexes where `last_runner_team = X` as of midnight yesterday
- Simple, matches current data model

### D2: Elite City Assignment  
**DECISION**: User's home_hex City (Res 6 parent)
- Derive City from Res 6 parent of user's `home_hex`
- Stable, doesn't change daily

### D3: All Range Bonus Math
**DECISION**: Additive (+1x)
- RED Elite City Leader = 3x base + 1x bonus = 4x total

### D4: Purple Visual Effects
**DECISION**: REMOVED - no visual effects needed
- Simplifies implementation significantly

### D5: Buff Display Timing
**DECISION**: At run START (motivational)
- Buff known before running, based on yesterday's data

### D6: Crew System
**DECISION**: COMPLETELY REMOVED
- No crew social features (chat, leaderboard, membership)
- Just team-based buff system
- Delete: crew_model.dart, crew_provider.dart, crew_screen.dart, crew_multiplier_service.dart

### D7: Migration Strategy
**DECISION**: IMMEDIATE rollout
- Apply new buff system mid-season
- Keep existing points intact

### D8: Configuration
**DECISION**: All buff variables server-configurable via RemoteConfigService pattern

---

## Technical Decisions

1. **BuffConfig** replaces CrewConfig in AppConfig
2. **buff_service.dart** replaces crew_multiplier_service.dart
3. **Daily batch job** via pg_cron at midnight calculates:
   - City dominance (team with most hexes per Res 6)
   - All Range dominance (team with most hexes globally)
   - Elite thresholds (top 20% flip points per City per team)
   - Purple participation rates (per City)
4. **User buff lookup** fetched on app launch with `app_launch_sync`
5. **finalize_run RPC** updated to validate with new buff rules

---

## Scope Boundaries

### INCLUDE
- DEVELOPMENT_SPEC.md update (§2.5 rewrite, delete crew sections)
- BuffConfig in app_config.dart (replace CrewConfig)
- buff_service.dart (new service)
- PostgreSQL migrations:
  - daily_buff_stats table
  - calculate_daily_buffs() function
  - pg_cron schedule
  - update finalize_run RPC
- Update run_provider.dart to use BuffService
- Update app_launch_sync RPC
- DELETE crew-related files

### EXCLUDE
- Purple visual effects (user removed this requirement)
- Crew social features (completely removed)
- UI changes beyond removing crew screens
