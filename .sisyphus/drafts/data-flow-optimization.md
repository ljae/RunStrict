# Draft: Data Flow Optimization for RunStrict

## Requirements (confirmed from user request)

1. **Clarify minimum data storage** - what to store locally vs server
2. **Optimize data communication** - minimize server calls
3. **Remove crew system completely** - apply team-based buff
4. **Clarify all rules and data flow** - document working variables
5. **Update documentation** - DEVELOPMENT_SPEC.md, AGENTS.md, CLAUDE.md
6. **Apply to Flutter application** - optimize code with detailed comments
7. **Apply to Supabase database** - optimize data structures
8. **Create realistic test data** - for Season 1 testing (local + server)

## Research Findings

### Current Crew System Status

**DEPRECATED but NOT REMOVED**. Key findings:
- `CrewModel` class: REMOVED (only in docs)
- `crew_provider.dart`: REMOVED
- `crew_screen.dart`: REMOVED
- `supabase_service.dart`: ~200 lines of deprecated crew methods (marked @deprecated)
- `UserModel`: Still has `crewId` and `originalAvatar` fields (marked @deprecated)
- `AppConfig.CrewConfig`: Still defines max member limits

### Current BuffService Implementation (WORKING)

- Located at `lib/services/buff_service.dart`
- Singleton with ChangeNotifier
- Methods: `loadBuff()`, `setBuffFromLaunchSync()`, `freezeForRun()`, `unfreezeAfterRun()`
- Database tables: `daily_buff_stats`, `daily_all_range_stats`
- RPC functions: `get_user_buff()`, `calculate_daily_buffs()`
- Run integration: frozen at run start, used for point calculation, unfrozen after

### Team Buff Multipliers (CONFIRMED)

| Team | Condition | Max Multiplier |
|------|-----------|----------------|
| RED (Elite) | Top 20% + City Leader + All Range | 4x |
| RED (Common) | Non-Elite + All Range | 2x |
| BLUE | City Leader + All Range | 3x |
| PURPLE | Participation Rate >= 60% | 3x |

### Current Data Flow Architecture

**Local Storage (SQLite) - 8 tables:**
1. `runs` - RunSummary (lightweight, local history)
2. `routes` - GPS points (cold storage, lazy loaded)
3. `laps` - Per-km lap data for CV
4. `hex_cache` - Prefetched hex colors (ephemeral)
5. `leaderboard_cache` - Rankings (ephemeral)
6. `prefetch_meta` - Home hex and timestamps
7. `sync_queue` - Failed uploads for offline retry

**Server (Supabase) - Key tables:**
1. `users` - Profiles, points, home_hex
2. `hexes` - Last runner team only
3. `run_history` - Lightweight stats (5-year retention)
4. `daily_stats` - Aggregated daily
5. `daily_buff_stats` - City buff data (season only)
6. `daily_all_range_stats` - Server-wide dominance
7. `runs` (partitioned) - Heavy hex_path data (season only)
8. `crews` - DEPRECATED, should be removed

### Communication Pattern ("The Final Sync")

1. **App Launch**: `app_launch_sync()` RPC - single call fetches:
   - User stats
   - User buff (replaces crew multiplier)
   - Hex map (all non-neutral hexes)
   - Leaderboard

2. **Run Completion**: `finalize_run()` RPC - batch uploads:
   - hex_path array
   - buff_multiplier (server-validated)
   - CV data

3. **OnResume**: Refresh hex cache and leaderboard

## Technical Decisions

### Crew Removal Strategy
- DELETE: deprecated crew methods from supabase_service.dart
- DELETE: crewId, originalAvatar from UserModel
- DELETE: CrewConfig from AppConfig
- DELETE: crews table migration
- KEEP: BuffService as the sole multiplier source

### Data Storage Optimization
- LOCAL: runs, routes, laps, sync_queue (permanent)
- LOCAL: hex_cache, leaderboard_cache, prefetch_meta (ephemeral)
- SERVER: users, hexes, run_history, daily_stats, buff tables

### Documentation Updates
- DEVELOPMENT_SPEC.md: Remove all §2.3 Crew references, clean up §4 Data Structure
- AGENTS.md: Remove crew_provider.dart, crew_screen.dart references
- CLAUDE.md: Align with updated AGENTS.md

## Open Questions

1. Should we create a Supabase migration to DROP the `crews` table, or just deprecate the RPC functions?
2. For test data, how many "days" into Season 1 should we simulate?
3. Should the test data include edge cases (empty hexes, purple defectors, elite runners)?

## Scope Boundaries

### INCLUDE:
- Full crew code removal from Flutter
- supabase migration to drop crews table
- Updated DEVELOPMENT_SPEC.md, AGENTS.md, CLAUDE.md
- Flutter code optimization with comments
- Test data for SQLite + Supabase

### EXCLUDE:
- New features
- UI changes beyond crew removal
- Database schema changes beyond crew removal
- Real-time features

## Test Strategy Decision

- **Infrastructure exists**: YES (flutter test)
- **User wants tests**: TBD - need to ask
- **QA approach**: Automated verification via commands
