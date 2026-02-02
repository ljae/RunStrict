# Team-Based Buff Matrix Implementation

## TL;DR

> **Quick Summary**: Replace the Crew-Based Multiplier system with a new Team-Based Buff Matrix that rewards city/server dominance. RED rewards elite performers, BLUE rewards all participants equally, PURPLE scales with participation rate. Crew system completely removed.
> 
> **Deliverables**:
> - Updated DEVELOPMENT_SPEC.md with new buff rules
> - BuffConfig replacing CrewConfig in app_config.dart
> - buff_service.dart replacing crew_multiplier_service.dart
> - PostgreSQL daily batch job for dominance calculation
> - Updated finalize_run RPC for new validation
> - Deleted crew-related files (5 files)
> 
> **Estimated Effort**: Large (3-5 days)
> **Parallel Execution**: YES - 3 waves
> **Critical Path**: Spec Update → DB Migration → Buff Service → Run Provider Integration

---

## Context

### Original Request
Replace the existing "Yesterday's Check-in Multiplier" (crew-based) system with a new Team-Based Buff Matrix system based on city/server dominance.

### Interview Summary
**Key Decisions**:
- **Controlled Hexes**: Yesterday's midnight snapshot (last_runner_team as of midnight)
- **Elite City Assignment**: User's home_hex City (Res 6 parent)
- **All Range Bonus**: Additive (+1x, not multiplicative)
- **Purple Visual Effects**: REMOVED (no visual effects needed)
- **Buff Timing**: At run START (motivational, known before running)
- **Crew System**: COMPLETELY REMOVED (no social features)
- **Migration**: IMMEDIATE rollout (mid-season, keep existing points)
- **Configuration**: All thresholds server-configurable via RemoteConfigService

**Research Findings**:
- H3 Resolution 6 already defined as "City" level in `h3_config.dart` (36 km², ~3.2km edge)
- PostgreSQL `h3_cell_to_parent()` function available for hex aggregation
- `pg_cron` can schedule daily jobs at midnight
- Current `finalize_run` RPC validates points server-side
- `RemoteConfigService` implements server → cache → defaults fallback chain
- Crew files to delete: `crew_model.dart`, `crew_provider.dart`, `crew_screen.dart`, `crew_multiplier_service.dart`, `crew_avatar.dart`

### Key Rules Summary

