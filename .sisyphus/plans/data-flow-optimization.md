# RunStrict Data Flow Optimization

## TL;DR

> **Quick Summary**: Remove deprecated crew system, optimize data flow documentation, and create realistic test data for Season 1. All changes leverage the existing BuffService which already replaced the crew multiplier system.
> 
> **Deliverables**:
> - Clean crew code removal from Flutter (~200 lines)
> - Supabase migration to drop crews table and deprecated functions
> - Updated DEVELOPMENT_SPEC.md, AGENTS.md, CLAUDE.md
> - Realistic test data for 20+ users at Day 10 of Season 1
> - Clear data flow documentation (local vs server)
> 
> **Estimated Effort**: Medium (2-3 days)
> **Parallel Execution**: YES - 4 waves
> **Critical Path**: Wave 1 (docs) → Wave 2 (Flutter removal) → Wave 3 (Supabase) → Wave 4 (test data)

---

## Context

### Original Request
Comprehensive optimization of data storage, communication, and flow for RunStrict:
1. Clarify minimum data storage (local vs server)
2. Optimize data communication (minimize server calls)
3. Remove crew system completely (apply team-based buff)
4. Clarify all rules and data flow (document working variables)
5. Update documentation (DEVELOPMENT_SPEC.md, AGENTS.md, CLAUDE.md)
6. Apply to Flutter application (optimize code with comments)
7. Apply to Supabase database (optimize data structures)
8. Create realistic test data (local + server for Season 1)

### Interview Summary
**Key Findings**:
- Crew system already deprecated; BuffService is the working replacement
- CrewModel, crew_provider.dart, crew_screen.dart ALREADY REMOVED
- ~200 lines of deprecated crew methods remain in supabase_service.dart
- UserModel still has deprecated crewId, originalAvatar fields
- "The Final Sync" pattern is correct: app_launch_sync → run → finalize_run
- Team buff multipliers confirmed: RED Elite 4x, RED Common 2x, BLUE 3x, PURPLE 3x

**Research Findings**:
- Local SQLite: 7 tables (runs, routes, laps, hex_cache, leaderboard_cache, prefetch_meta, sync_queue)
- Server Supabase: Key tables (users, hexes, run_history, daily_stats, daily_buff_stats, daily_all_range_stats)
- crews table exists but unused (should be dropped)

### Gap Analysis (Self-Review)

**Identified Gaps (addressed in plan):**
1. No explicit test for crew removal - added TDD approach
2. Documentation inconsistency across 3 files - addressed with cross-reference task
3. Test data locality unclear - specified Seoul city center coordinates
4. Sync queue edge cases - included in test data
5. Purple defection flow - included as edge case in test data

---

## Work Objectives

### Core Objective
Clean removal of deprecated crew system and comprehensive documentation of the current data flow architecture using the team-based buff system.

### Concrete Deliverables
1. `lib/services/supabase_service.dart` - crew methods removed (~200 lines)
2. `lib/models/user_model.dart` - crewId, originalAvatar fields removed
3. `lib/models/app_config.dart` - CrewConfig removed
4. `supabase/migrations/010_remove_crew_system.sql` - DROP crews table + deprecated functions
5. `DEVELOPMENT_SPEC.md` - Updated with clean data flow documentation
6. `AGENTS.md` - Aligned with current architecture
7. `CLAUDE.md` - Aligned with AGENTS.md
8. `test/fixtures/season1_day10_local.sql` - SQLite test dump
9. `supabase/seed/season1_day10_server.sql` - Supabase seed data

### Definition of Done
- [ ] `flutter analyze` passes with 0 errors
- [ ] All crew references removed from codebase
- [ ] Documentation consistency verified across 3 files
- [ ] Test data loads successfully in local SQLite and Supabase

### Must Have
- Complete crew code removal without breaking existing functionality
- BuffService remains sole source of multiplier
- "The Final Sync" pattern preserved
- All 8 deliverables completed

### Must NOT Have (Guardrails)
- NO new features added (this is cleanup only)
- NO changes to BuffService implementation (working correctly)
- NO changes to "The Final Sync" pattern
- NO UI changes beyond crew removal
- NO database schema changes beyond crew table removal
- NO real-time/WebSocket features