**Team Buff Matrix** (based on YESTERDAY's data):

| Team | Target Type | City Leader (1st) | City Non-Leader | All Range Bonus |
|------|-------------|-------------------|-----------------|-----------------|
| RED | Top 20% Elite | 3x | 2x | +1x |
| RED | Bottom 80% Common | 1x | 1x | +1x |
| BLUE | All Participants | 2x | 1x | +1x |
| PURPLE | All Participants | [Rate-based] | [Rate-based] | None |

**Purple Participation Rate Tiers**:

| Yesterday Rate (R) | Buff |
|-------------------|------|
| R ≥ 60% | 3x |
| 30% ≤ R < 60% | 2x |
| R < 30% | 1x |

**Definitions**:
- **City Dominance**: Team with most `last_runner_team` hexes in City (Res 6) as of midnight
- **All Range Dominance**: Team with most controlled hexes server-wide as of midnight
- **Elite (RED only)**: Top 20% by YESTERDAY's Flip Points within that City's RED runners
- **Purple Rate**: (Purple users who ran yesterday in City) / (Total Purple users in City)

**Purple Defection Change**: Points now PRESERVED (was: reset to 0)

---

## Work Objectives

### Core Objective
Replace the crew-based multiplier system with a team-based buff system that rewards city and server-wide dominance, removing all crew functionality.

### Concrete Deliverables
1. `DEVELOPMENT_SPEC.md` - Rewritten §2.3, §2.5, §2.8 with new buff rules
2. `lib/models/app_config.dart` - BuffConfig replacing CrewConfig
3. `lib/services/buff_service.dart` - New service fetching/caching user buff
4. `lib/services/supabase_service.dart` - New RPC method for buff lookup
5. `supabase/migrations/008_buff_system.sql` - Daily buff calculation + storage
6. `lib/providers/run_provider.dart` - Use BuffService instead of CrewMultiplierService
7. **DELETED**: crew_model.dart, crew_provider.dart, crew_screen.dart, crew_multiplier_service.dart, crew_avatar.dart
8. `lib/screens/home_screen.dart` - Remove Crew tab from navigation

### Definition of Done
- [ ] `flutter analyze` passes with no errors
- [ ] `flutter test` passes
- [ ] App launches and displays buff multiplier before run starts
- [ ] finalize_run RPC validates points with new buff logic
- [ ] No crew-related code remains in codebase

### Must Have
- All buff thresholds server-configurable via RemoteConfigService
- Buff calculated at midnight, cached on app launch
- Points preserved on Purple defection
- Immediate rollout (no season reset required)

### Must NOT Have (Guardrails)
- NO crew social features (chat, membership, management)
- NO purple visual effects (particles, glow)
- NO new team selection flow changes
- NO changes to hex capture mechanics (only multiplier changes)
- NO real-time buff updates (daily batch only)

---

## Verification Strategy (MANDATORY)

### Test Decision
- **Infrastructure exists**: YES (flutter test configured)
- **User wants tests**: YES (TDD where practical)
- **Framework**: flutter_test

### TDD Approach
Each service/model task follows RED-GREEN-REFACTOR where practical. DB migrations verified via SQL assertions.

---

## Execution Strategy

### Parallel Execution Waves

```
Wave 1 (Start Immediately - Documentation + Schema):
├── Task 1: DEVELOPMENT_SPEC.md update [no dependencies]
├── Task 2: BuffConfig in app_config.dart [no dependencies]
└── Task 3: PostgreSQL migration (tables + functions) [no dependencies]

Wave 2 (After Wave 1):
├── Task 4: buff_service.dart [depends: 2, 3]
├── Task 5: Update supabase_service.dart [depends: 3]
└── Task 6: Update app_launch_sync RPC [depends: 3]

Wave 3 (After Wave 2):
├── Task 7: Update run_provider.dart [depends: 4]
├── Task 8: Update finalize_run RPC [depends: 3]
└── Task 9: Delete crew files + update navigation [depends: 7]

Wave 4 (Final - Integration):
└── Task 10: Integration test + manual verification [depends: all]

Critical Path: Task 1 → Task 2 → Task 4 → Task 7 → Task 10
Parallel Speedup: ~40% faster than sequential
```

### Dependency Matrix

| Task | Depends On | Blocks | Can Parallelize With |
|------|------------|--------|---------------------|
| 1 | None | None | 2, 3 |
| 2 | None | 4 | 1, 3 |
| 3 | None | 4, 5, 6, 8 | 1, 2 |
| 4 | 2, 3 | 7 | 5, 6 |
| 5 | 3 | None | 4, 6 |
| 6 | 3 | None | 4, 5 |
| 7 | 4 | 9 | 8 |
| 8 | 3 | 10 | 7 |
| 9 | 7 | 10 | 8 |
| 10 | All | None | None (final) |

### Agent Dispatch Summary

| Wave | Tasks | Recommended Approach |
|------|-------|---------------------|
| 1 | 1, 2, 3 | Parallel: spec writer, dart config, SQL |
| 2 | 4, 5, 6 | Parallel: dart services, SQL RPC |
| 3 | 7, 8, 9 | Parallel: provider update, SQL update, file deletion |
| 4 | 10 | Sequential: final integration |

---

## TODOs

### Wave 1: Foundation (Parallel)

- [ ] 1. Update DEVELOPMENT_SPEC.md with Team-Based Buff Matrix

  **What to do**:
  - Rewrite §2.3 (Crew System) → Remove entirely or mark as "DEPRECATED - See §2.10"
  - Rewrite §2.5.2 (Yesterday's Check-in Multiplier) → Replace with Team-Based Buff Matrix
  - Add new §2.10 (Team-Based Buff System) with complete rules
  - Update §2.8 (Purple Crew) → Remove crew references, update defection to preserve points
  - Update §3.2.7 (Crew Screen) → Mark as REMOVED
  - Update §4.1 (Client Models) → Remove CrewModel, add BuffState
  - Update navigation diagram in §3.1 → Remove Crew tab

  **Must NOT do**:
  - Change hex capture mechanics (§2.4)
  - Modify season/reset rules (§2.1, §2.9)
  - Alter CV/Stability scoring (§2.6)

  **Recommended Agent Profile**:
  - **Category**: `writing`
    - Reason: Documentation-focused task requiring clear technical writing
  - **Skills**: None required (markdown editing)

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Tasks 2, 3)
  - **Blocks**: None
  - **Blocked By**: None

  **References**:
  - `DEVELOPMENT_SPEC.md:119-158` - Current §2.3 Crew System to rewrite
  - `DEVELOPMENT_SPEC.md:224-275` - Current §2.5 Economy section to update
  - `DEVELOPMENT_SPEC.md:427-455` - Current §2.8 Purple Crew to update
  - `DEVELOPMENT_SPEC.md:633-645` - Current §3.2.7 Crew Screen to remove
  - Draft: `.sisyphus/drafts/team-buff-matrix.md` - Contains new rules tables

  **Acceptance Criteria**:
  - [ ] §2.3 removed or marked deprecated
  - [ ] §2.5.2 replaced with Team-Based Buff Matrix documentation
  - [ ] New §2.10 contains complete buff rules with tables
  - [ ] §2.8 updated: Purple defection preserves points
  - [ ] §3.2.7 marked as REMOVED
  - [ ] Navigation diagram no longer shows Crew tab
  - [ ] All tables follow existing DEVELOPMENT_SPEC formatting style

  **Commit**: YES
  - Message: `docs(spec): replace crew multiplier with team-based buff matrix`
  - Files: `DEVELOPMENT_SPEC.md`

---

- [ ] 2. Add BuffConfig to app_config.dart (replace CrewConfig)

  **What to do**:
  - Create `BuffConfig` class with all configurable thresholds
  - Replace `CrewConfig` import/usage in `AppConfig`
  - Implement `fromJson()`, `toJson()`, `copyWith()`, `defaults()`
  - Update `AppConfig.fromJson()` to parse `buffConfig` instead of `crewConfig`

  **BuffConfig structure**:
  ```dart
  class BuffConfig {
    // RED team thresholds
    final double redEliteThreshold; // 0.20 = top 20%
    final int redEliteCityLeaderBuff; // 3
    final int redEliteNonLeaderBuff; // 2
    final int redCommonCityLeaderBuff; // 1
    final int redCommonNonLeaderBuff; // 1
    
    // BLUE team thresholds
    final int blueUnionCityLeaderBuff; // 2
    final int blueUnionNonLeaderBuff; // 1
    
    // All Range bonus (additive)
    final int allRangeBonus; // 1
    
    // PURPLE thresholds
    final double purpleHighTierThreshold; // 0.60
    final double purpleMidTierThreshold; // 0.30
    final int purpleHighTierBuff; // 3
    final int purpleMidTierBuff; // 2
    final int purpleLowTierBuff; // 1
  }
  ```

  **Must NOT do**:
  - Delete CrewConfig yet (will be removed in Task 9)
  - Modify other config classes

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Straightforward Dart class addition following existing pattern
  - **Skills**: None required (follows existing AppConfig pattern)

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Tasks 1, 3)
  - **Blocks**: Task 4 (buff_service needs BuffConfig)
  - **Blocked By**: None

  **References**:
  - `lib/models/app_config.dart:122-149` - CrewConfig pattern to follow
  - `lib/models/app_config.dart:36-56` - fromJson pattern
  - `lib/models/app_config.dart:70-86` - copyWith pattern

  **Acceptance Criteria**:
  - [ ] `BuffConfig` class exists with all 13 configurable fields
  - [ ] `BuffConfig.defaults()` returns sensible defaults matching spec
  - [ ] `BuffConfig.fromJson()` handles missing keys with defaults
  - [ ] `AppConfig` includes `buffConfig` field
  - [ ] `flutter analyze lib/models/app_config.dart` passes

  ```bash
  # Verify BuffConfig defaults
  dart -e "import 'lib/models/app_config.dart'; print(BuffConfig.defaults().toJson());"
  ```

  **Commit**: YES
  - Message: `feat(config): add BuffConfig for team-based buff system`
  - Files: `lib/models/app_config.dart`

---

- [ ] 3. Create PostgreSQL migration for buff system

  **What to do**:
  - Create `supabase/migrations/008_buff_system.sql`
  - Create `daily_buff_stats` table to store calculated buffs
  - Create `calculate_daily_buffs()` function for nightly batch job
  - Create `get_user_buff()` function for client lookup
  - Schedule via pg_cron at 00:05 GMT+2 (after midnight)

  **Tables**:
  ```sql
  -- Store daily calculated buff data
  CREATE TABLE daily_buff_stats (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    stat_date DATE NOT NULL,
    -- City dominance
    city_hex TEXT NOT NULL, -- H3 Res 6 hex
    dominant_team TEXT, -- 'red', 'blue', 'purple', or NULL
    red_hex_count INTEGER DEFAULT 0,
    blue_hex_count INTEGER DEFAULT 0,
    purple_hex_count INTEGER DEFAULT 0,
    -- For RED elite calculation
    red_elite_threshold_points INTEGER, -- Top 20% flip point threshold
    -- For PURPLE participation rate
    purple_participation_rate DOUBLE PRECISION, -- 0.0 to 1.0
    created_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(stat_date, city_hex)
  );

  -- Store all-range (server-wide) dominance
  CREATE TABLE daily_all_range_stats (
    stat_date DATE PRIMARY KEY,
    dominant_team TEXT,
    red_hex_count INTEGER DEFAULT 0,
    blue_hex_count INTEGER DEFAULT 0,
    purple_hex_count INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT now()
  );
  ```

  **Functions**:
  - `calculate_daily_buffs()`: Runs at midnight, populates above tables
  - `get_user_buff(p_user_id UUID)`: Returns user's current buff multiplier

  **Must NOT do**:
  - Modify existing tables (hexes, users, run_history)
  - Delete crew-related RPC functions yet

  **Recommended Agent Profile**:
  - **Category**: `ultrabrain`
    - Reason: Complex SQL with H3 functions, aggregation, and scheduling
  - **Skills**: None (pure SQL)

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Tasks 1, 2)
  - **Blocks**: Tasks 4, 5, 6, 8
  - **Blocked By**: None

  **References**:
  - `supabase/migrations/002_rpc_functions.sql:55-66` - calculate_yesterday_checkins pattern
  - `supabase/migrations/002_rpc_functions.sql:74-187` - finalize_run pattern
  - `lib/models/app_config.dart:312-336` - HexConfig shows resolution values
  - Librarian research: h3_cell_to_parent(), DISTINCT ON pattern, pg_cron scheduling

  **Acceptance Criteria**:
  - [ ] Migration file exists at `supabase/migrations/008_buff_system.sql`
  - [ ] `daily_buff_stats` table created with correct schema
  - [ ] `daily_all_range_stats` table created
  - [ ] `calculate_daily_buffs()` function compiles without errors
  - [ ] `get_user_buff()` function returns correct multiplier
  - [ ] pg_cron schedule created for daily execution

  ```sql
  -- Verify functions exist after migration
  SELECT routine_name FROM information_schema.routines 
  WHERE routine_schema = 'public' 
  AND routine_name IN ('calculate_daily_buffs', 'get_user_buff');
  ```

  **Commit**: YES
  - Message: `feat(db): add buff system tables and daily calculation functions`
  - Files: `supabase/migrations/008_buff_system.sql`