---

## Verification Strategy (MANDATORY)

### Test Decision
- **Infrastructure exists**: YES (flutter test)
- **User wants tests**: YES (TDD approach)
- **Framework**: flutter test / bun test for scripts

### TDD Approach for Flutter Changes

Each crew removal task follows RED-GREEN-REFACTOR:

1. **RED**: Write test that imports removed code (should fail after removal)
2. **GREEN**: Remove the code, verify test catches the removal correctly
3. **REFACTOR**: Clean up imports and references

### Automated Verification (ALWAYS include)

**For Flutter code changes:**
```bash
# Agent runs:
flutter analyze
# Assert: 0 errors

flutter test test/models/user_model_test.dart
# Assert: All tests pass, no crewId references
```

**For Supabase migration:**
```bash
# Agent runs via psql or Supabase CLI:
supabase db diff
# Assert: Shows crews table DROP

# Verify table removed:
psql -c "SELECT * FROM information_schema.tables WHERE table_name = 'crews';"
# Assert: 0 rows (table does not exist)
```

**For Documentation:**
```bash
# Agent runs:
grep -r "crew_provider\|crew_screen\|CrewModel" DEVELOPMENT_SPEC.md AGENTS.md CLAUDE.md
# Assert: 0 matches
```

---

## Execution Strategy

### Parallel Execution Waves

```
Wave 1 (Start Immediately - Documentation + Analysis):
├── Task 1: Update DEVELOPMENT_SPEC.md (data flow section)
├── Task 2: Update AGENTS.md (remove crew references)
└── Task 3: Update CLAUDE.md (align with AGENTS.md)

Wave 2 (After Wave 1 - Flutter Code Removal):
├── Task 4: Remove crew methods from supabase_service.dart
├── Task 5: Remove crewId/originalAvatar from UserModel
├── Task 6: Remove CrewConfig from AppConfig
└── Task 7: Clean up any remaining crew imports/references

Wave 3 (After Wave 2 - Supabase Cleanup):
├── Task 8: Create migration 010_remove_crew_system.sql
└── Task 9: Update existing RPC functions to remove crew parameters

Wave 4 (After Wave 3 - Test Data):
├── Task 10: Generate local SQLite test data
└── Task 11: Generate Supabase seed data
```

### Dependency Matrix

| Task | Depends On | Blocks | Can Parallelize With |
|------|------------|--------|---------------------|
| 1 | None | 4, 5, 6 | 2, 3 |
| 2 | None | 4, 5, 6 | 1, 3 |
| 3 | None | 4, 5, 6 | 1, 2 |
| 4 | 1, 2, 3 | 7, 8 | 5, 6 |
| 5 | 1, 2, 3 | 7 | 4, 6 |
| 6 | 1, 2, 3 | 7 | 4, 5 |
| 7 | 4, 5, 6 | 8, 9 | None |
| 8 | 7 | 10, 11 | 9 |
| 9 | 7 | 10, 11 | 8 |
| 10 | 8, 9 | None | 11 |
| 11 | 8, 9 | None | 10 |

### Agent Dispatch Summary

| Wave | Tasks | Recommended Execution |
|------|-------|-----------------------|
| 1 | 1, 2, 3 | Parallel - all documentation tasks independent |
| 2 | 4, 5, 6, 7 | 4, 5, 6 parallel → 7 sequential after |
| 3 | 8, 9 | Parallel - SQL changes independent |
| 4 | 10, 11 | Parallel - test data generation independent |

---

## TODOs

### Wave 1: Documentation Updates

- [ ] 1. Update DEVELOPMENT_SPEC.md with clean data flow

  **What to do**:
  - Remove all crew references from §2.3 (rename to "Team-Based Buff System" - already partially done)
  - Remove CrewModel from §4.1 Client Models
  - Remove crews table from §4.2 Database Schema
  - Add clear data flow diagram showing local vs server storage
  - Update §4.5 Local Storage section with current SQLite tables
  - Ensure buff system documentation is complete and accurate

  **Must NOT do**:
  - Add new features or concepts not already in the system
  - Change the buff calculation logic documentation

  **Recommended Agent Profile**:
  - **Category**: `writing`
    - Reason: Documentation-focused task requiring clear technical writing
  - **Skills**: None required (markdown editing)

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Tasks 2, 3)
  - **Blocks**: Tasks 4, 5, 6
  - **Blocked By**: None

  **References**:
  - `DEVELOPMENT_SPEC.md` - Full file to update
  - `lib/services/buff_service.dart:6-45` - BuffBreakdown class for accurate documentation
  - `supabase/migrations/008_buff_system.sql:1-100` - Buff tables schema for accurate documentation

  **Acceptance Criteria**:
  ```bash
  # Agent runs:
  grep -c "CrewModel\|crew_provider\|crew_screen\|crewId" DEVELOPMENT_SPEC.md
  # Assert: Output is "0"
  
  grep -c "BuffService\|buff_multiplier\|team-based buff" DEVELOPMENT_SPEC.md
  # Assert: Output is >= 5 (buff system documented)
  ```

  **Commit**: YES
  - Message: `docs(spec): remove crew references, document buff-based data flow`
  - Files: `DEVELOPMENT_SPEC.md`

---

- [ ] 2. Update AGENTS.md to remove crew references

  **What to do**:
  - Remove crew_provider.dart, crew_screen.dart from Project Structure
  - Remove CrewModel from Models section
  - Update any crew-related code patterns/examples
  - Ensure BuffService is properly documented in Services section
  - Update Common Patterns section if crew examples exist

  **Must NOT do**:
  - Add new sections not related to cleanup
  - Change working code patterns

  **Recommended Agent Profile**:
  - **Category**: `writing`
    - Reason: Documentation-focused task
  - **Skills**: None required

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Tasks 1, 3)
  - **Blocks**: Tasks 4, 5, 6
  - **Blocked By**: None

  **References**:
  - `AGENTS.md` - Full file to update
  - `lib/services/buff_service.dart` - BuffService for accurate documentation

  **Acceptance Criteria**:
  ```bash
  # Agent runs:
  grep -c "crew_provider\|crew_screen\|CrewModel" AGENTS.md
  # Assert: Output is "0"
  ```

  **Commit**: YES
  - Message: `docs(agents): remove deprecated crew references`
  - Files: `AGENTS.md`

---

- [ ] 3. Update CLAUDE.md to align with AGENTS.md

  **What to do**:
  - Mirror changes from AGENTS.md to CLAUDE.md
  - Ensure consistency between the two files
  - Remove any crew-related examples or references

  **Must NOT do**:
  - Add content not present in AGENTS.md
  - Change the purpose or structure of CLAUDE.md

  **Recommended Agent Profile**:
  - **Category**: `writing`
    - Reason: Documentation-focused task
  - **Skills**: None required

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Tasks 1, 2)
  - **Blocks**: Tasks 4, 5, 6
  - **Blocked By**: None

  **References**:
  - `CLAUDE.md` - Full file to update
  - `AGENTS.md` - Reference for consistency

  **Acceptance Criteria**:
  ```bash
  # Agent runs:
  grep -c "crew_provider\|crew_screen\|CrewModel" CLAUDE.md
  # Assert: Output is "0"
  
  # Verify consistency with AGENTS.md Project Structure
  diff <(grep -A 50 "Project Structure" AGENTS.md) <(grep -A 50 "Project Structure" CLAUDE.md) | head -20
  # Assert: Minimal or no differences in structure
  ```

  **Commit**: YES
  - Message: `docs(claude): align with AGENTS.md, remove crew references`
  - Files: `CLAUDE.md`

---

### Wave 2: Flutter Code Removal