---

### Wave 2: Service Layer (Parallel, after Wave 1)

- [ ] 4. Create buff_service.dart

  **What to do**:
  - Create `lib/services/buff_service.dart`
  - Implement singleton pattern (like RemoteConfigService)
  - Fetch user buff via `SupabaseService.getUserBuff()`
  - Cache buff for session (invalidated on app resume)
  - Expose `int get multiplier` for use in RunProvider
  - Support run freezing (like RemoteConfigService.freezeForRun)

  **Class structure**:
  ```dart
  class BuffService with ChangeNotifier {
    int _multiplier = 1;
    bool _isLoading = false;
    BuffBreakdown? _breakdown; // For UI display

    int get multiplier => _frozenMultiplier ?? _multiplier;
    
    Future<void> loadBuff(String userId) async { ... }
    void freezeForRun() { ... }
    void unfreezeAfterRun() { ... }
  }
  
  class BuffBreakdown {
    final int baseMultiplier;
    final int allRangeBonus;
    final int total;
    final String reason; // e.g., "RED Elite, City Leader"
  }
  ```

  **Must NOT do**:
  - Modify CrewMultiplierService (deleted in Task 9)
  - Add UI components

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Straightforward Dart service following existing patterns
  - **Skills**: None (follows CrewMultiplierService pattern)

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 2 (with Tasks 5, 6)
  - **Blocks**: Task 7 (run_provider needs BuffService)
  - **Blocked By**: Tasks 2, 3

  **References**:
  - `lib/services/crew_multiplier_service.dart:1-89` - Pattern to follow/replace
  - `lib/services/remote_config_service.dart:112-122` - Freeze pattern
  - `lib/models/app_config.dart` - BuffConfig for threshold access

  **Acceptance Criteria**:
  - [ ] `BuffService` class exists with singleton pattern
  - [ ] `loadBuff()` fetches from Supabase and caches
  - [ ] `freezeForRun()` / `unfreezeAfterRun()` work correctly
  - [ ] `flutter analyze lib/services/buff_service.dart` passes

  ```bash
  flutter analyze lib/services/buff_service.dart
  ```

  **Commit**: YES
  - Message: `feat(service): add BuffService for team-based multiplier`
  - Files: `lib/services/buff_service.dart`