- [ ] 4. Remove crew methods from supabase_service.dart

  **What to do**:
  - Delete `getCrewMultiplier()` method (lines ~20-26)
  - Delete `getYesterdayCrewCount()` method (lines ~88-94)
  - Delete `fetchCrewsByTeam()` method (lines ~144-152)
  - Delete `getCrewById()` method (lines ~157-166)
  - Delete `createCrew()` method (lines ~172-201)
  - Delete `joinCrew()` method (lines ~207-251)
  - Delete `leaveCrew()` method (lines ~258-288)
  - Delete `fetchCrewMembers()` method (lines ~292-330)
  - Total removal: ~200 lines of deprecated code
  - Add comment documenting buff system as replacement

  **Must NOT do**:
  - Remove BuffService-related methods (`getUserBuff`, etc.)
  - Change working RPC methods (`finalizeRun`, `appLaunchSync`)

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Straightforward code deletion task
  - **Skills**: [`moai-lang-flutter`]
    - `moai-lang-flutter`: Flutter/Dart expertise for safe removal

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 2 (with Tasks 5, 6)
  - **Blocks**: Task 7
  - **Blocked By**: Tasks 1, 2, 3

  **References**:
  - `lib/services/supabase_service.dart:19-330` - All crew methods marked @deprecated
  - `lib/services/buff_service.dart:96-108` - getUserBuff() method (KEEP this)

  **Acceptance Criteria**:
  ```bash
  # Agent runs:
  grep -c "getCrewMultiplier\|fetchCrewsByTeam\|joinCrew\|leaveCrew" lib/services/supabase_service.dart
  # Assert: Output is "0"
  
  flutter analyze lib/services/supabase_service.dart
  # Assert: 0 errors
  
  # Verify getUserBuff still exists
  grep -c "getUserBuff" lib/services/supabase_service.dart
  # Assert: Output is "1" (method still exists)
  ```

  **Commit**: YES
  - Message: `refactor(supabase): remove deprecated crew methods (~200 lines)`
  - Files: `lib/services/supabase_service.dart`

---

- [ ] 5. Remove crewId and originalAvatar from UserModel

  **What to do**:
  - Remove `crewId` field and all references
  - Remove `originalAvatar` field and all references
  - Remove `clearCrewId` parameter from `copyWith()`
  - Remove `clearOriginalAvatar` parameter from `copyWith()`
  - Update `fromRow()` to remove crew field parsing
  - Update `toRow()` to remove crew field serialization
  - Update `fromJson()` / `toJson()` similarly
  - Update `defectToPurple()` to not reference crew

  **Must NOT do**:
  - Remove other fields (homeHex, seasonHomeHex, etc.)
  - Change buff-related logic

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Straightforward field removal
  - **Skills**: [`moai-lang-flutter`]
    - `moai-lang-flutter`: Dart model expertise

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 2 (with Tasks 4, 6)
  - **Blocks**: Task 7
  - **Blocked By**: Tasks 1, 2, 3

  **References**:
  - `lib/models/user_model.dart:10` - crewId field (deprecated)
  - `lib/models/user_model.dart:15` - originalAvatar field
  - `lib/models/user_model.dart:69-107` - copyWith method with clear* params
  - `lib/models/user_model.dart:112-129` - defectToPurple method

  **Acceptance Criteria**:
  ```bash
  # Agent runs:
  grep -c "crewId\|originalAvatar\|clearCrewId\|clearOriginalAvatar" lib/models/user_model.dart
  # Assert: Output is "0"
  
  flutter analyze lib/models/user_model.dart
  # Assert: 0 errors
  ```

  **Commit**: YES
  - Message: `refactor(model): remove deprecated crew fields from UserModel`
  - Files: `lib/models/user_model.dart`

---

- [ ] 6. Remove CrewConfig from AppConfig

  **What to do**:
  - Remove `CrewConfig` class definition
  - Remove `crewConfig` field from `AppConfig` class
  - Remove crew config from `defaults` factory
  - Remove crew config from `fromJson()` and `toJson()`
  - Update any imports that reference CrewConfig

  **Must NOT do**:
  - Remove BuffConfig (this is the active system)
  - Change other config sections

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Straightforward class removal
  - **Skills**: [`moai-lang-flutter`]
    - `moai-lang-flutter`: Dart config expertise

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 2 (with Tasks 4, 5)
  - **Blocks**: Task 7
  - **Blocked By**: Tasks 1, 2, 3

  **References**:
  - `lib/models/app_config.dart` - Full file, search for CrewConfig

  **Acceptance Criteria**:
  ```bash
  # Agent runs:
  grep -c "CrewConfig\|crewConfig\|maxMembersRegular\|maxMembersPurple" lib/models/app_config.dart
  # Assert: Output is "0"
  
  flutter analyze lib/models/app_config.dart
  # Assert: 0 errors
  ```

  **Commit**: YES
  - Message: `refactor(config): remove deprecated CrewConfig`
  - Files: `lib/models/app_config.dart`

---

- [ ] 7. Clean up remaining crew imports and references

  **What to do**:
  - Search entire codebase for remaining crew references
  - Update `AppStateProvider` to remove crew-related methods
  - Update `LeaderboardProvider` to remove crewId from entries
  - Fix any broken imports
  - Run flutter analyze to catch all issues

  **Must NOT do**:
  - Remove buff-related code
  - Change working provider logic

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Search and cleanup task
  - **Skills**: [`moai-lang-flutter`]
    - `moai-lang-flutter`: Flutter/Dart codebase navigation

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Sequential (after 4, 5, 6)
  - **Blocks**: Tasks 8, 9
  - **Blocked By**: Tasks 4, 5, 6

  **References**:
  - `lib/providers/app_state_provider.dart` - updateCrewId method
  - `lib/providers/leaderboard_provider.dart` - crewId in entries

  **Acceptance Criteria**:
  ```bash
  # Agent runs:
  grep -r "crewId\|CrewModel\|crew_provider\|crew_screen" lib/ --include="*.dart" | grep -v "// @deprecated"
  # Assert: 0 matches (no active crew references)
  
  flutter analyze
  # Assert: 0 errors
  ```

  **Commit**: YES
  - Message: `refactor: clean up remaining crew references across codebase`
  - Files: Multiple files in lib/providers/

---

### Wave 3: Supabase Cleanup

- [ ] 8. Create migration 010_remove_crew_system.sql

  **What to do**:
  - Create new migration file: `supabase/migrations/010_remove_crew_system.sql`
  - DROP TABLE crews CASCADE
  - DROP TABLE active_runs CASCADE (deprecated, was for crew notifications)
  - DROP FUNCTION get_crew_multiplier
  - DROP FUNCTION calculate_yesterday_checkins
  - DROP FUNCTION get_user_multiplier (if exists)
  - Add migration comments explaining deprecation
  - Remove crew_id column from users table

  **Must NOT do**:
  - Drop buff-related tables (daily_buff_stats, daily_all_range_stats)
  - Drop working functions (get_user_buff, calculate_daily_buffs)
  - Modify run_history or runs tables

  **Recommended Agent Profile**:
  - **Category**: `ultrabrain`
    - Reason: Database migration requires careful SQL knowledge
  - **Skills**: [`senior-data-engineer`]
    - `senior-data-engineer`: PostgreSQL migration expertise

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 3 (with Task 9)
  - **Blocks**: Tasks 10, 11
  - **Blocked By**: Task 7

  **References**:
  - `supabase/migrations/001_initial_schema.sql` - Original crews table definition
  - `supabase/migrations/008_buff_system.sql` - Current working buff system
  - `supabase/migrations/002_rpc_functions.sql` - Deprecated crew functions

  **Acceptance Criteria**:
  ```bash
  # Agent runs in Supabase:
  # 1. Apply migration
  supabase db push
  # Assert: Migration succeeds
  
  # 2. Verify crews table dropped
  psql "$DATABASE_URL" -c "SELECT EXISTS (SELECT FROM pg_tables WHERE tablename = 'crews');"
  # Assert: Returns 'f' (false)
  
  # 3. Verify buff tables still exist
  psql "$DATABASE_URL" -c "SELECT EXISTS (SELECT FROM pg_tables WHERE tablename = 'daily_buff_stats');"
  # Assert: Returns 't' (true)
  ```

  **Commit**: YES
  - Message: `migration(db): remove deprecated crew tables and functions`
  - Files: `supabase/migrations/010_remove_crew_system.sql`

---