---

- [ ] 5. Update supabase_service.dart with buff RPC

  **What to do**:
  - Add `getUserBuff(String userId)` method
  - Call `get_user_buff` RPC function
  - Return `BuffResult` with multiplier and breakdown

  **Must NOT do**:
  - Remove existing crew-related methods yet (Task 9)

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Simple RPC wrapper addition
  - **Skills**: None

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 2 (with Tasks 4, 6)
  - **Blocks**: None
  - **Blocked By**: Task 3

  **References**:
  - `lib/services/supabase_service.dart` - Existing RPC patterns
  - `supabase/migrations/008_buff_system.sql` - get_user_buff signature

  **Acceptance Criteria**:
  - [ ] `getUserBuff()` method exists in SupabaseService
  - [ ] Returns multiplier and breakdown info
  - [ ] Handles errors gracefully (returns 1x on failure)

  **Commit**: YES (groups with Task 4)
  - Message: `feat(service): add BuffService for team-based multiplier`
  - Files: `lib/services/supabase_service.dart`

---

- [ ] 6. Update app_launch_sync RPC to include buff

  **What to do**:
  - Modify `app_launch_sync` in `002_rpc_functions.sql` or add to `008_buff_system.sql`
  - Include `user_buff` in response with multiplier and breakdown
  - Remove `yesterday_multiplier` crew reference

  **Must NOT do**:
  - Break existing response structure (add, don't replace yet)

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Small SQL modification
  - **Skills**: None

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 2 (with Tasks 4, 5)
  - **Blocks**: None
  - **Blocked By**: Task 3

  **References**:
  - `supabase/migrations/002_rpc_functions.sql:195-200` - app_launch_sync structure
  - Task 3 output - get_user_buff function to call

  **Acceptance Criteria**:
  - [ ] `app_launch_sync` response includes `user_buff` object
  - [ ] Buff includes `multiplier`, `breakdown`, and `reason`

  **Commit**: YES (groups with Task 3)
  - Message: `feat(db): add buff system tables and daily calculation functions`
  - Files: `supabase/migrations/008_buff_system.sql`

---

### Wave 3: Integration (Parallel, after Wave 2)

- [ ] 7. Update run_provider.dart to use BuffService

  **What to do**:
  - Replace `CrewMultiplierService` dependency with `BuffService`
  - Update `_handleHexCapture` to use `BuffService.multiplier`
  - Update run start to call `BuffService.freezeForRun()`
  - Update run end to call `BuffService.unfreezeAfterRun()`
  - Remove all crew-related code from RunProvider

  **Must NOT do**:
  - Change hex capture logic (only multiplier source)
  - Modify points calculation formula (base × multiplier)

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Straightforward dependency swap
  - **Skills**: None

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 3 (with Tasks 8, 9)
  - **Blocks**: Task 9
  - **Blocked By**: Task 4

  **References**:
  - `lib/providers/run_provider.dart` - Current CrewMultiplierService usage
  - `lib/services/buff_service.dart` - New service from Task 4

  **Acceptance Criteria**:
  - [ ] No imports of `crew_multiplier_service.dart`
  - [ ] `BuffService` used for multiplier
  - [ ] `freezeForRun()` called at run start
  - [ ] `unfreezeAfterRun()` called at run end
  - [ ] `flutter analyze lib/providers/run_provider.dart` passes

  **Commit**: YES
  - Message: `refactor(provider): use BuffService instead of CrewMultiplierService`
  - Files: `lib/providers/run_provider.dart`

---

- [ ] 8. Update finalize_run RPC for buff validation

  **What to do**:
  - Modify `finalize_run` to accept `p_buff_multiplier` instead of `p_yesterday_crew_count`
  - Update server-side validation: `points ≤ hex_count × buff_multiplier`
  - Call `get_user_buff()` to verify client-provided multiplier

  **Must NOT do**:
  - Change hex update logic
  - Modify run_history schema

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Small SQL modification
  - **Skills**: None

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 3 (with Tasks 7, 9)
  - **Blocks**: Task 10
  - **Blocked By**: Task 3

  **References**:
  - `supabase/migrations/002_rpc_functions.sql:74-187` - Current finalize_run
  - Task 3 output - get_user_buff for verification

  **Acceptance Criteria**:
  - [ ] `finalize_run` accepts `p_buff_multiplier` parameter
  - [ ] Server validates multiplier against `get_user_buff()`
  - [ ] Points calculated as `flips × validated_multiplier`

  **Commit**: YES
  - Message: `feat(db): update finalize_run to use buff multiplier`
  - Files: `supabase/migrations/008_buff_system.sql` (or new migration)

---

- [ ] 9. Delete crew files and update navigation

  **What to do**:
  - Delete `lib/models/crew_model.dart`
  - Delete `lib/providers/crew_provider.dart`
  - Delete `lib/screens/crew_screen.dart`
  - Delete `lib/services/crew_multiplier_service.dart`
  - Delete `lib/widgets/crew_avatar.dart`
  - Remove CrewConfig from `app_config.dart` (keep BuffConfig)
  - Update `lib/screens/home_screen.dart` - remove Crew tab from navigation
  - Update `lib/main.dart` - remove CrewProvider from MultiProvider
  - Fix any remaining imports/references

  **Must NOT do**:
  - Delete user.crew_id column from DB (may be needed for migration)
  - Remove crew-related RPC functions (deprecate, don't delete)

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: File deletion and import cleanup
  - **Skills**: [`git-master`]
    - `git-master`: Atomic commit for file deletions

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 3 (with Tasks 7, 8)
  - **Blocks**: Task 10
  - **Blocked By**: Task 7

  **References**:
  - `lib/models/crew_model.dart` - To delete
  - `lib/providers/crew_provider.dart` - To delete
  - `lib/screens/crew_screen.dart` - To delete
  - `lib/services/crew_multiplier_service.dart` - To delete
  - `lib/widgets/crew_avatar.dart` - To delete
  - `lib/screens/home_screen.dart` - Navigation to update
  - `lib/main.dart` - Provider setup to update

  **Acceptance Criteria**:
  - [ ] All 5 crew files deleted
  - [ ] `CrewConfig` removed from `app_config.dart`
  - [ ] Home screen navigation has 4 tabs (no Crew)
  - [ ] `main.dart` has no CrewProvider
  - [ ] `flutter analyze` passes with no missing import errors
  - [ ] `flutter build` succeeds

  ```bash
  flutter analyze
  flutter build ios --no-codesign
  ```

  **Commit**: YES
  - Message: `refactor(crew): remove crew system completely`
  - Files: Multiple deletions + edits

---

### Wave 4: Final Integration

- [ ] 10. Integration testing and manual verification

  **What to do**:
  - Run full test suite
  - Verify app launches successfully
  - Verify buff is displayed before run starts
  - Test run completion with new multiplier
  - Verify no crew UI remains

  **Recommended Agent Profile**:
  - **Category**: `visual-engineering`
    - Reason: Requires running app and visual verification
  - **Skills**: [`playwright`]
    - `playwright`: For any automated UI verification

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: None (final task)
  - **Blocks**: None
  - **Blocked By**: All previous tasks

  **References**:
  - All modified files from previous tasks

  **Acceptance Criteria**:
  - [ ] `flutter test` - all tests pass
  - [ ] `flutter analyze` - no errors
  - [ ] App launches on iOS simulator
  - [ ] Team selection → Home screen works
  - [ ] Running screen shows buff multiplier
  - [ ] No "Crew" tab visible in navigation
  - [ ] Run completion syncs with new buff logic

  ```bash
  flutter test
  flutter analyze
  flutter run -d ios
  ```

  **Commit**: NO (verification only)

---

## Commit Strategy

| After Task | Message | Files | Verification |
|------------|---------|-------|--------------|
| 1 | `docs(spec): replace crew multiplier with team-based buff matrix` | DEVELOPMENT_SPEC.md | Manual review |
| 2+4+5 | `feat(service): add BuffService for team-based multiplier` | app_config.dart, buff_service.dart, supabase_service.dart | flutter analyze |
| 3+6+8 | `feat(db): add buff system tables and daily calculation functions` | 008_buff_system.sql | SQL syntax check |
| 7 | `refactor(provider): use BuffService instead of CrewMultiplierService` | run_provider.dart | flutter analyze |
| 9 | `refactor(crew): remove crew system completely` | Multiple files | flutter build |

---

## Success Criteria

### Verification Commands
```bash
# Full analysis
flutter analyze

# Run tests
flutter test

# Build verification
flutter build ios --no-codesign

# Check no crew references remain
grep -r "crew" lib/ --include="*.dart" | grep -v "// crew" | wc -l
# Expected: 0 (or only comments)
```

### Final Checklist
- [ ] All "Must Have" features implemented
- [ ] All "Must NOT Have" guardrails respected
- [ ] DEVELOPMENT_SPEC.md fully updated
- [ ] BuffConfig server-configurable
- [ ] PostgreSQL daily batch job scheduled
- [ ] No crew code remains
- [ ] App builds and runs successfully
- [ ] Purple defection preserves points (verified in spec + RPC)