- [ ] 9. Update existing RPC functions to remove crew parameters

  **What to do**:
  - Update `app_launch_sync()` to remove any crew_info references
  - Update `finalize_run()` to ensure no p_yesterday_crew_count parameter
  - Update `reset_season()` to remove crews table from reset
  - Verify all functions use buff system instead

  **Must NOT do**:
  - Change buff calculation logic
  - Modify finalize_run's hex processing
  - Break app_launch_sync return structure

  **Recommended Agent Profile**:
  - **Category**: `ultrabrain`
    - Reason: RPC function modification requires PostgreSQL expertise
  - **Skills**: [`senior-data-engineer`]
    - `senior-data-engineer`: PostgreSQL function expertise

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 3 (with Task 8)
  - **Blocks**: Tasks 10, 11
  - **Blocked By**: Task 7

  **References**:
  - `supabase/migrations/008_buff_system.sql:377-463` - Current app_launch_sync
  - `supabase/migrations/008_buff_system.sql:471-595` - Current finalize_run
  - `supabase/migrations/008_buff_system.sql:601-630` - Current reset_season

  **Acceptance Criteria**:
  ```bash
  # Agent runs:
  grep -c "crew_info\|yesterday_crew_count\|p_crew_id" supabase/migrations/010_remove_crew_system.sql
  # Assert: Only in DROP FUNCTION statements (cleanup), not in new function definitions
  
  # Verify app_launch_sync works
  psql "$DATABASE_URL" -c "SELECT public.app_launch_sync('00000000-0000-0000-0000-000000000000'::uuid);"
  # Assert: Returns JSONB with user_buff, no crew_info
  ```

  **Commit**: Groups with Task 8

---

### Wave 4: Test Data Generation

- [ ] 10. Generate local SQLite test data

  **What to do**:
  - Create `test/fixtures/season1_day10_local.sql` for SQLite import
  - Generate data for current user (id matches test setup)
  - Include 15 runs over 10 days with realistic patterns:
    - Distance: 3-10 km per run
    - Pace: 5:30 - 7:30 min/km
    - CV: 5-25% (varied consistency)
  - Include lap data for CV calculation
  - Include route points (simplified, ~50 points per run)
  - Include 3 entries in sync_queue (simulating offline runs)
  - Add hex_cache with ~500 hexes around Seoul city center
  - Use coordinates: Seoul City Hall (37.5665, 126.9780)

  **Must NOT do**:
  - Include crew-related data
  - Generate unrealistic patterns (100km runs, 3:00 pace)

  **Recommended Agent Profile**:
  - **Category**: `ultrabrain`
    - Reason: Realistic data generation requires domain knowledge
  - **Skills**: [`senior-data-engineer`]
    - `senior-data-engineer`: Test data generation expertise

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 4 (with Task 11)
  - **Blocks**: None (final task)
  - **Blocked By**: Tasks 8, 9

  **References**:
  - `lib/storage/local_storage.dart:54-149` - SQLite table definitions
  - `lib/models/run_summary.dart` - RunSummary model for data shape
  - `lib/models/lap_model.dart` - LapModel for CV data

  **Acceptance Criteria**:
  ```bash
  # Agent runs:
  sqlite3 test.db < test/fixtures/season1_day10_local.sql
  # Assert: No errors
  
  sqlite3 test.db "SELECT COUNT(*) FROM runs;"
  # Assert: Returns 15
  
  sqlite3 test.db "SELECT COUNT(*) FROM sync_queue;"
  # Assert: Returns 3
  
  sqlite3 test.db "SELECT COUNT(*) FROM hex_cache;"
  # Assert: Returns ~500
  ```

  **Commit**: YES
  - Message: `test(fixtures): add Season 1 Day 10 local SQLite test data`
  - Files: `test/fixtures/season1_day10_local.sql`

---

- [ ] 11. Generate Supabase seed data

  **What to do**:
  - Create `supabase/seed/season1_day10_server.sql`
  - Generate 25 users with realistic distribution:
    - 10 RED team (2 elite, 8 common)
    - 10 BLUE team (all union)
    - 5 PURPLE team (defectors)
  - Include season_points ranging from 50 to 2000
  - Include run_history entries (5-15 runs per user)
  - Include hexes table with ~2000 colored hexes:
    - 800 RED, 900 BLUE, 300 PURPLE
  - Include daily_buff_stats for 10 days
  - Include daily_all_range_stats for 10 days
  - Use realistic Seoul coordinates (multiple neighborhoods)
  - Include edge cases:
    - User with 0 runs (new signup)
    - User with sync_queue pending (offline)
    - Elite RED user with high flip points
    - Purple defector with preserved points

  **Must NOT do**:
  - Include crews table data (deprecated)
  - Generate data beyond Day 10

  **Recommended Agent Profile**:
  - **Category**: `ultrabrain`
    - Reason: Complex multi-table data generation
  - **Skills**: [`senior-data-engineer`]
    - `senior-data-engineer`: PostgreSQL seed data expertise

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 4 (with Task 10)
  - **Blocks**: None (final task)
  - **Blocked By**: Tasks 8, 9

  **References**:
  - `supabase/migrations/001_initial_schema.sql` - Table definitions
  - `supabase/migrations/008_buff_system.sql:17-45` - Buff tables schema
  - Seoul coordinates reference: City Hall (37.5665, 126.9780), Gangnam (37.4979, 127.0276)

  **Acceptance Criteria**:
  ```bash
  # Agent runs:
  psql "$DATABASE_URL" -f supabase/seed/season1_day10_server.sql
  # Assert: No errors
  
  psql "$DATABASE_URL" -c "SELECT COUNT(*) FROM users WHERE team IS NOT NULL;"
  # Assert: Returns 25
  
  psql "$DATABASE_URL" -c "SELECT team, COUNT(*) FROM users GROUP BY team;"
  # Assert: red=10, blue=10, purple=5
  
  psql "$DATABASE_URL" -c "SELECT COUNT(*) FROM hexes;"
  # Assert: Returns ~2000
  
  psql "$DATABASE_URL" -c "SELECT COUNT(*) FROM daily_buff_stats;"
  # Assert: Returns 10 (one per day)
  ```

  **Commit**: YES
  - Message: `test(seed): add Season 1 Day 10 Supabase seed data (25 users)`
  - Files: `supabase/seed/season1_day10_server.sql`

---

## Commit Strategy

| After Task(s) | Message | Files | Verification |
|---------------|---------|-------|--------------|
| 1 | `docs(spec): remove crew references, document buff-based data flow` | DEVELOPMENT_SPEC.md | grep -c crew |
| 2 | `docs(agents): remove deprecated crew references` | AGENTS.md | grep -c crew |
| 3 | `docs(claude): align with AGENTS.md, remove crew references` | CLAUDE.md | grep -c crew |
| 4 | `refactor(supabase): remove deprecated crew methods (~200 lines)` | supabase_service.dart | flutter analyze |
| 5 | `refactor(model): remove deprecated crew fields from UserModel` | user_model.dart | flutter analyze |
| 6 | `refactor(config): remove deprecated CrewConfig` | app_config.dart | flutter analyze |
| 7 | `refactor: clean up remaining crew references across codebase` | lib/providers/*.dart | flutter analyze |
| 8, 9 | `migration(db): remove deprecated crew tables and functions` | 010_remove_crew_system.sql | supabase db push |
| 10 | `test(fixtures): add Season 1 Day 10 local SQLite test data` | test/fixtures/ | sqlite3 import |
| 11 | `test(seed): add Season 1 Day 10 Supabase seed data (25 users)` | supabase/seed/ | psql import |

---

## Success Criteria

### Verification Commands
```bash
# 1. No crew references in codebase
grep -r "crewId\|CrewModel\|crew_provider\|crew_screen" lib/ --include="*.dart"
# Expected: 0 matches

# 2. Flutter analysis passes
flutter analyze
# Expected: 0 issues

# 3. BuffService still works
grep -c "BuffService\|getUserBuff" lib/services/
# Expected: Multiple matches

# 4. Documentation cleaned
grep -c "crew_provider\|crew_screen" DEVELOPMENT_SPEC.md AGENTS.md CLAUDE.md
# Expected: 0

# 5. Test data loads
sqlite3 /tmp/test.db < test/fixtures/season1_day10_local.sql && echo "Local OK"
# Expected: "Local OK"
```

### Final Checklist
- [ ] All "Must Have" deliverables present
- [ ] All "Must NOT Have" guardrails respected
- [ ] All 11 tasks completed with commits
- [ ] flutter analyze passes with 0 errors
- [ ] Test data successfully loads in both SQLite and Supabase
